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
        // 1.6 cm per texel over the 8 x 4 m masked wall; 256x128 (3.1 cm) blurred every cut edge.
        const val W = 512
        const val H = 256
        private const val BLEND = 0.45f
        // Closer than this, a plain wall fills the view with no context and the segmenter guesses; keep memory.
        private const val MIN_UPDATE_DISTANCE_M = 0.9f
    }

    private val acc = FloatArray(W * H)
    // User brush (Erase / Restore in Live AR): 0 = automatic, 1 = always stone, 2 = never stone.
    // Wins over the segmenter and survives its updates; cleared when the design is placed again.
    private val edit = ByteArray(W * H)
    @Volatile var userEdited = false
        private set
    private val shade = FloatArray(W * H) { 1f }
    @Volatile var hasData = false
        private set
    /** The last frame's WallGeodesic mask (WallSegmenter.GW x GH, view space), for WallEdges. */
    @Volatile var lastWall: BooleanArray? = null
        private set
    /** Share of the quad texels seen in the last update that the segmenter calls wall (0..1). */
    @Volatile var lastCoverage = 0f
        private set

    @Synchronized fun reset() {
        acc.fill(0f)
        shade.fill(1f)
        edit.fill(0)
        userEdited = false
        lastWall = null
        hasData = false
        lastCoverage = 0f
    }

    /**
     * @param mask view-space wall probability, [maskW] x [maskH], row 0 = screen top
     * @param vp camera view-projection (column-major) of the frame [mask] came from
     * @param quadToWorld column-major model matrix of the quad's anchor (x along wall, y normal, z up)
     * @param luma camera brightness 0..1 on the same grid as [mask]
     * @param camDistanceM distance from the camera to the wall plane when the frame was taken
     * @param seedX / [seedZ] where on the quad the wall flood fill starts
     * @param keepMinX / [keepMaxX] the quad's extent along X that is this wall (a room corner ends it)
     */
    @Synchronized fun update(
        seg: WallSegmenter.Result, maskW: Int, maskH: Int, vp: FloatArray, quadToWorld: FloatArray,
        quadW: Float, quadH: Float, zMin: Float, seedZ: Float, camDistanceM: Float,
        seedX: Float = 0f, keepMinX: Float = -Float.MAX_VALUE, keepMaxX: Float = Float.MAX_VALUE,
    ) {
        if (camDistanceM < MIN_UPDATE_DISTANCE_M && hasData) return
        val m = FloatArray(16)
        android.opengl.Matrix.multiplyMM(m, 0, vp, 0, quadToWorld, 0) // quad-local -> clip
        val gw = WallSegmenter.GW; val gh = WallSegmenter.GH
        val seed = seedPixel(m, seedX, seedZ, gw, gh) ?: return   // design off-screen: keep the remembered mask
        // THE wall: everything reachable from where the design was placed without crossing an edge or leaving
        // the wall's colour/lighting (WallGeodesic), at camera resolution.
        val wall = WallGeodesic.segment(seg.lab, gw, gh, seed % gw, seed / gw, seg.nonWall)
        lastWall = wall
        val lum = seg.lab[0]
        // Mean brightness of the wall in this frame: the reference for "unshaded".
        var lumSum = 0f; var lumN = 0
        for (k in wall.indices) if (wall[k]) { lumSum += lum[k]; lumN++ }
        val meanWall = if (lumN > 50) (lumSum / lumN).coerceAtLeast(5f) else 0f
        var seen = 0; var wallSeen = 0
        // The first mask after a placement is taken as is: blending it in from 0 took two segmenter runs (~3-5 s on
        // the OnePlus) before any texel passed 0.5, so the design stayed hidden that long.
        val blend = if (hasData) BLEND else 1f
        for (j in 0 until H) {
            val z = zMin + (j + 0.5f) / H * quadH
            for (i in 0 until W) {
                val x = ((i + 0.5f) / W - 0.5f) * quadW
                if (x < keepMinX || x > keepMaxX) { acc[j * W + i] = 0f; continue }
                // clip = m * (x, 0, z, 1)
                val cw = m[3] * x + m[11] * z + m[15]
                if (cw <= 1e-4f) continue
                val nx = (m[0] * x + m[8] * z + m[12]) / cw
                val ny = (m[1] * x + m[9] * z + m[13]) / cw
                if (nx < -1f || nx > 1f || ny < -1f || ny > 1f) continue
                val sx = (nx * 0.5f + 0.5f) * gw - 0.5f
                val sy = (0.5f - ny * 0.5f) * gh - 0.5f
                val p = sampleBool(wall, gw, gh, sx, sy)
                val k = j * W + i
                acc[k] += (p - acc[k]) * blend
                seen++
                if (acc[k] > 0.5f) wallSeen++
                if (meanWall > 0f && p > 0.5f) {
                    val l = lum[sy.toInt().coerceIn(0, gh - 1) * gw + sx.toInt().coerceIn(0, gw - 1)]
                    shade[k] += ((l / meanWall).coerceIn(0.3f, 1.8f) - shade[k]) * blend
                }
            }
        }
        if (seen > 0) lastCoverage = wallSeen.toFloat() / seen
        hasData = true
    }

    /** Mask pixel where the design's seed point ([seedX] along, [seedZ] up from the anchor) lands, or null. */
    private fun seedPixel(m: FloatArray, seedX: Float, seedZ: Float, maskW: Int, maskH: Int): Int? {
        // clip = m * (seedX, 0, seedZ, 1)
        val cw = m[3] * seedX + m[11] * seedZ + m[15]
        if (cw <= 1e-4f) return null
        val nx = (m[0] * seedX + m[8] * seedZ + m[12]) / cw
        val ny = (m[1] * seedX + m[9] * seedZ + m[13]) / cw
        if (nx < -1f || nx > 1f || ny < -1f || ny > 1f) return null
        val sx = ((nx * 0.5f + 0.5f) * maskW).toInt().coerceIn(0, maskW - 1)
        val sy = ((0.5f - ny * 0.5f) * maskH).toInt().coerceIn(0, maskH - 1)
        return sy * maskW + sx
    }

    /** Paints a brush disk of [radiusM] at quad-space ([x], [z]) on the mask (see [edit]). */
    @Synchronized fun paint(x: Float, z: Float, radiusM: Float, erase: Boolean, quadW: Float, quadH: Float, zMin: Float) {
        val ci = (x / quadW + 0.5f) * W; val cj = (z - zMin) / quadH * H
        val ri = radiusM / quadW * W; val rj = radiusM / quadH * H
        if (ri < 0.5f || rj < 0.5f) return
        val value: Byte = if (erase) 2 else 1
        for (j in (cj - rj).toInt().coerceAtLeast(0)..(cj + rj).toInt().coerceAtMost(H - 1)) {
            for (i in (ci - ri).toInt().coerceAtLeast(0)..(ci + ri).toInt().coerceAtMost(W - 1)) {
                val dx = (i + 0.5f - ci) / ri; val dy = (j + 0.5f - cj) / rj
                if (dx * dx + dy * dy <= 1f) edit[j * W + i] = value
            }
        }
        userEdited = true
        hasData = true
    }

    /** Interleaved RG8: wall probability (after the user's brush), shading / 2. */
    @Synchronized fun toBytes(): ByteArray = ByteArray(W * H * 2) { b ->
        val k = b / 2
        val wall = when (edit[k].toInt()) { 1 -> 1f; 2 -> 0f; else -> acc[k] }
        val v = if (b % 2 == 0) wall else shade[k] / 2f
        (v * 255f).toInt().coerceIn(0, 255).toByte()
    }

    private fun sampleBool(mask: BooleanArray, w: Int, h: Int, fx: Float, fy: Float): Float {
        val x0 = fx.toInt().coerceIn(0, w - 1); val y0 = fy.toInt().coerceIn(0, h - 1)
        val x1 = (x0 + 1).coerceAtMost(w - 1); val y1 = (y0 + 1).coerceAtMost(h - 1)
        val tx = (fx - x0).coerceIn(0f, 1f); val ty = (fy - y0).coerceIn(0f, 1f)
        fun v(x: Int, y: Int) = if (mask[y * w + x]) 1f else 0f
        val top = v(x0, y0) + (v(x1, y0) - v(x0, y0)) * tx
        val bot = v(x0, y1) + (v(x1, y1) - v(x0, y1)) * tx
        return top + (bot - top) * ty
    }

}
