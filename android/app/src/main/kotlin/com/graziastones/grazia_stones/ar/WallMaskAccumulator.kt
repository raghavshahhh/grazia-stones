package com.graziastones.grazia_stones.ar

import kotlin.math.abs

/**
 * Wall mask stored ON the placed design quad (quad space), not on the screen.
 *
 * Every segmenter result is projected onto the quad through the camera matrix of the frame it came from and
 * blended in. So the mask is remembered as the user moves: walking up close (where the segmenter loses the
 * context to call a plain wall "wall") or turning away no longer makes the stone vanish, and single-frame
 * mistakes average out.
 *
 * It also stores the real room's shading on the wall (camera brightness / the wall's mean brightness), so the
 * stone picks up the actual light falloff and shadows on that wall. Texture: R = wall, G = shading / 2.
 *
 * Quad space: u = x / width + 0.5 (x along the wall), v = (z - zMin) / height (z up); row 0 = bottom.
 * Thread-safe: updated on the segmenter worker, reset from the main thread.
 */
class WallMaskAccumulator {
    companion object {
        const val W = 256
        const val H = 128
        private const val BLEND = 0.45f
        // Mask cells around the seed searched for a wall cell (the seed may land on a frame or a switch).
        private const val SEED_SEARCH = 6
        // Colour region grow: neighbour-to-neighbour brightness step, max drift from the seed's brightness and chroma.
        private const val STEP_LUMA = 0.06f
        private const val SEED_LUMA = 0.28f
        private const val SEED_CHROMA = 0.045f
        // Closer than this, a plain wall fills the view with no context and the segmenter guesses; keep memory.
        private const val MIN_UPDATE_DISTANCE_M = 0.9f
    }

    private val acc = FloatArray(W * H)
    private val shade = FloatArray(W * H) { 1f }
    @Volatile var hasData = false
        private set
    /** Share of the quad texels seen in the last update that the segmenter calls wall (0..1). */
    @Volatile var lastCoverage = 0f
        private set

    @Synchronized fun reset() {
        acc.fill(0f)
        shade.fill(1f)
        hasData = false
        lastCoverage = 0f
    }

    /**
     * @param mask view-space wall probability, [maskW] x [maskH], row 0 = screen top
     * @param vp camera view-projection (column-major) of the frame [mask] came from
     * @param quadToWorld column-major model matrix of the quad's anchor (x along wall, y normal, z up)
     * @param luma camera brightness 0..1 on the same grid as [mask]
     * @param camDistanceM distance from the camera to the wall plane when the frame was taken
     */
    @Synchronized fun update(
        seg: WallSegmenter.Result, maskW: Int, maskH: Int, vp: FloatArray, quadToWorld: FloatArray,
        quadW: Float, quadH: Float, zMin: Float, seedZ: Float, camDistanceM: Float,
    ) {
        if (camDistanceM < MIN_UPDATE_DISTANCE_M && hasData) return
        val luma = seg.luma
        val m = FloatArray(16)
        android.opengl.Matrix.multiplyMM(m, 0, vp, 0, quadToWorld, 0) // quad-local -> clip
        val seed = seedPixel(m, seedZ, maskW, maskH) ?: return   // design off-screen: keep the remembered mask
        // Wall = pixels of the same colour as the tapped spot (region grow from the seed; walls are one colour,
        // doors / frames / pictures sit behind a colour edge) OR what the model calls wall, minus what the
        // model is confident is a door, window, person, picture... The colour path is what makes raw plaster
        // and flat primer work, where the ADE20K model sees "floor" or "bed".
        val colour = colourRegion(seed, luma, seg.chromaU, seg.chromaV, maskW, maskH)
        val mask = ByteArray(maskW * maskH)
        for (k in mask.indices) {
            val model = (seg.wall[k].toInt() and 0xFF)
            val vetoed = (seg.veto[k].toInt() and 0xFF) > 127
            mask[k] = when {
                vetoed -> 0
                colour[k] -> 255.toByte()
                else -> model.toByte()
            }
        }
        // THE wall, not every wall: keep only the blob connected to where the design was placed.
        val region = connectedWall(mask, maskW, maskH, seed) ?: return
        // Mean brightness of the locked wall in this frame: the reference for "unshaded".
        var lumSum = 0f; var lumN = 0
        for (k in mask.indices) if (region[k] && (mask[k].toInt() and 0xFF) > 160) { lumSum += luma[k]; lumN++ }
        val meanWall = if (lumN > 50) (lumSum / lumN).coerceAtLeast(0.05f) else 0f
        var seen = 0; var wallSeen = 0
        for (j in 0 until H) {
            val z = zMin + (j + 0.5f) / H * quadH
            for (i in 0 until W) {
                val x = ((i + 0.5f) / W - 0.5f) * quadW
                // clip = m * (x, 0, z, 1)
                val cw = m[3] * x + m[11] * z + m[15]
                if (cw <= 1e-4f) continue
                val nx = (m[0] * x + m[8] * z + m[12]) / cw
                val ny = (m[1] * x + m[9] * z + m[13]) / cw
                if (nx < -1f || nx > 1f || ny < -1f || ny > 1f) continue
                val sx = (nx * 0.5f + 0.5f) * maskW - 0.5f
                val sy = (0.5f - ny * 0.5f) * maskH - 0.5f
                val inRegion = region[sy.toInt().coerceIn(0, maskH - 1) * maskW + sx.toInt().coerceIn(0, maskW - 1)]
                val p = if (inRegion) sample(mask, maskW, maskH, sx, sy) else 0f
                val k = j * W + i
                acc[k] += (p - acc[k]) * BLEND
                seen++
                if (acc[k] > 0.5f) wallSeen++
                if (meanWall > 0f && p > 0.5f) {
                    val l = luma[sy.toInt().coerceIn(0, maskH - 1) * maskW + sx.toInt().coerceIn(0, maskW - 1)]
                    shade[k] += ((l / meanWall).coerceIn(0.3f, 1.8f) - shade[k]) * BLEND
                }
            }
        }
        if (seen > 0) lastCoverage = wallSeen.toFloat() / seen
        hasData = true
    }

    /** Mask pixel where the design's seed point (anchor origin, [seedZ] up) lands in this frame, or null. */
    private fun seedPixel(m: FloatArray, seedZ: Float, maskW: Int, maskH: Int): Int? {
        // clip = m * (0, 0, seedZ, 1)
        val cw = m[11] * seedZ + m[15]
        if (cw <= 1e-4f) return null
        val nx = (m[8] * seedZ + m[12]) / cw
        val ny = (m[9] * seedZ + m[13]) / cw
        if (nx < -1f || nx > 1f || ny < -1f || ny > 1f) return null
        val sx = ((nx * 0.5f + 0.5f) * maskW).toInt().coerceIn(0, maskW - 1)
        val sy = ((0.5f - ny * 0.5f) * maskH).toInt().coerceIn(0, maskH - 1)
        return sy * maskW + sx
    }

    /**
     * Pixels of the same surface colour as the seed, 4-connected: each step must be close to its neighbour
     * (walls shade gradually) and not too far from the seed's own colour (so a gradient cannot wander onto
     * the ceiling), and must not cross a strong brightness edge (frames, skirting, door jambs).
     */
    private fun colourRegion(seed: Int, luma: FloatArray, cu: FloatArray, cv: FloatArray, w: Int, h: Int): BooleanArray {
        val region = BooleanArray(w * h)
        val sx = seed % w; val sy = seed / w
        // seed colour = 5x5 average so a single noisy pixel does not define the wall
        var l0 = 0f; var u0 = 0f; var v0 = 0f; var n = 0
        for (dy in -2..2) for (dx in -2..2) {
            val x = sx + dx; val y = sy + dy
            if (x !in 0 until w || y !in 0 until h) continue
            l0 += luma[y * w + x]; u0 += cu[y * w + x]; v0 += cv[y * w + x]; n++
        }
        l0 /= n; u0 /= n; v0 /= n
        fun colourOk(k: Int, from: Int): Boolean {
            val dl = abs(luma[k] - luma[from]); val dls = abs(luma[k] - l0)
            val du = abs(cu[k] - u0); val dv = abs(cv[k] - v0)
            return dl < STEP_LUMA && dls < SEED_LUMA && du < SEED_CHROMA && dv < SEED_CHROMA
        }
        val stack = IntArray(w * h); var top = 0
        stack[top++] = seed; region[seed] = true
        while (top > 0) {
            val k = stack[--top]
            val x = k % w; val y = k / w
            if (x > 0 && !region[k - 1] && colourOk(k - 1, k)) { region[k - 1] = true; stack[top++] = k - 1 }
            if (x < w - 1 && !region[k + 1] && colourOk(k + 1, k)) { region[k + 1] = true; stack[top++] = k + 1 }
            if (y > 0 && !region[k - w] && colourOk(k - w, k)) { region[k - w] = true; stack[top++] = k - w }
            if (y < h - 1 && !region[k + w] && colourOk(k + w, k)) { region[k + w] = true; stack[top++] = k + w }
        }
        return region
    }

    /**
     * Wall pixels (mask > 127) 4-connected to the design's seed point in this frame, or null when no wall
     * pixel lies within a few cells of it.
     */
    private fun connectedWall(mask: ByteArray, maskW: Int, maskH: Int, seed: Int): BooleanArray? {
        val sx = seed % maskW; val sy = seed / maskW
        fun wall(x: Int, y: Int) = (mask[y * maskW + x].toInt() and 0xFF) > 127
        // The seed itself may sit on a switch, a frame or a misread cell: take the nearest wall cell close by.
        var start = -1; var bestD = Int.MAX_VALUE
        for (dy in -SEED_SEARCH..SEED_SEARCH) for (dx in -SEED_SEARCH..SEED_SEARCH) {
            val x = sx + dx; val y = sy + dy
            if (x !in 0 until maskW || y !in 0 until maskH || !wall(x, y)) continue
            val d = dx * dx + dy * dy
            if (d < bestD) { bestD = d; start = y * maskW + x }
        }
        if (start < 0) return null
        val region = BooleanArray(maskW * maskH)
        val stack = IntArray(maskW * maskH)
        var top = 0
        stack[top++] = start; region[start] = true
        while (top > 0) {
            val k = stack[--top]
            val x = k % maskW; val y = k / maskW
            if (x > 0 && !region[k - 1] && wall(x - 1, y)) { region[k - 1] = true; stack[top++] = k - 1 }
            if (x < maskW - 1 && !region[k + 1] && wall(x + 1, y)) { region[k + 1] = true; stack[top++] = k + 1 }
            if (y > 0 && !region[k - maskW] && wall(x, y - 1)) { region[k - maskW] = true; stack[top++] = k - maskW }
            if (y < maskH - 1 && !region[k + maskW] && wall(x, y + 1)) { region[k + maskW] = true; stack[top++] = k + maskW }
        }
        return region
    }

    /** Interleaved RG8: wall probability, shading / 2. */
    @Synchronized fun toBytes(): ByteArray = ByteArray(W * H * 2) { b ->
        val k = b / 2
        val v = if (b % 2 == 0) acc[k] else shade[k] / 2f
        (v * 255f).toInt().coerceIn(0, 255).toByte()
    }

    private fun sample(mask: ByteArray, w: Int, h: Int, fx: Float, fy: Float): Float {
        val x0 = fx.toInt().coerceIn(0, w - 1); val y0 = fy.toInt().coerceIn(0, h - 1)
        val x1 = (x0 + 1).coerceAtMost(w - 1); val y1 = (y0 + 1).coerceAtMost(h - 1)
        val tx = (fx - x0).coerceIn(0f, 1f); val ty = (fy - y0).coerceIn(0f, 1f)
        fun v(x: Int, y: Int) = (mask[y * w + x].toInt() and 0xFF) / 255f
        val top = v(x0, y0) + (v(x1, y0) - v(x0, y0)) * tx
        val bot = v(x0, y1) + (v(x1, y1) - v(x0, y1)) * tx
        return top + (bot - top) * ty
    }
}
