package com.graziastones.grazia_stones.ar

import android.content.Context
import android.opengl.GLES20
import android.opengl.Matrix
import android.util.Log
import android.util.Size
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import com.google.ar.core.Anchor
import com.google.ar.core.ArCoreApk
import com.google.ar.core.AugmentedFace
import com.google.ar.core.Camera
import com.google.ar.core.Config
import com.google.ar.core.Frame
import com.google.ar.core.HitResult
import com.google.ar.core.Plane
import com.google.ar.core.Session
import com.google.ar.core.Trackable
import com.google.ar.core.TrackingState
import com.google.ar.sceneform.AnchorNode
import com.google.ar.sceneform.FrameTime
import com.google.ar.sceneform.Node
import com.google.ar.sceneform.Scene
import com.google.ar.sceneform.SceneView
import com.google.ar.sceneform.rendering.MaterialFactory
import com.google.ar.sceneform.rendering.ModelRenderable
import com.google.ar.sceneform.rendering.Renderable
import com.google.ar.sceneform.rendering.Texture
import com.google.ar.sceneform.ux.ArFragment
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * ARCoreManager - Native ARCore implementation for wall detection, tracking, and visualization.
 * Handles vertical plane detection, world anchors, and texture mapping.
 */
class ARCoreManager private constructor(private val context: Context) {

    companion object {
        @Volatile
        private var INSTANCE: ARCoreManager? = null

        fun getInstance(context: Context): ARCoreManager {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: ARCoreManager(context).also { INSTANCE = it }
            }
        }
    }

    // Callbacks
    var onWallDetected: ((String, Map<String, Any>) -> Unit)? = null
    var onWallUpdated: ((String, Map<String, Any>) -> Unit)? = null
    var onWallRemoved: ((String) -> Unit)? = null
    var onTrackingStateChanged: ((String) -> Unit)? = null
    var onWallStateChanged: ((String) -> Unit)? = null
    var onMeasurementResult: ((Map<String, Any>) -> Unit)? = null
    var onError: ((String) -> Unit)? = null

    // Session and Scene
    private var arSession: Session? = null
    private var sceneView: SceneView? = null
    private var previewView: PreviewView? = null
    private val cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var isSessionRunning = false

    // Wall tracking
    private val wallPlanes = mutableMapOf<String, Plane>()
    private var selectedWallId: String? = null
    private var textureNode: Node? = null
    private var currentTexture: Texture? = null

    // Measurement
    private val measurementAnchors = mutableMapOf<String, Anchor>()
    private var measurementStartPoint: com.google.ar.core.Pose? = null
    private var measurementEndPoint: com.google.ar.core.Pose? = null

    // Calibration
    private val calibrationPoints = mutableListOf<com.google.ar.core.Pose>()
    private var calibrationUnit: String = "ft"
    private var pixelsPerMeter: Float = 0.0f
    private var isCalibrating = false

    // Texture preloading
    private val preloadedTextures = mutableMapOf<String, Texture>()

    // Check if ARCore is supported
    fun isARSupported(): Boolean {
        return ArCoreApk.getInstance().requestInstall(context, true) == ArCoreApk.InstallStatus.INSTALLED
    }

    // Initialize AR session
    fun initialize(previewView: PreviewView, sceneView: SceneView) {
        this.previewView = previewView
        this.sceneView = sceneView

        // Create ARCore session
        try {
            arSession = Session(context)
            Log.d("ARCoreManager", "ARCore session created")

            // Configure session
            val config = Config(arSession!!)
            config.planeFindingMode = Config.PlaneFindingMode.VERTICAL
            config.updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
            config.focusMode = Config.FocusMode.AUTO
            config.lightEstimationMode = Config.LightEstimationMode.ENVIRONMENTAL_HDR

            // Enable depth if supported
            if (Session.isDepthModeSupported(Config.DepthMode.AUTOMATIC)) {
                config.depthMode = Config.DepthMode.AUTOMATIC
            }

            arSession!!.configure(config)

            // Set up SceneView
            sceneView.setupSession(arSession!!)
            sceneView.scene.addOnUpdateListener(::onSceneUpdate)

            // Start camera
            startCamera()

        } catch (e: Exception) {
            Log.e("ARCoreManager", "Failed to initialize ARCore", e)
            onError?.invoke("Failed to initialize ARCore: ${e.message}")
        }
    }

    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener({
            val cameraProvider = cameraProviderFuture.get()
            val preview = Preview.Builder().build().also {
                it.setSurfaceProvider(previewView!!.surfaceProvider)
            }
            val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
            cameraProvider.bindToLifecycle(
                null, // We'll handle lifecycle manually
                cameraSelector,
                preview
            )
        }, cameraExecutor)
    }

    // Session control
    fun startSession() {
        if (isSessionRunning) return
        sceneView?.resume()
        isSessionRunning = true
        Log.d("ARCoreManager", "Session started")
    }

    fun pauseSession() {
        if (!isSessionRunning) return
        sceneView?.pause()
        isSessionRunning = false
        Log.d("ARCoreManager", "Session paused")
    }

    fun resumeSession() {
        if (isSessionRunning) return
        sceneView?.resume()
        isSessionRunning = true
        Log.d("ARCoreManager", "Session resumed")
    }

    // Scene update callback
    private fun onSceneUpdate(frameTime: FrameTime) {
        val frame = sceneView?.arFrame ?: return
        val camera = frame.camera
        val trackingState = camera.trackingState

        // Update tracking state
        when (trackingState) {
            TrackingState.TRACKING -> onTrackingStateChanged?.invoke("TRACKING")
            TrackingState.PAUSED -> onTrackingStateChanged?.invoke("PAUSED")
            TrackingState.STOPPED -> onTrackingStateChanged?.invoke("STOPPED")
        }

        // Process new planes
        val planes = frame.updatedTrackables(Plane::class.java)
        for (plane in planes) {
            if (plane.type == Plane.Type.VERTICAL && plane.trackingState == TrackingState.TRACKING) {
                processWallPlane(plane)
            }
        }
    }

    private fun processWallPlane(plane: Plane) {
        val wallId = plane.id.toString()
        val isNew = !wallPlanes.containsKey(wallId)

        wallPlanes[wallId] = plane

        if (isNew) {
            Log.d("ARCoreManager", "Wall plane detected: $wallId extent: ${plane.extentX}x${plane.extentZ}")
            val wallData = planeToMap(plane)
            onWallDetected?.invoke(wallId, wallData)

            // Auto-select first wall
            if (selectedWallId == null) {
                selectedWallId = wallId
                updateWallVisualization()
            }
        } else {
            // Update existing wall
            val wallData = planeToMap(plane)
            onWallUpdated?.invoke(wallId, wallData)

            if (wallId == selectedWallId) {
                updateWallVisualization()
            }
        }
    }

    // Wall selection
    fun selectWall(wallId: String) {
        if (!wallPlanes.containsKey(wallId)) {
            Log.w("ARCoreManager", "Wall not found: $wallId")
            return
        }
        selectedWallId = wallId
        updateWallVisualization()
        val wallData = planeToMap(wallPlanes[wallId]!!)
        onWallUpdated?.invoke(wallId, wallData)
    }

    fun getWalls(): List<Map<String, Any>> {
        return wallPlanes.values.map { planeToMap(it) }
    }

    fun getSelectedWallId(): String? {
        return selectedWallId
    }

    // Texture management
    fun setTexture(imageData: ByteArray) {
        // Create texture from image data
        MaterialFactory.makeOpaqueWithTexture(context, imageData)
            .thenAccept { material ->
                currentTexture = material.getTexture("baseColor") as Texture?
                updateTextureOnNode(currentTexture!!)
            }
            .exceptionally { e ->
                Log.e("ARCoreManager", "Failed to create texture", e)
                onError?.invoke("Failed to create texture: ${e.message}")
                null
            }
    }

    private fun updateTextureOnNode(texture: Texture) {
        textureNode?.let { node ->
            val renderable = node.renderable as? ModelRenderable
            renderable?.let { r ->
                val material = r.material
                material.setTexture("baseColor", texture)
            }
        }
    }

    fun clearTexture() {
        currentTexture = null
        textureNode?.renderable?.let { r ->
            (r as ModelRenderable).material.setTexture("baseColor", null)
        }
    }

    // Measurement
    fun startMeasurement() {
        measurementAnchors.values.forEach { arSession?.removeAnchor(it) }
        measurementAnchors.clear()
        measurementStartPoint = null
        measurementEndPoint = null
    }

    fun addMeasurementPoint(x: Float, y: Float, z: Float): String {
        val pose = com.google.ar.core.Pose.makeTranslation(x, y, z)
        val anchor = arSession?.createAnchor(pose)
        anchor?.let {
            val id = it.id.toString()
            measurementAnchors[id] = it

            if (measurementStartPoint == null) {
                measurementStartPoint = pose
            } else if (measurementEndPoint == null) {
                measurementEndPoint = pose
            }
            return id
        }
        return ""
    }

    fun getMeasurementDistance(): Float? {
        measurementStartPoint?.let { start ->
            measurementEndPoint?.let { end ->
                val dx = end.tx() - start.tx()
                val dy = end.ty() - start.ty()
                val dz = end.tz() - start.tz()
                return Math.sqrt(dx * dx + dy * dy + dz * dz)
            }
        }
        return null
    }

    fun clearMeasurement() {
        measurementAnchors.values.forEach { arSession?.removeAnchor(it) }
        measurementAnchors.clear()
        measurementStartPoint = null
        measurementEndPoint = null
    }

    // Wall visualization
    private fun updateWallVisualization() {
        selectedWallId?.let { wallId ->
            wallPlanes[wallId]?.let { plane ->
                // Remove existing node
                textureNode?.parent?.removeChild(textureNode!!)
                textureNode = null

                // Create plane node
                val planeNode = Node()
                planeNode.localPosition = android.graphics.Matrix().let { m ->
                    plane.centerPose.toMatrix(m.values, 0)
                    android.graphics.Matrix().invert(m)
                    com.google.ar.sceneform.math.Vector3(
                        m.getValue(12), m.getValue(13), m.getValue(14)
                    )
                }

                // Create plane geometry
                val planeRenderable = com.google.ar.sceneform.rendering.ShapeFactory.makeCube(
                    com.google.ar.sceneform.math.Vector3(plane.extentX, 0.01f, plane.extentZ),
                    com.google.ar.sceneform.rendering.MaterialFactory.makeOpaqueWithColor(context, 0xFFFFFFFF)
                )

                planeNode.renderable = planeRenderable
                planeNode.localRotation = com.google.ar.sceneform.Quaternion.axisAngle(
                    com.google.ar.sceneform.math.Vector3(1f, 0f, 0f), -90f
                )

                // Apply texture if available
                currentTexture?.let { texture ->
                    MaterialFactory.makeOpaqueWithTexture(context, texture)
                        .thenAccept { material ->
                            planeNode.renderable = planeRenderable.toBuilder().setMaterial(material).build()
                        }
                }

                sceneView?.scene?.addChild(planeNode)
                textureNode = planeNode
            }
        }
    }

    private fun planeToMap(plane: Plane): Map<String, Any> {
        val pose = plane.centerPose
        val extentX = plane.extentX
        val extentZ = plane.extentZ

        // Calculate corners
        val corners = mutableListOf<Map<String, Float>>()
        val halfX = extentX / 2
        val halfZ = extentZ / 2

        val localCorners = arrayOf(
            floatArrayOf(-halfX, 0f, -halfZ),
            floatArrayOf(halfX, 0f, -halfZ),
            floatArrayOf(halfX, 0f, halfZ),
            floatArrayOf(-halfX, 0f, halfZ)
        )

        for (local in localCorners) {
            val world = FloatArray(4)
            pose.toMatrix(world, 0)
            val worldPoint = FloatArray(4)
            // Transform local to world
            worldPoint[0] = world[0] * local[0] + world[4] * local[1] + world[8] * local[2] + world[12]
            worldPoint[1] = world[1] * local[0] + world[5] * local[1] + world[9] * local[2] + world[13]
            worldPoint[2] = world[2] * local[0] + world[6] * local[1] + world[10] * local[2] + world[14]
            corners.add(mapOf(
                "x" to worldPoint[0],
                "y" to worldPoint[1],
                "z" to worldPoint[2]
            ))
        }

        return mapOf(
            "id" to plane.id.toString(),
            "center" to mapOf(
                "x" to pose.tx(),
                "y" to pose.ty(),
                "z" to pose.tz()
            ),
            "extent" to mapOf(
                "width" to extentX,
                "height" to extentZ
            ),
            "alignment" to "vertical",
            "corners" to corners,
            "area" to (extentX * extentZ),
            "confidence" to 0.9,
            "isSelected" to (plane.id.toString() == selectedWallId)
        )
    }

    // MARK: - Calibration

    fun startCalibration(unit: String) {
        calibrationUnit = unit
        calibrationPoints.clear()
        isCalibrating = true
        pixelsPerMeter = 0.0f
        Log.d("ARCoreManager", "Calibration started with unit: $unit")
    }

    fun addCalibrationPoint(x: Float, y: Float, z: Float): String {
        if (!isCalibrating) return ""
        val pose = com.google.ar.core.Pose.makeTranslation(x, y, z)
        calibrationPoints.add(pose)

        if (calibrationPoints.size == 2) {
            val start = calibrationPoints[0]
            val end = calibrationPoints[1]
            val dx = end.tx() - start.tx()
            val dy = end.ty() - start.ty()
            val dz = end.tz() - start.tz()
            val pixelDistance = Math.sqrt((dx * dx + dy * dy + dz * dz).toDouble()).toFloat()
            // The actual pixels per meter will be calculated in finishCalibration
            val anchorId = addMeasurementPoint(start.tx(), start.ty(), start.tz())
            _ = addMeasurementPoint(end.tx(), end.ty(), end.tz())
            return anchorId
        }
        return ""
    }

    fun finishCalibration(realLength: Float): Boolean {
        if (!isCalibrating || calibrationPoints.size != 2) return false

        val start = calibrationPoints[0]
        val end = calibrationPoints[1]
        val dx = end.tx() - start.tx()
        val dy = end.ty() - start.ty()
        val dz = end.tz() - start.tz()
        val pixelDistance = Math.sqrt((dx * dx + dy * dy + dz * dz).toDouble()).toFloat()

        // Convert real length to meters based on unit
        var realLengthMeters: Float = realLength
        when (calibrationUnit) {
            "ft" -> realLengthMeters = realLength * 0.3048f
            "m" -> realLengthMeters = realLength
            "in" -> realLengthMeters = realLength * 0.0254f
            "cm" -> realLengthMeters = realLength * 0.01f
            else -> realLengthMeters = realLength * 0.3048f
        }

        if (realLengthMeters > 0) {
            pixelsPerMeter = pixelDistance / realLengthMeters
        }
        isCalibrating = false

        Log.d("ARCoreManager", "Calibration finished: $pixelDistance pixels = $realLengthMeters meters, $pixelsPerMeter pixels/meter")
        return true
    }

    fun getCalibration(): Map<String, Any>? {
        if (pixelsPerMeter <= 0) return null
        return mapOf(
            "pixelsPerUnit" to pixelsPerMeter,
            "unit" to calibrationUnit,
            "isCalibrated" to true
        )
    }

    fun measureDistance(x1: Float, y1: Float, x2: Float, y2: Float): Float? {
        if (pixelsPerMeter <= 0) return null

        val frame = sceneView?.arFrame ?: return null
        
        val hitResults1 = frame.hitTest(x1, y1)
        val hitResults2 = frame.hitTest(x2, y2)

        val hit1 = hitResults1.firstOrNull { it.trackable is Plane && (it.trackable as Plane).type == Plane.Type.VERTICAL }
        val hit2 = hitResults2.firstOrNull { it.trackable is Plane && (it.trackable as Plane).type == Plane.Type.VERTICAL }

        hit1?.let { h1 ->
            hit2?.let { h2 ->
                val p1 = h1.hitPose
                val p2 = h2.hitPose
                val dx = p2.tx() - p1.tx()
                val dy = p2.ty() - p1.ty()
                val dz = p2.tz() - p1.tz()
                val worldDistance = Math.sqrt((dx * dx + dy * dy + dz * dz).toDouble()).toFloat()
                return worldDistance
            }
        }
        return null
    }

    // MARK: - Tile Quantity Calculation

    fun calculateTileQuantity(
        tileWidth: Float,
        tileHeight: Float,
        tileUnit: String,
        wastagePercent: Float
    ): Map<String, Any>? {
        val wallId = selectedWallId ?: return null
        val plane = wallPlanes[wallId] ?: return null

        // Wall dimensions in meters
        val wallWidthM = plane.extentX
        val wallHeightM = plane.extentZ
        val wallAreaM2 = wallWidthM * wallHeightM

        // Convert tile dimensions to meters
        var tileWidthM = tileWidth
        var tileHeightM = tileHeight
        when (tileUnit) {
            "mm" -> {
                tileWidthM = tileWidth / 1000.0f
                tileHeightM = tileHeight / 1000.0f
            }
            "cm" -> {
                tileWidthM = tileWidth / 100.0f
                tileHeightM = tileHeight / 100.0f
            }
            "ft" -> {
                tileWidthM = tileWidth * 0.3048f
                tileHeightM = tileHeight * 0.3048f
            }
            "in" -> {
                tileWidthM = tileWidth * 0.0254f
                tileHeightM = tileHeight * 0.0254f
            }
            "m" -> {
                // already in meters
            }
            else -> {
                tileWidthM = tileWidth / 1000.0f
                tileHeightM = tileHeight / 1000.0f
            }
        }

        val tileAreaM2 = tileWidthM * tileHeightM
        if (tileAreaM2 <= 0) return null

        val baseQuantity = Math.ceil(wallAreaM2 / tileAreaM2).toInt()
        val wastage = Math.ceil(baseQuantity * wastagePercent / 100.0).toInt()
        val recommendedQuantity = baseQuantity + wastage

        // Convert back to requested unit for display
        var displayWallWidth = wallWidthM
        var displayWallHeight = wallHeightM
        var displayUnit = "m"
        when (tileUnit) {
            "ft" -> {
                displayWallWidth = wallWidthM / 0.3048f
                displayWallHeight = wallHeightM / 0.3048f
                displayUnit = "ft"
            }
            "in" -> {
                displayWallWidth = wallWidthM / 0.0254f
                displayWallHeight = wallHeightM / 0.0254f
                displayUnit = "in"
            }
            "cm" -> {
                displayWallWidth = wallWidthM * 100.0f
                displayWallHeight = wallHeightM * 100.0f
                displayUnit = "cm"
            }
            "mm" -> {
                displayWallWidth = wallWidthM * 1000.0f
                displayWallHeight = wallHeightM * 1000.0f
                displayUnit = "mm"
            }
            else -> displayUnit = "m"
        }

        return mapOf(
            "wallWidth" to displayWallWidth,
            "wallHeight" to displayWallHeight,
            "wallArea" to wallAreaM2,
            "tileWidth" to tileWidthM,
            "tileHeight" to tileHeightM,
            "tileArea" to tileAreaM2,
            "baseQuantity" to baseQuantity,
            "wastagePercent" to wastagePercent,
            "recommendedQuantity" to recommendedQuantity,
            "unit" to displayUnit,
            "isCalibrated" to (pixelsPerMeter > 0),
            "calibrationUnit" to calibrationUnit
        )
    }

    // MARK: - Wall State

    fun getWallState(): String {
        var state = "SEARCHING"

        if (wallPlanes.isEmpty()) {
            state = "SEARCHING"
        } else if (selectedWallId != null && wallPlanes.containsKey(selectedWallId)) {
            state = "TRACKING"
        } else {
            state = "DETECTING"
        }

        onWallStateChanged?.invoke(state)
        return state
    }

    // MARK: - Texture Preloading

    fun preloadTexture(textureUrl: String) {
        // For asset URLs, we can't easily preload without the asset manager
        // This would need to be implemented with a bitmap loader
        Log.d("ARCoreManager", "Preload texture requested: $textureUrl")
    }

    // Cleanup
    fun destroy() {
        pauseSession()
        arSession?.close()
        arSession = null
        cameraExecutor.shutdown()
        sceneView = null
        previewView = null
        wallPlanes.clear()
        measurementAnchors.clear()
        textureNode = null
        currentTexture = null
        INSTANCE = null
    }
}