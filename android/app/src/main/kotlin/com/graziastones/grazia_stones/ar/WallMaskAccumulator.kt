package com.graziastones.grazia_stones.ar

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
        mask: ByteArray, luma: FloatArray, maskW: Int, maskH: Int, vp: FloatArray, quadToWorld: FloatArray,
        quadW: Float, quadH: Float, zMin: Float, camDistanceM: Float,
    ) {
        if (camDistanceM < MIN_UPDATE_DISTANCE_M && hasData) return
        // Mean brightness of what the segmenter calls wall in this frame: the reference for "unshaded".
        var lumSum = 0f; var lumN = 0
        for (k in mask.indices) if ((mask[k].toInt() and 0xFF) > 160) { lumSum += luma[k]; lumN++ }
        val meanWall = if (lumN > 50) (lumSum / lumN).coerceAtLeast(0.05f) else 0f
        val m = FloatArray(16)
        android.opengl.Matrix.multiplyMM(m, 0, vp, 0, quadToWorld, 0) // quad-local -> clip
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
                val p = sample(mask, maskW, maskH, sx, sy)
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
