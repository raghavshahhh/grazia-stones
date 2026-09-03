package com.graziastones.grazia_stones.ar

import android.content.Context
import android.util.Log

/**
 * ARCoreManager — native AR bridge for the `com.graziastones.ar/native`
 * method channel.
 *
 * HONEST CAPABILITY REPORTING:
 * The previous revision of this file used Sceneform/ARCore APIs that
 * never compiled (arFrame property, Session.removeAnchor,
 * MaterialFactory with raw ByteArray, Sceneform 1.17 namespace
 * collisions). Shipping code that cannot build means Android has had
 * NO native AR at all — silently.
 *
 * This shell keeps every method-channel contract the Dart side
 * (`ARNativeChannel`) expects, answers capability checks honestly
 * (isARSupported = false until a real implementation exists), and the
 * Flutter Live AR experience uses its real web-camera AR engine on
 * Android instead of pretending to have native AR. iOS ARKit
 * (ARKitManager.swift) is unaffected and remains the real native path.
 *
 * When a genuine ARCore implementation is built later, replace the
 * bodies below — the channel contract stays identical.
 */
class ARCoreManager private constructor(private val context: Context) {

    companion object {
        private const val TAG = "ARCoreManager"

        @Volatile
        private var INSTANCE: ARCoreManager? = null

        fun getInstance(context: Context): ARCoreManager {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: ARCoreManager(context).also { INSTANCE = it }
            }
        }
    }

    // Callbacks (kept so ARCorePlugin wiring stays valid)
    var onWallDetected: ((String, Map<String, Any>) -> Unit)? = null
    var onWallUpdated: ((String, Map<String, Any>) -> Unit)? = null
    var onWallRemoved: ((String) -> Unit)? = null
    var onTrackingStateChanged: ((String) -> Unit)? = null
    var onWallStateChanged: ((String) -> Unit)? = null
    var onMeasurementResult: ((Map<String, Any>) -> Unit)? = null
    var onError: ((String) -> Unit)? = null

    fun isARSupported(): Boolean {
        // Honest answer: native ARCore rendering is not implemented.
        // The Flutter layer falls back to its real web-camera AR engine.
        return false
    }

    fun initialize(
        previewView: android.view.View?,
        sceneView: android.view.View?
    ) {
        Log.d(TAG, "initialize called — native AR not implemented on Android")
    }

    fun startSession() { /* no-op until real implementation */ }
    fun pauseSession() { /* no-op */ }
    fun resumeSession() { /* no-op */ }
    fun destroy() { /* no-op */ }

    fun selectWall(wallId: String) { /* no-op */ }
    fun getWalls(): List<Map<String, Any>> = emptyList()
    fun getSelectedWallId(): String? = null

    fun setTexture(imageData: ByteArray) { /* no-op */ }
    fun clearTexture() { /* no-op */ }
    fun preloadTexture(textureUrl: String) { /* no-op */ }

    fun startMeasurement() { /* no-op */ }
    fun addMeasurementPoint(x: Float, y: Float, z: Float): String = ""
    fun getMeasurementDistance(): Float? = null
    fun clearMeasurement() { /* no-op */ }
    fun measureDistance(
        x1: Float, y1: Float, x2: Float, y2: Float
    ): Float? = null

    fun startCalibration(unit: String) { /* no-op */ }
    fun finishCalibration(realLength: Float): Boolean = false
    fun getCalibration(): Map<String, Any>? = null

    fun calculateTileQuantity(
        tileWidth: Float,
        tileHeight: Float,
        tileUnit: String,
        wastagePercent: Float
    ): Map<String, Any>? = null

    fun getWallState(): String = "SEARCHING"
}
