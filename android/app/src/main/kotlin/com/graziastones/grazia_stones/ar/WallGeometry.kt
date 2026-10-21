package com.graziastones.grazia_stones.ar

import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Pure geometry for wall placement (no ARCore types), so it can be unit-tested on the JVM.
 * World axes follow ARCore: +Y up. A "vertical" plane has a normal with a small Y component.
 */
object WallGeometry {
    /** A fitted plane: unit [normal], a [point] on it and how many input points were inliers. */
    class PlaneFit(val normal: FloatArray, val point: FloatArray, val inliers: Int)

    /** |normal.y| above this is a floor, ceiling or slope, never a wall. */
    const val MAX_WALL_NORMAL_Y = 0.35f

    /**
     * RANSAC vertical-plane fit. Returns null unless at least [minPoints] points and 40% of all points are
     * within [inlierM] of the best plane, and the inliers span at least [minSpreadM] along the wall or up it
     * (a single cluster on a switch or frame is not a wall). Deterministic for a given input (seeded).
     */
    fun fitVerticalPlane(
        pts: List<FloatArray>, iterations: Int = 80, inlierM: Float = 0.04f, minPoints: Int = 10, minSpreadM: Float = 0.35f,
    ): PlaneFit? {
        if (pts.size < minPoints) return null
        val rnd = java.util.Random(pts.size.toLong())
        var bestN: FloatArray? = null; var bestP: FloatArray? = null; var bestCount = 0
        repeat(iterations) {
            val a = pts[rnd.nextInt(pts.size)]; val b = pts[rnd.nextInt(pts.size)]; val c = pts[rnd.nextInt(pts.size)]
            val n = normalOf(a, b, c) ?: return@repeat
            if (abs(n[1]) > MAX_WALL_NORMAL_Y) return@repeat
            var count = 0
            for (q in pts) if (distanceToPlane(n, a, q) < inlierM) count++
            if (count > bestCount) { bestCount = count; bestN = n; bestP = a }
        }
        val n = bestN ?: return null; val p0 = bestP ?: return null
        if (bestCount < minPoints || bestCount < pts.size * 0.4f) return null
        var minA = Float.MAX_VALUE; var maxA = -Float.MAX_VALUE; var minY = Float.MAX_VALUE; var maxY = -Float.MAX_VALUE
        for (q in pts) {
            if (distanceToPlane(n, p0, q) >= inlierM) continue
            val along = -n[2] * q[0] + n[0] * q[2] // coordinate along the wall
            minA = minOf(minA, along); maxA = maxOf(maxA, along); minY = minOf(minY, q[1]); maxY = maxOf(maxY, q[1])
        }
        if (maxA - minA < minSpreadM && maxY - minY < minSpreadM) return null
        return PlaneFit(n, p0, bestCount)
    }

    /** Do two fits describe the same wall (parallel within ~14 degrees, offset within [offsetM])? */
    fun agree(a: PlaneFit, b: PlaneFit, offsetM: Float): Boolean {
        val dot = a.normal[0] * b.normal[0] + a.normal[1] * b.normal[1] + a.normal[2] * b.normal[2]
        if (abs(dot) < 0.97f) return false
        return distanceToPlane(a.normal, a.point, b.point) < offsetM
    }

    fun distanceToPlane(n: FloatArray, p0: FloatArray, q: FloatArray): Float =
        abs(n[0] * (q[0] - p0[0]) + n[1] * (q[1] - p0[1]) + n[2] * (q[2] - p0[2]))

    private fun normalOf(a: FloatArray, b: FloatArray, c: FloatArray): FloatArray? {
        val ux = b[0] - a[0]; val uy = b[1] - a[1]; val uz = b[2] - a[2]
        val vx = c[0] - a[0]; val vy = c[1] - a[1]; val vz = c[2] - a[2]
        val nx = uy * vz - uz * vy; val ny = uz * vx - ux * vz; val nz = ux * vy - uy * vx
        val len = sqrt(nx * nx + ny * ny + nz * nz)
        if (len < 1e-4f) return null
        return floatArrayOf(nx / len, ny / len, nz / len)
    }
}
