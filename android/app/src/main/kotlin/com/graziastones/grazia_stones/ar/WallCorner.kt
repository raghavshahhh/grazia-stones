package com.graziastones.grazia_stones.ar

import kotlin.math.abs

/**
 * The second wall of a room corner. Pointing at a corner put the design on one wall only: the placed wall's mask
 * stops at the corner and the other wall stayed bare. Here the other wall is the large model-"wall" region next
 * to the placed wall's mask; their shared boundary, cast onto the placed wall's plane, must be a vertical line
 * in the room (that is what a corner is), and the second wall is the plane through that line at 90 degrees to the
 * first (room corners are square; the floor-line estimate is not needed for it).
 *
 * Pure geometry on mask grids (no ARCore types) so it is unit-tested on the JVM. World +Y is up; matrices are
 * column-major OpenGL (ARCore Camera.getProjection/ViewMatrix), as in [WallEdges].
 */
object WallCorner {
    private const val MIN_AREA = 0.08f          // share of the view the other wall must cover
    private const val ADJ_PX = 6                // max gap between the two masks across the corner line
    private const val MIN_ROWS = 0.15f          // share of rows that must show the corner line
    private const val MIN_LINE_HEIGHT_M = 0.4f
    private const val MAX_LINE_SPREAD_M = 0.08f // median |deviation| of the line from vertical
    private const val MIN_CONSISTENT = 0.85f
    private const val MAX_DIST_M = 8f

    /**
     * @param cornerX corner position along the placed wall (its anchor's local X), metres
     * @param keepA +1 / -1: the side of [cornerX] the placed wall keeps
     * @param point a point on the corner line at the placed wall's anchor height; [normal] the second wall's normal
     * @param keepB +1 / -1: the side of the corner the second wall extends to, in ITS anchor's local X
     * @param seedX / [seedZ] a point well inside the second wall, in its anchor's local X / height above the anchor
     */
    class Corner(
        val cornerX: Float, val keepA: Int, val point: FloatArray, val normal: FloatArray, val keepB: Int,
        val seedX: Float, val seedZ: Float,
        /** True once [refineAngle] measured the second wall's angle; false = the square-corner assumption. */
        val angleMeasured: Boolean = false,
        /** Angle between the two walls' faces, degrees (90 until measured). */
        val angleDeg: Float = 90f,
    )

    private const val REFINE_MIN_POINTS = 8
    private const val REFINE_MAX_DEV = 0.6f       // rad (~35 deg) from square: beyond that it is not this wall
    private const val REFINE_MAX_MAD = 0.06f      // rad: the points must agree on one direction
    private const val REFINE_NEAR_M = 0.6f        // max distance of a candidate point from the square-corner plane

    /**
     * Turns the second wall about the corner line to where ARCore's feature points on it say it is. Room corners
     * are often not 90 degrees; plain paint has no feature points, and then the square assumption stays (and
     * [Corner.angleMeasured] says so). [points] are world positions (confidence-filtered), [cam] the camera.
     */
    fun refineAngle(c: Corner, points: List<FloatArray>, cam: FloatArray): Corner {
        val n0 = c.normal
        val ub0 = floatArrayOf(-n0[2], 0f, n0[0])
        // Direction from the corner into the second wall, as assumed (square corner).
        val dx = ub0[0] * c.keepB; val dz = ub0[2] * c.keepB
        val dev = ArrayList<Float>()
        for (p in points) {
            val vx = p[0] - c.point[0]; val vz = p[2] - c.point[2]
            val along = vx * dx + vz * dz
            val off = vx * n0[0] + vz * n0[2]
            if (along < 0.3f || along > 4f || abs(off) > REFINE_NEAR_M) continue
            if (abs(p[1] - c.point[1]) > 2.5f) continue
            dev.add(kotlin.math.atan2(off, along))
        }
        if (dev.size < REFINE_MIN_POINTS) return c
        val phi = median(dev)
        if (abs(phi) > REFINE_MAX_DEV || median(dev.map { abs(it - phi) }) > REFINE_MAX_MAD) return c
        val cos = kotlin.math.cos(phi); val sin = kotlin.math.sin(phi)
        val ex = dx * cos + n0[0] * sin; val ez = dz * cos + n0[2] * sin // measured direction into wall B
        var nb = floatArrayOf(-ez, 0f, ex)
        if ((cam[0] - c.point[0]) * nb[0] + (cam[2] - c.point[2]) * nb[2] < 0f) nb = floatArrayOf(ez, 0f, -ex)
        val ub = floatArrayOf(-nb[2], 0f, nb[0])
        // Same seed point in the world, expressed along the turned wall.
        val sx = c.point[0] + ub0[0] * c.seedX; val sz = c.point[2] + ub0[2] * c.seedX
        val seedX = (sx - c.point[0]) * ub[0] + (sz - c.point[2]) * ub[2]
        val keepB = if (ex * ub[0] + ez * ub[2] >= 0f) 1 else -1
        // Interior angle between the faces: the normal faces the room, so turning toward it (phi > 0) closes the corner.
        val angle = 90f - Math.toDegrees(phi.toDouble()).toFloat()
        return Corner(c.cornerX, c.keepA, c.point, nb, keepB, seedX, c.seedZ, angleMeasured = true, angleDeg = angle)
    }

    /**
     * @param a the placed wall's mask (WallGeodesic), [w] x [h], row 0 = screen top
     * @param modelWall the segmenter's "wall" per pixel on the same grid
     * @param p0 the placed wall's anchor position; [n] its horizontal normal (toward the camera)
     */
    fun find(
        a: BooleanArray, modelWall: BooleanArray, w: Int, h: Int, proj: FloatArray, view: FloatArray,
        p0: FloatArray, n: FloatArray,
    ): Corner? {
        val cam = WallEdges.cameraPosition(view)
        val u = floatArrayOf(-n[2], 0f, n[0]) // the placed wall's local X
        // The other wall: the biggest model-wall region outside the placed wall (kept 2 px off its edge).
        val nearA = BooleanArray(w * h)
        for (y in 0 until h) for (x in 0 until w) if (a[y * w + x]) {
            for (dx in -2..2) { val xx = x + dx; if (xx in 0 until w) nearA[y * w + xx] = true }
        }
        val b = largestComponent(BooleanArray(w * h) { modelWall[it] && !nearA[it] }, w, h) ?: return null
        if (b.count { it } < MIN_AREA * w * h) return null

        // Rows where B starts within ADJ_PX of A's last pixel, on the right (+1) or the left (-1) of A.
        var right = 0; var left = 0
        val lineR = ArrayList<IntArray>(); val lineL = ArrayList<IntArray>()
        for (y in 0 until h) {
            val r = y * w
            for (x in 0 until w - 1) {
                if (a[r + x] && !a[r + x + 1]) {
                    if ((x + 1..minOf(w - 1, x + ADJ_PX)).any { b[r + it] }) { right++; lineR.add(intArrayOf(x, y)) }
                }
                if (a[r + x + 1] && !a[r + x]) {
                    if ((maxOf(0, x - ADJ_PX + 1)..x).any { b[r + it] }) { left++; lineL.add(intArrayOf(x + 1, y)) }
                }
            }
        }
        val bOnRight = right >= left
        val line = if (bOnRight) lineR else lineL
        if (line.size < MIN_ROWS * h) return null

        // The shared boundary on the placed wall's plane: a vertical line in the room, or not a corner.
        val s = ArrayList<Float>(); var yMin = Float.MAX_VALUE; var yMax = -Float.MAX_VALUE
        for ((x, y) in line.map { it[0] to it[1] }) {
            val p = hit(x.toFloat(), y.toFloat(), w, h, proj, view, cam, p0, n) ?: continue
            s.add((p[0] - p0[0]) * u[0] + (p[2] - p0[2]) * u[2])
            yMin = minOf(yMin, p[1]); yMax = maxOf(yMax, p[1])
        }
        if (s.size < MIN_ROWS * h || yMax - yMin < MIN_LINE_HEIGHT_M) return null
        val cornerX = median(s)
        if (median(s.map { abs(it - cornerX) }) > MAX_LINE_SPREAD_M) return null

        // The placed wall keeps the side its own pixels are on.
        val sa = ArrayList<Float>()
        for (k in a.indices step 37) if (a[k]) {
            hit((k % w).toFloat(), (k / w).toFloat(), w, h, proj, view, cam, p0, n)?.let { sa.add((it[0] - p0[0]) * u[0] + (it[2] - p0[2]) * u[2]) }
        }
        if (sa.isEmpty()) return null
        val keepA = if (median(sa) >= cornerX) 1 else -1

        // Second wall: through the corner line, normal along the first wall (square corner), facing the camera.
        val c = floatArrayOf(p0[0] + u[0] * cornerX, p0[1], p0[2] + u[2] * cornerX)
        val nb = if ((cam[0] - c[0]) * u[0] + (cam[2] - c[2]) * u[2] >= 0f) u else floatArrayOf(-u[0], 0f, -u[2])
        val ub = floatArrayOf(-nb[2], 0f, nb[0])
        // Every sampled B pixel must land on that plane in front of the camera, all on one side of the corner.
        var ok = 0; var tot = 0; var pos = 0
        val bx = ArrayList<Float>(); val bz = ArrayList<Float>()
        for (k in b.indices step 23) if (b[k]) {
            tot++
            val p = hit((k % w).toFloat(), (k / w).toFloat(), w, h, proj, view, cam, c, nb) ?: continue
            val lx = (p[0] - c[0]) * ub[0] + (p[2] - c[2]) * ub[2]
            ok++; if (lx > 0f) pos++
            bx.add(lx); bz.add(p[1] - c[1])
        }
        if (tot == 0 || ok < MIN_CONSISTENT * tot) return null
        val keepB = if (pos >= ok - pos) 1 else -1
        if (maxOf(pos, ok - pos) < MIN_CONSISTENT * ok) return null
        return Corner(cornerX, keepA, c, nb, keepB, median(bx), median(bz))
    }

    /** Where the ray through mask pixel ([px], [py]) meets the plane (p0, n), within [MAX_DIST_M], or null. */
    private fun hit(
        px: Float, py: Float, w: Int, h: Int, proj: FloatArray, view: FloatArray, cam: FloatArray, p0: FloatArray, n: FloatArray,
    ): FloatArray? {
        val d = WallEdges.ray(px, py, w, h, proj, view)
        val den = n[0] * d[0] + n[1] * d[1] + n[2] * d[2]
        if (abs(den) < 1e-4f) return null
        val t = (n[0] * (p0[0] - cam[0]) + n[1] * (p0[1] - cam[1]) + n[2] * (p0[2] - cam[2])) / den
        if (t <= 0f || t > MAX_DIST_M) return null
        return floatArrayOf(cam[0] + t * d[0], cam[1] + t * d[1], cam[2] + t * d[2])
    }

    private fun largestComponent(m: BooleanArray, w: Int, h: Int): BooleanArray? {
        val label = IntArray(w * h); var best = 0; var bestN = 0; var next = 0
        val stack = IntArray(w * h)
        for (start in m.indices) {
            if (!m[start] || label[start] != 0) continue
            next++; var sp = 0; var cnt = 0
            stack[sp++] = start; label[start] = next
            while (sp > 0) {
                val k = stack[--sp]; cnt++
                val x = k % w; val y = k / w
                if (x > 0 && m[k - 1] && label[k - 1] == 0) { label[k - 1] = next; stack[sp++] = k - 1 }
                if (x < w - 1 && m[k + 1] && label[k + 1] == 0) { label[k + 1] = next; stack[sp++] = k + 1 }
                if (y > 0 && m[k - w] && label[k - w] == 0) { label[k - w] = next; stack[sp++] = k - w }
                if (y < h - 1 && m[k + w] && label[k + w] == 0) { label[k + w] = next; stack[sp++] = k + w }
            }
            if (cnt > bestN) { bestN = cnt; best = next }
        }
        if (best == 0) return null
        return BooleanArray(w * h) { label[it] == best }
    }

    private fun median(v: List<Float>): Float = v.sorted()[v.size / 2]
}
