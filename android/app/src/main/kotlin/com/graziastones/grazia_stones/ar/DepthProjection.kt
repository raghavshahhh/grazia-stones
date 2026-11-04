package com.graziastones.grazia_stones.ar

/**
 * Camera-space point -> GPU-texture-normalized (u, v) -> depth-image pixel: the mapping every DepthValidator sample
 * goes through. Pure math (no ARCore types) so it is JVM-tested.
 *
 * Conventions follow ARCore: camera space is `Camera.getPose().inverse()` applied to a world point (+X right, +Y up,
 * looking down -Z, in the sensor's native landscape orientation); intrinsics are `Camera.getTextureIntrinsics()`
 * (pixels, origin top-left, y down); the depth image shares the GPU texture's aspect ratio and orientation.
 */
object DepthProjection {
    /** Points this close along the optical axis, or behind the camera, are not projected. */
    const val MIN_DEPTH_M = 0.05f

    /**
     * (depth along the optical axis in m, u, v) for camera-space point ([x], [y], [z]), or null when it is behind or
     * at the camera, or not finite. u and v are normalized by the texture [width] / [height] and may fall outside [0, 1].
     */
    fun toTexture(
        x: Float, y: Float, z: Float, fx: Float, fy: Float, cx: Float, cy: Float, width: Int, height: Int,
    ): FloatArray? {
        val depth = -z // the camera looks down -Z
        if (!(depth > MIN_DEPTH_M) || !x.isFinite() || !y.isFinite() || depth.isInfinite()) return null // ARCore's cloud holds NaN points
        return floatArrayOf(depth, (fx * x / depth + cx) / width, (cy - fy * y / depth) / height) // image y grows down
    }

    /** Depth-image pixel (x, y) for texture-normalized ([u], [v]), or null when that is outside the image. */
    fun toDepthPixel(u: Float, v: Float, depthWidth: Int, depthHeight: Int): IntArray? {
        if (u !in 0f..1f || v !in 0f..1f) return null
        return intArrayOf(
            (u * depthWidth).toInt().coerceAtMost(depthWidth - 1),
            (v * depthHeight).toInt().coerceAtMost(depthHeight - 1),
        )
    }
}
