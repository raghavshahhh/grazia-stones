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
 * Model: EfficientViT-Seg B1 trained on ADE20K (MIT HAN Lab, Apache-2.0), exported to ONNX at 224x480
 * (portrait, close to the phone's screen aspect). ADE20K class 0 is "wall". Output: 28x60 logits.
 * The mask is produced in VIEW space (row 0 = top of the screen), which is what the wall material samples.
 */
class WallSegmenter(context: Context) {
    companion object {
        private const val TAG = "WallSegmenter"
        const val IN_W = 224
        const val IN_H = 480
        const val OUT_W = 28
        const val OUT_H = 60
        private const val CLASSES = 150
        private const val WALL = 0
        private val MEAN = floatArrayOf(0.485f, 0.456f, 0.406f)
        private val STD = floatArrayOf(0.229f, 0.224f, 0.225f)
    }

    private val env = OrtEnvironment.getEnvironment()
    private val session: OrtSession = context.assets.open("models/wall_seg_224x480.onnx").use { input ->
        val bytes = input.readBytes()
        // XNNPACK (ARM NEON kernels) is several times faster than ORT's default CPU path on phones.
        runCatching {
            env.createSession(bytes, OrtSession.SessionOptions().apply {
                addXnnpack(mapOf("intra_op_num_threads" to "4"))
                setIntraOpNumThreads(1)
            })
        }.onFailure { Log.w(TAG, "XNNPACK unavailable, using default CPU", it) }.getOrNull()
            ?: env.createSession(bytes, OrtSession.SessionOptions().apply { setIntraOpNumThreads(4) })
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
     * background. [onMask] gets OUT_W x OUT_H wall probabilities (0..255, row 0 = screen top) on the worker.
     */
    fun request(frame: Frame, onMask: (ByteArray) -> Unit) {
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
                    val input = toInput(coords, w, h, yBytes, uBytes, vBytes, yRow, uvRow, uvPix)
                    val t0 = android.os.SystemClock.elapsedRealtime()
                    val mask = OnnxTensor.createTensor(env, input, longArrayOf(1, 3, IN_H.toLong(), IN_W.toLong())).use { tensor ->
                        session.run(mapOf("image" to tensor)).use { out ->
                            @Suppress("UNCHECKED_CAST")
                            wallProbability((out[0].value as Array<Array<Array<FloatArray>>>)[0])
                        }
                    }
                    lastInferenceMs = android.os.SystemClock.elapsedRealtime() - t0
                    onMask(mask)
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

    /** Nearest-pixel YUV -> RGB sampling of the view grid into a normalised NCHW tensor. */
    private fun toInput(
        coords: FloatArray, w: Int, h: Int, yB: ByteArray, uB: ByteArray, vB: ByteArray, yRow: Int, uvRow: Int, uvPix: Int,
    ): FloatBuffer {
        val plane = IN_W * IN_H
        val buf = FloatBuffer.allocate(3 * plane)
        val arr = buf.array()
        for (i in 0 until plane) {
            val px = coords[i * 2].toInt().coerceIn(0, w - 1)
            val py = coords[i * 2 + 1].toInt().coerceIn(0, h - 1)
            val yy = (yB[py * yRow + px].toInt() and 0xFF).toFloat()
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

    /** Softmax probability of the wall class per output cell, as 0..255 bytes. */
    private fun wallProbability(logits: Array<Array<FloatArray>>): ByteArray {
        val out = ByteArray(OUT_W * OUT_H)
        for (y in 0 until OUT_H) for (x in 0 until OUT_W) {
            var max = Float.NEGATIVE_INFINITY
            for (c in 0 until CLASSES) max = maxOf(max, logits[c][y][x])
            var sum = 0f
            for (c in 0 until CLASSES) sum += exp(logits[c][y][x] - max)
            val p = exp(logits[WALL][y][x] - max) / sum
            out[y * OUT_W + x] = (p * 255f).toInt().coerceIn(0, 255).toByte()
        }
        return out
    }

    fun close() {
        worker.shutdown()
        session.close()
    }
}
