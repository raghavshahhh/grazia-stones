package com.graziastones.grazia_stones.ar

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class DepthProjectionTest {
    // OnePlus NE2211 texture intrinsics from the 2026-11-02 device log (DEPTH_PT lines).
    private val fx = 1322f; private val fy = 1332f; private val cx = 994f; private val cy = 540f
    private val w = 1920; private val h = 1080

    private fun tex(x: Float, y: Float, z: Float, width: Int = w, height: Int = h, px: Float = cx, py: Float = cy) =
        DepthProjection.toTexture(x, y, z, fx, fy, px, py, width, height)

    @Test fun `point on the optical axis lands on the principal point`() {
        val p = tex(0f, 0f, -2f)!!
        assertEquals(2f, p[0], 1e-6f)
        assertEquals(994f / 1920f, p[1], 1e-6f)
        assertEquals(0.5f, p[2], 1e-6f)
        // Depth 2 m in a 160x90 depth image: the pixel under the principal point.
        assertArrayEquals(intArrayOf(82, 45), DepthProjection.toDepthPixel(p[1], p[2], 160, 90))
    }

    @Test fun `camera right and up map to texture right and up`() {
        val right = tex(0.5f, 0f, -2f)!!
        assertEquals((1322f * 0.25f + 994f) / 1920f, right[1], 1e-6f)
        val up = tex(0f, 0.5f, -2f)!!
        assertEquals((540f - 1332f * 0.25f) / 1080f, up[2], 1e-6f) // up = smaller v (image y grows down)
        // Doubling the distance halves the offset from the principal point (pinhole).
        val far = tex(0.5f, 0f, -4f)!!
        assertEquals(4f, far[0], 1e-6f)
        assertEquals(right[1] - 994f / 1920f, 2f * (far[1] - 994f / 1920f), 1e-6f)
    }

    @Test fun `texture corners map to depth image corners`() {
        // A point that projects exactly onto texture pixel (0, 0) and one onto (1920, 1080).
        val z = -3f
        val topLeft = tex(-994f / fx * 3f, 540f / fy * 3f, z)!!
        assertEquals(0f, topLeft[1], 1e-5f); assertEquals(0f, topLeft[2], 1e-5f)
        assertArrayEquals(intArrayOf(0, 0), DepthProjection.toDepthPixel(0f, 0f, 160, 90))
        val bottomRight = tex((1920f - 994f) / fx * 3f, -(1080f - 540f) / fy * 3f, z)!!
        assertEquals(1f, bottomRight[1], 1e-5f); assertEquals(1f, bottomRight[2], 1e-5f)
        // u = v = 1 is the far edge, clamped onto the last pixel instead of one past it.
        assertArrayEquals(intArrayOf(159, 89), DepthProjection.toDepthPixel(1f, 1f, 160, 90))
    }

    @Test fun `points outside the texture have no depth pixel`() {
        val left = tex(-2f, 0f, -1f)!! // far beyond the left edge of a 72 deg field of view
        assertNull(DepthProjection.toDepthPixel(left[1], left[2], 160, 90))
        assertNull(DepthProjection.toDepthPixel(-0.001f, 0.5f, 160, 90))
        assertNull(DepthProjection.toDepthPixel(0.5f, 1.001f, 160, 90))
    }

    @Test fun `points behind or at the camera are rejected`() {
        assertNull(tex(0f, 0f, 1f)) // behind (+Z)
        assertNull(tex(0f, 0f, 0f))
        assertNull(tex(0f, 0f, -0.05f)) // at MIN_DEPTH_M
        assertNotNull(tex(0f, 0f, -0.06f))
    }

    @Test fun `portrait and landscape dimensions normalize by their own width and height`() {
        // Same point, landscape 1920x1080 texture vs a portrait 1080x1920 one (principal point at its centre).
        val land = tex(0.2f, 0.1f, -2f)!!
        val port = tex(0.2f, 0.1f, -2f, width = 1080, height = 1920, px = 540f, py = 960f)!!
        assertEquals((1322f * 0.1f + 994f) / 1920f, land[1], 1e-6f)
        assertEquals((1322f * 0.1f + 540f) / 1080f, port[1], 1e-6f)
        assertEquals((960f - 1332f * 0.05f) / 1920f, port[2], 1e-6f)
        // A portrait 90x160 depth image indexes x by width 90, y by height 160.
        assertArrayEquals(intArrayOf(45, 80), DepthProjection.toDepthPixel(0.5f, 0.5f, 90, 160))
        assertArrayEquals(intArrayOf(80, 45), DepthProjection.toDepthPixel(0.5f, 0.5f, 160, 90))
    }

    @Test fun `NaN and infinite cloud points are not projected`() {
        // ARCore's point cloud held (NaN, NaN, NaN) points on a featureless wall (device log 2026-11-02 session 5).
        assertNull(tex(Float.NaN, Float.NaN, Float.NaN))
        assertNull(tex(0f, 0f, Float.NEGATIVE_INFINITY))
        assertNull(tex(Float.POSITIVE_INFINITY, 0f, -2f))
    }
}
