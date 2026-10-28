package com.graziastones.grazia_stones.ar

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.sqrt

class PlacementTest {
    @Test fun `provenance and scale of every placement kind`() {
        assertEquals("real_plane", Placement.provenance("Plane"))
        assertEquals("validated_depth", Placement.provenance("DepthPoint"))
        assertEquals("validated_pointcloud", Placement.provenance("pointcloud"))
        assertEquals("user_calibrated", Placement.provenance("user_calibrated"))
        assertEquals(Placement.Scale.MEASURED, Placement.scale("edge_floor_tracked"))
        // The wall's angle from its floor/ceiling line is real, but an assumed height is not a measurement.
        assertEquals(Placement.Scale.APPROXIMATE, Placement.scale("edge_ceiling"))
        assertEquals(Placement.Scale.APPROXIMATE, Placement.scale("edge_floor_assumed"))
        assertEquals(Placement.Scale.APPROXIMATE, Placement.scale("approximate"))
        assertEquals(Placement.Scale.USER, Placement.scale("user_calibrated"))
    }

    @Test fun `only approximate placements may be replaced automatically`() {
        assertTrue(Placement.upgradable("approximate"))
        assertTrue(Placement.upgradable("edge_ceiling"))
        assertFalse(Placement.upgradable("Plane"))
        assertFalse(Placement.upgradable("user_calibrated"))
        assertFalse(Placement.upgradable(null))
    }

    private fun norm(x: Float, y: Float, z: Float): FloatArray {
        val l = sqrt(x * x + y * y + z * z); return floatArrayOf(x / l, y / l, z / l)
    }

    @Test fun `a known length on the wall fixes its distance`() {
        // Camera at the origin, wall 2.4 m in front (normal +Z facing the camera); door edges 0.9 m apart.
        val cam = floatArrayOf(0f, 1.4f, 0f)
        val a = floatArrayOf(-0.45f, 1.0f, -2.4f); val b = floatArrayOf(0.45f, 1.0f, -2.4f)
        val r1 = norm(a[0] - cam[0], a[1] - cam[1], a[2] - cam[2])
        val r2 = norm(b[0] - cam[0], b[1] - cam[1], b[2] - cam[2])
        val d = WallCalibration.distanceForKnownLength(r1, r2, floatArrayOf(0f, 0f, 1f), 0.9f)
        assertNotNull(d)
        assertEquals(2.4f, d!!, 0.01f)
        val p = WallCalibration.pointOnWall(cam, r1, floatArrayOf(0f, 0f, 1f), 2.4f)
        assertEquals(-2.4f, p!![2], 0.01f)
    }

    @Test fun `degenerate calibrations are refused`() {
        val r = norm(0f, 0f, -1f)
        assertNull(WallCalibration.distanceForKnownLength(r, r, floatArrayOf(0f, 0f, 1f), 1f))          // same point
        assertNull(WallCalibration.distanceForKnownLength(r, norm(0.1f, 0f, -1f), floatArrayOf(0f, 0f, 1f), 50f)) // implausible
        assertNull(WallCalibration.distanceForKnownLength(norm(0f, 0f, 1f), r, floatArrayOf(0f, 0f, 1f), 1f))     // behind
    }
}

class SegmentationBudgetTest {
    @Test fun `segmentation slows down as the phone heats up and pauses when critical`() {
        assertEquals(900L, WallSegmenter.intervalForThermal(0, 900L))
        assertEquals(1300L, WallSegmenter.intervalForThermal(2, 900L))
        assertEquals(2000L, WallSegmenter.intervalForThermal(3, 900L))
        assertNull(WallSegmenter.intervalForThermal(4, 900L))
    }
}
