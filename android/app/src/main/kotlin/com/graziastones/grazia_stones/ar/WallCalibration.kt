package com.graziastones.grazia_stones.ar

import kotlin.math.sqrt

/**
 * User-calibrated scale for walls ARCore cannot measure (plain paint, no depth): the user taps the two ends of
 * something they measured on that wall (a door's width, a switchboard, the wall itself) and types the length.
 * With the wall's angle known (from a plane, its floor/ceiling line, or facing the camera), the two rays hit the
 * wall at points whose separation grows linearly with the wall's distance, which fixes that distance exactly.
 * Pure geometry (no ARCore types) so it is unit-tested on the JVM; world axes follow ARCore (+Y up).
 */
object WallCalibration {
    const val MIN_DISTANCE_M = 0.3f
    const val MAX_DISTANCE_M = 10f

    /** Horizontal unit normal facing the camera, from a wall normal. */
    private fun horizontal(n: FloatArray): FloatArray? {
        val len = sqrt(n[0] * n[0] + n[2] * n[2])
        return if (len < 1e-4f) null else floatArrayOf(n[0] / len, 0f, n[2] / len)
    }

    /** Where [ray] from [cam] meets the wall with normal [n] (facing the camera) [distanceM] in front of it. */
    fun pointOnWall(cam: FloatArray, ray: FloatArray, n: FloatArray, distanceM: Float): FloatArray? {
        val h = horizontal(n) ?: return null
        val nr = h[0] * ray[0] + h[2] * ray[2]
        if (nr > -0.05f) return null // the ray does not head into the wall
        val t = -distanceM / nr
        return floatArrayOf(cam[0] + t * ray[0], cam[1] + t * ray[1], cam[2] + t * ray[2])
    }

    /**
     * Distance from the camera to the wall (normal [n], facing the camera) at which rays [r1] and [r2] hit
     * points [lengthM] apart, or null when the rays do not both reach the wall or the result is implausible.
     */
    fun distanceForKnownLength(r1: FloatArray, r2: FloatArray, n: FloatArray, lengthM: Float): Float? {
        if (lengthM <= 0f) return null
        val h = horizontal(n) ?: return null
        val a = h[0] * r1[0] + h[2] * r1[2]
        val b = h[0] * r2[0] + h[2] * r2[2]
        if (a > -0.05f || b > -0.05f) return null
        // x_i - cam = (-D / a_i) r_i  ->  x1 - x2 = D (r2 / b - r1 / a)
        val dx = r2[0] / b - r1[0] / a; val dy = r2[1] / b - r1[1] / a; val dz = r2[2] / b - r1[2] / a
        val k = sqrt(dx * dx + dy * dy + dz * dz)
        if (k < 1e-4f) return null // the two taps are the same point
        val d = lengthM / k
        return d.takeIf { it in MIN_DISTANCE_M..MAX_DISTANCE_M }
    }

}
