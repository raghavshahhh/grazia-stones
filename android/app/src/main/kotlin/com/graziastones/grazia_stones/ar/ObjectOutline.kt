package com.graziastones.grazia_stones.ar

import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/**
 * Finds the outline of the object under a seed point in a grey image (an A4 sheet, a tile, a book, a phone, a panel).
 *
 * "Magic wand" flood fill from the seed over pixels that stay close to their neighbour AND to the seed colour, then the
 * tightest rotated rectangle around that region, then each rectangle corner snapped to the region point nearest to it,
 * so a rectangle seen in perspective keeps its true (trapezoid) corners.
 *
 * Pure Kotlin on a plain byte array so it can be unit-tested without a phone or a camera.
 */
object ObjectOutline {
    /** Corners in image pixels, clockwise starting at the top-left-most corner, or null when nothing sensible was found. */
    fun find(gray: ByteArray, w: Int, h: Int, seedX: Int, seedY: Int): List<Pair<Float, Float>>? {
        if (w < 16 || h < 16 || seedX !in 0 until w || seedY !in 0 until h) return null
        val g = boxBlur(gray, w, h)
        val seed = patchMean(g, w, h, seedX, seedY, 3)

        val inRegion = BooleanArray(w * h)
        val stack = IntArray(w * h)
        var sp = 0
        stack[sp++] = seedY * w + seedX
        inRegion[seedY * w + seedX] = true
        var count = 0
        var touchesBorder = 0
        val xs = ArrayList<Int>()
        val ys = ArrayList<Int>()
        while (sp > 0) {
            val p = stack[--sp]
            val x = p % w
            val y = p / w
            count++
            if (x == 0 || y == 0 || x == w - 1 || y == h - 1) touchesBorder++
            val gp = u(g[p])
            var edge = false
            for (d in 0 until 4) {
                val nx = x + (if (d == 0) 1 else if (d == 1) -1 else 0)
                val ny = y + (if (d == 2) 1 else if (d == 3) -1 else 0)
                if (nx !in 0 until w || ny !in 0 until h) {
                    edge = true
                    continue
                }
                val q = ny * w + nx
                if (inRegion[q]) continue
                val gq = u(g[q])
                if (abs(gq - gp) <= NEIGHBOUR_STEP && abs(gq - seed) <= SEED_RANGE) {
                    inRegion[q] = true
                    stack[sp++] = q
                } else {
                    edge = true
                }
            }
            if (edge) {
                xs.add(x)
                ys.add(y)
            }
        }
        val area = w * h
        // Too small = noise, too large = the wall/floor itself (nothing to outline), or leaked past the border
        if (count < area * MIN_FRACTION || count > area * MAX_FRACTION || touchesBorder > (w + h) / 4) return null

        // Tightest rotated rectangle around the boundary points
        var bestArea = Double.MAX_VALUE
        var bestAngle = 0.0
        var step = 0
        while (step < 90) {
            val a = Math.toRadians(step.toDouble())
            val ca = cos(a)
            val sa = sin(a)
            var minU = Double.MAX_VALUE
            var maxU = -Double.MAX_VALUE
            var minV = Double.MAX_VALUE
            var maxV = -Double.MAX_VALUE
            for (i in xs.indices) {
                val ru = xs[i] * ca + ys[i] * sa
                val rv = -xs[i] * sa + ys[i] * ca
                if (ru < minU) minU = ru
                if (ru > maxU) maxU = ru
                if (rv < minV) minV = rv
                if (rv > maxV) maxV = rv
            }
            val boxArea = (maxU - minU) * (maxV - minV)
            if (boxArea < bestArea) {
                bestArea = boxArea
                bestAngle = a
            }
            step += 2
        }
        val ca = cos(bestAngle)
        val sa = sin(bestAngle)
        var minU = Double.MAX_VALUE
        var maxU = -Double.MAX_VALUE
        var minV = Double.MAX_VALUE
        var maxV = -Double.MAX_VALUE
        for (i in xs.indices) {
            val ru = xs[i] * ca + ys[i] * sa
            val rv = -xs[i] * sa + ys[i] * ca
            minU = min(minU, ru); maxU = max(maxU, ru)
            minV = min(minV, rv); maxV = max(maxV, rv)
        }
        val boxCorners = listOf(
            doubleArrayOf(minU, minV), doubleArrayOf(maxU, minV), doubleArrayOf(maxU, maxV), doubleArrayOf(minU, maxV),
        ).map { (ru, rv) -> doubleArrayOf(ru * ca - rv * sa, ru * sa + rv * ca) }

        // Snap each rectangle corner to the nearest real boundary point (keeps perspective trapezoids honest)
        val snapped = boxCorners.map { c ->
            var best = 0
            var bestD = Double.MAX_VALUE
            for (i in xs.indices) {
                val d = hypot(xs[i] - c[0], ys[i] - c[1])
                if (d < bestD) {
                    bestD = d
                    best = i
                }
            }
            Pair(xs[best].toFloat(), ys[best].toFloat())
        }
        // Order clockwise from the top-left-most corner
        val cx = snapped.sumOf { it.first.toDouble() } / 4
        val cy = snapped.sumOf { it.second.toDouble() } / 4
        val sorted = snapped.sortedBy { Math.atan2(it.second - cy, it.first - cx) }
        val start = sorted.indices.minByOrNull { sorted[it].first + sorted[it].second } ?: 0
        val ordered = List(4) { sorted[(start + it) % 4] }
        // A degenerate sliver is not an object
        val s1 = hypot(ordered[1].first - ordered[0].first, ordered[1].second - ordered[0].second)
        val s2 = hypot(ordered[3].first - ordered[0].first, ordered[3].second - ordered[0].second)
        return if (min(s1, s2) < min(w, h) * 0.06) null else ordered
    }

    private fun u(b: Byte): Int = b.toInt() and 0xFF

    private fun patchMean(g: ByteArray, w: Int, h: Int, x: Int, y: Int, r: Int): Int {
        var sum = 0
        var n = 0
        for (yy in max(0, y - r)..min(h - 1, y + r)) for (xx in max(0, x - r)..min(w - 1, x + r)) {
            sum += u(g[yy * w + xx]); n++
        }
        return sum / max(1, n)
    }

    private fun boxBlur(src: ByteArray, w: Int, h: Int): ByteArray {
        val out = ByteArray(w * h)
        for (y in 0 until h) for (x in 0 until w) {
            var sum = 0
            var n = 0
            for (yy in max(0, y - 1)..min(h - 1, y + 1)) for (xx in max(0, x - 1)..min(w - 1, x + 1)) {
                sum += u(src[yy * w + xx]); n++
            }
            out[y * w + x] = (sum / n).toByte()
        }
        return out
    }

    private const val NEIGHBOUR_STEP = 7
    private const val SEED_RANGE = 60
    private const val MIN_FRACTION = 0.01
    private const val MAX_FRACTION = 0.72
}
