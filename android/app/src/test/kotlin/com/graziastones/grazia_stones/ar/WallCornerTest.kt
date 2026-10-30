package com.graziastones.grazia_stones.ar

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class WallCornerTest {
    private val w = 135
    private val h = 300
    // Camera at the origin looking down -Z (identity view), ~67 degree vertical field of view.
    private val view = FloatArray(16).also { it[0] = 1f; it[5] = 1f; it[10] = 1f; it[15] = 1f }
    private val proj = FloatArray(16).also { it[0] = 1.5f * h / w / 2f; it[5] = 1.5f; it[10] = -1f; it[11] = -1f }

    /**
     * Wall A at z = -2 (normal +Z) for x < [cx]; wall B at x = [cx] (normal -X) from z = -2 toward the camera, or
     * (convex = true) no B and A simply ends. Returns (A mask, model wall mask).
     */
    private fun scene(cx: Float, withB: Boolean = true, bLeaksAsWall: Boolean = true): Pair<BooleanArray, BooleanArray> {
        val a = BooleanArray(w * h); val m = BooleanArray(w * h)
        for (y in 0 until h) for (x in 0 until w) {
            val d = WallEdges.ray(x.toFloat(), y.toFloat(), w, h, proj, view)
            val tA = -2f / d[2]
            val hitA = tA > 0 && tA * d[0] < cx && kotlin.math.abs(tA * d[1]) < 1.4f
            val tB = if (d[0] > 1e-4f) cx / d[0] else Float.MAX_VALUE
            val zB = tB * d[2]
            val hitB = withB && tB > 0 && zB in -2f..-0.6f && kotlin.math.abs(tB * d[1]) < 1.4f
            val k = y * w + x
            when {
                hitB && (!hitA || tB < tA) -> m[k] = bLeaksAsWall
                hitA -> { a[k] = true; m[k] = true }
            }
        }
        return a to m
    }

    @Test fun `finds the square corner and the second wall`() {
        val (a, m) = scene(0.4f)
        val c = WallCorner.find(a, m, w, h, proj, view, floatArrayOf(0f, 0f, -2f), floatArrayOf(0f, 0f, 1f))
        assertNotNull(c)
        // Anchor local X = (-nz, 0, nx) = -world X, so the corner at world x = 0.4 is local -0.4; A keeps x < 0.4.
        assertEquals(-0.4f, c!!.cornerX, 0.03f)
        assertEquals(1, c.keepA)
        assertEquals(0.4f, c.point[0], 0.03f)
        // Second wall faces the camera: normal -X.
        assertEquals(-1f, c.normal[0], 1e-3f)
        assertEquals(0f, c.normal[2], 1e-3f)
        // Its seed lies on the wall, between the corner and the camera (z between -2 and -0.6).
        val ub = floatArrayOf(-c.normal[2], 0f, c.normal[0])
        val seedZw = c.point[2] + ub[2] * c.seedX
        assert(seedZw in -2f..-0.6f) { "seed z $seedZw" }
    }

    // Corner at (0.4, 0, -2): wall A along X at z = -2, the assumed square wall B runs from it toward the camera (+Z).
    private fun squareCorner() = WallCorner.Corner(
        cornerX = -0.4f, keepA = 1, point = floatArrayOf(0.4f, 0f, -2f), normal = floatArrayOf(-1f, 0f, 0f),
        keepB = -1, seedX = -0.8f, seedZ = 0f,
    )

    /** Points on a wall through the corner, running into the room at [deg] from wall A's face. */
    private fun wallPoints(deg: Double): List<FloatArray> {
        val rad = Math.toRadians(deg)
        // Wall A's face direction away from wall B is -X; B leaves the corner toward +Z, turned from square by deg-90.
        val ex = -kotlin.math.cos(rad).toFloat(); val ez = kotlin.math.sin(rad).toFloat()
        return (0 until 20).map { i -> val s = 0.4f + i * 0.08f; floatArrayOf(0.4f + ex * s, (i % 5) * 0.3f - 0.6f, -2f + ez * s) }
    }

    @Test fun `feature points turn the second wall to a 100 degree corner`() {
        val c = WallCorner.refineAngle(squareCorner(), wallPoints(100.0), floatArrayOf(0f, 0f, 0f))
        assertTrue(c.angleMeasured)
        assertEquals(100f, c.angleDeg, 1.5f)
        // The normal is perpendicular to the measured wall direction and faces the camera.
        val rad = Math.toRadians(100.0)
        val ex = -kotlin.math.cos(rad).toFloat(); val ez = kotlin.math.sin(rad).toFloat()
        assertEquals(0f, c.normal[0] * ex + c.normal[2] * ez, 0.02f)
        assertTrue((0f - c.point[0]) * c.normal[0] + (0f - c.point[2]) * c.normal[2] > 0f)
    }

    @Test fun `no feature points keeps the square assumption and says so`() {
        val c = WallCorner.refineAngle(squareCorner(), emptyList(), floatArrayOf(0f, 0f, 0f))
        assertFalse(c.angleMeasured)
        assertEquals(-1f, c.normal[0], 1e-4f)
    }

    @Test fun `scattered points do not turn the wall`() {
        val rnd = java.util.Random(1)
        val pts = (0 until 30).map { floatArrayOf(0.4f + rnd.nextFloat() * 1.2f - 0.6f, 0f, -2f + rnd.nextFloat() * 2f) }
        assertFalse(WallCorner.refineAngle(squareCorner(), pts, floatArrayOf(0f, 0f, 0f)).angleMeasured)
    }

    @Test fun `a single flat wall has no corner`() {
        val (a, m) = scene(5f, withB = false)
        assertNull(WallCorner.find(a, m, w, h, proj, view, floatArrayOf(0f, 0f, -2f), floatArrayOf(0f, 0f, 1f)))
    }

    @Test fun `a big non-wall object beside the wall is not a corner`() {
        val (a, m) = scene(0.4f, bLeaksAsWall = false)
        assertNull(WallCorner.find(a, m, w, h, proj, view, floatArrayOf(0f, 0f, -2f), floatArrayOf(0f, 0f, 1f)))
    }
}
