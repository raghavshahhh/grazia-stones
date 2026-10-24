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
class WallSegmenter(private val context: Context) {
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
        private const val BUILDING = 1 // the model says "building" for some plain plastered walls
        // Camera-resolution grid for the wall's edges (WallGeodesic). The CPU camera image is 640x480, of which the
        // portrait view covers ~287x640 pixels, so this is close to native.
        const val GW = 270
        const val GH = 600
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
    private val gGrid = FloatArray(GW * GH * 2).also { g ->
        for (y in 0 until GH) for (x in 0 until GW) {
            val i = (y * GW + x) * 2
            g[i] = (x + 0.5f) / GW
            g[i + 1] = (y + 0.5f) / GH
        }
    }
    private val gCoords = FloatArray(GW * GH * 2)

    /**
     * Grabs the current camera image (on the caller's thread: ARCore needs that) and segments it in the
     * background. [onMask] gets MASK_W x MASK_H wall probabilities (0..255, row 0 = screen top) and the camera
     * brightness (0..1) on the same grid, on the worker thread.
     */
    /** Everything one segmentation produces, all on the MASK_W x MASK_H grid (row 0 = screen top). */
    class Result(
        val wall: ByteArray,      // wall probability 0..255
        val veto: ByteArray,      // 255 where the model is confident the pixel is a door / window / person / picture...
        val luma: FloatArray,     // camera brightness 0..1
        val chromaU: FloatArray,  // camera chroma 0..1 (0.5 = neutral)
        val chromaV: FloatArray,
        val lab: Array<FloatArray>,  // smoothed Lab at GW x GH (L 0..100, a/b +128)
        val nonWall: BooleanArray,   // GW x GH: confidently not wall per the model (background seeds)
        val classes: ByteArray,      // OUT_W x OUT_H ADE20K arg-max (WallEdges: is there floor below the wall?)
    )

    fun request(frame: Frame, onMask: (Result) -> Unit) {
        if (busy) return
        val image = try { frame.acquireCameraImage() } catch (e: Exception) { return }
        busy = true
        try {
            frame.transformCoordinates2d(Coordinates2d.VIEW_NORMALIZED, viewGrid, Coordinates2d.IMAGE_PIXELS, imageCoords)
            frame.transformCoordinates2d(Coordinates2d.VIEW_NORMALIZED, gGrid, Coordinates2d.IMAGE_PIXELS, gCoords)
            val gc = gCoords.copyOf()
            val w = image.width; val h = image.height
            val yP = image.planes[0]; val uP = image.planes[1]; val vP = image.planes[2]
            val yBytes = ByteArray(yP.buffer.remaining()).also { yP.buffer.get(it) }
            val uBytes = ByteArray(uP.buffer.remaining()).also { uP.buffer.get(it) }
            val vBytes = ByteArray(vP.buffer.remaining()).also { vP.buffer.get(it) }
            val yRow = yP.rowStride; val uvRow = uP.rowStride; val uvPix = uP.pixelStride
            val coords = imageCoords.copyOf()
            if (dumpEnabled && dumped < MAX_DUMPS) dumpFrame(frame, w, h, yBytes, uBytes, vBytes, yRow, uvRow, uvPix)
            image.close()
            worker.execute {
                try {
                    val luma = FloatArray(IN_W * IN_H)
                    val cu = FloatArray(IN_W * IN_H); val cv = FloatArray(IN_W * IN_H)
                    val input = toInput(coords, w, h, yBytes, uBytes, vBytes, yRow, uvRow, uvPix, luma, cu, cv)
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
                    val lab = labGrid(gc, w, h, yBytes, uBytes, vBytes, yRow, uvRow, uvPix)
                    onMask(Result(mask, upsampleVeto(lastVeto), downsampleLuma(luma), downsampleLuma(cu), downsampleLuma(cv),
                        lab, nonWallSeeds(lastNonWall), lastClasses))
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

    // ── Debug frame dump (`adb shell setprop debug.grazia.dump 1`, off otherwise) ──
    // Raw camera YUV + the view->image mapping + camera matrices, so the mask pipeline can be tuned offline on
    // real frames from the phone. Files land in Android/data/<pkg>/files/segdump (adb pull, no root needed).
    private val dumpEnabled = runCatching {
        Class.forName("android.os.SystemProperties").getMethod("get", String::class.java)
            .invoke(null, "debug.grazia.dump") as? String
    }.getOrNull() == "1"
    private var dumped = 0
    private val MAX_DUMPS = 12

    private fun dumpFrame(
        frame: Frame, w: Int, h: Int, yB: ByteArray, uB: ByteArray, vB: ByteArray, yRow: Int, uvRow: Int, uvPix: Int,
    ) {
        runCatching {
            val dir = java.io.File(context.getExternalFilesDir(null), "segdump").apply { mkdirs() }
            val id = "f%02d".format(dumped++)
            java.io.File(dir, "$id.y").writeBytes(yB)
            java.io.File(dir, "$id.u").writeBytes(uB)
            java.io.File(dir, "$id.v").writeBytes(vB)
            val corners = floatArrayOf(0f, 0f, 1f, 0f, 0f, 1f, 1f, 1f)
            val img = FloatArray(8)
            frame.transformCoordinates2d(Coordinates2d.VIEW_NORMALIZED, corners, Coordinates2d.IMAGE_PIXELS, img)
            val proj = FloatArray(16); val view = FloatArray(16)
            frame.camera.getProjectionMatrix(proj, 0, 0.05f, 100f)
            frame.camera.getViewMatrix(view, 0)
            val intr = frame.camera.imageIntrinsics
            val json = org.json.JSONObject()
                .put("w", w).put("h", h).put("yRow", yRow).put("uvRow", uvRow).put("uvPix", uvPix)
                .put("viewCornersToImage", org.json.JSONArray(img.toList()))
                .put("proj", org.json.JSONArray(proj.toList())).put("view", org.json.JSONArray(view.toList()))
                .put("focal", org.json.JSONArray(intr.focalLength.toList()))
                .put("pp", org.json.JSONArray(intr.principalPoint.toList()))
                .put("imgDims", org.json.JSONArray(intr.imageDimensions.toList()))
            java.io.File(dir, "$id.json").writeText(json.toString())
            Log.i(TAG, "SEGDUMP $id ${w}x$h -> ${dir.absolutePath}")
        }.onFailure { Log.w(TAG, "dump failed", it) }
    }

    @Volatile var lastInferenceMs = 0L
        private set
    /** Model run only (no softmax / edge refinement), to tell model cost from post-processing cost. */
    @Volatile var lastRunMs = 0L
        private set

    /** Nearest-pixel YUV -> RGB sampling of the view grid into a normalised NCHW tensor. */
    private fun toInput(
        coords: FloatArray, w: Int, h: Int, yB: ByteArray, uB: ByteArray, vB: ByteArray, yRow: Int, uvRow: Int, uvPix: Int,
        luma: FloatArray, chromaU: FloatArray, chromaV: FloatArray,
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
            chromaU[i] = (u + 128f) / 255f
            chromaV[i] = (v + 128f) / 255f
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
        val hist = IntArray(CLASSES)
        val veto = ByteArray(cells)
        val nonWall = BooleanArray(cells)
        val classes = ByteArray(cells)
        for (k in 0 until cells) {
            var max = Float.NEGATIVE_INFINITY; var arg = 0
            for (c in 0 until CLASSES) {
                val v = logits.get(c * cells + k)
                if (v > max) { max = v; arg = c }
            }
            hist[arg]++
            classes[k] = arg.toByte()
            if (arg in VETO_CLASSES) veto[k] = 0xFF.toByte()
            var sum = 0f
            for (c in 0 until CLASSES) sum += exp(logits.get(c * cells + k) - max)
            // softmax of the arg-max class is 1 / sum
            nonWall[k] = arg != WALL && arg != BUILDING && 1f / sum > 0.5f
            val p = (exp(logits.get(WALL * cells + k) - max) + exp(logits.get(BUILDING * cells + k) - max)) / sum
            out[k] = (p * 255f).toInt().coerceIn(0, 255).toByte()
        }
        // What the model thinks the scene is, for logcat: "ade#5:48% ade#0:30% ade#2:10%" (ADE20K class ids).
        lastTopClasses = hist.withIndex().sortedByDescending { it.value }.take(3)
            .joinToString(" ") { "ade#${it.index}:${it.value * 100 / cells}%" }
        lastVeto = veto
        lastNonWall = nonWall
        lastClasses = classes
        return out
    }

    /** ADE20K classes that must never receive stone even if their colour matches the wall. */
    private val VETO_CLASSES = setOf(8 /*window*/, 10 /*cabinet*/, 12 /*person*/, 14 /*door*/, 18 /*curtain*/,
        22 /*painting*/, 24 /*shelf*/, 27 /*mirror*/, 89 /*television*/)
    private var lastVeto = ByteArray(OUT_W * OUT_H)
    private var lastNonWall = BooleanArray(OUT_W * OUT_H)
    private var lastClasses = ByteArray(OUT_W * OUT_H)

    /** OUT-grid "confidently not wall" -> GW x GH, eroded 4 px so seeds never sit on a boundary. */
    private fun nonWallSeeds(cells: BooleanArray): BooleanArray {
        val up = BooleanArray(GW * GH) { k -> cells[((k / GW) * OUT_H / GH) * OUT_W + (k % GW) * OUT_W / GW] }
        val r = 4
        val rows = BooleanArray(GW * GH)
        for (y in 0 until GH) for (x in 0 until GW) {
            var all = true
            for (d in -r..r) { val xx = x + d; if (xx !in 0 until GW || !up[y * GW + xx]) { all = false; break } }
            rows[y * GW + x] = all
        }
        return BooleanArray(GW * GH) { k ->
            val x = k % GW; val y = k / GW
            (-r..r).all { d -> val yy = y + d; yy in 0 until GH && rows[yy * GW + x] }
        }
    }

    /** Camera image at GW x GH in view orientation, Gaussian-smoothed (5x5, sigma 1.2), as Lab. */
    private fun labGrid(
        coords: FloatArray, w: Int, h: Int, yB: ByteArray, uB: ByteArray, vB: ByteArray, yRow: Int, uvRow: Int, uvPix: Int,
    ): Array<FloatArray> {
        val n = GW * GH
        val rgb = Array(3) { FloatArray(n) }
        for (i in 0 until n) {
            val px = coords[i * 2].toInt().coerceIn(0, w - 1)
            val py = coords[i * 2 + 1].toInt().coerceIn(0, h - 1)
            val yy = (yB[py * yRow + px].toInt() and 0xFF).toFloat()
            val uvi = (py / 2) * uvRow + (px / 2) * uvPix
            val u = (uB.getOrElse(uvi) { 128.toByte() }.toInt() and 0xFF) - 128f
            val v = (vB.getOrElse(uvi) { 128.toByte() }.toInt() and 0xFF) - 128f
            rgb[0][i] = (yy + 1.402f * v).coerceIn(0f, 255f)
            rgb[1][i] = (yy - 0.344136f * u - 0.714136f * v).coerceIn(0f, 255f)
            rgb[2][i] = (yy + 1.772f * u).coerceIn(0f, 255f)
        }
        val k5 = floatArrayOf(0.0663f, 0.2483f, 0.3707f, 0.2483f, 0.0663f) // sigma 1.2
        for (ch in rgb) {
            val tmp = FloatArray(n)
            for (y in 0 until GH) for (x in 0 until GW) {
                var acc = 0f
                for (d in -2..2) acc += k5[d + 2] * ch[y * GW + (x + d).coerceIn(0, GW - 1)]
                tmp[y * GW + x] = acc
            }
            for (y in 0 until GH) for (x in 0 until GW) {
                var acc = 0f
                for (d in -2..2) acc += k5[d + 2] * tmp[(y + d).coerceIn(0, GH - 1) * GW + x]
                ch[y * GW + x] = acc
            }
        }
        val out = Array(3) { FloatArray(n) }
        for (i in 0 until n) {
            val lin = FloatArray(3) { c -> SRGB_LIN[rgb[c][i].toInt().coerceIn(0, 255)] }
            val x = (0.412453f * lin[0] + 0.357580f * lin[1] + 0.180423f * lin[2]) / 0.950456f
            val y = 0.212671f * lin[0] + 0.715160f * lin[1] + 0.072169f * lin[2]
            val z = (0.019334f * lin[0] + 0.119193f * lin[1] + 0.950227f * lin[2]) / 1.088754f
            fun f(t: Float) = if (t > 0.008856f) Math.cbrt(t.toDouble()).toFloat() else 7.787f * t + 16f / 116f
            out[0][i] = if (y > 0.008856f) 116f * Math.cbrt(y.toDouble()).toFloat() - 16f else 903.3f * y
            out[1][i] = 500f * (f(x) - f(y)) + 128f
            out[2][i] = 200f * (f(y) - f(z)) + 128f
        }
        return out
    }

    private val SRGB_LIN = FloatArray(256) { c ->
        val v = c / 255f
        if (v <= 0.04045f) v / 12.92f else Math.pow(((v + 0.055f) / 1.055f).toDouble(), 2.4).toFloat()
    }

    /** Nearest-neighbour OUT -> MASK grid (4x); the veto is a coarse "not here" hint, edges come from colour. */
    private fun upsampleVeto(v: ByteArray): ByteArray {
        val out = ByteArray(MASK_W * MASK_H)
        val sx = MASK_W / OUT_W; val sy = MASK_H / OUT_H
        for (y in 0 until MASK_H) for (x in 0 until MASK_W) out[y * MASK_W + x] = v[(y / sy) * OUT_W + x / sx]
        return out
    }

    /** Top-3 ADE20K classes by area in the last frame (0 = wall, 1 = building, 2 = sky, 3 = floor, 5 = ceiling, 8 = window, 14 = door). */
    @Volatile var lastTopClasses = ""
        private set

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
