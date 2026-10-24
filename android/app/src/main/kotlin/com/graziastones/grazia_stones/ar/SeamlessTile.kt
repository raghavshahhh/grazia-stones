package com.graziastones.grazia_stones.ar

import android.graphics.Bitmap

/**
 * Makes a catalogue photo tile without visible seams: the right band overlaps the left band (then bottom onto top)
 * and each row is cut along the path where both sides match best (minimum-error boundary cut, image quilting,
 * Efros & Freeman 2001). On cladding the cut runs along mortar lines, so the wall reads as one surface instead of
 * a grid of photo edges. Cross-fading would ghost the stones instead.
 */
object SeamlessTile {
    private const val BAND = 0.12f

    fun make(src: Bitmap): Bitmap {
        var w = src.width; var h = src.height
        if (w < 32 || h < 32) return src
        var px = IntArray(w * h).also { src.getPixels(it, 0, w, 0, 0, w, h) }
        val bw = (w * BAND).toInt().coerceAtLeast(4)
        px = cutHorizontal(px, w, h, bw)
        w -= bw
        // Vertical: the same cut on the transposed image (h wide, w tall), then back.
        val bh = (h * BAND).toInt().coerceAtLeast(4)
        px = transpose(cutHorizontal(transpose(px, w, h), h, w, bh), h - bh, w)
        h -= bh
        return Bitmap.createBitmap(px, w, h, Bitmap.Config.ARGB_8888)
    }

    /** Period becomes w - band: columns [0, band) take the right band left of the cut, the original right of it. */
    private fun cutHorizontal(p: IntArray, w: Int, h: Int, band: Int): IntArray {
        val off = w - band
        val cum = FloatArray(h * band)
        val back = IntArray(h * band)
        for (y in 0 until h) for (c in 0 until band) {
            val e = diff(p[y * w + c], p[y * w + off + c])
            if (y == 0) { cum[c] = e; continue }
            var best = c; var bv = cum[(y - 1) * band + c]
            if (c > 0 && cum[(y - 1) * band + c - 1] < bv) { best = c - 1; bv = cum[(y - 1) * band + c - 1] }
            if (c < band - 1 && cum[(y - 1) * band + c + 1] < bv) { best = c + 1; bv = cum[(y - 1) * band + c + 1] }
            cum[y * band + c] = e + bv
            back[y * band + c] = best
        }
        var c = 0
        for (k in 1 until band) if (cum[(h - 1) * band + k] < cum[(h - 1) * band + c]) c = k
        val out = IntArray(off * h)
        for (y in h - 1 downTo 0) {
            for (x in 0 until off) out[y * off + x] = if (x < c) p[y * w + off + x] else p[y * w + x]
            if (y > 0) c = back[y * band + c]
        }
        return out
    }

    private fun diff(a: Int, b: Int): Float {
        val dr = ((a shr 16) and 0xFF) - ((b shr 16) and 0xFF)
        val dg = ((a shr 8) and 0xFF) - ((b shr 8) and 0xFF)
        val db = (a and 0xFF) - (b and 0xFF)
        return (dr * dr + dg * dg + db * db).toFloat()
    }

    private fun transpose(p: IntArray, w: Int, h: Int): IntArray {
        val out = IntArray(w * h)
        for (y in 0 until h) for (x in 0 until w) out[x * h + y] = p[y * w + x]
        return out
    }
}
