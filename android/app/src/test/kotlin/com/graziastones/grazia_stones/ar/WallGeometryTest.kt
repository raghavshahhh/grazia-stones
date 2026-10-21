package com.graziastones.grazia_stones.ar

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs

class WallGeometryTest {
    private val rnd = java.util.Random(7)

    /** Points on the wall z = -2 (normal +Z), spread 1.2 m wide and 0.8 m tall, with [noise] m of jitter. */
    private fun wallPoints(n: Int, noise: Float = 0.01f, outliers: Int = 0): List<FloatArray> {
        val pts = ArrayList<FloatArray>()
        repeat(n) {
            pts.add(floatArrayOf(rnd.nextFloat() * 1.2f - 0.6f, rnd.nextFloat() * 0.8f + 0.8f, -2f + (rnd.nextFloat() - 0.5f) * 2 * noise))
        }
        repeat(outliers) { pts.add(floatArrayOf(rnd.nextFloat() * 2 - 1, rnd.nextFloat() * 2, -1f - rnd.nextFloat() * 2)) }
        return pts
    }

    @Test fun `fits a vertical wall through noisy points with outliers`() {
        val fit = WallGeometry.fitVerticalPlane(wallPoints(40, outliers = 10))
        assertNotNull(fit)
        assertTrue("normal should be +/-Z, was ${fit!!.normal.toList()}", abs(abs(fit.normal[2]) - 1f) < 0.05f)
        assertEquals(-2f, fit.point[2], 0.03f)
        assertTrue(fit.inliers >= 30)
    }

    @Test fun `rejects a floor (horizontal plane)`() {
        val floor = (0 until 40).map { floatArrayOf(rnd.nextFloat() * 2 - 1, 0f + (rnd.nextFloat() - 0.5f) * 0.02f, -rnd.nextFloat() * 2) }
        assertNull(WallGeometry.fitVerticalPlane(floor))
    }

    @Test fun `rejects too few points and a single small cluster`() {
        assertNull(WallGeometry.fitVerticalPlane(wallPoints(6)))
        val cluster = (0 until 30).map { floatArrayOf(rnd.nextFloat() * 0.1f, 1f + rnd.nextFloat() * 0.1f, -2f + (rnd.nextFloat() - 0.5f) * 0.01f) }
        assertNull(WallGeometry.fitVerticalPlane(cluster)) // 10 cm patch: a switch or a frame, not a wall
    }

    @Test fun `rejects when inliers are a minority`() {
        val mixed = wallPoints(12, outliers = 30)
        assertNull(WallGeometry.fitVerticalPlane(mixed))
    }

    @Test fun `agreement needs the same orientation and offset`() {
        val a = WallGeometry.PlaneFit(floatArrayOf(0f, 0f, 1f), floatArrayOf(0f, 1f, -2f), 20)
        val same = WallGeometry.PlaneFit(floatArrayOf(0f, 0f, -1f), floatArrayOf(0.5f, 1.2f, -2.05f), 20)
        val shifted = WallGeometry.PlaneFit(floatArrayOf(0f, 0f, 1f), floatArrayOf(0f, 1f, -2.4f), 20)
        val turned = WallGeometry.PlaneFit(floatArrayOf(0.5f, 0f, 0.866f), floatArrayOf(0f, 1f, -2f), 20)
        assertTrue(WallGeometry.agree(a, same, 0.12f))
        assertTrue(!WallGeometry.agree(a, shifted, 0.12f))
        assertTrue(!WallGeometry.agree(a, turned, 0.12f))
    }
}
