package com.graziastones.grazia_stones.ar

import kotlin.math.abs
import kotlin.math.hypot
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ObjectOutlineTest {
    private fun scene(w: Int, h: Int, bg: Int, fg: Int, rect: IntArray): ByteArray {
        val g = ByteArray(w * h) { bg.toByte() }
        for (y in rect[1] until rect[3]) for (x in rect[0] until rect[2]) g[y * w + x] = fg.toByte()
        return g
    }

    @Test
    fun `bright sheet on a dark table gives its four corners`() {
        val w = 320
        val h = 240
        val g = scene(w, h, 40, 210, intArrayOf(100, 60, 220, 190)) // 120 x 130 px sheet
        val c = ObjectOutline.find(g, w, h, 160, 125)
        assertNotNull(c)
        val sides = (0 until 4).map { hypot(c!![(it + 1) % 4].first - c[it].first, c[(it + 1) % 4].second - c[it].second) }
        assertTrue("sides $sides", sides.sorted().let { abs(it[0] - 120f) < 4 && abs(it[3] - 130f) < 4 })
    }

    @Test
    fun `an empty uniform wall is not an object`() {
        val w = 320
        val h = 240
        assertNull(ObjectOutline.find(ByteArray(w * h) { 120 }, w, h, 160, 120))
    }
}
