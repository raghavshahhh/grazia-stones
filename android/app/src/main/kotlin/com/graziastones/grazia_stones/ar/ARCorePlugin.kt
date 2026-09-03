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
                    arCoreManager?.setTexture(it)
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
            else -> {
                result.notImplemented()
            }
        }
    }
}

/**
 * ARCore Platform View Factory for embedding SceneView in Flutter
 */
class ARCoreViewFactory(private val binaryMessenger: BinaryMessenger) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, id: Int, args: Any?): PlatformView {
        return ARCorePlatformView(context, id, binaryMessenger)
    }
}

/**
 * ARCore Platform View — placeholder container.
 *
 * Native Android AR rendering is not implemented (see ARCoreManager for
 * the honest capability report); the Flutter side routes Android to its
 * real web-camera AR engine instead of embedding this view. The factory
 * stays registered so the view type resolves without crashing if it is
 * ever requested.
 */
class ARCorePlatformView(
    private val context: Context,
    private val id: Int,
    private val binaryMessenger: BinaryMessenger
) : PlatformView {

    private val frameLayout = android.widget.FrameLayout(context)

    init {
        frameLayout.layoutParams = android.widget.FrameLayout.LayoutParams(
            android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
            android.widget.FrameLayout.LayoutParams.MATCH_PARENT
        )
    }

    override fun getView(): android.view.View? {
        return frameLayout
    }

    override fun dispose() {
        // Nothing to tear down — no native session is ever started.
    }
}