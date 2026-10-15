package com.graziastones.grazia_stones.ar

import android.content.Context
import android.graphics.BitmapFactory
import android.util.Log
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import com.google.android.filament.MaterialInstance
import com.google.android.filament.Texture
import com.google.android.filament.android.TextureHelper
import android.opengl.Matrix
import com.google.ar.core.Anchor
import com.google.ar.core.ArCoreApk
import com.google.ar.core.Config
import com.google.ar.core.Coordinates2d
import com.google.ar.core.Plane
import com.google.ar.core.Pose
import com.google.ar.core.Session
import com.google.ar.core.HitResult
import com.google.ar.core.TrackingFailureReason
import com.google.ar.core.TrackingState
import io.github.sceneview.ar.ARSceneView
import io.github.sceneview.ar.node.AnchorNode
import io.github.sceneview.math.Position
import io.github.sceneview.math.Size
import dev.romainguy.kotlin.math.Float2
import io.github.sceneview.node.Node
import io.github.sceneview.node.PlaneNode
import io.github.sceneview.node.SphereNode
import java.util.IdentityHashMap
import java.util.UUID
import kotlin.math.ceil
import kotlin.math.sqrt

/**
 * ARCoreManager — native AR bridge for the `com.graziastones.ar/native`
 * method channel, backed by real ARCore (via SceneView-Android, which wraps
 * ARCore + Google Filament).
 *
 * Mirrors ARKitManager.swift method-for-method: same event names, same
 * dictionary shapes, same tile-quantity formula. Where ARKit and ARCore
 * genuinely differ (calibration is legacy/unused on both — real-world
 * anchors are already in metres) the comment says so explicitly.
 */
class ARCoreManager private constructor(context: Context) {

    companion object {
        // ponytail: assumed real height of one catalogue photo; add a per-stone value when the client supplies photo sizes.
        const val TEXTURE_PATCH_HEIGHT_M = 0.9f
        // ponytail: default size of a tapped wall patch; a drag-to-resize handle would replace this.
        // A wall hit nearer than 0.3 m or farther than 8 m is a tracking artefact, not a wall.
        const val MIN_HIT_DISTANCE_M = 0.3f
        const val MAX_HIT_DISTANCE_M = 8.0f
        const val APPROX_WALL_DISTANCE_M = 2.0f
        /** Ruler: ARCore is only trustworthy for hits in this range; outside it we say 'no surface' instead of guessing. */
        const val MIN_MEASURE_M = 0.10f
        const val MAX_MEASURE_M = 6.0f
        const val PLACED_WALL_WIDTH_M = 3.0f
        const val PLACED_WALL_HEIGHT_M = 2.7f
        private const val TAG = "ARCoreManager"

        @Volatile
        private var INSTANCE: ARCoreManager? = null

        fun getInstance(context: Context): ARCoreManager =
            INSTANCE ?: synchronized(this) {
                INSTANCE ?: ARCoreManager(context.applicationContext).also { INSTANCE = it }
            }
    }

    // Callbacks — identical contract to ARKitManager.swift
    var onWallDetected: ((String, Map<String, Any>) -> Unit)? = null
    var onWallUpdated: ((String, Map<String, Any>) -> Unit)? = null
    var onWallRemoved: ((String) -> Unit)? = null
    var onTrackingStateChanged: ((String) -> Unit)? = null
    var onWallStateChanged: ((String) -> Unit)? = null
    var onMeasurementResult: ((Map<String, Any>) -> Unit)? = null
    var onError: ((String) -> Unit)? = null

    private val appContext = context.applicationContext

    /**
     * ARSceneView drives its ARCore session off a Lifecycle. Dart calls
     * startSession/pauseSession/resumeSession imperatively (matching
     * ARKitManager's explicit session control), so we own a private
     * LifecycleOwner and move its state by hand instead of tying AR to the
     * host Activity's lifecycle.
     */
    private class ManagerLifecycleOwner : LifecycleOwner {
        val registry = LifecycleRegistry(this)
        override val lifecycle: Lifecycle get() = registry
    }

    private val lifecycleOwner = ManagerLifecycleOwner()
    private var sceneView: ARSceneView? = null

    // Wall tracking. ARCore's Plane has no stable id, so we mint one the
    // first time we see each plane instance.
    private val planeIds = IdentityHashMap<Plane, String>()
    private val wallPlanes = LinkedHashMap<String, Plane>()
    private var selectedWallId: String? = null
    private var wallNode: Node? = null
    // A wall the user placed by tapping it (depth / feature / plane hit). Independent of plane detection,
    // so a plain wall works on the first frame instead of waiting for ARCore to find a plane.
    private var placedAnchorNode: AnchorNode? = null
    private var placedQuad: Node? = null
    private var placedWidthM = PLACED_WALL_WIDTH_M
    private var placedHeightM = PLACED_WALL_HEIGHT_M
    private var pendingTexture: MaterialInstance? = null
    // Width / height of the current texture photo, so tiling keeps its proportions.
    private var textureAspect = 1f
    private var texturePatchHeightM = TEXTURE_PATCH_HEIGHT_M

    // Measurement
    private val measurementAnchors = LinkedHashMap<String, Anchor>()
    private val measurementNodes = mutableListOf<Node>()
    private var lastRulerLogMs = 0L
    private var measurementStart: FloatArray? = null
    private var measurementEnd: FloatArray? = null

    // Calibration — kept for interface parity with ARKitManager. Real
    // measurements don't need it: ARCore hit-test anchors are already in
    // real-world metres (see measureDistance).
    private var calibrationUnit: String = "ft"
    private val calibrationPoints = mutableListOf<FloatArray>()
    private var isCalibrating = false
    private var pixelsPerMeter: Float = 0f

    fun isARSupported(): Boolean = try {
        ArCoreApk.getInstance().checkAvailability(appContext).isSupported
    } catch (e: Exception) {
        Log.e(TAG, "isARSupported check failed", e)
        false
    }

    // ── View attachment (called by ARCorePlatformView) ─────────────────────

    fun attachSceneView(view: ARSceneView) {
        sceneView = view
        view.lifecycle = lifecycleOwner.lifecycle
        view.planeRenderer.isEnabled = true
        view.planeRenderer.isVisible = false // the ruler and the wall preview draw their own overlays; no debug plane polygons
        view.onSessionUpdated = { session, frame ->
            // onSessionCreated / sessionConfiguration never fired on the OnePlus, but onSessionUpdated does,
            // so the ARCore config is applied here, once per session, before anything else.
            if (configuredSession !== session) {
                configuredSession = session
                try {
                    applySessionConfig(session)
                } catch (e: Exception) {
                    Log.e(TAG, "AR_CONFIG failed: ${e.javaClass.simpleName}: ${e.message}", e)
                    onError?.invoke("AR configuration failed: ${e.message}")
                }
            }
            val updated = frame.getUpdatedTrackables(Plane::class.java)
            onPlanesUpdated(updated)
            val camera = frame.camera
            logTrackingDiagnostics(camera.trackingState, camera.trackingFailureReason, updated.size, view)
            onTrackingStateChanged?.invoke(
                if (camera.trackingState == TrackingState.TRACKING) "TRACKING"
                else mapTrackingFailure(camera.trackingFailureReason)
            )
        }
        view.onTrackingFailureChanged = { reason ->
            onTrackingStateChanged?.invoke(mapTrackingFailure(reason))
        }
        view.onSessionFailed = { e ->
            Log.e(TAG, "AR session failed", e)
            onError?.invoke(e.message ?: "AR session failed")
        }
    }

    private var configuredSession: Session? = null

    private fun fillConfig(session: Session, config: Config) {
        config.planeFindingMode = Config.PlaneFindingMode.HORIZONTAL_AND_VERTICAL
        config.updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
        config.focusMode = Config.FocusMode.AUTO
        // Depth is OFF. On the OnePlus NE2211 (ARCore 1.56) the Depth API reports "supported" but returns
        // nonsense: hits 14-36 m away on a wall 2 m from the camera, and ARCore logs
        // `spherical_rectifier.cc RET_CHECK ... unrectified_camera_model_type`. Plane and feature-point hits
        // are real, so those are used; see AR_DIAG for the support flags.
        config.depthMode = Config.DepthMode.DISABLED
        // Lets a tap on a plain, featureless wall still place the design (see placeApproximateWall).
        config.instantPlacementMode = Config.InstantPlacementMode.LOCAL_Y_UP
        // Match the overlay's brightness to the room's real lighting.
        config.lightEstimationMode = Config.LightEstimationMode.ENVIRONMENTAL_HDR
    }

    private fun applySessionConfig(session: Session) {
        val config = session.config
        fillConfig(session, config)
        session.configure(config)
        val applied = session.config
        Log.i(
            TAG,
            "AR_CONFIG applied planeFinding=${applied.planeFindingMode} depth=${applied.depthMode} " +
                "light=${applied.lightEstimationMode} " +
                "depthAutoSupported=${session.isDepthModeSupported(Config.DepthMode.AUTOMATIC)} " +
                "rawDepthSupported=${session.isDepthModeSupported(Config.DepthMode.RAW_DEPTH_ONLY)}"
        )
    }

    fun detachSceneView(view: ARSceneView) {
        if (sceneView === view) {
            sceneView = null
        }
    }

    // ── Session control ─────────────────────────────────────────────────

    // Wall-detection latency, logged as `WALL_TIMING` so it can be read from logcat on a real phone.
    private var sessionStartedAtMs = 0L
    private var firstWallLogged = false

    fun startSession() {
        sessionStartedAtMs = android.os.SystemClock.elapsedRealtime()
        firstWallLogged = false
        lifecycleOwner.registry.currentState = Lifecycle.State.RESUMED
    }

    fun pauseSession() {
        lifecycleOwner.registry.currentState = Lifecycle.State.STARTED
    }

    fun resumeSession() {
        lifecycleOwner.registry.currentState = Lifecycle.State.RESUMED
    }

    fun destroy() {
        // INITIALIZED -> DESTROYED is an illegal transition; if AR never started
        // there is nothing to tear down and moving the state crashes the Activity.
        if (lifecycleOwner.registry.currentState == Lifecycle.State.INITIALIZED) return
        lifecycleOwner.registry.currentState = Lifecycle.State.DESTROYED
    }

    // ── Wall detection (driven by onSessionUpdated above) ───────────────

    private fun onPlanesUpdated(planes: Collection<Plane>) {
        for (plane in planes) {
            if (plane.type != Plane.Type.VERTICAL) continue
            val existingId = planeIds[plane]

            val isGone = plane.trackingState != TrackingState.TRACKING || plane.subsumedBy != null
            if (isGone) {
                existingId?.let { id ->
                    planeIds.remove(plane)
                    wallPlanes.remove(id)
                    if (selectedWallId == id) {
                        selectedWallId = null
                        clearWallNode()
                    }
                    onWallRemoved?.invoke(id)
                }
                continue
            }

            if (existingId == null) {
                val id = UUID.randomUUID().toString()
                planeIds[plane] = id
                wallPlanes[id] = plane
                Log.d(TAG, "Wall plane detected: $id extent: ${plane.extentX}x${plane.extentZ}")
                if (!firstWallLogged) {
                    firstWallLogged = true
                    Log.i(TAG, "WALL_TIMING first wall after ${android.os.SystemClock.elapsedRealtime() - sessionStartedAtMs} ms, extent ${plane.extentX}x${plane.extentZ} m")
                }
                onWallDetected?.invoke(id, planeToMap(id, plane))
                if (selectedWallId == null) {
                    selectedWallId = id
                    updateWallVisualization()
                }
            } else {
                wallPlanes[existingId] = plane
                onWallUpdated?.invoke(existingId, planeToMap(existingId, plane))
                if (existingId == selectedWallId) {
                    updateWallVisualization()
                }
            }
        }
    }

    private fun mapTrackingFailure(reason: TrackingFailureReason?): String = when (reason) {
        TrackingFailureReason.EXCESSIVE_MOTION -> "LIMITED_EXCESSIVE_MOTION"
        TrackingFailureReason.INSUFFICIENT_FEATURES -> "LIMITED_INSUFFICIENT_FEATURES"
        TrackingFailureReason.INSUFFICIENT_LIGHT -> "LIMITED_INSUFFICIENT_FEATURES"
        TrackingFailureReason.CAMERA_UNAVAILABLE -> "UNAVAILABLE"
        TrackingFailureReason.BAD_STATE -> "LIMITED"
        else -> "INITIALIZING"
    }

    // ── Wall selection ───────────────────────────────────────────────────

    fun selectWall(wallId: String) {
        if (!wallPlanes.containsKey(wallId)) {
            Log.w(TAG, "Wall not found: $wallId")
            return
        }
        selectedWallId = wallId
        updateWallVisualization()
        wallPlanes[wallId]?.let { onWallUpdated?.invoke(wallId, planeToMap(wallId, it)) }
    }

    fun getWalls(): List<Map<String, Any>> = wallPlanes.map { (id, plane) -> planeToMap(id, plane) }

    fun getSelectedWallId(): String? = selectedWallId

    // ── Texture ──────────────────────────────────────────────────────────

    fun setTexture(imageData: ByteArray, patchHeightM: Float? = null) {
        val view = sceneView ?: return
        try {
            val raw = BitmapFactory.decodeByteArray(imageData, 0, imageData.size) ?: return
            // Catalogue photos have a light border/vignette that tiles into a grid of seams; trim 8% per side.
            val bitmap = android.graphics.Bitmap.createBitmap(
                raw, raw.width * 8 / 100, raw.height * 8 / 100, raw.width * 84 / 100, raw.height * 84 / 100,
            )
            val texture = Texture.Builder()
                .width(bitmap.width)
                .height(bitmap.height)
                .sampler(Texture.Sampler.SAMPLER_2D)
                .format(Texture.InternalFormat.SRGB8_A8) // photo pixels are sRGB; RGBA8 rendered washed out
                .levels(0xFF)
                .build(view.engine)
            TextureHelper.setBitmap(view.engine, texture, 0, bitmap)
            texture.generateMipmaps(view.engine)
            // Unlit image material: shows the catalogue colour as-is. The lit PBR material went near-black
            // in normal room light because the quad is seen from the side its normal points away from.
            // Plain REPEAT: the trimmed photo tiles cleanly; MIRRORED_REPEAT read as a kaleidoscope.
            pendingTexture = view.materialLoader.createImageInstance(
                texture,
                com.google.android.filament.TextureSampler(
                    com.google.android.filament.TextureSampler.MinFilter.LINEAR_MIPMAP_LINEAR,
                    com.google.android.filament.TextureSampler.MagFilter.LINEAR,
                    com.google.android.filament.TextureSampler.WrapMode.REPEAT,
                ),
            ).twoSided()
            textureAspect = bitmap.width.toFloat() / bitmap.height.coerceAtLeast(1)
            texturePatchHeightM = patchHeightM ?: TEXTURE_PATCH_HEIGHT_M
            updateWallVisualization()
        } catch (e: Exception) {
            Log.e(TAG, "setTexture failed", e)
            onError?.invoke("Failed to set texture: ${e.message}")
        }
    }

    fun clearTexture() {
        pendingTexture = null
        updateWallVisualization()
    }

    fun preloadTexture(textureUrl: String) {
        // No-op on Android: setTexture() already receives raw bytes pushed
        // from Dart and applies them instantly — nothing to prefetch.
    }

    private fun clearWallNode() {
        wallNode?.let {
            sceneView?.removeChildNode(it)
            it.destroy()
        }
        wallNode = null
    }

    private fun updateWallVisualization() {
        val view = sceneView ?: return
        if (placedAnchorNode != null) {
            rebuildPlacedQuad(view)
            return
        }
        clearWallNode()

        val wallId = selectedWallId ?: return
        val plane = wallPlanes[wallId] ?: return

        // A child node with SceneView's default normal (Direction(y=1)) lies
        // flat in its parent's local XZ plane. Parenting it to an AnchorNode
        // created from the plane's own centerPose (whose local Y axis IS the
        // plane normal) makes the quad land exactly on the wall, facing out,
        // without any manual rotation math.
        val anchor = plane.createAnchor(plane.centerPose) ?: return
        val anchorNode = AnchorNode(engine = view.engine, anchor = anchor)

        val material = pendingTexture
            ?: view.materialLoader.createColorInstance(android.graphics.Color.argb(128, 255, 215, 0)).twoSided()
        // The catalogue photos show a patch of finished wall (many stones), not a
        // single tile. Repeat that patch at a realistic physical size instead of
        // stretching one photo over the whole wall, which is what looked fake.
        val patchH = texturePatchHeightM
        val patchW = patchH * textureAspect
        val quad = PlaneNode(
            engine = view.engine,
            size = Size(x = plane.extentX, y = plane.extentZ),
            uvScale = Float2(plane.extentX / patchW, plane.extentZ / patchH),
            materialInstance = material,
        )
        anchorNode.addChildNode(quad)
        view.addChildNode(anchorNode)
        wallNode = anchorNode
    }

    // ── Tap-to-place wall ────────────────────────────────────────────────

    private fun materialForWall(view: ARSceneView): MaterialInstance =
        pendingTexture ?: view.materialLoader.createColorInstance(android.graphics.Color.argb(128, 255, 215, 0)).twoSided()

    /** Wall quads were back-face culled when seen from the side ARCore's normal points away from. */
    private fun MaterialInstance.twoSided(): MaterialInstance =
        apply { setCullingMode(com.google.android.filament.Material.CullingMode.NONE) }

    private fun rebuildPlacedQuad(view: ARSceneView) {
        val node = placedAnchorNode ?: return
        placedQuad?.let {
            node.removeChildNode(it)
            it.destroy()
        }
        val patchH = texturePatchHeightM
        val patchW = patchH * textureAspect
        val quad = PlaneNode(
            engine = view.engine,
            size = Size(x = placedWidthM, y = placedHeightM),
            uvScale = Float2(placedWidthM / patchW, placedHeightM / patchH),
            materialInstance = materialForWall(view),
        )
        node.addChildNode(quad)
        placedQuad = quad
    }

    /**
     * Places the selected design on the real surface under a screen tap. Every stage is logged under
     * `PLACE` so a failure can be pinned to one step: native entry, tracking, hit list, per-hit verdict.
     * Only real ARCore hits are accepted: a vertical Plane inside its polygon, or a Depth/feature point
     * whose surface normal is roughly horizontal (a wall), never floors or ceilings.
     */
    fun placeWallAtScreenPoint(screenX: Float, screenY: Float): Map<String, Any>? {
        val view = sceneView ?: run {
            Log.w(TAG, "PLACE stage=native reason=no_scene_view")
            return null
        }
        val frame = view.frame
        val tracking = frame?.camera?.trackingState
        val planes = view.session?.getAllTrackables(Plane::class.java).orEmpty()
        Log.i(
            TAG,
            "PLACE stage=native px=(${screenX.toInt()},${screenY.toInt()}) view=${view.width}x${view.height} " +
                "frame=${frame != null} tracking=$tracking planes=${planes.size} " +
                planes.joinToString(prefix = "[", postfix = "]") {
                    "${it.type}/${it.trackingState}/${"%.1f".format(it.extentX)}x${"%.1f".format(it.extentZ)}"
                }
        )
        if (frame == null) return mapOf("placed" to false, "reason" to "no_frame")
        if (tracking != TrackingState.TRACKING) return mapOf("placed" to false, "reason" to "not_tracking")

        val hits = frame.hitTest(screenX, screenY)
        Log.i(TAG, "PLACE stage=hits count=${hits.size}")
        var chosen: HitResult? = null
        var firstRejection = "no_hit"
        hits.forEachIndexed { i, h ->
            val t = h.trackable
            val n = h.hitPose.getTransformedAxis(1, 1.0f) // surface normal in world space
            val verdict = when {
                h.distance < MIN_HIT_DISTANCE_M || h.distance > MAX_HIT_DISTANCE_M -> "implausible_distance"
                t is com.google.ar.core.DepthPoint -> "depth_untrusted"
                t is Plane && !t.isPoseInPolygon(h.hitPose) -> "outside_plane_polygon"
                t is Plane && t.type != Plane.Type.VERTICAL -> "plane_${t.type}"
                t is Plane -> "ok"
                t is com.google.ar.core.Point &&
                    t.orientationMode != com.google.ar.core.Point.OrientationMode.ESTIMATED_SURFACE_NORMAL -> "point_without_normal"
                t is com.google.ar.core.DepthPoint || t is com.google.ar.core.Point ->
                    if (kotlin.math.abs(n[1]) > 0.6f) "floor_or_ceiling" else "ok"
                else -> "unsupported_${t.javaClass.simpleName}"
            }
            Log.i(
                TAG,
                "PLACE hit#$i ${t.javaClass.simpleName} dist=${"%.2f".format(h.distance)}m " +
                    "normal=(${"%.2f".format(n[0])},${"%.2f".format(n[1])},${"%.2f".format(n[2])}) verdict=$verdict"
            )
            if (verdict == "ok" && chosen == null) chosen = h
            else if (verdict != "ok" && firstRejection == "no_hit") firstRejection = verdict
        }

        val hit = chosen ?: run {
            // Floors/ceilings are a user mistake; anything else means ARCore found no wall
            // (plain painted walls have no texture to track), so stand the design up anyway.
            if (firstRejection.startsWith("plane_HORIZONTAL") || firstRejection == "floor_or_ceiling") {
                Log.i(TAG, "PLACE stage=result placed=false reason=$firstRejection")
                return mapOf("placed" to false, "reason" to firstRejection)
            }
            return placeApproximateWall(view, frame, screenX, screenY, firstRejection)
        }

        clearPlacedWall()
        val anchor = hit.createAnchor() ?: run {
            Log.w(TAG, "PLACE stage=anchor reason=createAnchor_null")
            return mapOf("placed" to false, "reason" to "anchor_failed")
        }
        val node = AnchorNode(engine = view.engine, anchor = anchor)
        view.addChildNode(node)
        placedAnchorNode = node
        clearWallNode() // a placed wall replaces any plane-based overlay
        rebuildPlacedQuad(view)
        Log.i(TAG, "PLACE stage=result placed=true surface=${hit.trackable.javaClass.simpleName} dist=${"%.2f".format(hit.distance)}m")
        return mapOf(
            "placed" to true,
            "surface" to hit.trackable.javaClass.simpleName,
            "distanceM" to hit.distance,
        )
    }

    /**
     * Fallback when no real wall is hit: a vertical wall facing the camera, [APPROX_WALL_DISTANCE_M]
     * along the tap ray, anchored in world space so it stays put as the user walks around.
     * ponytail: fixed distance guess, so the scale is approximate; a real plane hit replaces it.
     */
    private fun placeApproximateWall(
        view: ARSceneView, frame: com.google.ar.core.Frame, screenX: Float, screenY: Float, why: String,
    ): Map<String, Any> {
        val hit = frame.hitTestInstantPlacement(screenX, screenY, APPROX_WALL_DISTANCE_M).firstOrNull()
        val session = view.session
        if (hit == null || session == null) {
            Log.i(TAG, "PLACE stage=result placed=false reason=$why (no instant placement)")
            return mapOf("placed" to false, "reason" to why)
        }
        val p = hit.hitPose.translation
        val cam = frame.camera.pose.translation
        // Horizontal normal from the wall point back to the camera.
        var nx = cam[0] - p[0]
        var nz = cam[2] - p[2]
        val len = sqrt(nx * nx + nz * nz).takeIf { it > 1e-3f } ?: 1f
        nx /= len; nz /= len
        // Local axes: X along the wall, Y = wall normal (PlaneNode's normal), Z = up (X × Y = Z).
        // Rotation matrix rows: [m00 m01 m02; m10 m11 m12; m20 m21 m22] with columns X, Y, Z.
        val m00 = -nz; val m01 = nx; val m02 = 0f
        val m10 = 0f;  val m11 = 0f; val m12 = 1f
        val m20 = nx;  val m21 = nz; val m22 = 0f
        val pose = Pose(p, quaternionFromRotation(m00, m01, m02, m10, m11, m12, m20, m21, m22))
        clearPlacedWall()
        val anchor = session.createAnchor(pose)
        val node = AnchorNode(engine = view.engine, anchor = anchor)
        view.addChildNode(node)
        placedAnchorNode = node
        clearWallNode()
        rebuildPlacedQuad(view)
        Log.i(TAG, "PLACE stage=result placed=true surface=approximate dist=${APPROX_WALL_DISTANCE_M}m why=$why")
        return mapOf("placed" to true, "surface" to "approximate", "distanceM" to APPROX_WALL_DISTANCE_M)
    }

    /** Standard rotation-matrix → (x, y, z, w) quaternion. */
    private fun quaternionFromRotation(
        m00: Float, m01: Float, m02: Float, m10: Float, m11: Float, m12: Float, m20: Float, m21: Float, m22: Float,
    ): FloatArray {
        val tr = m00 + m11 + m22
        return when {
            tr > 0 -> { val s = sqrt(tr + 1f) * 2; floatArrayOf((m21 - m12) / s, (m02 - m20) / s, (m10 - m01) / s, 0.25f * s) }
            m00 > m11 && m00 > m22 -> { val s = sqrt(1f + m00 - m11 - m22) * 2; floatArrayOf(0.25f * s, (m01 + m10) / s, (m02 + m20) / s, (m21 - m12) / s) }
            m11 > m22 -> { val s = sqrt(1f + m11 - m00 - m22) * 2; floatArrayOf((m01 + m10) / s, 0.25f * s, (m12 + m21) / s, (m02 - m20) / s) }
            else -> { val s = sqrt(1f + m22 - m00 - m11) * 2; floatArrayOf((m02 + m20) / s, (m12 + m21) / s, 0.25f * s, (m10 - m01) / s) }
        }
    }

    fun clearPlacedWall() {
        placedQuad = null
        placedAnchorNode?.let {
            sceneView?.removeChildNode(it)
            it.destroy()
        }
        placedAnchorNode = null
    }

    // ── Snapshot ─────────────────────────────────────────────────────────

    /**
     * Captures what the AR view currently shows (camera feed + the placed design) with PixelCopy, saves
     * it to Pictures/Grazia in the gallery and also to the app cache so Flutter can share it.
     * [done] gets (galleryUri, cachePath) or (null, errorMessage). Always called on the main thread.
     */
    fun captureSnapshot(done: (Map<String, String>?, String?) -> Unit) {
        val view = sceneView
        if (view == null || view.width <= 0 || view.height <= 0) {
            done(null, "AR view is not ready")
            return
        }
        val bitmap = android.graphics.Bitmap.createBitmap(view.width, view.height, android.graphics.Bitmap.Config.ARGB_8888)
        val handler = android.os.Handler(android.os.Looper.getMainLooper())
        android.view.PixelCopy.request(view, bitmap, { code ->
            if (code != android.view.PixelCopy.SUCCESS) {
                Log.w(TAG, "SNAPSHOT PixelCopy failed code=$code")
                done(null, "Could not capture the camera view (code $code)")
                return@request
            }
            Thread {
                try {
                    val name = "Grazia_AR_" + java.text.SimpleDateFormat("yyyyMMdd_HHmmss", java.util.Locale.US).format(java.util.Date())
                    val cacheFile = java.io.File(appContext.cacheDir, "$name.jpg")
                    cacheFile.outputStream().use { bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 92, it) }

                    val values = android.content.ContentValues().apply {
                        put(android.provider.MediaStore.Images.Media.DISPLAY_NAME, "$name.jpg")
                        put(android.provider.MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                        put(android.provider.MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Grazia")
                        put(android.provider.MediaStore.Images.Media.IS_PENDING, 1)
                    }
                    val resolver = appContext.contentResolver
                    val uri = resolver.insert(android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                        ?: throw java.io.IOException("MediaStore insert returned null")
                    resolver.openOutputStream(uri)?.use { out -> cacheFile.inputStream().use { it.copyTo(out) } }
                        ?: throw java.io.IOException("could not open gallery output stream")
                    values.clear()
                    values.put(android.provider.MediaStore.Images.Media.IS_PENDING, 0)
                    resolver.update(uri, values, null, null)
                    Log.i(TAG, "SNAPSHOT saved ${bitmap.width}x${bitmap.height} -> $uri")
                    handler.post { done(mapOf("uri" to uri.toString(), "path" to cacheFile.absolutePath), null) }
                } catch (e: Exception) {
                    Log.e(TAG, "SNAPSHOT save failed", e)
                    handler.post { done(null, "Could not save the photo: ${e.message}") }
                }
            }.start()
        }, handler)
    }

    // ── Diagnostics ─────────────────────────────────────────────────────

    private var lastTrackingState: TrackingState? = null
    private var lastDiagAtMs = 0L

    /** Logs tracking transitions plus a 5 s heartbeat so wall-detection problems are visible in logcat. */
    private fun logTrackingDiagnostics(state: TrackingState, reason: TrackingFailureReason?, updatedPlanes: Int, view: ARSceneView) {
        val now = android.os.SystemClock.elapsedRealtime()
        if (state != lastTrackingState) {
            lastTrackingState = state
            Log.i(TAG, "TRACKING_STATE $state reason=$reason after ${now - sessionStartedAtMs} ms")
        }
        if (now - lastDiagAtMs > 5000) {
            lastDiagAtMs = now
            val depth = view.session?.config?.depthMode
            val all = view.session?.getAllTrackables(Plane::class.java).orEmpty()
            val byType = all.groupingBy { it.type.name }.eachCount()
            val sess = view.session
            val depthSupport = "auto=${sess?.isDepthModeSupported(Config.DepthMode.AUTOMATIC)} raw=${sess?.isDepthModeSupported(Config.DepthMode.RAW_DEPTH_ONLY)}"
            Log.i(TAG, "AR_DIAG tracking=$state depthMode=$depth depthSupported[$depthSupport] allPlanes=$byType acceptedWalls=${wallPlanes.size} placed=${placedAnchorNode != null} updatedPlanes=$updatedPlanes")
            placedAnchorNode?.let { n ->
                val cam = view.frame?.camera?.pose
                Log.i(TAG, "AR_DIAG placedNode world=${n.worldPosition} visible=${n.isVisible} anchor=${n.anchor.trackingState} " +
                    "quad=${placedQuad?.let { q -> "${q.worldPosition} vis=${q.isVisible} parent=${q.parent != null}" }} " +
                    "cam=${cam?.tx()},${cam?.ty()},${cam?.tz()} fwd=${cam?.zAxis?.joinToString { "%.2f".format(-it) }}")
            }
        }
    }

    // ── Measurement ──────────────────────────────────────────────────────

    fun startMeasurement() {
        measurementStart = null
        measurementEnd = null
        measurementAnchors.values.forEach { it.detach() }
        measurementAnchors.clear()
        measurementNodes.forEach { sceneView?.removeChildNode(it) }
        measurementNodes.clear()
    }

    fun addMeasurementPoint(x: Float, y: Float, z: Float): String {
        val session = sceneView?.session ?: return ""
        val anchor = session.createAnchor(Pose.makeTranslation(x, y, z))
        val id = UUID.randomUUID().toString()
        measurementAnchors[id] = anchor

        if (measurementStart == null) measurementStart = floatArrayOf(x, y, z)
        else if (measurementEnd == null) measurementEnd = floatArrayOf(x, y, z)

        // Pins and lines are drawn by the Flutter overlay (projectMeasurementAnchors), no 3D marker, so Undo is clean.
        return id
    }

    private fun addMeasurementMarkerNode(x: Float, y: Float, z: Float) {
        val view = sceneView ?: return
        val material = view.materialLoader.createColorInstance(android.graphics.Color.rgb(255, 214, 0))
        val sphere = SphereNode(
            engine = view.engine,
            radius = 0.012f,
            center = Position(x, y, z),
            materialInstance = material,
        )
        view.addChildNode(sphere)
        measurementNodes.add(sphere)
    }

    /**
     * Ray-casts a screen-space tap against tracked vertical planes and places
     * a real ARCore world-space measurement anchor there — the only
     * supported way to add a measurement point, same contract as
     * ARKitManager.hitTestWallAtScreenPoint.
     */
    fun hitTestWallAtScreenPoint(screenX: Float, screenY: Float): Map<String, Any>? {
        val view = sceneView ?: return null
        // Like the iPhone Measure app: any real surface counts, not only an already-detected vertical
        // plane. ARCore returns hits nearest-first across planes, depth points (phones with the Depth
        // API) and feature points, so the ruler works on the first frame on plain walls too.
        val hit = rulerHit(view, screenX, screenY) ?: return null

        val pose = hit.hitPose
        val anchorId = addMeasurementPoint(pose.tx(), pose.ty(), pose.tz())
        return mapOf(
            "anchorId" to anchorId,
            "x" to pose.tx(),
            "y" to pose.ty(),
            "z" to pose.tz(),
            "surface" to hit.trackable.javaClass.simpleName,
            "distanceM" to hit.distance,
        )
    }

    /** Nearest real surface (plane or oriented feature point) under a screen pixel, within ruler range. */
    private fun rulerHit(view: ARSceneView, x: Float, y: Float): HitResult? {
        val cam = view.frame?.camera ?: return null
        if (cam.trackingState != TrackingState.TRACKING) return null
        // Depth API output is not used: it returned 14-36 m for a 2 m wall on the test phone, and
        // planes/feature points are what ARCore documents as metrically tracked on every ARCore device.
        val hit = view.hitTestAR(
            xPx = x,
            yPx = y,
            planeTypes = Plane.Type.values().toSet(),
            point = true,
            depthPoint = false,
            instantPlacementPoint = false,
        )
        // Throttled diagnostics so a device that never finds a surface can be explained from logcat
        val now = System.currentTimeMillis()
        if (now - lastRulerLogMs > 3000) {
            lastRulerLogMs = now
            val pts = runCatching { cam.let { view.frame?.acquirePointCloud()?.use { pc -> pc.ids.limit() } } }.getOrNull()
            val cp = cam.pose
            Log.i(TAG, "RULER hit=${hit?.trackable?.javaClass?.simpleName} dist=${hit?.distance} pointCloud=$pts pose=%.2f,%.2f,%.2f ts=${view.frame?.timestamp}".format(cp.tx(), cp.ty(), cp.tz()))
        }
        if (hit == null) return null
        return if (hit.distance in MIN_MEASURE_M..MAX_MEASURE_M) hit else null
    }

    /** Live crosshair probe: same hit test as placing a point, but creates no anchor. */
    fun probeSurfaceAtScreenPoint(screenX: Float, screenY: Float): Map<String, Any>? {
        val view = sceneView ?: return null
        val hit = rulerHit(view, screenX, screenY) ?: return null
        val pose = hit.hitPose
        return mapOf(
            "x" to pose.tx(),
            "y" to pose.ty(),
            "z" to pose.tz(),
            "distanceM" to hit.distance,
            "surface" to hit.trackable.javaClass.simpleName,
        )
    }

    /**
     * Current screen position (native pixels) of measurement anchors, so pins and lines stay glued to the
     * real object while the phone moves. `visible` is false when behind the camera or the anchor is not tracked.
     */
    fun projectMeasurementAnchors(ids: List<String>): List<Map<String, Any>> {
        val view = sceneView ?: return emptyList()
        val cam = view.frame?.camera ?: return emptyList()
        val w = view.width.toFloat()
        val h = view.height.toFloat()
        if (w <= 0f || h <= 0f) return emptyList()
        val proj = FloatArray(16)
        val viewM = FloatArray(16)
        val vp = FloatArray(16)
        cam.getProjectionMatrix(proj, 0, 0.05f, 50f)
        cam.getViewMatrix(viewM, 0)
        Matrix.multiplyMM(vp, 0, proj, 0, viewM, 0)
        return ids.map { id ->
            val anchor = measurementAnchors[id]
            if (anchor == null || anchor.trackingState != TrackingState.TRACKING) {
                mapOf<String, Any>("visible" to false, "x" to 0.0, "y" to 0.0)
            } else {
                val p = anchor.pose
                val clip = FloatArray(4)
                Matrix.multiplyMV(clip, 0, vp, 0, floatArrayOf(p.tx(), p.ty(), p.tz(), 1f), 0)
                if (clip[3] <= 0.0001f) {
                    mapOf<String, Any>("visible" to false, "x" to 0.0, "y" to 0.0)
                } else {
                    val ndcX = clip[0] / clip[3]
                    val ndcY = clip[1] / clip[3]
                    mapOf<String, Any>(
                        "visible" to true,
                        "x" to ((ndcX * 0.5f + 0.5f) * w).toDouble(),
                        "y" to ((1f - (ndcY * 0.5f + 0.5f)) * h).toDouble(),
                    )
                }
            }
        }
    }

    /**
     * "Auto" ruler: outlines the object under the reticle (A4 sheet, tile, book, panel) from the camera image, drops a
     * measurement anchor on each of its 4 corners (hit-tested on the real surface, like a manual pin) and returns the
     * corners in order. Returns a reason string under "error" when nothing could be outlined or measured.
     */
    fun detectObjectAtScreenPoint(screenX: Float, screenY: Float): Map<String, Any> {
        val view = sceneView ?: return mapOf("error" to "no_view")
        val frame = view.frame ?: return mapOf("error" to "no_frame")
        val cam = frame.camera
        if (cam.trackingState != TrackingState.TRACKING) return mapOf("error" to "not_tracking")
        val image = try {
            frame.acquireCameraImage()
        } catch (e: Exception) {
            Log.w(TAG, "AUTO acquireCameraImage failed: ${e.message}")
            return mapOf("error" to "no_image")
        }
        val corners: List<Pair<Float, Float>>
        val iw: Int
        val ih: Int
        try {
            val plane = image.planes[0]
            val buf = plane.buffer
            val rowStride = plane.rowStride
            iw = image.width
            ih = image.height
            // Half resolution is plenty for an outline and keeps the flood fill fast
            val gw = iw / 2
            val gh = ih / 2
            val gray = ByteArray(gw * gh)
            for (y in 0 until gh) {
                val rowStart = y * 2 * rowStride
                for (x in 0 until gw) gray[y * gw + x] = buf.get(rowStart + x * 2)
            }
            val seedView = floatArrayOf(screenX, screenY)
            val seedImg = FloatArray(2)
            frame.transformCoordinates2d(Coordinates2d.VIEW, seedView, Coordinates2d.IMAGE_PIXELS, seedImg)
            val found = ObjectOutline.find(gray, gw, gh, (seedImg[0] / 2).toInt(), (seedImg[1] / 2).toInt())
                ?: run {
                    Log.i(TAG, "AUTO no_object seed=(${seedImg[0].toInt()},${seedImg[1].toInt()}) img=${iw}x$ih")
                    return mapOf("error" to "no_object")
                }
            Log.i(TAG, "AUTO outline found seed=(${seedImg[0].toInt()},${seedImg[1].toInt()}) img=${iw}x$ih")
            corners = found.map { Pair(it.first * 2, it.second * 2) }
        } finally {
            image.close()
        }

        val worlds = ArrayList<FloatArray>()
        val screens = ArrayList<Map<String, Double>>()
        for ((cx, cy) in corners) {
            val imgPt = floatArrayOf(cx, cy)
            val viewPt = FloatArray(2)
            frame.transformCoordinates2d(Coordinates2d.IMAGE_PIXELS, imgPt, Coordinates2d.VIEW, viewPt)
            val hit = rulerHit(view, viewPt[0], viewPt[1]) ?: run {
                Log.i(TAG, "AUTO no_surface at corner view=(${viewPt[0].toInt()},${viewPt[1].toInt()})")
                return mapOf("error" to "no_surface")
            }
            worlds.add(floatArrayOf(hit.hitPose.tx(), hit.hitPose.ty(), hit.hitPose.tz()))
            screens.add(mapOf("x" to viewPt[0].toDouble(), "y" to viewPt[1].toDouble()))
        }
        startMeasurement()
        val ids = worlds.map { addMeasurementPoint(it[0], it[1], it[2]) }
        Log.i(TAG, "AUTO corners=${corners.size} sides=" + (0 until 4).joinToString { i ->
            val a = worlds[i]; val b = worlds[(i + 1) % 4]
            "%.3f".format(sqrt((a[0]-b[0])*(a[0]-b[0]) + (a[1]-b[1])*(a[1]-b[1]) + (a[2]-b[2])*(a[2]-b[2])))
        })
        return mapOf(
            "ids" to ids,
            "world" to worlds.map { listOf(it[0].toDouble(), it[1].toDouble(), it[2].toDouble()) },
            "screen" to screens,
        )
    }

    fun getMeasurementDistance(): Float? {
        val start = measurementStart ?: return null
        val end = measurementEnd ?: return null
        return distance(start, end)
    }

    fun clearMeasurement() {
        measurementAnchors.values.forEach { it.detach() }
        measurementAnchors.clear()
        measurementNodes.forEach { sceneView?.removeChildNode(it) }
        measurementNodes.clear()
        measurementStart = null
        measurementEnd = null
    }

    // ── Calibration (interface parity — see measureDistance below) ──────

    fun startCalibration(unit: String) {
        calibrationUnit = unit
        calibrationPoints.clear()
        isCalibrating = true
        pixelsPerMeter = 0f
    }

    fun finishCalibration(realLength: Float): Boolean {
        if (!isCalibrating || calibrationPoints.size < 2) return false
        val pixelDistance = distance(calibrationPoints[0], calibrationPoints[1])
        val realLengthMeters = when (calibrationUnit) {
            "ft" -> realLength * 0.3048f
            "m" -> realLength
            "in" -> realLength * 0.0254f
            "cm" -> realLength * 0.01f
            else -> realLength * 0.3048f
        }
        pixelsPerMeter = if (realLengthMeters > 0) pixelDistance / realLengthMeters else 0f
        isCalibrating = false
        return true
    }

    fun getCalibration(): Map<String, Any>? {
        if (pixelsPerMeter <= 0f) return null
        return mapOf(
            "pixelsPerUnit" to pixelsPerMeter,
            "unit" to calibrationUnit,
            "isCalibrated" to true,
        )
    }

    /**
     * Distance in metres between two screen taps, resolved through real
     * ARCore world anchors. Deliberately does NOT require pixelsPerMeter —
     * both points come back as real world-space coordinates already in
     * metres, matching ARKitManager.measureDistance's same reasoning.
     */
    fun measureDistance(x1: Float, y1: Float, x2: Float, y2: Float): Float? {
        val view = sceneView ?: return null
        val planeTypes = setOf(Plane.Type.VERTICAL)
        val hit1 = view.hitTestAR(xPx = x1, yPx = y1, planeTypes = planeTypes) ?: return null
        val hit2 = view.hitTestAR(xPx = x2, yPx = y2, planeTypes = planeTypes) ?: return null
        val p1 = hit1.hitPose
        val p2 = hit2.hitPose
        return distance(
            floatArrayOf(p1.tx(), p1.ty(), p1.tz()),
            floatArrayOf(p2.tx(), p2.ty(), p2.tz()),
        )
    }

    private fun distance(a: FloatArray, b: FloatArray): Float {
        val dx = a[0] - b[0]
        val dy = a[1] - b[1]
        val dz = a[2] - b[2]
        return sqrt(dx * dx + dy * dy + dz * dz)
    }

    // ── Tile quantity — identical formula to ARKitManager.calculateTileQuantity ──

    fun calculateTileQuantity(
        tileWidth: Float,
        tileHeight: Float,
        tileUnit: String,
        wastagePercent: Float,
    ): Map<String, Any>? {
        val wallId = selectedWallId ?: return null
        val plane = wallPlanes[wallId] ?: return null

        val wallWidthM = plane.extentX
        val wallHeightM = plane.extentZ
        val wallAreaM2 = wallWidthM * wallHeightM

        val (tileWidthM, tileHeightM) = when (tileUnit) {
            "mm" -> (tileWidth / 1000f) to (tileHeight / 1000f)
            "cm" -> (tileWidth / 100f) to (tileHeight / 100f)
            "ft" -> (tileWidth * 0.3048f) to (tileHeight * 0.3048f)
            "in" -> (tileWidth * 0.0254f) to (tileHeight * 0.0254f)
            "m" -> tileWidth to tileHeight
            else -> (tileWidth / 1000f) to (tileHeight / 1000f)
        }

        val tileAreaM2 = tileWidthM * tileHeightM
        if (tileAreaM2 <= 0f) return null

        val baseQuantity = ceil(wallAreaM2 / tileAreaM2).toInt()
        val wastage = ceil(baseQuantity * wastagePercent / 100.0).toInt()
        val recommendedQuantity = baseQuantity + wastage

        var displayWallWidth = wallWidthM
        var displayWallHeight = wallHeightM
        var displayUnit = tileUnit
        when (tileUnit) {
            "ft" -> {
                displayWallWidth = wallWidthM / 0.3048f
                displayWallHeight = wallHeightM / 0.3048f
            }
            "in" -> {
                displayWallWidth = wallWidthM / 0.0254f
                displayWallHeight = wallHeightM / 0.0254f
            }
            "cm" -> {
                displayWallWidth = wallWidthM * 100f
                displayWallHeight = wallHeightM * 100f
                displayUnit = "cm"
            }
            "mm" -> {
                displayWallWidth = wallWidthM * 1000f
                displayWallHeight = wallHeightM * 1000f
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
            "calibrationUnit" to calibrationUnit,
        )
    }

    // ── Wall state ───────────────────────────────────────────────────────

    /** True when [pose] is inside roughly +-60 degrees of where the camera is looking. */
    private fun inCameraView(pose: Pose): Boolean {
        val cam = sceneView?.frame?.camera?.pose ?: return true
        val fwd = cam.getTransformedAxis(2, -1.0f) // the camera looks down its -Z axis
        val dx = pose.tx() - cam.tx()
        val dy = pose.ty() - cam.ty()
        val dz = pose.tz() - cam.tz()
        val len = sqrt(dx * dx + dy * dy + dz * dz)
        if (len < 1e-3f) return true
        return (fwd[0] * dx + fwd[1] * dy + fwd[2] * dz) / len > 0.5f
    }

    /**
     * "TRACKING" only while a wall is both tracked by ARCore and actually in front of the camera.
     * A plane/anchor stays tracked after the camera turns away, so without the view test the UI kept
     * saying "Wall detected" while pointing at the floor or a different room.
     */
    fun getWallState(): String {
        val placed = placedAnchorNode?.anchor
        val selected = selectedWallId?.let { wallPlanes[it] }
        val state = when {
            placed != null ->
                if (placed.trackingState == TrackingState.TRACKING && inCameraView(placed.pose)) "TRACKING" else "LOST"
            wallPlanes.isEmpty() -> "SEARCHING"
            selected != null ->
                if (selected.trackingState == TrackingState.TRACKING && inCameraView(selected.centerPose)) "TRACKING" else "LOST"
            else -> "DETECTING"
        }
        onWallStateChanged?.invoke(state)
        return state
    }

    // ── Plane -> Map (matches ARKitManager.planeToDictionary shape) ─────

    private fun planeToMap(id: String, plane: Plane): Map<String, Any> {
        val pose = plane.centerPose
        val halfWidth = plane.extentX / 2f
        val halfHeight = plane.extentZ / 2f

        val localCorners = listOf(
            floatArrayOf(-halfWidth, 0f, -halfHeight),
            floatArrayOf(halfWidth, 0f, -halfHeight),
            floatArrayOf(halfWidth, 0f, halfHeight),
            floatArrayOf(-halfWidth, 0f, halfHeight),
        )
        val corners = localCorners.map { local ->
            val world = pose.transformPoint(local)
            mapOf("x" to world[0], "y" to world[1], "z" to world[2])
        }

        return mapOf(
            "id" to id,
            "center" to mapOf("x" to pose.tx(), "y" to pose.ty(), "z" to pose.tz()),
            "extent" to mapOf("width" to plane.extentX, "height" to plane.extentZ),
            "alignment" to "vertical",
            "corners" to corners,
            "area" to (plane.extentX * plane.extentZ),
            "confidence" to 0.9,
            "isSelected" to (id == selectedWallId),
        )
    }
}
