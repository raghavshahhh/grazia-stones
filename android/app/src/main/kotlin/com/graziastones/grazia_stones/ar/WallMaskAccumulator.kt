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
        /**
         * ADE20K objects that hang ON a wall and that the model rarely invents on bare plaster: painting, mirror,
         * television, poster, screen, crt screen, monitor, bulletin board, clock. Door / window / person are left
         * out on purpose: the model calls close-up or bright plaster those (see WallGeodesic BG_* notes).
         */
        private val HARD_OBJECTS = intArrayOf(22, 27, 89, 100, 130, 141, 143, 144, 148)
        /** Model wall probability (0..255) below which a hard-object pixel is cut even if it looks like the wall. */
        private const val HARD_CUT_WALL_MAX = 64
        /** More of the view than this called "painting" etc. is a misread textured wall, not an object: no cut. */
        private const val HARD_MAX_SHARE = 0.25f
        /** Grid step (m) of the fallback seed search over the quad when the placement point is off screen. */
        private const val SEED_STEP_M = 0.25f
        /** Model wall probability (0..255) a fallback seed must have. */
        private const val SEED_MIN_WALL = 178
        /**
         * Fallback seeds stay within this distance (m) along the wall from the placement point. Further out the
         * oversized quad's plane runs past a room corner and projects onto the side wall, which must not be seeded.
         */
        private const val SEED_MAX_SIDE_M = 1.5f

        /** Column-major 4x4 a * b (android.opengl.Matrix.multiplyMM without the Android stub, for JVM tests). */
        internal fun mul(a: FloatArray, b: FloatArray): FloatArray = FloatArray(16) { k ->
            val c = k / 4; val r = k % 4
            a[r] * b[c * 4] + a[4 + r] * b[c * 4 + 1] + a[8 + r] * b[c * 4 + 2] + a[12 + r] * b[c * 4 + 3]
        }
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
    /** Why the last update did what it did (seed pixel, flood-fill size), for the SEG log line. */
    @Volatile var lastDebug = ""
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
        if (camDistanceM < MIN_UPDATE_DISTANCE_M && hasData) { lastDebug = "skip=too_close"; return }
        val m = mul(vp, quadToWorld) // quad-local -> clip
        val gw = WallSegmenter.GW; val gh = WallSegmenter.GH
        val hard = hardObjects(seg, maskW, maskH)
        var seed = seedPixel(m, seedX, seedZ, gw, gh)
        var seedNote = ""
        // The placement point is off screen (an edge placement seeds 1 m above an assumed floor while the camera
        // looks at the ceiling line) or sits on a painting/TV: seed on the nearest quad point the model calls wall
        // instead. Before, every update was skipped and a fresh placement stayed unclipped (quadCoverage=0.00).
        if (seed == null || (hard != null && hardAt(hard, seed % gw, seed / gw, gw, gh, maskW, maskH))) {
            val alt = fallbackSeed(m, seg, maskW, maskH, hard, seedX, seedZ, quadW, quadH, zMin, keepMinX, keepMaxX)
            if (alt != null) { seedNote = if (seed == null) " seed_fallback" else " seed_off_object"; seed = alt }
        }
        if (seed == null) { lastDebug = "skip=seed_off_screen"; return } // keep the remembered mask
        // THE wall: everything reachable from where the design was placed without crossing an edge or leaving
        // the wall's colour/lighting (WallGeodesic), at camera resolution.
        val geo = WallGeodesic.segment(seg.lab, gw, gh, seed % gw, seed / gw, seg.nonWall)
        lastWall = geo // WallEdges / WallCorner keep the uncut outline
        // Paintings / mirrors / TVs the same colour as the wall have no colour edge for the fill to stop at; cut
        // them from the stone where the model (edge-refined) is sure they are not wall.
        var cut = 0
        val wall = if (hard == null) geo else geo.copyOf().also { s ->
            for (k in s.indices) if (s[k] && hardAt(hard, k % gw, k / gw, gw, gh, maskW, maskH)) { s[k] = false; cut++ }
        }
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
        lastDebug = "seed=(${seed % gw},${seed / gw})$seedNote fill=${wall.count { it } * 100 / wall.size}% seen=$seen" +
            if (cut > 0) " hardCut=${cut * 100 / wall.size}%" else ""
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

    /**
     * MASK-grid flags: the model's arg-max is a [HARD_OBJECTS] class and its edge-refined wall probability is low.
     * Null when there is nothing to cut or when so much of the view is "painting" that the model misread the wall.
     */
    private fun hardObjects(seg: WallSegmenter.Result, maskW: Int, maskH: Int): BooleanArray? {
        val ow = WallSegmenter.OUT_W; val oh = WallSegmenter.OUT_H
        var cells = 0
        for (c in seg.classes) if ((c.toInt() and 0xFF) in HARD_OBJECTS) cells++
        if (cells == 0 || cells > seg.classes.size * HARD_MAX_SHARE) return null
        return BooleanArray(maskW * maskH) { k ->
            val x = k % maskW; val y = k / maskW
            val cls = seg.classes[(y * oh / maskH) * ow + x * ow / maskW].toInt() and 0xFF
            cls in HARD_OBJECTS && (seg.wall[k].toInt() and 0xFF) < HARD_CUT_WALL_MAX
        }
    }

    /** [hard] (MASK grid) at GW x GH grid pixel ([gx], [gy]). */
    private fun hardAt(hard: BooleanArray, gx: Int, gy: Int, gw: Int, gh: Int, mw: Int, mh: Int): Boolean =
        hard[(gy * mh / gh) * mw + gx * mw / gw]

    /**
     * The quad point nearest to ([seedX], [seedZ]) that is on screen (10% margin), on this wall's side of a corner,
     * at most [SEED_MAX_SIDE_M] along the wall from it, and that the model calls wall with confidence, as a GW x GH grid index; null when there is none.
     */
    private fun fallbackSeed(
        m: FloatArray, seg: WallSegmenter.Result, maskW: Int, maskH: Int, hard: BooleanArray?,
        seedX: Float, seedZ: Float, quadW: Float, quadH: Float, zMin: Float, keepMinX: Float, keepMaxX: Float,
    ): Int? {
        val gw = WallSegmenter.GW; val gh = WallSegmenter.GH
        val nx = (quadW / SEED_STEP_M).toInt(); val nz = (quadH / SEED_STEP_M).toInt()
        val cands = ArrayList<FloatArray>(nx * nz)
        for (i in 0..nx) for (j in 0..nz) {
            val x = -quadW / 2f + i * SEED_STEP_M; val z = zMin + j * SEED_STEP_M
            if (x < keepMinX || x > keepMaxX || abs(x - seedX) > SEED_MAX_SIDE_M) continue
            cands.add(floatArrayOf(x, z, (x - seedX) * (x - seedX) + (z - seedZ) * (z - seedZ)))
        }
        cands.sortBy { it[2] }
        for (c in cands) {
            val cw = m[3] * c[0] + m[11] * c[1] + m[15]
            if (cw <= 1e-4f) continue
            val px = (m[0] * c[0] + m[8] * c[1] + m[12]) / cw
            val py = (m[1] * c[0] + m[9] * c[1] + m[13]) / cw
            if (px < -0.9f || px > 0.9f || py < -0.9f || py > 0.9f) continue
            val mx = ((px * 0.5f + 0.5f) * maskW).toInt().coerceIn(0, maskW - 1)
            val my = ((0.5f - py * 0.5f) * maskH).toInt().coerceIn(0, maskH - 1)
            if ((seg.wall[my * maskW + mx].toInt() and 0xFF) < SEED_MIN_WALL) continue
            if (hard != null && hard[my * maskW + mx]) continue
            val gx = ((px * 0.5f + 0.5f) * gw).toInt().coerceIn(0, gw - 1)
            val gy = ((0.5f - py * 0.5f) * gh).toInt().coerceIn(0, gh - 1)
            return gy * gw + gx
        }
        return null
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
