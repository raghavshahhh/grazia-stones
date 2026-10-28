package com.graziastones.grazia_stones.ar

import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Finds an A4 sheet (210 x 297 mm) stuck on the wall in the camera's luma image and measures the wall from it:
 * the four corners of a rectangle of known size fix the wall's distance and angle from ONE frame, with no depth
 * and no ARCore plane. On the OnePlus test phone this is the only metric source on a plain painted wall (its
 * depth read 2-64 m for a wall ~2 m away and ARCore grew no plane there).
 *
 * The shape is over-determined: the corner angle (90 deg) and the side ratio (sqrt 2) are free checks, so a
 * switchboard, a poster or a lamp is rejected instead of giving a wrong distance. Width and height each give
 * their own distance ([Measure.distShortM], [Measure.distLongM]) so they can be compared independently.
 *
 * Pure Kotlin (no Android types), unit-tested on the JVM. Holds its pixel buffers, so one instance per thread.
 */
class A4Reference {
    companion object {
        const val SHORT_M = 0.210f
        const val LONG_M = 0.297f
        private const val MIN_SIDE_PX = 24f
        private const val MAX_RATIO_ERR = 0.06f  // long/short side vs sqrt 2
        private const val MAX_COS = 0.10f        // corner angle within ~84..96 deg
        // Sheet vs wall, luma levels. A real crumpled sheet under one bulb read ~150 against a ~115 wall up close,
        // only 8-10 from 1.5 m on (exposure follows the bulb); shape, angle and straight edges reject the rest.
        private const val MIN_CONTRAST = 6f
        private const val MAX_EDGE_RMS_PX = 1.5f
        private const val MIN_STEP = 6f         // luma drop over 2 px for a point to count as outline
        // Regions are cut out by the sheet's own outline (gradient barriers), not by brightness: on the test wall
        // the bulb's glow made bare wall as bright as the sheet and the glow touched it, so no brightness threshold
        // separated them. Several barrier strengths, as wrinkles inside the sheet also make (weaker) edges.
        private val EDGE_THRESHOLDS = intArrayOf(5, 8, 12)

        /**
         * Wall from the sheet's corners (image px, cyclic order) and the CPU-image intrinsics. Camera frame:
         * +X right, +Y up, -Z forward, camera at the origin (ARCore Camera.getPose convention).
         */
        fun measure(c: FloatArray, fx: Float, fy: Float, cx: Float, cy: Float): Measure? =
            measureRays(Array(4) { i -> floatArrayOf((c[2 * i] - cx) / fx, -(c[2 * i + 1] - cy) / fy, -1f) }, SHORT_M, LONG_M)

        /**
         * Any rectangle of known size ([sideA] x [sideB] m, either order) from rays through its corners in cyclic
         * order, camera at the origin (any axes: the result comes back in the rays' axes). The painting / door /
         * switchboard calibration feeds hand-tapped corners, so it allows a looser shape match.
         */
        fun measureRays(
            d: Array<FloatArray>, sideA: Float, sideB: Float,
            maxRatioErr: Float = MAX_RATIO_ERR, maxCos: Float = MAX_COS,
        ): Measure? {
            val shortM = minOf(sideA, sideB); val longM = maxOf(sideA, sideB)
            // Rectangle -> parallelogram: P0 + P2 = P1 + P3 with P_i = t_i d_i, t0 = 1.
            //   -t1 d1 + t2 d2 - t3 d3 = -d0
            val m = arrayOf(
                floatArrayOf(-d[1][0], d[2][0], -d[3][0]),
                floatArrayOf(-d[1][1], d[2][1], -d[3][1]),
                floatArrayOf(-d[1][2], d[2][2], -d[3][2]),
            )
            val t = solve3(m, floatArrayOf(-d[0][0], -d[0][1], -d[0][2])) ?: return null
            if (t.any { it <= 0f }) return null
            val tt = floatArrayOf(1f, t[0], t[1], t[2])
            val p = Array(4) { i -> FloatArray(3) { k -> tt[i] * d[i][k] } }
            val a = sub(p[1], p[0]); val b = sub(p[3], p[0])
            val la = len(a); val lb = len(b)
            if (la < 1e-6f || lb < 1e-6f) return null
            val cos = dot(a, b) / (la * lb)
            val lMax = maxOf(la, lb); val lMin = minOf(la, lb)
            val ratio = lMax / lMin
            if (abs(cos) > maxCos || abs(ratio / (longM / shortM) - 1f) > maxRatioErr) return null
            val n = cross(a, b).let { v -> val l = len(v); FloatArray(3) { v[it] / l } }
            val centreU = FloatArray(3) { k -> (p[0][k] + p[2][k]) / 2f }
            if (dot(n, centreU) > 0f) for (k in 0..2) n[k] = -n[k] // face the camera
            val depthU = abs(dot(n, p[0])) // perpendicular camera-to-wall distance, unit scale
            // Least-squares scale over both sides; each side alone gives its own distance for comparison.
            val s = (longM * lMax + shortM * lMin) / (lMax * lMax + lMin * lMin)
            return Measure(
                distanceM = s * depthU, distShortM = shortM / lMin * depthU, distLongM = longM / lMax * depthU,
                normal = n, centre = FloatArray(3) { s * centreU[it] }, ratio = ratio, cosAngle = cos,
            )
        }

        /** Four points (x0,y0..x3,y3) re-ordered around their centre, so corners can be tapped in any order. */
        fun cyclic(p: FloatArray): FloatArray {
            val cx = (p[0] + p[2] + p[4] + p[6]) / 4f; val cy = (p[1] + p[3] + p[5] + p[7]) / 4f
            val order = (0 until 4).sortedBy { kotlin.math.atan2(p[2 * it + 1] - cy, p[2 * it] - cx) }
            return FloatArray(8) { k -> p[2 * order[k / 2] + k % 2] }
        }

        private fun solve3(m: Array<FloatArray>, r: FloatArray): FloatArray? {
            fun det(a: Array<FloatArray>) =
                a[0][0] * (a[1][1] * a[2][2] - a[1][2] * a[2][1]) -
                    a[0][1] * (a[1][0] * a[2][2] - a[1][2] * a[2][0]) +
                    a[0][2] * (a[1][0] * a[2][1] - a[1][1] * a[2][0])
            val dm = det(m)
            if (abs(dm) < 1e-9f) return null
            return FloatArray(3) { col -> det(Array(3) { row -> FloatArray(3) { k -> if (k == col) r[row] else m[row][k] } }) / dm }
        }

        private fun sub(a: FloatArray, b: FloatArray) = floatArrayOf(a[0] - b[0], a[1] - b[1], a[2] - b[2])
        private fun dot(a: FloatArray, b: FloatArray) = a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
        private fun len(a: FloatArray) = sqrt(dot(a, a))
        private fun cross(a: FloatArray, b: FloatArray) =
            floatArrayOf(a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])
    }

    /** distanceM: perpendicular camera-to-wall; centre: sheet centre in the camera frame (metres). */
    class Measure(
        val distanceM: Float, val distShortM: Float, val distLongM: Float,
        val normal: FloatArray, val centre: FloatArray, val ratio: Float, val cosAngle: Float,
    )

    private var lum = IntArray(0)
    private var grad = IntArray(0)
    private var labels = IntArray(0)
    private var stack = IntArray(0)
    private var w = 0
    private var h = 0

    /** Last rejection, for logcat. */
    var lastReport = ""
        private set

    /**
     * Corners of the most sheet-like bright quadrilateral (x0,y0..x3,y3 in image px, cyclic), sub-pixel, or null.
     * [y] is the luma plane with row stride [stride].
     */
    fun find(y: ByteArray, width: Int, height: Int, stride: Int): FloatArray? {
        w = width; h = height
        val n = w * h
        if (lum.size != n) { lum = IntArray(n); grad = IntArray(n); labels = IntArray(n); stack = IntArray(n) }
        for (r in 0 until h) for (x in 0 until w) lum[r * w + x] = y[r * stride + x].toInt() and 0xFF
        gradient()
        var best: FloatArray? = null; var bestRms = Float.MAX_VALUE; var candidates = 0
        val fails = ArrayList<String>()
        for (t in EDGE_THRESHOLDS) {
            labels.fill(0)
            var next = 1
            for (start in 0 until n) {
                if (labels[start] != 0 || grad[start] >= t) continue
                val rough = component(start, next++, t) ?: continue
                candidates++
                val (quad, rms) = refine(rough) ?: run { fails.add("t=$t ${rejectWhy} ${rough.joinToString(",") { "%.0f".format(it) }}"); null } ?: continue
                if (rms < bestRms) { bestRms = rms; best = quad }
            }
        }
        lastReport = if (best == null) "no sheet ($candidates bright quads: ${fails.take(4)})" else "rms=${"%.2f".format(bestRms)}px"
        return best
    }

    /** Flood-fills one edge-free region; returns its rough corners when it looks like a filled quadrilateral. */
    private fun component(start: Int, id: Int, t: Int): FloatArray? {
        var sp = 0; stack[sp++] = start; labels[start] = id
        var area = 0; var border = false
        var tl = start; var br = start; var tr = start; var bl = start
        fun s(i: Int) = i % w + i / w
        fun d(i: Int) = i % w - i / w
        while (sp > 0) {
            val i = stack[--sp]; area++
            val x = i % w; val yy = i / w
            if (x <= 2 || yy <= 2 || x >= w - 3 || yy >= h - 3) border = true
            if (s(i) < s(tl)) tl = i
            if (s(i) > s(br)) br = i
            if (d(i) > d(tr)) tr = i
            if (d(i) < d(bl)) bl = i
            if (x > 0) push(i - 1, id, t).let { if (it) stack[sp++] = i - 1 }
            if (x < w - 1) push(i + 1, id, t).let { if (it) stack[sp++] = i + 1 }
            if (yy > 0) push(i - w, id, t).let { if (it) stack[sp++] = i - w }
            if (yy < h - 1) push(i + w, id, t).let { if (it) stack[sp++] = i + w }
        }
        if (border || area < MIN_SIDE_PX * MIN_SIDE_PX) return null
        val c = floatArrayOf(
            (tl % w).toFloat(), (tl / w).toFloat(), (tr % w).toFloat(), (tr / w).toFloat(),
            (br % w).toFloat(), (br / w).toFloat(), (bl % w).toFloat(), (bl / w).toFloat(),
        )
        val quadArea = abs((0 until 4).sumOf { k ->
            val j = (k + 1) % 4
            (c[2 * k] * c[2 * j + 1] - c[2 * j] * c[2 * k + 1]).toDouble()
        } / 2.0).toFloat()
        // A filled quad covers its corner quadrilateral; a disc (lamp) or an L-shape does not.
        // Wrinkle edges punch holes in a real sheet's region, hence the loose lower bound; refine() checks edges.
        if (quadArea < 1f || area / quadArea !in 0.75f..1.08f) return null
        for (k in 0 until 4) {
            val j = (k + 1) % 4
            if (hypot(c[2 * j] - c[2 * k], c[2 * j + 1] - c[2 * k + 1]) < MIN_SIDE_PX) return null
        }
        return c
    }

    private fun push(i: Int, id: Int, t: Int): Boolean {
        if (labels[i] != 0 || grad[i] >= t) return false
        labels[i] = id
        return true
    }

    /**
     * Sub-pixel edges. The rough region can be short of the outline (a wrinkle cut it) so each side looks outward
     * up to 0.6 of its shortest side for the strongest bright-to-dark step, then takes the halfway luma crossing there
     * (a fixed threshold would move the edge with exposure and blur). A robust line through those points (wrinkle
     * hits dropped) per side; the lines meet at the refined corners. Null if a side is not a clean straight step.
     */
    private var rejectWhy = ""

    private fun refine(c: FloatArray): Pair<FloatArray, Float>? {
        val lines = Array(4) { FloatArray(3) } // a x + b y = c, (a, b) unit
        var worst = 0f
        val qcx = (c[0] + c[2] + c[4] + c[6]) / 4f; val qcy = (c[1] + c[3] + c[5] + c[7]) / 4f
        var minSide = Float.MAX_VALUE
        for (k in 0 until 4) { val j = (k + 1) % 4; minSide = minOf(minSide, hypot(c[2 * j] - c[2 * k], c[2 * j + 1] - c[2 * k + 1])) }
        val reach = maxOf(8f, minSide * 0.6f)
        for (k in 0 until 4) {
            val j = (k + 1) % 4
            val px = c[2 * k]; val py = c[2 * k + 1]; val qx = c[2 * j]; val qy = c[2 * j + 1]
            val l = hypot(qx - px, qy - py)
            var nx = (qy - py) / l; var ny = -(qx - px) / l
            if (nx * (qcx - px) + ny * (qcy - py) > 0f) { nx = -nx; ny = -ny } // n points out of the quad
            val xs = ArrayList<Float>(); val ys = ArrayList<Float>()
            val steps = (l * 0.7f).toInt().coerceAtLeast(1)
            for (s in 0..steps) {
                val f = 0.15f + 0.7f * s / steps
                val mx = px + f * (qx - px); val my = py + f * (qy - py)
                fun v(o: Float) = sample(mx + o * nx, my + o * ny)
                // Strongest drop (inside bright -> outside dark) over 2 px.
                var bestO = Float.NaN; var bestD = 0f
                var o = -6f
                while (o <= reach) {
                    val a = v(o - 1f); val b = v(o + 1f)
                    if (a >= 0 && b >= 0 && a - b > bestD) { bestD = a - b; bestO = o }
                    o += 0.5f
                }
                if (bestO.isNaN() || bestD < MIN_STEP) continue
                val hi = v(bestO - 3f); val lo = v(bestO + 3f)
                if (hi < 0 || lo < 0) continue
                val mid = (hi + lo) / 2f
                var oo = bestO - 3f
                while (oo < bestO + 3f) {
                    val a = v(oo); val b = v(oo + 0.25f)
                    if (a >= mid && b < mid) {
                        val t = oo + 0.25f * (a - mid) / (a - b)
                        xs.add(mx + t * nx); ys.add(my + t * ny)
                        break
                    }
                    oo += 0.25f
                }
            }
            if (xs.size < 10) { rejectWhy = "steps${xs.size}@side$k"; return null }
            // Robust: fit, drop points more than 2 px off, refit. Most of the side must be on the line.
            var fit = fitLine(xs, ys)
            val keepX = ArrayList<Float>(); val keepY = ArrayList<Float>()
            for (i in xs.indices) {
                if (abs(fit.first[0] * xs[i] + fit.first[1] * ys[i] - fit.first[2]) <= 2f) { keepX.add(xs[i]); keepY.add(ys[i]) }
            }
            if (keepX.size < maxOf(10, (steps * 0.5f).toInt())) { rejectWhy = "inliers${keepX.size}/${steps}@side$k"; return null }
            fit = fitLine(keepX, keepY)
            worst = maxOf(worst, fit.second)
            if (fit.second > MAX_EDGE_RMS_PX) { rejectWhy = "rms${"%.1f".format(fit.second)}@side$k"; return null }
            lines[k] = fit.first
        }
        // Corner k is where side k-1 meets side k.
        val out = FloatArray(8)
        for (k in 0 until 4) {
            val a = lines[(k + 3) % 4]; val b = lines[k]
            val det = a[0] * b[1] - a[1] * b[0]
            if (abs(det) < 1e-4f) return null
            out[2 * k] = (a[2] * b[1] - a[1] * b[2]) / det
            out[2 * k + 1] = (a[0] * b[2] - a[2] * b[0]) / det
            if (hypot(out[2 * k] - c[2 * k], out[2 * k + 1] - c[2 * k + 1]) > reach * 1.5f + 6f) { rejectWhy = "cornerMoved@$k"; return null }
        }
        // The refined sheet must be clearly brighter than the wall just outside it, all round.
        for (k in 0 until 4) {
            val j = (k + 1) % 4
            val ins = ArrayList<Float>(); val outs = ArrayList<Float>()
            val ocx = (out[0] + out[2] + out[4] + out[6]) / 4f; val ocy = (out[1] + out[3] + out[5] + out[7]) / 4f
            val l = hypot(out[2 * j] - out[2 * k], out[2 * j + 1] - out[2 * k + 1])
            var nx = (out[2 * j + 1] - out[2 * k + 1]) / l; var ny = -(out[2 * j] - out[2 * k]) / l
            if (nx * (ocx - out[2 * k]) + ny * (ocy - out[2 * k + 1]) > 0f) { nx = -nx; ny = -ny }
            for (s in 0..10) {
                val f = 0.2f + 0.06f * s
                val mx = out[2 * k] + f * (out[2 * j] - out[2 * k]); val my = out[2 * k + 1] + f * (out[2 * j + 1] - out[2 * k + 1])
                val a = sample(mx - 4 * nx, my - 4 * ny); val b = sample(mx + 4 * nx, my + 4 * ny)
                if (a < 0 || b < 0) { rejectWhy = "edgeOutOfImage"; return null }
                ins.add(a); outs.add(b)
            }
            ins.sort(); outs.sort()
            val contrast = ins[ins.size / 2] - outs[outs.size / 2]
            if (contrast < MIN_CONTRAST) { rejectWhy = "contrast${contrast.toInt()}@side$k"; return null }
        }
        return out to worst
    }

    /** Total-least-squares line (a, b, c) with a x + b y = c, and the RMS distance of the points to it. */
    private fun fitLine(xs: List<Float>, ys: List<Float>): Pair<FloatArray, Float> {
        val mx = xs.average().toFloat(); val my = ys.average().toFloat()
        var sxx = 0f; var syy = 0f; var sxy = 0f
        for (i in xs.indices) { val dx = xs[i] - mx; val dy = ys[i] - my; sxx += dx * dx; syy += dy * dy; sxy += dx * dy }
        // Normal = eigenvector of the smaller eigenvalue of the scatter matrix.
        val theta = 0.5f * kotlin.math.atan2(2 * sxy, sxx - syy) // direction of the line
        val a = -kotlin.math.sin(theta); val b = kotlin.math.cos(theta)
        val c = a * mx + b * my
        var ss = 0f
        for (i in xs.indices) { val e = a * xs[i] + b * ys[i] - c; ss += e * e }
        return floatArrayOf(a, b, c) to sqrt(ss / xs.size)
    }

    /** [grad] = |Sobel| / 4 of the luma, then grown by one pixel so a barely broken outline still closes. */
    private fun gradient() {
        grad.fill(255) // the image border is a barrier too
        val g = IntArray(w * h)
        for (yy in 1 until h - 1) for (xx in 1 until w - 1) {
            val i = yy * w + xx
            val gx = (lum[i - w + 1] + 2 * lum[i + 1] + lum[i + w + 1]) - (lum[i - w - 1] + 2 * lum[i - 1] + lum[i + w - 1])
            val gy = (lum[i + w - 1] + 2 * lum[i + w] + lum[i + w + 1]) - (lum[i - w - 1] + 2 * lum[i - w] + lum[i - w + 1])
            g[i] = (abs(gx) + abs(gy)) / 4
        }
        for (yy in 2 until h - 2) for (xx in 2 until w - 2) {
            val i = yy * w + xx
            var m = 0
            for (dy in -1..1) for (dx in -1..1) m = maxOf(m, g[i + dy * w + dx])
            grad[i] = m
        }
    }

    /** Bilinear luma, or -1 outside the image. */
    private fun sample(x: Float, y: Float): Float {
        if (x < 0f || y < 0f || x > w - 1.001f || y > h - 1.001f) return -1f
        val x0 = x.toInt(); val y0 = y.toInt(); val fx = x - x0; val fy = y - y0
        val i = y0 * w + x0
        val top = lum[i] + (lum[i + 1] - lum[i]) * fx
        val bot = lum[i + w] + (lum[i + w + 1] - lum[i + w]) * fx
        return top + (bot - top) * fy
    }

    private fun hypot(a: Float, b: Float) = sqrt(a * a + b * b)
}
