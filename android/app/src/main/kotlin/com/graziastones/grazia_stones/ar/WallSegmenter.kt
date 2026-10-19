package com.graziastones.grazia_stones.ar

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.Context
import android.util.Log
import com.google.ar.core.Coordinates2d
import com.google.ar.core.Frame
import java.nio.FloatBuffer
import java.util.concurrent.Executors
import kotlin.math.exp

/**
 * Finds the wall pixels in the live camera image, so the stone is drawn only on the wall (not on doors,
 * switchboards, furniture, floor or ceiling). ARCore cannot find plain painted walls; this can.
 *
 * Model: EfficientViT-Seg B1 trained on ADE20K (MIT HAN Lab, Apache-2.0), exported to ONNX at 288x640
 * (portrait, close to the phone's screen aspect). ADE20K class 0 is "wall". Output: 36x80 logits.
 * The mask is produced in VIEW space (row 0 = top of the screen), which is what the wall material samples.
 */
class WallSegmenter(context: Context) {
    companion object {
        private const val TAG = "WallSegmenter"
        // Model input (portrait). The ONNX graph is exported for exactly this size (tool/export_wall_segmenter.py).
        // 160x352 runs ~3x faster than the earlier 288x640 export; a phone CPU took 1.5-2.5 s per frame at the
        // larger size, which made the mask lag far behind the camera.
        const val IN_W = 160
        const val IN_H = 352
        const val MODEL_ASSET = "models/wall_seg_160x352.onnx"
        // Model output is 1/8 of the input; the final mask is 1/2 (edge-aware 4x upsample of the output).
        const val OUT_W = IN_W / 8
        const val OUT_H = IN_H / 8
        const val MASK_W = IN_W / 2
        const val MASK_H = IN_H / 2
        private const val CLASSES = 150
        private const val WALL = 0
        private val MEAN = floatArrayOf(0.485f, 0.456f, 0.406f)
        private val STD = floatArrayOf(0.229f, 0.224f, 0.225f)
    }

    private val env = OrtEnvironment.getEnvironment()
    /** Which execution provider the session ended up on, for the SEG log line. */
    @Volatile var backend = "cpu"
        private set

    private val session: OrtSession = context.assets.open(MODEL_ASSET).use { input ->
        val bytes = input.readBytes()
        // `adb shell setprop debug.grazia.seg_ep nnapi|xnnpack|cpu` picks the backend for an on-device A/B.
        val wanted = runCatching {
            Class.forName("android.os.SystemProperties").getMethod("get", String::class.java)
                .invoke(null, "debug.grazia.seg_ep") as? String
        }.getOrNull()?.takeIf { it.isNotEmpty() } ?: "xnnpack"
        // 3 threads, not all big cores: ARCore tracking and the Flutter UI must keep their share or the AR
        // view stutters and the phone throttles.
        val threads = (Runtime.getRuntime().availableProcessors() / 2).coerceIn(2, 3)
        val attempts = buildList<Pair<String, () -> OrtSession>> {
            if (wanted == "nnapi") add("nnapi" to {
                env.createSession(bytes, OrtSession.SessionOptions().apply { addNnapi(); setIntraOpNumThreads(threads) })
            })
            if (wanted != "cpu") add("xnnpack" to {
                // XNNPACK takes the convolutions; the attention MatMul/Transpose ops stay on the CPU EP, and
                // those ran single-threaded before (intraOp=1), which is why a frame took 1.5-2.5 s.
                env.createSession(bytes, OrtSession.SessionOptions().apply {
                    addXnnpack(mapOf("intra_op_num_threads" to "$threads"))
                    setIntraOpNumThreads(threads)
                })
            })
            add("cpu" to { env.createSession(bytes, OrtSession.SessionOptions().apply { setIntraOpNumThreads(threads) }) })
        }
        var created: OrtSession? = null
        for ((name, make) in attempts) {
            created = runCatching(make).onFailure { Log.w(TAG, "$name unavailable, trying next", it) }.getOrNull()
            if (created != null) { backend = name; break }
        }
        Log.i(TAG, "segmenter backend=$backend threads=$threads")
        created ?: error("no ONNX runtime backend could load the wall model")
    }
    private val worker = Executors.newSingleThreadExecutor()
    @Volatile private var busy = false

    // View-normalized sample grid (x, y per input pixel), mapped to camera-image pixels every request.
    private val viewGrid = FloatArray(IN_W * IN_H * 2).also { g ->
        for (y in 0 until IN_H) for (x in 0 until IN_W) {
            val i = (y * IN_W + x) * 2
            g[i] = (x + 0.5f) / IN_W
            g[i + 1] = (y + 0.5f) / IN_H
        }
    }
    private val imageCoords = FloatArray(IN_W * IN_H * 2)

    /**
     * Grabs the current camera image (on the caller's thread: ARCore needs that) and segments it in the
     * background. [onMask] gets MASK_W x MASK_H wall probabilities (0..255, row 0 = screen top) and the camera
     * brightness (0..1) on the same grid, on the worker thread.
     */
    fun request(frame: Frame, onMask: (ByteArray, FloatArray) -> Unit) {
        if (busy) return
        val image = try { frame.acquireCameraImage() } catch (e: Exception) { return }
        busy = true
        try {
            frame.transformCoordinates2d(Coordinates2d.VIEW_NORMALIZED, viewGrid, Coordinates2d.IMAGE_PIXELS, imageCoords)
            val w = image.width; val h = image.height
            val yP = image.planes[0]; val uP = image.planes[1]; val vP = image.planes[2]
            val yBytes = ByteArray(yP.buffer.remaining()).also { yP.buffer.get(it) }
            val uBytes = ByteArray(uP.buffer.remaining()).also { uP.buffer.get(it) }
            val vBytes = ByteArray(vP.buffer.remaining()).also { vP.buffer.get(it) }
            val yRow = yP.rowStride; val uvRow = uP.rowStride; val uvPix = uP.pixelStride
            val coords = imageCoords.copyOf()
            image.close()
            worker.execute {
                try {
                    val luma = FloatArray(IN_W * IN_H)
                    val input = toInput(coords, w, h, yBytes, uBytes, vBytes, yRow, uvRow, uvPix, luma)
                    val t0 = android.os.SystemClock.elapsedRealtime()
                    var tRun = 0L
                    val mask = OnnxTensor.createTensor(env, input, longArrayOf(1, 3, IN_H.toLong(), IN_W.toLong())).use { tensor ->
                        session.run(mapOf("image" to tensor)).use { out ->
                            tRun = android.os.SystemClock.elapsedRealtime() - t0
                            // Read the logits as one flat buffer: boxing 150x80x36 floats into nested Java
                            // arrays through JNI cost more than the softmax itself.
                            wallProbability((out[0] as OnnxTensor).floatBuffer)
                        }
                    }.let { refineEdges(it, luma) }
                    lastInferenceMs = android.os.SystemClock.elapsedRealtime() - t0
                    lastRunMs = tRun
                    onMask(mask, downsampleLuma(luma))
                } catch (e: Exception) {
                    Log.e(TAG, "segmentation failed", e)
                } finally {
                    busy = false
                }
            }
        } catch (e: Exception) {
            image.close()
            busy = false
            Log.e(TAG, "camera image read failed", e)
        }
    }

    @Volatile var lastInferenceMs = 0L
        private set
    /** Model run only (no softmax / edge refinement), to tell model cost from post-processing cost. */
    @Volatile var lastRunMs = 0L
        private set

    /** Nearest-pixel YUV -> RGB sampling of the view grid into a normalised NCHW tensor. */
    private fun toInput(
        coords: FloatArray, w: Int, h: Int, yB: ByteArray, uB: ByteArray, vB: ByteArray, yRow: Int, uvRow: Int, uvPix: Int,
        luma: FloatArray,
    ): FloatBuffer {
        val plane = IN_W * IN_H
        val buf = FloatBuffer.allocate(3 * plane)
        val arr = buf.array()
        for (i in 0 until plane) {
            val px = coords[i * 2].toInt().coerceIn(0, w - 1)
            val py = coords[i * 2 + 1].toInt().coerceIn(0, h - 1)
            val yy = (yB[py * yRow + px].toInt() and 0xFF).toFloat()
            luma[i] = yy / 255f
            val uvi = (py / 2) * uvRow + (px / 2) * uvPix
            val u = (uB.getOrElse(uvi) { 128.toByte() }.toInt() and 0xFF) - 128f
            val v = (vB.getOrElse(uvi) { 128.toByte() }.toInt() and 0xFF) - 128f
            val r = (yy + 1.402f * v).coerceIn(0f, 255f) / 255f
            val g = (yy - 0.344136f * u - 0.714136f * v).coerceIn(0f, 255f) / 255f
            val b = (yy + 1.772f * u).coerceIn(0f, 255f) / 255f
            arr[i] = (r - MEAN[0]) / STD[0]
            arr[plane + i] = (g - MEAN[1]) / STD[1]
            arr[2 * plane + i] = (b - MEAN[2]) / STD[2]
        }
        return buf
    }

    /** Softmax probability of the wall class per output cell, as 0..255 bytes. [logits] is NCHW, N = 1. */
    private fun wallProbability(logits: FloatBuffer): ByteArray {
        val cells = OUT_W * OUT_H
        val out = ByteArray(cells)
        for (k in 0 until cells) {
            var max = Float.NEGATIVE_INFINITY
            for (c in 0 until CLASSES) max = maxOf(max, logits.get(c * cells + k))
            var sum = 0f
            for (c in 0 until CLASSES) sum += exp(logits.get(c * cells + k) - max)
            val p = exp(logits.get(WALL * cells + k) - max) / sum
            out[k] = (p * 255f).toInt().coerceIn(0, 255).toByte()
        }
        return out
    }

    /**
     * Joint bilateral upsampling: the model's 36x80 mask is blocky, so poster / AC / window edges bled.
     * Each output pixel blends its 3x3 coarse neighbours, weighted by how close their brightness is to its
     * own in the camera image, so the mask edge snaps to the real object edge.
     */
    private fun refineEdges(coarse: ByteArray, luma: FloatArray): ByteArray {
        val bx = IN_W / OUT_W; val by = IN_H / OUT_H // input pixels per coarse cell (8x8)
        val coarseLuma = FloatArray(OUT_W * OUT_H)
        for (y in 0 until IN_H) for (x in 0 until IN_W) coarseLuma[(y / by) * OUT_W + x / bx] += luma[y * IN_W + x]
        for (i in coarseLuma.indices) coarseLuma[i] /= (bx * by).toFloat()
        val fx = IN_W / MASK_W; val fy = IN_H / MASK_H // input pixels per fine pixel (2x2)
        val inv2s2 = 1f / (2f * 0.08f * 0.08f)
        val out = ByteArray(MASK_W * MASK_H)
        for (y in 0 until MASK_H) for (x in 0 until MASK_W) {
            var g = 0f
            for (dy in 0 until fy) for (dx in 0 until fx) g += luma[(y * fy + dy) * IN_W + x * fx + dx]
            g /= (fx * fy).toFloat()
            // Position in coarse-cell units (cell centres at k + 0.5).
            val cx = (x + 0.5f) * OUT_W / MASK_W - 0.5f
            val cy = (y + 0.5f) * OUT_H / MASK_H - 0.5f
            var num = 0f; var den = 0f
            for (j in -1..1) for (i in -1..1) {
                val nx = (cx.toInt() + i).coerceIn(0, OUT_W - 1)
                val ny = (cy.toInt() + j).coerceIn(0, OUT_H - 1)
                val ddx = nx - cx; val ddy = ny - cy
                val spatial = exp(-(ddx * ddx + ddy * ddy) * 0.5f)
                val dl = coarseLuma[ny * OUT_W + nx] - g
                val wgt = spatial * exp(-dl * dl * inv2s2)
                num += wgt * (coarse[ny * OUT_W + nx].toInt() and 0xFF)
                den += wgt
            }
            out[y * MASK_W + x] = (num / den.coerceAtLeast(1e-6f)).toInt().coerceIn(0, 255).toByte()
        }
        return out
    }

    /** Camera brightness averaged onto the MASK_W x MASK_H grid. */
    private fun downsampleLuma(luma: FloatArray): FloatArray {
        val fx = IN_W / MASK_W; val fy = IN_H / MASK_H
        return FloatArray(MASK_W * MASK_H) { k ->
            val x = k % MASK_W; val y = k / MASK_W
            var sum = 0f
            for (dy in 0 until fy) for (dx in 0 until fx) sum += luma[(y * fy + dy) * IN_W + x * fx + dx]
            sum / (fx * fy)
        }
    }

    fun close() {
        worker.shutdown()
        session.close()
    }
}
