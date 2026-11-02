package com.graziastones.grazia_stones.ar

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WallMaskAccumulatorTest {
    private val gw = WallSegmenter.GW
    private val gh = WallSegmenter.GH
    private val mw = WallSegmenter.MASK_W
    private val mh = WallSegmenter.MASK_H
    private val ow = WallSegmenter.OUT_W
    private val oh = WallSegmenter.OUT_H

    // Quad 8 x 4 m (bottom at z = 0) filling the whole view: nx = x / 4, ny = z / 2 - 1, w = 1.
    private val identity = FloatArray(16).also { it[0] = 1f; it[5] = 1f; it[10] = 1f; it[15] = 1f }
    private val vp = FloatArray(16).also { it[0] = 0.25f; it[9] = 0.5f; it[13] = -1f; it[15] = 1f }

    /** A plain wall with an object at view u 0.4..0.6, v 0.35..0.5 that has exactly the wall's colour. */
    private fun frame(objectClass: Int, modelSeesWall: Boolean = true): WallSegmenter.Result {
        fun inObj(u: Float, v: Float) = u in 0.4f..0.6f && v in 0.35f..0.5f
        val lab = Array(3) { c -> FloatArray(gw * gh) { if (c == 0) 60f else if (c == 1) 130f else 134f } }
        val wall = ByteArray(mw * mh) { k ->
            val u = (k % mw + 0.5f) / mw; val v = (k / mw + 0.5f) / mh
            if (!modelSeesWall || inObj(u, v)) 0 else 255.toByte()
        }
        val classes = ByteArray(ow * oh) { k ->
            val u = (k % ow + 0.5f) / ow; val v = (k / ow + 0.5f) / oh
            (if (inObj(u, v)) objectClass else 0).toByte()
        }
        val n = mw * mh
        return WallSegmenter.Result(wall, ByteArray(n), FloatArray(n), FloatArray(n), FloatArray(n), lab, BooleanArray(gw * gh), classes)
    }

    private fun wallAt(m: WallMaskAccumulator, x: Float, z: Float): Int {
        val i = ((x / 8f + 0.5f) * WallMaskAccumulator.W).toInt()
        val j = (z / 4f * WallMaskAccumulator.H).toInt()
        return m.toBytes()[(j * WallMaskAccumulator.W + i) * 2].toInt() and 0xFF
    }

    private fun WallMaskAccumulator.feed(seg: WallSegmenter.Result, seedX: Float, seedZ: Float) =
        update(seg, mw, mh, vp, identity, 8f, 4f, 0f, seedZ, 2f, seedX = seedX)

    @Test fun `a painting the colour of the wall is cut from the stone`() {
        val m = WallMaskAccumulator()
        m.feed(frame(22), seedX = -2f, seedZ = 2f)
        // Object centre: u 0.5 -> x 0; v 0.425 -> ny 0.15 -> z 2.3.
        assertEquals(0, wallAt(m, 0f, 2.3f))
        assertEquals(255, wallAt(m, 2f, 1f))
        assertTrue(m.lastDebug, m.lastDebug.contains("hardCut="))
        // WallEdges / WallCorner still get the uncut outline.
        assertTrue(m.lastWall!![(gh * 425 / 1000) * gw + gw / 2])
    }

    @Test fun `a door is left to the colour fill (the model calls plain plaster door)`() {
        val m = WallMaskAccumulator()
        m.feed(frame(14), seedX = -2f, seedZ = 2f)
        assertEquals(255, wallAt(m, 0f, 2.3f))
    }

    @Test fun `a seed on the painting moves to the wall beside it`() {
        val m = WallMaskAccumulator()
        m.feed(frame(22), seedX = 0f, seedZ = 2.3f)
        assertTrue(m.lastDebug, m.lastDebug.contains("seed_off_object"))
        assertEquals(255, wallAt(m, 1f, 2.3f))
        assertEquals(0, wallAt(m, 0f, 2.3f))
    }

    @Test fun `an off-screen placement point seeds on the visible wall above it`() {
        val m = WallMaskAccumulator()
        m.feed(frame(0), seedX = 0f, seedZ = -2f) // ny = -2: below the screen
        assertTrue(m.lastDebug, m.lastDebug.contains("seed_fallback"))
        assertTrue(m.hasData)
        assertTrue(m.lastCoverage > 0.9f)
    }

    @Test fun `no confident wall on screen keeps the old skip`() {
        val m = WallMaskAccumulator()
        m.feed(frame(0, modelSeesWall = false), seedX = 0f, seedZ = -2f)
        assertEquals("skip=seed_off_screen", m.lastDebug)
        assertFalse(m.hasData)
    }

    @Test fun `the fallback never reaches past 1_5 m along the wall`() {
        val m = WallMaskAccumulator()
        m.feed(frame(0), seedX = 6f, seedZ = 2f) // nx = 1.5: right of the screen, nearest on-screen point is 2.4 m away
        assertEquals("skip=seed_off_screen", m.lastDebug)
    }

    @Test fun `matrix multiply matches the column-major convention`() {
        val t = FloatArray(16).also { it[0] = 1f; it[5] = 1f; it[10] = 1f; it[15] = 1f; it[12] = 3f }
        val s = FloatArray(16).also { it[0] = 2f; it[5] = 2f; it[10] = 2f; it[15] = 1f }
        val m = WallMaskAccumulator.mul(s, t) // scale after translate: x' = 2 * (x + 3)
        assertEquals(6f, m[12], 1e-6f)
        assertEquals(2f, m[0], 1e-6f)
    }

    @Test fun `affine view grid matches the three mapped corners`() {
        // Portrait view over a 640x480 landscape image: view (0,0) -> (640,0), (1,0) -> (640,480), (0,1) -> (0,0).
        val out = FloatArray(2 * 2 * 2)
        WallSegmenter.affineGrid(floatArrayOf(640f, 0f, 640f, 480f, 0f, 0f), 2, 2, out)
        assertEquals(480f, out[0], 1e-4f); assertEquals(120f, out[1], 1e-4f)  // (u, v) = (0.25, 0.25)
        assertEquals(160f, out[6], 1e-4f); assertEquals(360f, out[7], 1e-4f)  // (0.75, 0.75)
    }
}
