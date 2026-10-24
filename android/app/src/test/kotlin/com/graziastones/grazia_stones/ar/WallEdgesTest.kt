package com.graziastones.grazia_stones.ar

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.cos
import kotlin.math.sin

class WallEdgesTest {
    private val w = 270
    private val h = 600
    // Same intrinsics as the OnePlus test phone's portrait view (from a debug.grazia.dump frame).
    private val proj = floatArrayOf(3.0851f, 0f, 0f, 0f, 0f, 1.3814f, 0f, 0f, 0.0069f, -0.0009f, -1.001f, -1f, 0f, 0f, -0.1f, 0f)

    /** View matrix for a camera at [pos] turned [yawDeg] left and pitched [pitchDeg] up. */
    private fun view(pos: FloatArray, yawDeg: Float, pitchDeg: Float): FloatArray {
        val y = Math.toRadians(yawDeg.toDouble()); val p = Math.toRadians(pitchDeg.toDouble())
        // camera-to-world C = Ry(yaw) * Rx(pitch); view rotation R = C^T
        val c = arrayOf(
            floatArrayOf(cos(y).toFloat(), (sin(y) * sin(p)).toFloat(), (sin(y) * cos(p)).toFloat()),
            floatArrayOf(0f, cos(p).toFloat(), (-sin(p)).toFloat()),
            floatArrayOf((-sin(y)).toFloat(), (cos(y) * sin(p)).toFloat(), (cos(y) * cos(p)).toFloat()),
        )
        val v = FloatArray(16)
        for (r in 0 until 3) for (col in 0 until 3) v[col * 4 + r] = c[col][r] // R[r][col] = C[col][r]
        for (r in 0 until 3) v[12 + r] = -(0 until 3).sumOf { k -> (v[k * 4 + r] * pos[k]).toDouble() }.toFloat()
        v[15] = 1f
        return v
    }

    /** Wall through [p0] with horizontal normal at [wallYawDeg]; floor y = 0; ceiling y = [ceiling]. */
    private fun render(view: FloatArray, p0: FloatArray, wallYawDeg: Float, ceiling: Float = 2.9f): Pair<BooleanArray, ByteArray> {
        val a = Math.toRadians(wallYawDeg.toDouble())
        val n = floatArrayOf(sin(a).toFloat(), 0f, cos(a).toFloat())
        val cam = WallEdges.cameraPosition(view)
        val wall = BooleanArray(w * h); val classes = ByteArray(w * h)
        for (y in 0 until h) for (x in 0 until w) {
            val r = WallEdges.ray(x.toFloat(), y.toFloat(), w, h, proj, view)
            val den = n[0] * r[0] + n[2] * r[2]
            val t = if (kotlin.math.abs(den) > 1e-6f) (n[0] * (p0[0] - cam[0]) + n[2] * (p0[2] - cam[2])) / den else -1f
            val hitY = cam[1] + t * r[1]
            when {
                t > 0 && hitY in 0f..ceiling -> wall[y * w + x] = true
                r[1] < 0 -> classes[y * w + x] = 3 // floor
                else -> classes[y * w + x] = 5     // ceiling
            }
        }
        return wall to classes
    }

    private fun check(e: WallEdges.Estimate?, wallYawDeg: Float, dist: Float, tolM: Float) {
        assertNotNull(e)
        val a = Math.toRadians(wallYawDeg.toDouble())
        val dot = e!!.normal[0] * sin(a).toFloat() + e.normal[2] * cos(a).toFloat()
        assertTrue("normal off by ${Math.toDegrees(kotlin.math.acos(dot.toDouble().coerceIn(-1.0, 1.0)))} deg", dot > 0.995f)
        assertEquals(dist, e.distanceM, tolM)
    }

    @Test fun `floor line gives the wall angle and distance`() {
        val v = view(floatArrayOf(0f, 1.35f, 0f), yawDeg = 0f, pitchDeg = -25f)
        // Wall 2.5 m in front, turned 25 degrees.
        val (wall, classes) = render(v, floatArrayOf(0f, 0f, -2.5f), wallYawDeg = 25f)
        val e = WallEdges.estimate(wall, w, h, classes, w, h, proj, v, floorY = 0f)
        assertEquals("floor", e?.edge)
        check(e, 25f, 2.5f * cos(Math.toRadians(25.0)).toFloat(), 0.08f)
    }

    @Test fun `ceiling line alone gives the angle, distance from the typical height`() {
        val v = view(floatArrayOf(0f, 1.35f, 0f), yawDeg = 10f, pitchDeg = 22f)
        val (wall, classes) = render(v, floatArrayOf(0f, 0f, -2.2f), wallYawDeg = -20f)
        val e = WallEdges.estimate(wall, w, h, classes, w, h, proj, v, floorY = null)
        assertEquals("ceiling", e?.edge)
        check(e, -20f, 2.2f * cos(Math.toRadians(20.0)).toFloat(), 0.15f)
    }

    @Test fun `bottom edge over a bed is not used as the floor line`() {
        val v = view(floatArrayOf(0f, 1.35f, 0f), yawDeg = 0f, pitchDeg = -25f)
        val (wall, classes) = render(v, floatArrayOf(0f, 0f, -2.5f), wallYawDeg = 0f)
        classes.fill(7) // ADE20K bed everywhere below and above
        assertNull(WallEdges.estimate(wall, w, h, classes, w, h, proj, v, floorY = 0f)?.takeIf { it.edge == "floor" })
    }
}
