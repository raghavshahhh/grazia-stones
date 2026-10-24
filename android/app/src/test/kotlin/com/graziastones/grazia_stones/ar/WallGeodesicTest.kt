package com.graziastones.grazia_stones.ar

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WallGeodesicTest {
    private val w = 120
    private val h = 200
    private val rnd = java.util.Random(3)

    /**
     * A brown wall (L 30..42, lit from the top-right) with a ceiling band (L 70, grey) across the top, a maroon
     * curtain on the left, and a beige board on the right wall edge whose top edge is nearly invisible.
     */
    private fun scene(): Array<FloatArray> {
        val lab = Array(3) { FloatArray(w * h) }
        for (y in 0 until h) for (x in 0 until w) {
            val k = y * w + x
            var l = 30f + 12f * (x / w.toFloat()) * (1f - y / h.toFloat()) + (rnd.nextFloat() - 0.5f) * 2f
            var a = 133f; var b = 137f
            when {
                y < 30 -> { l = 70f; a = 128f; b = 130f }                       // ceiling band
                x < 20 -> { l = 22f; a = 150f; b = 132f }                       // curtain
                x >= 95 && y in 110..160 -> { l = 47f }                         // board, same hue as the wall
            }
            lab[0][k] = l; lab[1][k] = a; lab[2][k] = b
        }
        return lab
    }

    private fun at(m: BooleanArray, x: Int, y: Int) = m[y * w + x]

    @Test fun `keeps the lit wall and stops at ceiling and curtain`() {
        val lab = scene()
        val nonWall = BooleanArray(w * h) { k -> k % w < 12 } // the model is sure about the curtain's middle
        val m = WallGeodesic.segment(lab, w, h, 60, 100, nonWall)
        assertTrue("wall at the seed", at(m, 60, 100))
        assertTrue("brightly lit wall corner", at(m, 90, 40))
        assertTrue("wall at the bottom", at(m, 60, 190))
        assertFalse("ceiling band", at(m, 60, 10))
        assertFalse("curtain", at(m, 8, 100))
        assertFalse("board on the wall", at(m, 110, 140))
    }

    @Test fun `raster geodesic stops at a hard edge`() {
        val s = FloatArray(10 * 10) { k -> if (k % 10 == 5) 100f else 0.01f }
        val d = WallGeodesic.geodesic(s, 10, 10, intArrayOf(0))
        assertTrue(d[9] > 50f)   // across the wall of cost 100
        assertTrue(d[90] < 1f)   // same side, far away
    }
}
