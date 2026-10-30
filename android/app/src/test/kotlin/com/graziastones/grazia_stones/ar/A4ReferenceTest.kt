package com.graziastones.grazia_stones.ar

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

class A4ReferenceTest {
    private val w = 640
    private val h = 480
    private val f = 500f
    private val cx = 320f
    private val cy = 240f

    /**
     * Luma image of a wall [dist] m away turned [yawDeg], with a [sw] x [sh] m bright rectangle centred at
     * ([ox], [oy]) on it; 4x4 supersampled so edges are soft like a real camera's. Returns the image and the
     * true perpendicular distance.
     */
    private fun render(dist: Float, yawDeg: Float, sw: Float = 0.21f, sh: Float = 0.297f, ox: Float = 0.1f, oy: Float = 0.05f, disc: Boolean = false): Pair<ByteArray, Float> {
        val a = Math.toRadians(yawDeg.toDouble())
        val n = floatArrayOf(sin(a).toFloat(), 0f, cos(a).toFloat())
        val u = floatArrayOf(cos(a).toFloat(), 0f, (-sin(a)).toFloat())
        val p0 = floatArrayOf(ox, oy, -dist)
        val np0 = n[0] * p0[0] + n[1] * p0[1] + n[2] * p0[2]
        val rnd = java.util.Random(7)
        val img = ByteArray(w * h)
        for (y in 0 until h) for (x in 0 until w) {
            var hits = 0
            for (sy in 0 until 4) for (sx in 0 until 4) {
                val rx = (x + (sx + 0.5f) / 4 - cx) / f; val ry = -(y + (sy + 0.5f) / 4 - cy) / f; val rz = -1f
                val t = np0 / (n[0] * rx + n[2] * rz)
                val lx = t * rx - p0[0]; val ly = t * ry - p0[1]; val lz = t * rz - p0[2]
                val uu = lx * u[0] + lz * u[2]
                val inside = if (disc) uu * uu + ly * ly < (sw / 2) * (sw / 2) else abs(uu) < sw / 2 && abs(ly) < sh / 2
                if (inside) hits++
            }
            val v = 115 + 105 * hits / 16 + rnd.nextInt(7) - 3
            img[y * w + x] = v.coerceIn(0, 255).toByte()
        }
        return img to abs(np0)
    }

    private fun measure(img: ByteArray): A4Reference.Measure? =
        A4Reference().find(img, w, h, w)?.let { A4Reference.measure(it, f, f, cx, cy) }

    @Test fun `sheet facing the camera gives its distance`() {
        val (img, d) = render(2.0f, 0f)
        val m = measure(img)
        assertNotNull(m)
        assertEquals(d, m!!.distanceM, d * 0.02f)
        assertEquals(m.distShortM, m.distLongM, d * 0.03f)
    }

    @Test fun `turned wall still gives the perpendicular distance and angle`() {
        val (img, d) = render(1.5f, 25f)
        val m = measure(img)
        assertNotNull(m)
        assertEquals(d, m!!.distanceM, d * 0.03f)
        // Wall normal (sin 25, 0, cos 25) in the camera frame.
        assertEquals(sin(Math.toRadians(25.0)).toFloat(), m.normal[0], 0.06f)
    }

    @Test fun `far sheet at 3 m`() {
        val (img, d) = render(3.0f, 10f)
        val m = measure(img)
        assertNotNull(m)
        assertEquals(d, m!!.distanceM, d * 0.04f)
    }

    @Test fun `a switchboard shaped rectangle is not taken for A4`() {
        val (img, _) = render(1.5f, 0f, sw = 0.12f, sh = 0.24f)
        assertNull(measure(img))
    }

    @Test fun `a round lamp is not taken for A4`() {
        val (img, _) = render(1.5f, 0f, sw = 0.25f, disc = true)
        assertNull(measure(img))
    }

    /**
     * Real OnePlus NE2211 frames (640x480 luma, debug.grazia.dump) of a crumpled A4 sheet under one bulb whose
     * glow makes bare wall as bright as the sheet. The old raw-luma thresholds found nothing here.
     */
    @Test fun `real phone frames with a crumpled sheet under a bulb`() {
        for (id in listOf("f00", "f02", "f04")) {
            val y = javaClass.getResourceAsStream("/a4/oneplus_$id.y")!!.readBytes()
            val det = A4Reference()
            val c = det.find(y, 640, 480, 640)
            assertNotNull("sheet not found in $id: ${det.lastReport}", c)
            // Intrinsics from that dump's JSON.
            val m = A4Reference.measure(c!!, 447.74f, 449.60f, 323.76f, 237.54f)
            assertNotNull("not A4-shaped in $id", m)
            println("$id dist=${m!!.distanceM} w=${m.distShortM} h=${m.distLongM} ratio=${m.ratio} cos=${m.cosAngle}")
        }
    }

    @Test fun `real phone frames of a bulb and door frame without a sheet find nothing`() {
        for (id in listOf("f06", "f09")) {
            val y = javaClass.getResourceAsStream("/a4/oneplus_nosheet_$id.y")!!.readBytes()
            val m = A4Reference().find(y, 640, 480, 640)?.let { A4Reference.measure(it, 447.74f, 449.60f, 323.76f, 237.54f) }
            assertNull("false sheet in $id", m)
        }
    }

    /** Corners of a [sw] x [sh] m rectangle on a wall [dist] m away turned [yawDeg], projected to image px. */
    private fun corners(dist: Float, yawDeg: Float, sw: Float, sh: Float): FloatArray {
        val a = Math.toRadians(yawDeg.toDouble())
        val u = floatArrayOf(cos(a).toFloat(), 0f, (-sin(a)).toFloat())
        val c = floatArrayOf(0.05f, 0.1f, -dist)
        val out = FloatArray(8)
        val s = listOf(-1f to 1f, 1f to 1f, 1f to -1f, -1f to -1f)
        for ((k, p) in s.withIndex()) {
            val x = c[0] + p.first * sw / 2 * u[0]; val y = c[1] + p.second * sh / 2; val z = c[2] + p.first * sw / 2 * u[2]
            out[2 * k] = cx + f * x / -z; out[2 * k + 1] = cy - f * y / -z
        }
        return out
    }

    @Test fun `tapped painting corners in any order give the wall distance`() {
        val dist = 1.8f; val yaw = 20f
        val c = corners(dist, yaw, 0.50f, 0.36f)
        // Tapped out of order, each a couple of pixels off.
        val noise = floatArrayOf(1.5f, -2f, -1f, 1.5f, 2f, 1f, -1.5f, -1f)
        val tapped = FloatArray(8)
        val order = intArrayOf(2, 0, 3, 1)
        for (k in 0 until 4) { tapped[2 * k] = c[2 * order[k]] + noise[2 * k]; tapped[2 * k + 1] = c[2 * order[k] + 1] + noise[2 * k + 1] }
        val q = A4Reference.cyclic(tapped)
        val rays = Array(4) { i -> floatArrayOf((q[2 * i] - cx) / f, -(q[2 * i + 1] - cy) / f, -1f) }
        val m = A4Reference.measureRays(rays, 0.50f, 0.36f, maxRatioErr = 0.15f, maxCos = 0.2f)
        assertNotNull(m)
        val trueDist = abs(0.05f * sin(Math.toRadians(20.0)).toFloat() - dist * cos(Math.toRadians(20.0)).toFloat())
        assertEquals(trueDist, m!!.distanceM, trueDist * 0.04f)
        assertEquals(sin(Math.toRadians(20.0)).toFloat(), m.normal[0], 0.08f)
    }

    @Test fun `a wrong size for the tapped shape is rejected`() {
        val c = corners(1.8f, 0f, 0.50f, 0.36f)
        val rays = Array(4) { i -> floatArrayOf((c[2 * i] - cx) / f, -(c[2 * i + 1] - cy) / f, -1f) }
        assertNull(A4Reference.measureRays(rays, 0.50f, 0.20f, maxRatioErr = 0.15f, maxCos = 0.2f))
    }

    /**
     * The on-device path end to end: OnePlus NE2211's logged projection (1080x1920 view), screen taps turned into
     * rays by WallEdges.ray exactly as calibrateRectangle does. A 61 x 61 cm tape square 1.626 m away, taps up to
     * 5 px off, must come back within 3 %: if the device reads ~1.80 m, the error is not in this geometry.
     */
    @Test fun `tape square through the phone's projection gives the tape distance`() {
        val vw = 1080; val vh = 1920
        val proj = FloatArray(16).also { it[0] = 2.5097f; it[5] = 1.4117f; it[8] = -0.0099f; it[9] = 0.0264f; it[10] = -1f; it[11] = -1f; it[14] = -0.1f }
        val view = FloatArray(16).also { it[0] = 1f; it[5] = 1f; it[10] = 1f; it[15] = 1f }
        val d = 1.626f; val s = 0.61f
        fun px(x: Float, y: Float, z: Float): FloatArray {
            val cxp = proj[0] * x + proj[8] * z; val cyp = proj[5] * y + proj[9] * z; val wc = -z
            return floatArrayOf((cxp / wc + 1f) / 2f * vw, (1f - cyp / wc) / 2f * vh)
        }
        val world = listOf(floatArrayOf(-0.1f, 0.4f), floatArrayOf(0.51f, 0.4f), floatArrayOf(0.51f, -0.21f), floatArrayOf(-0.1f, -0.21f))
        val noise = floatArrayOf(4f, -5f, -3f, 4f, 5f, 3f, -4f, -2f)
        val taps = FloatArray(8)
        world.forEachIndexed { k, p -> val q = px(p[0], p[1], -d); taps[2 * k] = q[0] + noise[2 * k]; taps[2 * k + 1] = q[1] + noise[2 * k + 1] }
        val c = A4Reference.cyclic(taps)
        val rays = Array(4) { i -> WallEdges.ray(c[2 * i], c[2 * i + 1], vw, vh, proj, view) }
        val m = A4Reference.measureRays(rays, s, s, maxRatioErr = 0.15f, maxCos = 0.2f)
        assertNotNull(m)
        assertEquals(d, m!!.distanceM, d * 0.03f)
    }
}
