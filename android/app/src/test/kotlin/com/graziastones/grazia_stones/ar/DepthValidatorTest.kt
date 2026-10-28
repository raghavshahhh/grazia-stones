package com.graziastones.grazia_stones.ar

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class DepthValidatorTest {
    private val rnd = java.util.Random(5)

    /** [n] samples of feature points at 1.5-3 m whose depth-image value is [scale] x the truth (+/- [noise]). */
    private fun samples(n: Int, scale: Float, noise: Float = 0.03f, conf: Float = 0.9f) = List(n) {
        val d = 1.5f + rnd.nextFloat() * 1.5f
        floatArrayOf(d, d * scale * (1f + (rnd.nextFloat() - 0.5f) * 2f * noise), conf)
    }

    @Test fun `agreeing depth becomes trusted after three checks`() {
        val v = DepthValidator()
        assertEquals(DepthValidator.State.UNKNOWN, v.addCheck(samples(40, 1.0f), 0))
        assertEquals(DepthValidator.State.UNKNOWN, v.addCheck(samples(40, 1.0f), 1000))
        assertEquals(DepthValidator.State.TRUSTED, v.addCheck(samples(40, 1.0f), 2000))
    }

    @Test fun `OnePlus-like depth (walls reported 5-10x too far) is rejected and stays rejected`() {
        val v = DepthValidator()
        repeat(3) { v.addCheck(samples(40, 6f, noise = 0.4f), it * 1000L) }
        assertEquals(DepthValidator.State.REJECTED, v.state)
        // later good-looking data does not resurrect it
        assertEquals(DepthValidator.State.REJECTED, v.addCheck(samples(40, 1.0f), 5000))
    }

    @Test fun `low-confidence pixels are ignored and too few samples never decide`() {
        val v = DepthValidator()
        repeat(5) { v.addCheck(samples(40, 1.0f, conf = 0.2f), it * 1000L) }
        assertEquals(DepthValidator.State.UNKNOWN, v.state)
        v.addCheck(samples(5, 1.0f), 25_000)
        assertEquals(DepthValidator.State.UNAVAILABLE, v.state) // no decision within the time budget
    }

    @Test fun `unstable depth (alternating good and bad) never becomes trusted`() {
        val v = DepthValidator()
        repeat(6) { v.addCheck(samples(40, if (it % 2 == 0) 1.0f else 1.6f), it * 1000L) }
        assertEquals(DepthValidator.State.UNKNOWN, v.state)
    }

    @Test fun `a depth hit must be trusted, plausible and repeat before it places anything`() {
        val v = DepthValidator()
        assertEquals("depth_unknown", v.rejectHit(2f, 500f, 900f, 0))
        repeat(3) { v.addCheck(samples(40, 1.0f), it * 1000L) }
        assertEquals("depth_implausible_distance", v.rejectHit(14f, 500f, 900f, 3000))
        assertEquals("depth_waiting_for_repeat", v.rejectHit(2.0f, 500f, 900f, 3100))
        assertEquals("depth_unstable", v.rejectHit(2.6f, 510f, 905f, 3500))
        assertNull(v.rejectHit(2.62f, 512f, 905f, 3900))
    }
}
