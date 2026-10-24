package com.graziastones.grazia_stones.ar

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.sqrt

/**
 * Picks THE wall the design was placed on, at camera resolution, from the tapped point outwards.
 *
 * The ADE20K model calls every wall "wall" (side walls, the plastered ceiling band, a pinned-up board), so it
 * cannot tell this wall from that one, and its 20x44 output is far too coarse for an edge. Here the wall is the
 * set of pixels reachable from the seed without crossing an image edge or drifting away from the wall's colour
 * (geodesic distance, as in GeoS, Criminisi et al. 2008). Steps cost almost nothing on the wall's own texture and
 * gradual light falloff, and a lot across a real edge, so the region stops at ceiling lines, curtains, boards and
 * skirting at pixel accuracy. Pixels the model is sure are something else (person, curtain, bed, floor...) seed
 * a competing background region, which closes weak edges such as a dark curtain on a shadowed wall.
 *
 * Tuned offline on frames dumped from the phone (debug.grazia.dump); see tool/wall_lab/ for the prototype.
 */
object WallGeodesic {
    private const val EPS = 0.002f        // base step cost: path length barely matters
    private const val LAMBDA_CHROMA = 0.08f
    private const val TOL_CHROMA = 6f      // Lab a/b units the wall's colour may vary before it costs anything
    private const val MU_LIGHT = 0.05f
    private const val TOL_LIGHT = 9f       // L units a pixel may differ from the wall's local lighting
    private const val T = 3f               // geodesic radius of the wall region
    private const val ITERS = 3            // raster sweeps; 3 matched Dijkstra exactly on the test frames
    private const val BORDER = 2           // no travelling along the screen edge (objects cut by it leaked in)
    private const val BLOCKED = 1e3f

    /**
     * @param lab L (0..100), a, b (8-bit Lab, +128 offset) at [w] x [h], row 0 = screen top, already smoothed
     * @param nonWall background seeds, true where the model is confident the pixel is not wall
     * @return true for wall pixels connected to ([sx], [sy])
     */
    fun segment(lab: Array<FloatArray>, w: Int, h: Int, sx: Int, sy: Int, nonWall: BooleanArray): BooleanArray {
        val (lL, la, lb) = Triple(lab[0], lab[1], lab[2])
        val cost = dilate3(edgeCost(lab, w, h), w, h)
        // The wall's colour and its own texture noise, measured around the seed.
        val refA = patchMedian(la, w, h, sx, sy, 20); val refB = patchMedian(lb, w, h, sx, sy, 20)
        val floor = patchPercentile(cost, w, h, sx, sy, 25, 0.95f)
        val step1 = FloatArray(w * h) { k ->
            val e = max(cost[k] - floor, 0f)
            val dc = sqrt((la[k] - refA) * (la[k] - refA) + (lb[k] - refB) * (lb[k] - refB))
            val c = max(dc - TOL_CHROMA, 0f)
            EPS + e * e + LAMBDA_CHROMA * c * c
        }
        val fg = IntArray(25) { i -> ((sy + (i / 5 - 2) * 3).coerceIn(0, h - 1)) * w + (sx + (i % 5 - 2) * 3).coerceIn(0, w - 1) }
        val bgSeeds = nonWall.indices.filter { nonWall[it] }.toIntArray()
        val dB = geodesic(step1, w, h, bgSeeds)
        val first = geodesic(step1, w, h, fg)
        val m1 = BooleanArray(w * h) { first[it] < T && first[it] < dB[it] }

        // Second pass: brightness relative to THIS wall's lighting field (a large median over pass-1 wall pixels),
        // so smooth falloff from a lamp stays wall while a sharp brightness step (a board, a switch plate) does not.
        val illum = illumination(lL, m1, w, h)
        for (k in step1.indices) {
            val d = max(abs(lL[k] - illum[k]) - TOL_LIGHT, 0f)
            step1[k] += MU_LIGHT * d * d
        }
        for (y in 0 until h) for (x in 0 until w) {
            if (x < BORDER || x >= w - BORDER || y < BORDER || y >= h - BORDER) step1[y * w + x] = BLOCKED
        }
        val dF = geodesic(step1, w, h, fg)
        val m = BooleanArray(w * h) { dF[it] < T && dF[it] < dB[it] }
        // The blocked frame takes its inner neighbour's value.
        for (y in 0 until h) for (x in 0 until w) {
            val ix = x.coerceIn(BORDER, w - 1 - BORDER); val iy = y.coerceIn(BORDER, h - 1 - BORDER)
            if (ix != x || iy != y) m[y * w + x] = m[iy * w + ix]
        }
        return m
    }

    /** Colour gradient magnitude (Delta-E per pixel) from 3x3 Sobel on each Lab channel. */
    fun edgeCost(lab: Array<FloatArray>, w: Int, h: Int): FloatArray {
        val out = FloatArray(w * h)
        for (ch in lab) {
            for (y in 0 until h) {
                val ym = if (y > 0) y - 1 else 1; val yp = if (y < h - 1) y + 1 else h - 2
                for (x in 0 until w) {
                    val xm = if (x > 0) x - 1 else 1; val xp = if (x < w - 1) x + 1 else w - 2
                    fun v(xx: Int, yy: Int) = ch[yy * w + xx]
                    val gx = (v(xp, ym) + 2 * v(xp, y) + v(xp, yp)) - (v(xm, ym) + 2 * v(xm, y) + v(xm, yp))
                    val gy = (v(xm, yp) + 2 * v(x, yp) + v(xp, yp)) - (v(xm, ym) + 2 * v(x, ym) + v(xp, ym))
                    out[y * w + x] += gx * gx + gy * gy
                }
            }
        }
        for (k in out.indices) out[k] = sqrt(out[k]) / 8f
        return out
    }

    private fun dilate3(a: FloatArray, w: Int, h: Int): FloatArray {
        val tmp = FloatArray(w * h); val out = FloatArray(w * h)
        for (y in 0 until h) for (x in 0 until w) {
            var m = a[y * w + x]
            if (x > 0) m = max(m, a[y * w + x - 1]); if (x < w - 1) m = max(m, a[y * w + x + 1])
            tmp[y * w + x] = m
        }
        for (y in 0 until h) for (x in 0 until w) {
            var m = tmp[y * w + x]
            if (y > 0) m = max(m, tmp[(y - 1) * w + x]); if (y < h - 1) m = max(m, tmp[(y + 1) * w + x])
            out[y * w + x] = m
        }
        return out
    }

    /** Raster-scan geodesic distance (4-neighbour; step between k and n costs (s[k] + s[n]) / 2). */
    fun geodesic(s: FloatArray, w: Int, h: Int, seeds: IntArray): FloatArray {
        val d = FloatArray(w * h) { Float.POSITIVE_INFINITY }
        for (k in seeds) d[k] = 0f
        if (seeds.isEmpty()) return d
        repeat(ITERS) {
            for (y in 0 until h) {
                val r = y * w
                for (x in 0 until w) {
                    val k = r + x
                    var best = d[k]
                    if (x > 0) { val c = d[k - 1] + 0.5f * (s[k] + s[k - 1]); if (c < best) best = c }
                    if (y > 0) { val c = d[k - w] + 0.5f * (s[k] + s[k - w]); if (c < best) best = c }
                    d[k] = best
                }
            }
            for (y in h - 1 downTo 0) {
                val r = y * w
                for (x in w - 1 downTo 0) {
                    val k = r + x
                    var best = d[k]
                    if (x < w - 1) { val c = d[k + 1] + 0.5f * (s[k] + s[k + 1]); if (c < best) best = c }
                    if (y < h - 1) { val c = d[k + w] + 0.5f * (s[k] + s[k + w]); if (c < best) best = c }
                    d[k] = best
                }
            }
        }
        return d
    }

    /** Median of L over [wall] pixels in a large window, computed at 1/4 resolution (window ~124 px). */
    private fun illumination(lL: FloatArray, wall: BooleanArray, w: Int, h: Int): FloatArray {
        var n = 0; var sum = 0f
        for (k in lL.indices) if (wall[k]) { sum += lL[k]; n++ }
        val fill = if (n > 0) sum / n else 50f
        val sw = w / 4; val sh = h / 4
        val small = IntArray(sw * sh)
        for (y in 0 until sh) for (x in 0 until sw) {
            var acc = 0f
            for (dy in 0 until 4) for (dx in 0 until 4) { val k = (y * 4 + dy) * w + x * 4 + dx; acc += if (wall[k]) lL[k] else fill }
            small[y * sw + x] = (acc / 16f).toInt().coerceIn(0, 100)
        }
        // Median filter (radius 15 = window 31) with a sliding 101-bin histogram per row.
        val r = 15
        val med = FloatArray(sw * sh)
        val hist = IntArray(101)
        for (y in 0 until sh) {
            hist.fill(0); var count = 0
            val y0 = max(0, y - r); val y1 = minOf(sh - 1, y + r)
            for (yy in y0..y1) for (xx in 0..minOf(sw - 1, r)) { hist[small[yy * sw + xx]]++; count++ }
            for (x in 0 until sw) {
                if (x > 0) {
                    val add = x + r; val rem = x - r - 1
                    if (add < sw) for (yy in y0..y1) { hist[small[yy * sw + add]]++; count++ }
                    if (rem >= 0) for (yy in y0..y1) { hist[small[yy * sw + rem]]--; count-- }
                }
                var c = 0; var v = 0
                while (v < 100) { c += hist[v]; if (c * 2 >= count) break; v++ }
                med[y * sw + x] = v.toFloat()
            }
        }
        // Bilinear back up to full resolution.
        return FloatArray(w * h) { k ->
            val fx = ((k % w) + 0.5f) / 4f - 0.5f; val fy = ((k / w) + 0.5f) / 4f - 0.5f
            val x0 = fx.toInt().coerceIn(0, sw - 1); val y0 = fy.toInt().coerceIn(0, sh - 1)
            val x1 = minOf(x0 + 1, sw - 1); val y1 = minOf(y0 + 1, sh - 1)
            val tx = (fx - x0).coerceIn(0f, 1f); val ty = (fy - y0).coerceIn(0f, 1f)
            val top = med[y0 * sw + x0] + (med[y0 * sw + x1] - med[y0 * sw + x0]) * tx
            val bot = med[y1 * sw + x0] + (med[y1 * sw + x1] - med[y1 * sw + x0]) * tx
            top + (bot - top) * ty
        }
    }

    private fun patchValues(a: FloatArray, w: Int, h: Int, sx: Int, sy: Int, r: Int): FloatArray {
        val out = ArrayList<Float>((2 * r) * (2 * r))
        for (y in max(0, sy - r) until minOf(h, sy + r)) for (x in max(0, sx - r) until minOf(w, sx + r)) out.add(a[y * w + x])
        return out.toFloatArray().also { it.sort() }
    }

    private fun patchMedian(a: FloatArray, w: Int, h: Int, sx: Int, sy: Int, r: Int): Float =
        patchValues(a, w, h, sx, sy, r).let { if (it.isEmpty()) 128f else it[it.size / 2] }

    private fun patchPercentile(a: FloatArray, w: Int, h: Int, sx: Int, sy: Int, r: Int, q: Float): Float =
        patchValues(a, w, h, sx, sy, r).let { if (it.isEmpty()) 1f else it[((it.size - 1) * q).toInt()] }
}
