package com.graziastones.grazia_stones.ar

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WallMaskBrushTest {
    private val w = WallMaskAccumulator.W
    private val h = WallMaskAccumulator.H

    /** R channel (wall) of texel (i, j) from the uploaded RG8 bytes. */
    private fun wallAt(bytes: ByteArray, i: Int, j: Int) = bytes[(j * w + i) * 2].toInt() and 0xFF

    @Test fun `erase and restore override the mask and reset clears them`() {
        val m = WallMaskAccumulator()
        // Quad 8 x 4 m, bottom at z = 0: the centre texel is (w/2, h/2) at x = 0, z = 2.
        m.paint(0f, 2f, 0.3f, erase = false, quadW = 8f, quadH = 4f, zMin = 0f)
        assertTrue(m.userEdited)
        assertEquals(255, wallAt(m.toBytes(), w / 2, h / 2))
        m.paint(0f, 2f, 0.1f, erase = true, quadW = 8f, quadH = 4f, zMin = 0f)
        val b = m.toBytes()
        assertEquals(0, wallAt(b, w / 2, h / 2))            // erased centre
        assertEquals(255, wallAt(b, w / 2 + 12, h / 2))     // restored ring around it (0.1..0.3 m)
        assertEquals(0, wallAt(b, 5, 5))                     // untouched: automatic (empty) mask
        m.reset()
        assertFalse(m.userEdited)
        assertEquals(0, wallAt(m.toBytes(), w / 2 + 12, h / 2))
    }
}
