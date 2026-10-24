package com.graziastones.grazia_stones.ar

import kotlin.math.abs
import kotlin.math.sqrt

/**
 * The wall's real orientation and distance from ONE camera frame, when ARCore has no plane for it (plain paint,
 * phone held still, no depth). The wall/floor and wall/ceiling lines are horizontal in the room, and ARCore knows
 * gravity, so the 3D direction of such a line in the image fixes the wall's yaw; where the line meets the floor
 * (or the ceiling, at a typical height) fixes its distance. Without this the design faced the camera at a guessed
 * 2 m, so any wall seen at an angle got the wrong perspective and scale.
 *
 * Pure geometry on the WallGeodesic mask (no ARCore types) so it is unit-tested on the JVM.
 * World axes follow ARCore: +Y up. Matrices are column-major OpenGL (ARCore Camera.getProjection/ViewMatrix).
 */
object WallEdges {
    /** Hand-held phone height above the floor when no floor plane is tracked. */
    const val ASSUMED_CAMERA_HEIGHT_M = 1.35f
    /** Typical Indian residential ceiling (10 ft), used only when the ceiling line is the only edge seen. */
    const val ASSUMED_CEILING_HEIGHT_M = 2.9f
    private const val MIN_COLUMNS = 0.25f      // share of columns that must show the edge
    private const val INLIER_PX = 2.5f
    private const val MIN_INLIERS = 0.7f
    private const val MAX_SLOPE = 0.6f         // |dy/dx| in pixels: steeper is not a wall/floor line in a portrait view
    private val FLOOR_CLASSES = setOf(3 /*floor*/, 28 /*rug*/)

    class Estimate(val base: FloatArray, val normal: FloatArray, val distanceM: Float, val edge: String)

    /**
     * @param wall WallGeodesic mask, [w] x [h], row 0 = screen top (view space)
     * @param classes ADE20K arg-max per model cell, [cw] x [ch], same view space
     * @param floorY tracked floor height, or null to assume [ASSUMED_CAMERA_HEIGHT_M] below the camera
     */
    fun estimate(
        wall: BooleanArray, w: Int, h: Int, classes: ByteArray?, cw: Int, ch: Int,
        proj: FloatArray, view: FloatArray, floorY: Float?,
    ): Estimate? {
        val cam = cameraPosition(view)
        val floor = floorY ?: (cam[1] - ASSUMED_CAMERA_HEIGHT_M)
        val bottom = edgePoints(wall, w, h, top = false)
        val top = edgePoints(wall, w, h, top = true)
        // The bottom edge is the floor line only if the model sees floor right below it (not a bed or sofa).
        val bottomLine = fitLine(bottom, w)?.takeIf { line -> classes == null || below(line, w, h, classes, cw, ch) in FLOOR_CLASSES }
        val topLine = fitLine(top, w)
        // The floor line wins: its height is known (or nearly), the ceiling's is assumed.
        return bottomLine?.let { fromLine(it, w, h, proj, view, cam, floor, floor, "floor") }
            ?: topLine?.let { fromLine(it, w, h, proj, view, cam, floor + ASSUMED_CEILING_HEIGHT_M, floor, "ceiling") }
    }

    /** Line y = a + b * x in mask pixels. */
    class Line(val a: Float, val b: Float)

    /** Topmost (or bottommost) wall pixel per column, kept only where the pixels beyond it are clearly not wall. */
    fun edgePoints(wall: BooleanArray, w: Int, h: Int, top: Boolean): List<FloatArray> {
        val pts = ArrayList<FloatArray>()
        val guard = 6
        for (x in 2 until w - 2) {
            val ys = if (top) (0 until h) else (h - 1 downTo 0)
            val y = ys.firstOrNull { wall[it * w + x] } ?: continue
            // The edge must be inside the image (not the screen border) with non-wall beyond and wall after it.
            if (y < guard || y > h - 1 - guard) continue
            val beyond = (1..guard).all { d -> !wall[(if (top) y - d else y + d) * w + x] }
            val inside = (1..10).all { d -> val yy = if (top) y + d else y - d; yy in 0 until h && wall[yy * w + x] }
            if (beyond && inside) pts.add(floatArrayOf(x.toFloat(), y.toFloat()))
        }
        return pts
    }

    /** RANSAC line through the edge points; null unless it spans enough columns and most points agree. */
    fun fitLine(pts: List<FloatArray>, w: Int): Line? {
        if (pts.size < w * MIN_COLUMNS) return null
        val rnd = java.util.Random(pts.size.toLong())
        var best: Line? = null; var bestCount = 0
        repeat(120) {
            val p = pts[rnd.nextInt(pts.size)]; val q = pts[rnd.nextInt(pts.size)]
            if (abs(q[0] - p[0]) < w * 0.15f) return@repeat
            val b = (q[1] - p[1]) / (q[0] - p[0]); val a = p[1] - b * p[0]
            if (abs(b) > MAX_SLOPE) return@repeat
            val count = pts.count { abs(it[1] - (a + b * it[0])) < INLIER_PX }
            if (count > bestCount) { bestCount = count; best = Line(a, b) }
        }
        if (bestCount < pts.size * MIN_INLIERS) return null
        // Least-squares refit on the inliers.
        val line = best ?: return null
        val inl = pts.filter { abs(it[1] - (line.a + line.b * it[0])) < INLIER_PX }
        val mx = inl.map { it[0] }.average().toFloat(); val my = inl.map { it[1] }.average().toFloat()
        var sxy = 0f; var sxx = 0f
        for (p in inl) { sxy += (p[0] - mx) * (p[1] - my); sxx += (p[0] - mx) * (p[0] - mx) }
        val b = if (sxx > 1e-3f) sxy / sxx else line.b
        return Line(my - b * mx, b)
    }

    /** ADE20K class a few pixels below the line's middle. */
    private fun below(line: Line, w: Int, h: Int, classes: ByteArray, cw: Int, ch: Int): Int {
        val x = w / 2f; val y = (line.a + line.b * x + 8f).coerceIn(0f, h - 1f)
        val cx = (x * cw / w).toInt().coerceIn(0, cw - 1); val cy = (y * ch / h).toInt().coerceIn(0, ch - 1)
        return classes[cy * cw + cx].toInt() and 0xFF
    }

    /**
     * Wall through a horizontal room edge seen as [line], lying at world height [edgeY]. The edge's direction is
     * the horizontal vector in the plane spanned by two of its rays; the wall normal is horizontal and
     * perpendicular to it; the base point is where the middle ray meets [edgeY], dropped to [floorY].
     */
    private fun fromLine(
        line: Line, w: Int, h: Int, proj: FloatArray, view: FloatArray, cam: FloatArray, edgeY: Float, floorY: Float,
        edge: String,
    ): Estimate? {
        val x1 = w * 0.2f; val x2 = w * 0.8f; val xm = w * 0.5f
        val r1 = ray(x1, line.a + line.b * x1, w, h, proj, view)
        val r2 = ray(x2, line.a + line.b * x2, w, h, proj, view)
        val rm = ray(xm, line.a + line.b * xm, w, h, proj, view)
        val n = wallNormalFromEdgeRays(r1, r2) ?: return null
        if (abs(rm[1]) < 1e-3f) return null
        val t = (edgeY - cam[1]) / rm[1]
        if (t <= 0f) return null // the line is on the wrong side of the horizon for this height
        val p = floatArrayOf(cam[0] + t * rm[0], edgeY, cam[2] + t * rm[2])
        // Face the user.
        if (n[0] * (cam[0] - p[0]) + n[2] * (cam[2] - p[2]) < 0) { n[0] = -n[0]; n[2] = -n[2] }
        val dist = abs(n[0] * (cam[0] - p[0]) + n[2] * (cam[2] - p[2]))
        if (dist !in 0.5f..8f) return null
        return Estimate(floatArrayOf(p[0], floorY, p[2]), n, dist, edge)
    }

    /** Horizontal wall normal from two rays through a horizontal edge: d = (r1 x r2) x up, n = up x d. */
    fun wallNormalFromEdgeRays(r1: FloatArray, r2: FloatArray): FloatArray? {
        val mx = r1[1] * r2[2] - r1[2] * r2[1]
        val mz = r1[0] * r2[1] - r1[1] * r2[0]
        // d = m x up = (-mz, 0, mx); n = up x d = (dz, 0, -dx) = (mx, 0, mz)
        val len = sqrt(mx * mx + mz * mz)
        if (len < 1e-6f) return null
        return floatArrayOf(mx / len, 0f, mz / len)
    }

    /** World-space direction through mask pixel ([px], [py]). */
    fun ray(px: Float, py: Float, w: Int, h: Int, proj: FloatArray, view: FloatArray): FloatArray {
        val xn = 2f * (px + 0.5f) / w - 1f
        val yn = 1f - 2f * (py + 0.5f) / h
        // Camera space (OpenGL looks down -Z): x_ndc = (P0 * x + P8 * z) / -z  ->  x = (x_ndc + P8) / P0 at z = -1.
        val cx = (xn + proj[8]) / proj[0]; val cy = (yn + proj[9]) / proj[5]; val cz = -1f
        // World = R^T * camera, R = view's rotation (column-major: R[r][c] = view[c * 4 + r]).
        val dx = view[0] * cx + view[1] * cy + view[2] * cz
        val dy = view[4] * cx + view[5] * cy + view[6] * cz
        val dz = view[8] * cx + view[9] * cy + view[10] * cz
        val len = sqrt(dx * dx + dy * dy + dz * dz)
        return floatArrayOf(dx / len, dy / len, dz / len)
    }

    /** Camera centre = -R^T t. */
    fun cameraPosition(view: FloatArray): FloatArray {
        val tx = view[12]; val ty = view[13]; val tz = view[14]
        return floatArrayOf(
            -(view[0] * tx + view[1] * ty + view[2] * tz),
            -(view[4] * tx + view[5] * ty + view[6] * tz),
            -(view[8] * tx + view[9] * ty + view[10] * tz),
        )
    }
}
