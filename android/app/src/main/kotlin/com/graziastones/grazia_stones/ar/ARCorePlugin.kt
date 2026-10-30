package com.graziastones.grazia_stones.ar

import android.content.Context
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.EventChannel.StreamHandler
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.github.sceneview.ar.ARSceneView

/**
 * ARCore Flutter Plugin - Handles method channel and platform view for ARCore
 */
class ARCorePlugin : FlutterPlugin, MethodCallHandler, StreamHandler {

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventSink? = null
    private var context: Context? = null
    private var arCoreManager: ARCoreManager? = null

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        arCoreManager = ARCoreManager.getInstance(context!!)

        // Method channel
        methodChannel = MethodChannel(binding.binaryMessenger, "com.graziastones.ar/native")
        methodChannel?.setMethodCallHandler(this)

        // Event channel
        eventChannel = EventChannel(binding.binaryMessenger, "com.graziastones.ar/events")
        eventChannel?.setStreamHandler(this)

        // Set up callbacks
        setupCallbacks()

        Log.d("ARCorePlugin", "Attached to engine")
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        eventSink = null
        arCoreManager?.destroy()
        arCoreManager = null
        Log.d("ARCorePlugin", "Detached from engine")
    }

    private fun setupCallbacks() {
        arCoreManager?.onWallDetected = { wallId, data ->
            sendEvent("wallDetected", mapOf("id" to wallId, "data" to data))
        }
        arCoreManager?.onWallUpdated = { wallId, data ->
            sendEvent("wallUpdated", mapOf("id" to wallId, "data" to data))
        }
        arCoreManager?.onWallRemoved = { wallId ->
            sendEvent("wallRemoved", mapOf("id" to wallId))
        }
        arCoreManager?.onTrackingStateChanged = { state ->
            sendEvent("trackingStateChanged", mapOf("state" to state))
        }
        arCoreManager?.onWallStateChanged = { state ->
            sendEvent("wallStateChanged", mapOf("state" to state))
        }
        arCoreManager?.onMeasurementResult = { data ->
            sendEvent("measurementResult", data)
        }
        arCoreManager?.onError = { error ->
            sendEvent("error", mapOf("message" to error))
        }
    }

    private fun sendEvent(type: String, data: Map<String, Any>) {
        val event = mapOf("type" to type, "data" to data)
        eventSink?.success(event)
    }

    // StreamHandler
    override fun onListen(arguments: Any?, events: EventSink) {
        eventSink = events
        Log.d("ARCorePlugin", "Event stream started")
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        Log.d("ARCorePlugin", "Event stream cancelled")
    }

    // MethodCallHandler
    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "startSession" -> {
                arCoreManager?.startSession()
                result.success(null)
            }
            "pauseSession" -> {
                arCoreManager?.pauseSession()
                result.success(null)
            }
            "resumeSession" -> {
                arCoreManager?.resumeSession()
                result.success(null)
            }
            "selectWall" -> {
                val wallId = call.argument<String>("wallId")
                wallId?.let {
                    arCoreManager?.selectWall(it)
                    result.success(null)
                } ?: result.error("INVALID_ARGS", "Missing wallId", null)
            }
            "getWalls" -> {
                val walls = arCoreManager?.getWalls() ?: emptyList()
                result.success(walls)
            }
            "getSelectedWallId" -> {
                result.success(arCoreManager?.getSelectedWallId())
            }
            "setTexture" -> {
                val imageData = call.argument<ByteArray>("imageData")
                imageData?.let {
                    arCoreManager?.setTexture(it, call.argument<Double>("patchHeightM")?.toFloat(), call.argument<Boolean>("seamCut") ?: false)
                    result.success(null)
                } ?: result.error("INVALID_ARGS", "Missing imageData", null)
            }
            "clearTexture" -> {
                arCoreManager?.clearTexture()
                result.success(null)
            }
            "startMeasurement" -> {
                arCoreManager?.startMeasurement()
                result.success(null)
            }
            "addMeasurementPoint" -> {
                val x = call.argument<Double>("x")?.toFloat()
                val y = call.argument<Double>("y")?.toFloat()
                val z = call.argument<Double>("z")?.toFloat()
                if (x != null && y != null && z != null) {
                    val anchorId = arCoreManager?.addMeasurementPoint(x, y, z) ?: ""
                    result.success(anchorId)
                } else {
                    result.error("INVALID_ARGS", "Missing point coordinates", null)
                }
            }
            "getMeasurementDistance" -> {
                val distance = arCoreManager?.getMeasurementDistance()
                result.success(distance)
            }
            "clearMeasurement" -> {
                arCoreManager?.clearMeasurement()
                result.success(null)
            }
            "isARSupported" -> {
                val supported = arCoreManager?.isARSupported() ?: false
                result.success(supported)
            }
            "hasLiDAR" -> {
                // Android doesn't have LiDAR, but some devices have depth API
                result.success(false)
            }
            "startCalibration" -> {
                val unit = call.argument<String>("unit") ?: "ft"
                arCoreManager?.startCalibration(unit)
                result.success(null)
            }
            "finishCalibration" -> {
                val realLength = call.argument<Double>("realLength")?.toFloat()
                realLength?.let {
                    val success = arCoreManager?.finishCalibration(it) ?: false
                    result.success(success)
                } ?: result.error("INVALID_ARGS", "Missing realLength", null)
            }
            "getCalibration" -> {
                val calibration = arCoreManager?.getCalibration()
                result.success(calibration)
            }
            "measureDistance" -> {
                val x1 = call.argument<Double>("x1")?.toFloat()
                val y1 = call.argument<Double>("y1")?.toFloat()
                val x2 = call.argument<Double>("x2")?.toFloat()
                val y2 = call.argument<Double>("y2")?.toFloat()
                if (x1 != null && y1 != null && x2 != null && y2 != null) {
                    val distance = arCoreManager?.measureDistance(x1, y1, x2, y2)
                    result.success(distance)
                } else {
                    result.error("INVALID_ARGS", "Missing screen coordinates", null)
                }
            }
            "calculateTileQuantity" -> {
                val tileWidth = call.argument<Double>("tileWidth")?.toFloat()
                val tileHeight = call.argument<Double>("tileHeight")?.toFloat()
                val tileUnit = call.argument<String>("tileUnit") ?: "ft"
                val wastagePercent = call.argument<Double>("wastagePercent")?.toFloat() ?: 10.0f
                if (tileWidth != null && tileHeight != null) {
                    val quantity = arCoreManager?.calculateTileQuantity(tileWidth, tileHeight, tileUnit, wastagePercent)
                    result.success(quantity)
                } else {
                    result.error("INVALID_ARGS", "Missing tile dimensions", null)
                }
            }
            "getWallState" -> {
                val state = arCoreManager?.getWallState() ?: "SEARCHING"
                result.success(state)
            }
            "preloadTexture" -> {
                val textureUrl = call.argument<String>("textureUrl") ?: ""
                arCoreManager?.preloadTexture(textureUrl)
                result.success(null)
            }
            "hitTestWallAtScreenPoint" -> {
                val screenX = call.argument<Double>("screenX")?.toFloat()
                val screenY = call.argument<Double>("screenY")?.toFloat()
                if (screenX != null && screenY != null) {
                    result.success(arCoreManager?.hitTestWallAtScreenPoint(screenX, screenY))
                } else {
                    result.error("INVALID_ARGS", "Missing screen coordinates", null)
                }
            }
            "probeSurfaceAtScreenPoint" -> {
                val screenX = call.argument<Double>("screenX")?.toFloat()
                val screenY = call.argument<Double>("screenY")?.toFloat()
                if (screenX != null && screenY != null) {
                    result.success(arCoreManager?.probeSurfaceAtScreenPoint(screenX, screenY))
                } else {
                    result.error("INVALID_ARGS", "Missing screen coordinates", null)
                }
            }
            "detectObjectAtScreenPoint" -> {
                val screenX = call.argument<Double>("screenX")?.toFloat()
                val screenY = call.argument<Double>("screenY")?.toFloat()
                if (screenX != null && screenY != null) {
                    result.success(arCoreManager?.detectObjectAtScreenPoint(screenX, screenY) ?: mapOf("error" to "no_manager"))
                } else {
                    result.error("INVALID_ARGS", "Missing screen coordinates", null)
                }
            }
            "projectMeasurementAnchors" -> {
                val ids = call.argument<List<String>>("ids") ?: emptyList()
                result.success(arCoreManager?.projectMeasurementAnchors(ids) ?: emptyList<Map<String, Any>>())
            }
            "calibrateKnownLength" -> {
                val x1 = call.argument<Double>("x1")?.toFloat(); val y1 = call.argument<Double>("y1")?.toFloat()
                val x2 = call.argument<Double>("x2")?.toFloat(); val y2 = call.argument<Double>("y2")?.toFloat()
                val len = call.argument<Double>("lengthM")?.toFloat()
                if (x1 == null || y1 == null || x2 == null || y2 == null || len == null) {
                    result.error("INVALID_ARGS", "Missing points or length", null)
                } else result.success(arCoreManager?.calibrateKnownLength(x1, y1, x2, y2, len) ?: mapOf("ok" to false))
            }
            "getPlacementInfo" -> result.success(arCoreManager?.getPlacementInfo() ?: mapOf("placed" to false))
            "editMask" -> {
                val x = call.argument<Double>("screenX")?.toFloat()
                val y = call.argument<Double>("screenY")?.toFloat()
                val erase = call.argument<Boolean>("erase") ?: true
                if (x != null && y != null) result.success(arCoreManager?.editMask(x, y, erase) ?: false)
                else result.error("INVALID_ARGS", "Missing screen coordinates", null)
            }
            "placeWallAtScreenPoint" -> {
                val screenX = call.argument<Double>("screenX")?.toFloat()
                val screenY = call.argument<Double>("screenY")?.toFloat()
                if (screenX != null && screenY != null) {
                    result.success(arCoreManager?.placeWallAtScreenPoint(screenX, screenY))
                } else {
                    result.error("INVALID_ARGS", "Missing screen coordinates", null)
                }
            }
            "captureSnapshot" -> {
                val mgr = arCoreManager
                if (mgr == null) {
                    result.error("NO_MANAGER", "AR is not initialised", null)
                } else {
                    mgr.captureSnapshot { saved, error ->
                        if (saved != null) result.success(saved) else result.error("SNAPSHOT_FAILED", error, null)
                    }
                }
            }
            "clearPlacedWall" -> {
                arCoreManager?.clearPlacedWall()
                result.success(null)
            }
            "setApproximateDistance" -> {
                val m = call.argument<Double>("meters")?.toFloat()
                if (m != null) { arCoreManager?.setApproximateDistance(m); result.success(null) }
                else result.error("INVALID_ARGS", "Missing meters", null)
            }
            "getCameraAspect" -> result.success(arCoreManager?.cameraAspect())
            "calibrateRectangle" -> {
                val pts = call.argument<List<Double>>("points")?.map { it.toFloat() }?.toFloatArray() ?: FloatArray(0)
                val w = call.argument<Double>("widthM")?.toFloat() ?: 0f
                val h = call.argument<Double>("heightM")?.toFloat() ?: 0f
                result.success(arCoreManager?.calibrateRectangle(pts, w, h) ?: mapOf("ok" to false, "reason" to "no_manager"))
            }
            "setDesignVisible" -> {
                arCoreManager?.setDesignVisible(call.argument<Boolean>("visible") ?: true)
                result.success(null)
            }
            "setWallSelected" -> {
                val id = call.argument<Int>("id") ?: -1
                result.success(arCoreManager?.setWallSelected(id, call.argument<Boolean>("selected") ?: true) ?: false)
            }
            "setWallClipping" -> {
                arCoreManager?.wallClippingEnabled = call.argument<Boolean>("enabled") ?: true
                result.success(null)
            }
            "stopCamera" -> {
                arCoreManager?.pauseSession()
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }
}

/**
 * ARCore Platform View Factory for embedding a real ARSceneView in Flutter.
 */
class ARCoreViewFactory(private val binaryMessenger: BinaryMessenger) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, id: Int, args: Any?): PlatformView {
        return ARCorePlatformView(context, id, binaryMessenger)
    }
}

/**
 * ARCore Platform View — hosts a real [io.github.sceneview.ar.ARSceneView]
 * (ARCore + Filament) and hands it to [ARCoreManager], which drives session
 * control, plane detection, texture mapping and measurement.
 */
class ARCorePlatformView(
    private val context: Context,
    private val id: Int,
    private val binaryMessenger: BinaryMessenger
) : PlatformView {

    private val arCoreManager = ARCoreManager.getInstance(context)
    private val sceneView = FlutterARSceneView(context)

    init {
        arCoreManager.attachSceneView(sceneView)
    }

    override fun getView(): android.view.View = sceneView

    override fun dispose() {
        arCoreManager.detachSceneView(sceneView)
        sceneView.destroy()
    }
}

/**
 * SceneView destroys itself (engine, camera stream, ARCore session) in onDetachedFromWindow. Flutter detaches
 * and re-attaches platform views when the app comes back from the background, so Live AR came back to a black
 * camera with "Wall lost" for good. Detaching skips that here; [ARCorePlatformView.dispose] still destroys it.
 */
class FlutterARSceneView(context: Context) : ARSceneView(context) {
    override fun onDetachedFromWindow() {
        val f = destroyedFlag ?: return super.onDetachedFromWindow()
        if (f.getBoolean(this)) return super.onDetachedFromWindow()
        // ponytail: flips SceneView's private isDestroyed so its detach skips destroy(); re-check on a SceneView upgrade.
        f.setBoolean(this, true)
        try { super.onDetachedFromWindow() } finally { f.setBoolean(this, false) }
    }

    private companion object {
        val destroyedFlag = runCatching {
            io.github.sceneview.SceneView::class.java.getDeclaredField("isDestroyed").apply { isAccessible = true }
        }.onFailure { android.util.Log.w("ARCorePlugin", "SceneView.isDestroyed not found; AR view dies on detach", it) }
            .getOrNull()
    }
}
