package com.graziastones.grazia_stones.ar

import kotlin.math.abs
import kotlin.math.hypot

/**
 * Decides at runtime whether this phone's Depth API can be trusted, by comparing its depth image with ARCore's
 * own feature points (metric, from visual-inertial tracking) at the same pixels. "Depth supported" is not enough:
 * the OnePlus NE2211 reports support and returned 9-36 m for a wall about 2 m away.
 *
 * TRUSTED after [CHECKS_TO_DECIDE] consecutive checks agree, REJECTED after as many clearly wrong ones (sticky for
 * the process, so bad depth is not retried endlessly), UNAVAILABLE when no decision is possible in time.
 * Pure Kotlin (no ARCore types), unit-tested on the JVM.
 */
class DepthValidator {
    enum class State { UNKNOWN, TRUSTED, REJECTED, UNAVAILABLE }

    companion object {
        const val MIN_SAMPLES = 12
        const val CHECKS_TO_DECIDE = 3
        const val GOOD_MEDIAN_ERR = 0.10f
        const val GOOD_P80_ERR = 0.25f
        const val BAD_MEDIAN_ERR = 0.25f
        const val MIN_CONFIDENCE = 0.5f
        const val DECIDE_WITHIN_MS = 20_000L
        const val MIN_DEPTH_M = 0.3f
        const val MAX_DEPTH_M = 6f
        // A depth hit must repeat within this share, near the same screen spot, before it places anything.
        const val HIT_AGREE = 0.10f
        const val HIT_WINDOW_MS = 1500L
        const val HIT_RADIUS_PX = 80f
    }

    @Volatile var state = State.UNKNOWN
        private set
    /** One-line summary of the last check, for logcat. */
    @Volatile var lastReport = "no check yet"
        private set
    private var good = 0
    private var bad = 0
    private var startedMs = -1L

    /**
     * One comparison: each sample is (feature-point depth m, depth-image depth m, confidence 0..1 or -1 when the
     * image has none). Returns the state after this check.
     */
    @Synchronized fun addCheck(samples: List<FloatArray>, nowMs: Long): State {
        if (state == State.REJECTED || state == State.UNAVAILABLE) return state
        if (startedMs < 0) startedMs = nowMs
        val errs = ArrayList<Float>(); val ratios = ArrayList<Float>()
        for (s in samples) {
            val point = s[0]; val img = s[1]; val conf = s[2]
            if (point !in MIN_DEPTH_M..MAX_DEPTH_M || img <= 0f) continue
            if (conf >= 0f && conf < MIN_CONFIDENCE) continue
            ratios.add(img / point); errs.add(abs(img / point - 1f))
        }
        if (errs.size < MIN_SAMPLES) {
            lastReport = "insufficient: ${errs.size}/${samples.size} usable samples"
            if (state == State.UNKNOWN && nowMs - startedMs > DECIDE_WITHIN_MS) state = State.UNAVAILABLE
            return state
        }
        errs.sort(); ratios.sort()
        val med = errs[errs.size / 2]; val p80 = errs[(errs.size * 4) / 5]; val medRatio = ratios[ratios.size / 2]
        when {
            med <= GOOD_MEDIAN_ERR && p80 <= GOOD_P80_ERR -> { good++; bad = 0 }
            med > BAD_MEDIAN_ERR -> { bad++; good = 0 }
            else -> { good = 0; bad = 0 } // in between: neither evidence for nor against
        }
        if (good >= CHECKS_TO_DECIDE && state == State.UNKNOWN) state = State.TRUSTED
        if (bad >= CHECKS_TO_DECIDE) state = State.REJECTED
        if (state == State.UNKNOWN && nowMs - startedMs > DECIDE_WITHIN_MS) state = State.UNAVAILABLE
        lastReport = "n=${errs.size} medianRatio=${"%.2f".format(medRatio)} medianErr=${"%.0f".format(med * 100)}% " +
            "p80Err=${"%.0f".format(p80 * 100)}% good=$good bad=$bad -> $state"
        return state
    }

    private var lastHit: FloatArray? = null // distance, sx, sy
    private var lastHitMs = 0L

    /**
     * A DepthPoint hit may place the wall only when depth is TRUSTED, the distance is plausible, and a previous hit
     * near the same screen spot within [HIT_WINDOW_MS] measured the same distance within [HIT_AGREE].
     * Returns null when accepted, otherwise the rejection reason.
     */
    @Synchronized fun rejectHit(distanceM: Float, sx: Float, sy: Float, nowMs: Long): String? {
        if (state != State.TRUSTED) return "depth_${state.name.lowercase()}"
        if (distanceM !in MIN_DEPTH_M..MAX_DEPTH_M) return "depth_implausible_distance"
        val prev = lastHit; val prevMs = lastHitMs
        lastHit = floatArrayOf(distanceM, sx, sy); lastHitMs = nowMs
        if (prev == null || nowMs - prevMs > HIT_WINDOW_MS || hypot(sx - prev[1], sy - prev[2]) > HIT_RADIUS_PX) {
            return "depth_waiting_for_repeat"
        }
        if (abs(distanceM - prev[0]) > HIT_AGREE * maxOf(distanceM, prev[0])) return "depth_unstable"
        return null
    }
}
