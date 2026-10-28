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
import kotlin.math.abs
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
        const val AUTO_PLACE_INTERVAL_MS = 400L
        const val AUTO_GUESS_AFTER_MS = 1500L
        // A placed design stays hidden until the wall mask can cut it to the wall; only if the segmenter never
        // gets there (raw plaster, bad light) is the plain panel shown after this long.
        const val SHOW_UNMASKED_AFTER_MS = 6000L
        const val EDGE_AGREE_WINDOW_MS = 3000L
        const val A4_INTERVAL_MS = 300L
        // cos 63 deg: a placed wall seen more obliquely than this means the camera has turned to another wall.
        const val WALL_TURN_COS = 0.45f
        const val MAX_REMEMBERED_WALLS = 4
        // How deep the joints read in the parallax relief (Grazia ledger panels are 25-35 mm thick).
        const val STONE_RELIEF_M = 0.02f
        // Larger UV offsets smear the stones into streaks with few march steps on mobile.
        const val MAX_RELIEF_UV = 0.035f
        // Below this share of wall pixels over the visible part of the quad the mask is ignored (see bindMask).
        const val MIN_MASK_COVERAGE = 0.15f
        // Point-cloud wall fit: ARCore feature points that land on segmenter wall pixels, RANSAC'd into a
        // vertical plane. Gives a real distance on plain walls long before ARCore grows a Plane there.
        const val PC_MIN_POINTS = 10
        const val PC_ITERATIONS = 80
        const val PC_INLIER_M = 0.04f
        const val PC_MIN_SPREAD_M = 0.35f
        const val PC_MIN_CONFIDENCE = 0.15f
        const val PC_AGREE_WINDOW_MS = 2000L
        const val PC_AGREE_OFFSET_M = 0.12f
        // Minimum gap between two segmentation requests (the mask is world-locked, so ~1.5 Hz is plenty).
        const val SEG_INTERVAL_MS = 900L // 600 ms still pushed the OnePlus to thermal status 3 within 90 s
        const val BRUSH_SCREEN_FRACTION = 0.06f
        const val MASKED_WALL_WIDTH_M = 8f
        const val MASKED_WALL_HEIGHT_M = 4f
        // Share of the stone photo shown as-is (emissive) under the lit, normal-mapped shading. Tuned on device.
        const val EMISSIVE_LEVEL = 0.6f
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
    @Volatile private var needTap = false
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

    private var lifecycleOwner = ManagerLifecycleOwner()
    private var sceneView: ARSceneView? = null

    // Wall tracking. ARCore hands back a NEW Plane wrapper object every frame (equals/hashCode compare the
    // native handle), so this must be a HashMap: the old IdentityHashMap minted a "new wall" every frame.
    private val planeIds = HashMap<Plane, String>()
    private var lastWallVizMs = 0L
    private val wallPlanes = LinkedHashMap<String, Plane>()
    private var selectedWallId: String? = null
    private var wallNode: Node? = null
    // A wall the user placed by tapping it (depth / feature / plane hit). Independent of plane detection,
    // so a plain wall works on the first frame instead of waiting for ARCore to find a plane.
    private var placedAnchorNode: AnchorNode? = null
    private var placedQuad: Node? = null
    // What the current placement rests on ("Plane", "Point", "wall_extended", "floor_line", "approximate").
    private var placedSurface: String? = null
    private var placedWidthM = PLACED_WALL_WIDTH_M
    private var placedHeightM = PLACED_WALL_HEIGHT_M
    private var placedBig = false // quad at MASKED_WALL_* size (mask on) rather than PLACED_WALL_* (panel)

    /**
     * Distance used by the "approximate" placement (no ARCore surface at all). The default is a guess; the
     * user can type the real distance to the wall, which makes the panel's scale honest on plain walls.
     */
    @Volatile var approxDistanceM = APPROX_WALL_DISTANCE_M
        private set

    fun setApproximateDistance(meters: Float) {
        approxDistanceM = meters.coerceIn(0.5f, 8f)
        // Re-place right away when the current placement is the guess, so the user sees the new scale.
        mainHandler.post {
            val view = sceneView ?: return@post
            if (Placement.scale(placedSurface) != Placement.Scale.APPROXIMATE) return@post
            // Keep the wall's angle (it may come from its floor/ceiling line); only its distance changes.
            if (!replaneAtDistance(view, approxDistanceM, placedSurface ?: "approximate")) {
                val (px, py) = wallProbePoint(view) ?: (view.width / 2f to view.height * 0.4f)
                placeWallAtScreenPoint(px, py)
            }
            Log.i(TAG, "PLACE distance ${approxDistanceM}m entered by the user (not measured)")
        }
    }
    private var placedOnFloor = false
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
        // The manager is a process singleton but destroy() runs when the Flutter engine detaches. A destroyed
        // LifecycleRegistry can never be RESUMED again, so reopening the app crashed with "State is 'DESTROYED'".
        reviveLifecycleIfDestroyed()
        if (sceneView !== view) forgetEngineObjects()
        sceneView = view
        view.lifecycle = lifecycleOwner.lifecycle
        view.planeRenderer.isEnabled = true
        view.planeRenderer.isVisible = false // the ruler and the wall preview draw their own overlays; no debug plane polygons
        view.onSessionUpdated = { session, frame ->
            // onSessionCreated / sessionConfiguration never fired on the OnePlus, but onSessionUpdated does,
            // so the ARCore config is applied here, once per session, before anything else.
            if (configuredSession !== session) {
                configuredSession = session
                // Anchors of an earlier session mean nothing in this one.
                rememberedWalls.forEach { runCatching { it.anchor.detach() } }
                rememberedWalls.clear()
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
            requestWallMask(view, frame)
            autoPlace(view, camera.trackingState)
            updateQuadTransform()
            placedAnchorNode?.let { val show = !userHidden && designReady(); if (shownState != show) { it.isVisible = show; shownState = show } }
            sideWall?.let { side ->
                val show = !userHidden && designReady() && sideReady(side)
                if (side.shown != show) { side.node.isVisible = show; side.shown = show }
                side.mi?.let { mi -> quadTransform(mi, side.node.anchor, side.zMin) }
            }
            logTrackingDiagnostics(camera.trackingState, camera.trackingFailureReason, updated.size, view)
            validateDepth(session, frame)
            detectA4(view, frame)
            onTrackingStateChanged?.invoke(
                if (camera.trackingState == TrackingState.TRACKING) "TRACKING"
                else mapTrackingFailure(camera.trackingFailureReason)
            )
        }
        view.onTrackingFailureChanged = { reason ->
            onTrackingStateChanged?.invoke(mapTrackingFailure(reason))
        }
        queuedTexture?.let { (bytes, patch, seam) -> setTexture(bytes, patch, seam) }
        view.onSessionFailed = { e ->
            Log.e(TAG, "AR session failed", e)
            onError?.invoke(e.message ?: "AR session failed")
        }
    }

    private var configuredSession: Session? = null

    // Thermal state (PowerManager, API 29+): the segmenter slows down as the phone heats up, so tracking and
    // rendering keep their share of the CPU (performance guide). Tracking > segmentation frequency.
    @Volatile private var thermalStatus = 0
    private val thermalListener: Any? = if (android.os.Build.VERSION.SDK_INT >= 29) {
        val pm = appContext.getSystemService(android.content.Context.POWER_SERVICE) as android.os.PowerManager
        thermalStatus = pm.currentThermalStatus
        android.os.PowerManager.OnThermalStatusChangedListener { status ->
            if (status != thermalStatus) Log.i(TAG, "THERMAL status $thermalStatus -> $status (segmentation every ${segIntervalLabel(status)})")
            thermalStatus = status
        }.also { pm.addThermalStatusListener(it) }
    } else null

    private fun segIntervalForThermal(status: Int = thermalStatus): Long? = WallSegmenter.intervalForThermal(status, SEG_INTERVAL_MS)

    private fun segIntervalLabel(status: Int) = segIntervalForThermal(status)?.let { "$it ms" } ?: "paused"
    private var lastEdgeEstimate: Pair<WallEdges.Estimate, Long>? = null
    /** Distance from the camera to the wall when the current placement was made (for getPlacementInfo). */
    private var placedDistanceM = 0f

    /**
     * Every AR view brings its own Filament engine, but this manager outlives views. Materials, textures and nodes
     * built on the old engine segfaulted the app (SIGSEGV in libfilament-jni) when Live AR was reopened, so they
     * are dropped, not destroyed (their engine is already gone). queuedTexture rebuilds the design on attach.
     */
    private fun forgetEngineObjects() {
        maskTexture = null
        wallMaskedMaterial = null
        ubershader = null
        pendingTexture = null
        wallNode = null
        placedAnchorNode = null
        placedQuad = null
        placedSurface = null
        sideWall = null // its engine objects went with the old view
        measurementNodes.clear()
        worldMask.reset()
        maskReady = false
    }

    // Depth finds plain painted walls that plane detection never does, but "supported" does not mean "right":
    // the OnePlus NE2211 returned walls 9-36 m away for one ~2 m away. DepthValidator checks the depth image
    // against ARCore's metric feature points at runtime; depth hits are used only once it is TRUSTED, and depth
    // is switched off for the rest of the process when it is REJECTED (or never becomes checkable).
    // `adb shell setprop debug.grazia.depth off` forces it off.
    private val depthValidator = DepthValidator()
    private var lastDepthCheckMs = 0L
    private var lastRawDepthTs = -1L
    private val depthForcedOff get() = debugProp("debug.grazia.depth") == "off"
    // `setprop debug.grazia.depth measure`: keep depth running for tape-measure tests even after a REJECTED decision
    // (it is still never used for placement unless TRUSTED) and log DEPTH_PROBE once a second.
    private val depthMeasureMode get() = debugProp("debug.grazia.depth") == "measure"
    private var lastProbeMs = 0L

    private fun debugProp(name: String): String? = runCatching {
        Class.forName("android.os.SystemProperties").getMethod("get", String::class.java).invoke(null, name) as? String
    }.getOrNull()?.takeIf { it.isNotEmpty() }

    // Auto-placement: until something is placed, probe the wall at the screen centre a few times a second.
    private var lastAutoPlaceMs = 0L

    // When the segmenter first saw a wall at the probe point without ARCore finding a real surface there.
    private var wallSeenSinceMs = 0L
    private var lastNeedTapMs = 0L

    /**
     * Places (and re-places) the design with no tap. Probe = the wall pixel nearest the screen centre
     * (segmenter), else the centre. A real ARCore surface is preferred; if the segmenter keeps seeing a wall
     * for [AUTO_GUESS_AFTER_MS] with no real hit (plain paint), it falls back to a guessed distance, which the
     * wall mask still clips to the true wall outline. If the user turns to another wall, it moves there.
     */
    private fun autoPlace(view: ARSceneView, tracking: TrackingState) {
        if (tracking != TrackingState.TRACKING) return
        if (pendingTexture == null) return // nothing to show (Measure screen): never place the gold placeholder
        val now = android.os.SystemClock.elapsedRealtime()
        if (now - lastAutoPlaceMs < AUTO_PLACE_INTERVAL_MS) return
        lastAutoPlaceMs = now
        val probe = wallProbePoint(view)
        val wallVisible = probe != null
        val (px, py) = probe ?: (view.width / 2f to view.height * 0.4f)
        if (placedAnchorNode != null) {
            val frame = view.frame ?: return
            // A guessed-distance placement has the wrong scale; the moment ARCore has real geometry under the
            // wall, move the design onto it (this is where "tiles the wrong size" came from).
            if (Placement.upgradable(placedSurface) && wallVisible) {
                val before = placedAnchorNode?.anchor?.pose?.translation?.toList()
                val previous = placedSurface
                val real = placeWallAtScreenPoint(px, py, realWallOnly = true)
                if (real?.get("placed") == true) {
                    Log.i(TAG, "AUTO upgraded $previous placement to ${real["surface"]} (${Placement.provenance(real["surface"] as String?)}): " +
                        "old=$before new=${placedAnchorNode?.anchor?.pose?.translation?.toList()} dist=${real["distanceM"]}")
                    onWallStateChanged?.invoke("LOCKED")
                    return
                }
            }
            if (!wallVisible || placedQuadCovers(view, frame, px, py) || sideWallCovers(view, frame, px, py)) { wallLeftTicks = 0; return }
            // Two ticks in a row (~0.8 s), so a quick sweep across a corner does not throw the design away.
            if (++wallLeftTicks < 2) return
            wallLeftTicks = 0
            Log.i(TAG, "AUTO wall moved out of the placed design, re-placing")
            rememberMeasuredWall(view)
            clearPlacedWall()
            // A wall is in view right now (wallVisible): put the design on it at once instead of waiting
            // AUTO_GUESS_AFTER_MS again; a real surface, an A4 sheet or the floor line still upgrade it after.
            wallSeenSinceMs = now - AUTO_GUESS_AFTER_MS - 1
        }
        // Searching since: the first auto-place attempt while tracking. Placement must not wait for the
        // segmenter to call something "wall" (it refuses raw plaster and flat primer): after
        // AUTO_GUESS_AFTER_MS with no real surface the design is placed at the guessed distance anyway, the
        // mask stays off until it is confident, and a tap or a later real hit re-places it.
        if (wallSeenSinceMs == 0L) wallSeenSinceMs = now
        // A real surface first. Plain paint gives ARCore none, so after AUTO_GUESS_AFTER_MS the design goes up
        // anyway where the segmenter sees wall: the geodesic mask cuts it to that wall and WallEdges turns it to
        // the wall's real angle and distance from its floor/ceiling line. A tap is asked for only when nothing in
        // view looks like a wall.
        val res = placeWallAtScreenPoint(px, py, realWallOnly = true)
        if (res?.get("placed") != true && now - wallSeenSinceMs > AUTO_GUESS_AFTER_MS) {
            // Back on a wall measured earlier this session: its measured placement, not a fresh 2 m guess.
            if (wallVisible && restoreMeasuredWall(view, px, py)) {
                wallSeenSinceMs = 0L
                needTap = false
                onWallStateChanged?.invoke("LOCKED")
                return
            }
            val guess = if (wallVisible) placeWallAtScreenPoint(px, py, realWallOnly = false) else null
            if (guess?.get("placed") == true) {
                wallSeenSinceMs = 0L
                needTap = false
                onWallStateChanged?.invoke(if (guess["surface"] == "approximate") "APPROXIMATE" else "LOCKED")
                return
            }
            if (now - lastNeedTapMs > 2000) {
                lastNeedTapMs = now
                needTap = true
                onWallStateChanged?.invoke("NEED_TAP")
            }
        }
        if (res?.get("placed") == true) {
            wallSeenSinceMs = 0L
            needTap = false
            onWallStateChanged?.invoke(if (res["surface"] == "approximate") "APPROXIMATE" else "LOCKED")
        }
    }

    // ── Wall segmentation (WallSegmenter) ───────────────────────────────

    private var segmenter: WallSegmenter? = null
    private var segmenterFailed = false
    private var lastSegRequestMs = 0L
    private var latestMask: ByteArray? = null
    private var maskTexture: Texture? = null
    @Volatile private var maskReady = false
    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private var lastSegLogMs = 0L

    private fun requestWallMask(view: ARSceneView, frame: com.google.ar.core.Frame) {
        if (segmenterFailed) return
        val seg = segmenter ?: runCatching { WallSegmenter(appContext) }
            .onFailure { segmenterFailed = true; Log.e(TAG, "WallSegmenter unavailable, design will not be clipped", it) }
            .getOrNull()?.also { segmenter = it } ?: return
        if (frame.camera.trackingState != TrackingState.TRACKING) return
        // Back-to-back segmentation pinned the big cores and drove the OnePlus into thermal throttling
        // (status 4), which then slowed ARCore and Flutter too; the world-locked mask does not need more.
        val nowMs = android.os.SystemClock.elapsedRealtime()
        val interval = segIntervalForThermal() ?: return // critical: keep the last mask, run nothing
        if (nowMs - lastSegRequestMs < interval) return
        lastSegRequestMs = nowMs
        // Camera view-projection for this exact frame; the material reprojects the mask through it.
        val proj = FloatArray(16); val viewM = FloatArray(16); val vp = FloatArray(16)
        frame.camera.getProjectionMatrix(proj, 0, 0.05f, 100f)
        frame.camera.getViewMatrix(viewM, 0)
        Matrix.multiplyMM(vp, 0, proj, 0, viewM, 0)
        // Everything the worker needs about the placed quad, captured now (anchors are main-thread objects).
        val anchor = placedAnchorNode?.anchor?.takeIf { it.trackingState == TrackingState.TRACKING }
        val quadToWorld = anchor?.let { a -> FloatArray(16).also { a.pose.toMatrix(it, 0) } }
        val camDist = anchor?.let { a ->
            val n = a.pose.getTransformedAxis(1, 1f); val c = a.pose.translation; val cam = frame.camera.pose.translation
            kotlin.math.abs((cam[0] - c[0]) * n[0] + (cam[1] - c[1]) * n[1] + (cam[2] - c[2]) * n[2])
        } ?: 0f
        // The mask always covers the full MASKED_WALL area around the anchor, whatever size the drawn quad
        // has right now, so switching between the panel and the full wall never invalidates it.
        val qw = MASKED_WALL_WIDTH_M; val qh = MASKED_WALL_HEIGHT_M; val zMin = maskZMin()
        // Where the wall flood fill starts: the anchor itself, 1 m up from a floor-line anchor, or beside a
        // reference object (see anchorWall's refSizeM).
        val seedZ = placedSeedZ
        // For WallEdges: this frame's camera, the tracked floor (main-thread objects) and which placement it is.
        val camProj = proj.copyOf(); val camView = viewM.copyOf()
        val floorY = floorHeight(view)
        // Re-align a guessed placement; an edge placement whose height was assumed may still upgrade to one on
        // a tracked floor. Measured and user-calibrated placements are never touched.
        val guessed = placedSurface == "approximate" ||
            ((placedSurface == "edge_ceiling" || placedSurface == "edge_floor_assumed") && floorY != null)
        val placedAt = placedAnchorNode
        val gen = placementGen
        // The corner's second wall, if any: its pose and where it splits the room with the placed wall.
        val side = sideWall
        val sideAnchor = side?.node?.anchor?.takeIf { it.trackingState == TrackingState.TRACKING }
        val sideToWorld = sideAnchor?.let { a -> FloatArray(16).also { a.pose.toMatrix(it, 0) } }
        val sideDist = sideAnchor?.let { a ->
            val n = a.pose.getTransformedAxis(1, 1f); val c = a.pose.translation; val cam = frame.camera.pose.translation
            kotlin.math.abs((cam[0] - c[0]) * n[0] + (cam[1] - c[1]) * n[1] + (cam[2] - c[2]) * n[2])
        } ?: 0f
        val corner = side?.corner
        seg.request(frame) { result ->
            // Heavy per-texel reprojection stays on the worker so the camera feed never stutters.
            // A result for a placement that has since been replaced would land in the new placement's fresh mask.
            val bytes = quadToWorld?.takeIf { gen == placementGen }?.let {
                // At a room corner the placed wall ends at the corner line; the other side is the second wall's.
                val minX = if (corner != null && corner.keepA > 0) corner.cornerX else -Float.MAX_VALUE
                val maxX = if (corner != null && corner.keepA < 0) corner.cornerX else Float.MAX_VALUE
                worldMask.update(result, WallSegmenter.MASK_W, WallSegmenter.MASK_H, vp, it, qw, qh, zMin, seedZ, camDist,
                    keepMinX = minX, keepMaxX = maxX)
                worldMask.toBytes()
            }
            mainHandler.post { applyMask(view, result.wall, vp, bytes) }
            val sideBytes = if (side != null && sideToWorld != null && corner != null && gen == placementGen) {
                side.mask.update(result, WallSegmenter.MASK_W, WallSegmenter.MASK_H, vp, sideToWorld, qw, qh, side.zMin, corner.seedZ,
                    sideDist, seedX = corner.seedX,
                    keepMinX = if (corner.keepB > 0) 0f else -Float.MAX_VALUE, keepMaxX = if (corner.keepB < 0) 0f else Float.MAX_VALUE)
                side.mask.toBytes()
            } else null
            if (side != null && sideBytes != null) mainHandler.post { if (sideWall === side && sceneView === view) uploadSideMask(view, side, sideBytes) }
            // No second wall yet: is the placed wall's mask ending at a room corner with another wall beyond it?
            val aMask = worldMask.lastWall
            if (side == null && quadToWorld != null && aMask != null && gen == placementGen) {
                val gw = WallSegmenter.GW; val gh = WallSegmenter.GH
                val model = BooleanArray(gw * gh) { k ->
                    val mx = (k % gw) * WallSegmenter.MASK_W / gw; val my = (k / gw) * WallSegmenter.MASK_H / gh
                    (result.wall[my * WallSegmenter.MASK_W + mx].toInt() and 0xFF) > 127
                }
                val p0 = floatArrayOf(quadToWorld[12], quadToWorld[13], quadToWorld[14])
                val n0 = floatArrayOf(quadToWorld[4], 0f, quadToWorld[6])
                WallCorner.find(aMask, model, gw, gh, camProj, camView, p0, n0)?.let { c ->
                    mainHandler.post { onCornerCandidate(view, c, gen) }
                }
            }
            // A guessed-distance placement faces the camera at 2 m. Once the wall's own edge with the floor or
            // ceiling is visible, re-place it at the wall's real angle and distance.
            val wallMask = worldMask.lastWall
            if (guessed && wallMask != null) {
                val est = WallEdges.estimate(
                    wallMask, WallSegmenter.GW, WallSegmenter.GH, result.classes, WallSegmenter.OUT_W, WallSegmenter.OUT_H,
                    camProj, camView, floorY,
                )
                if (est != null) mainHandler.post {
                    if (sceneView !== view || placedAnchorNode !== placedAt) return@post
                    val surface = when {
                        est.edge == "floor" && floorY != null -> "edge_floor_tracked"
                        est.edge == "floor" -> "edge_floor_assumed"
                        else -> "edge_ceiling"
                    }
                    if (surface == placedSurface) return@post
                    // Two consecutive estimates must agree before the wall moves, so it never jumps on one frame.
                    val now = android.os.SystemClock.elapsedRealtime()
                    val prev = lastEdgeEstimate
                    lastEdgeEstimate = est to now
                    if (prev == null || now - prev.second > EDGE_AGREE_WINDOW_MS || !WallEdges.agree(prev.first, est)) {
                        Log.i(TAG, "WALL_EDGE candidate from ${est.edge} line (dist=${"%.2f".format(est.distanceM)}m), waiting for agreement")
                        return@post
                    }
                    Log.i(TAG, "WALL_EDGE accepted: $placedSurface -> $surface (${Placement.provenance(surface)}, " +
                        "${Placement.scale(surface)}) dist=${"%.2f".format(est.distanceM)}m " +
                        "n=(${"%.2f".format(est.normal[0])},${"%.2f".format(est.normal[2])})")
                    anchorWall(view, est.base, est.normal, onFloor = true, surface = surface, dist = est.distanceM)
                    onWallStateChanged?.invoke(if (Placement.scale(surface) == Placement.Scale.APPROXIMATE) "APPROXIMATE" else "LOCKED")
                }
            }
        }
    }

    // ── A4 reference sheet (A4Reference) ──────────────────────────────

    private val a4 = A4Reference()
    private val a4Worker = java.util.concurrent.Executors.newSingleThreadExecutor()
    @Volatile private var a4Busy = false
    private var lastA4Ms = 0L
    private var wallLeftTicks = 0
    private var lastA4: Pair<A4Reference.Measure, Long>? = null
    @Volatile private var lastA4ScanLogMs = 0L

    /**
     * Looks for an A4 sheet on the wall a few times a second (slower when hot). Two agreeing sightings anchor
     * the wall at the sheet's measured distance and angle; after that every sighting is only logged (A4_MEASURE)
     * next to the anchor's own distance, so a walk-back test shows both.
     */
    private fun detectA4(view: ARSceneView, frame: com.google.ar.core.Frame) {
        if (a4Busy || pendingTexture == null || frame.camera.trackingState != TrackingState.TRACKING) return
        // ~30-60 ms on one core: cheap next to segmentation, and it is the only metric source on a plain wall,
        // so it keeps running (slower) even when segmentation is paused for heat.
        val interval = when {
            thermalStatus >= 4 -> 1500L
            thermalStatus >= 3 -> 800L
            else -> A4_INTERVAL_MS
        }
        val now = android.os.SystemClock.elapsedRealtime()
        if (now - lastA4Ms < interval) return
        lastA4Ms = now
        val image = try { frame.acquireCameraImage() } catch (e: Exception) { return }
        val w: Int; val h: Int; val stride: Int; val bytes: ByteArray
        try {
            w = image.width; h = image.height
            val plane = image.planes[0]
            stride = plane.rowStride
            bytes = ByteArray(plane.buffer.remaining()).also { plane.buffer.get(it) }
        } finally {
            image.close()
        }
        val intr = frame.camera.imageIntrinsics
        val fl = intr.focalLength; val pp = intr.principalPoint
        val camPose = frame.camera.pose
        // View-normalized (0,0), (1,0), (0,1) in image px: maps found corners back to the screen for A4_VIEW logs.
        val v2i = FloatArray(6).also { frame.transformCoordinates2d(Coordinates2d.VIEW_NORMALIZED, floatArrayOf(0f, 0f, 1f, 0f, 0f, 1f), Coordinates2d.IMAGE_PIXELS, it) }
        val vw = view.width; val vh = view.height
        val projDbg = FloatArray(16).also { frame.camera.getProjectionMatrix(it, 0, 0.05f, 100f) }
        a4Busy = true
        a4Worker.execute {
            try {
                val t0 = android.os.SystemClock.elapsedRealtime()
                val corners = a4.find(bytes, w, h, stride)
                val m = corners?.let { A4Reference.measure(it, fl[0], fl[1], pp[0], pp[1]) }
                val ms = android.os.SystemClock.elapsedRealtime() - t0
                if (corners != null && m == null) Log.i(TAG, "A4 rejected: bright quad is not A4-shaped (${ms}ms)")
                if (corners == null && t0 - lastA4ScanLogMs > 3000L) {
                    lastA4ScanLogMs = t0
                    Log.i(TAG, "A4_SCAN ${a4.lastReport} ${ms}ms")
                }
                if (m != null && corners != null) {
                    // image px -> view px through the inverse of the captured affine map.
                    val ox = v2i[0]; val oy = v2i[1]; val ax = v2i[2] - ox; val ay = v2i[3] - oy; val bx = v2i[4] - ox; val by = v2i[5] - oy
                    val det = ax * by - ay * bx
                    val vpts = (0 until 4).joinToString(" ") { k ->
                        val dx = corners[2 * k] - ox; val dy = corners[2 * k + 1] - oy
                        val u = (dx * by - dy * bx) / det; val v = (ax * dy - ay * dx) / det
                        "(${(u * vw).toInt()},${(v * vh).toInt()})"
                    }
                    Log.i(TAG, "A4_VIEW corners=$vpts view=${vw}x$vh proj0=${"%.4f".format(projDbg[0])} proj5=${"%.4f".format(projDbg[5])} " +
                        "proj8=${"%.4f".format(projDbg[8])} proj9=${"%.4f".format(projDbg[9])} fx=${"%.1f".format(fl[0])} fy=${"%.1f".format(fl[1])} " +
                        "img=${w}x$h v2i=${v2i.joinToString(",") { "%.1f".format(it) }}")
                }
                if (m != null) mainHandler.post { onA4(view, m, camPose, ms) }
            } catch (e: Exception) {
                Log.w(TAG, "A4 detection failed", e)
            } finally {
                a4Busy = false
            }
        }
    }

    private fun onA4(view: ARSceneView, m: A4Reference.Measure, camPose: Pose, ms: Long) {
        if (sceneView !== view) return
        val n = camPose.rotateVector(m.normal)
        val c = camPose.transformPoint(m.centre)
        val anchorDist = anchorDistance(view)
        Log.i(TAG, "A4_MEASURE dist=${"%.3f".format(m.distanceM)}m fromWidth=${"%.3f".format(m.distShortM)}m " +
            "fromHeight=${"%.3f".format(m.distLongM)}m ratio=${"%.3f".format(m.ratio)} cos=${"%.3f".format(m.cosAngle)} " +
            "nY=${"%.2f".format(n[1])} anchorDist=${anchorDist?.let { "%.3f".format(it) }}m planeDist=${planeDistance(view)?.let { "%.3f".format(it) }}m " +
            "surface=$placedSurface ${ms}ms")
        // A sheet on a wall faces sideways; one on a table or the ceiling does not anchor a wall.
        if (abs(n[1]) > 0.3f) return
        // Already measured from the sheet, or sized by the user on purpose: log only, never move it.
        if (placedAnchorNode != null && placedSurface in setOf("a4_reference", "user_rectangle", "user_calibrated")) return
        val now = android.os.SystemClock.elapsedRealtime()
        val prev = lastA4
        lastA4 = m to now
        if (prev == null || now - prev.second > 1500L || abs(prev.first.distanceM - m.distanceM) > 0.04f * m.distanceM) return
        val floorY = floorHeight(view)
        val base = if (floorY != null) floatArrayOf(c[0], floorY, c[2]) else c
        anchorWall(view, base, floatArrayOf(n[0], 0f, n[2]), onFloor = floorY != null, surface = "a4_reference", dist = m.distanceM,
            refCentreY = c[1], refSizeM = A4Reference.LONG_M)
        onWallStateChanged?.invoke("LOCKED")
    }

    /** Perpendicular camera distance to the nearest tracked ARCore vertical plane: a third, independent reading. */
    private fun planeDistance(view: ARSceneView): Float? {
        val cam = view.frame?.camera?.pose ?: return null
        return view.session?.getAllTrackables(Plane::class.java).orEmpty()
            .filter { it.trackingState == TrackingState.TRACKING && it.subsumedBy == null && it.type == Plane.Type.VERTICAL }
            .minOfOrNull {
                val n = it.centerPose.getTransformedAxis(1, 1f); val p = it.centerPose.translation
                abs((cam.tx() - p[0]) * n[0] + (cam.ty() - p[1]) * n[1] + (cam.tz() - p[2]) * n[2])
            }
    }

    /** Perpendicular distance from the camera to the placed wall right now, or null when nothing is placed. */
    private fun anchorDistance(view: ARSceneView): Float? {
        val pose = placedAnchorNode?.anchor?.pose ?: return null
        val cam = view.frame?.camera?.pose ?: return null
        val n = pose.getTransformedAxis(1, 1f); val p = pose.translation
        return abs((cam.tx() - p[0]) * n[0] + (cam.ty() - p[1]) * n[1] + (cam.tz() - p[2]) * n[2])
    }

    private var maskViewProj = FloatArray(16).also { Matrix.setIdentityM(it, 0) }

    /**
     * Uploads the wall mask with the camera matrix it was captured under and turns clipping on. No blending
     * between masks: they come from different camera poses, and the reprojection already keeps them stable.
     */
    private fun applyMask(view: ARSceneView, mask: ByteArray, vp: FloatArray, quadMask: ByteArray?) {
        if (sceneView !== view || lifecycleOwner.registry.currentState == Lifecycle.State.DESTROYED) return
        latestMask = mask
        maskViewProj = vp
        maskReady = true
        if (quadMask != null) uploadQuadMask(view, quadMask)
        val now = android.os.SystemClock.elapsedRealtime()
        if (now - lastSegLogMs > 5000) {
            lastSegLogMs = now
            val wall = mask.count { (it.toInt() and 0xFF) > 127 } * 100 / mask.size
            Log.i(TAG, "SEG wall=$wall% top=[${segmenter?.lastTopClasses}] backend=${segmenter?.backend} run=${segmenter?.lastRunMs}ms total=${segmenter?.lastInferenceMs}ms " +
                "quadCoverage=${"%.2f".format(worldMask.lastCoverage)} useMask=${maskWanted()}")
        }
    }

    private fun uploadQuadMask(view: ARSceneView, quadMask: ByteArray) {
        if (placedAnchorNode == null || !worldMask.hasData) return
        val tex = maskTexture ?: Texture.Builder().width(WallMaskAccumulator.W).height(WallMaskAccumulator.H)
            .sampler(Texture.Sampler.SAMPLER_2D).format(Texture.InternalFormat.RG8).levels(1).build(view.engine)
            .also { maskTexture = it }
        val buf = java.nio.ByteBuffer.allocateDirect(quadMask.size).put(quadMask).also { it.flip() }
        tex.setImage(view.engine, 0, Texture.PixelBufferDescriptor(buf, Texture.Format.RG, Texture.Type.UBYTE))
        pendingTexture?.let { bindMask(it) }
        // Mask confidence changed: switch between the full masked wall and the plain panel.
        if (maskWanted() != placedBig) rebuildPlacedQuad(view)
    }

    /**
     * Erase / Restore brush: paints the stone off (or back on) the placed wall around a screen point, for the
     * edges the automatic cut gets wrong (a low-contrast board, a shelf the same colour as the wall).
     */
    fun editMask(screenX: Float, screenY: Float, erase: Boolean): Boolean {
        val view = sceneView ?: return false
        val frame = view.frame ?: return false
        val anchor = placedAnchorNode?.anchor?.takeIf { it.trackingState == TrackingState.TRACKING } ?: return false
        val proj = FloatArray(16); val viewM = FloatArray(16)
        frame.camera.getProjectionMatrix(proj, 0, 0.05f, 100f)
        frame.camera.getViewMatrix(viewM, 0)
        val dir = WallEdges.ray(screenX, screenY, view.width, view.height, proj, viewM)
        val cam = WallEdges.cameraPosition(viewM)
        val pose = anchor.pose
        val n = pose.getTransformedAxis(1, 1f); val p0 = pose.translation
        val den = n[0] * dir[0] + n[1] * dir[1] + n[2] * dir[2]
        if (kotlin.math.abs(den) < 1e-4f) return false
        val t = (n[0] * (p0[0] - cam[0]) + n[1] * (p0[1] - cam[1]) + n[2] * (p0[2] - cam[2])) / den
        if (t <= 0f) return false
        val local = pose.inverse().transformPoint(floatArrayOf(cam[0] + t * dir[0], cam[1] + t * dir[1], cam[2] + t * dir[2]))
        // Brush = BRUSH_SCREEN_FRACTION of the screen width, in metres at this distance (focal px = P0 * width / 2).
        val radiusM = BRUSH_SCREEN_FRACTION * t / (proj[0] / 2f)
        worldMask.paint(local[0], local[2], radiusM, erase, MASKED_WALL_WIDTH_M, MASKED_WALL_HEIGHT_M, maskZMin())
        uploadQuadMask(view, worldMask.toBytes())
        return true
    }

    private fun bindMask(mi: MaterialInstance) {
        val tex = maskTexture ?: return
        if (!mi.material.hasParameter("maskMap")) return
        mi.setParameter("maskMap", tex, com.google.android.filament.TextureSampler(
            com.google.android.filament.TextureSampler.MinFilter.LINEAR,
            com.google.android.filament.TextureSampler.MagFilter.LINEAR,
            com.google.android.filament.TextureSampler.WrapMode.CLAMP_TO_EDGE,
        ))
        // When the segmenter barely sees any wall where ARCore put the design (peeling paint, odd textures,
        // bad light), clipping would erase the stone entirely; showing it unclipped is the better failure.
        mi.setParameter("useMask", if (maskWanted()) 1f else 0f)
    }

    /** User switch for the AI wall clipping (Live AR settings sheet). The segmenter keeps running either way. */
    @Volatile var wallClippingEnabled = true
        set(value) {
            field = value
            mainHandler.post { pendingTexture?.let { if (it.material.hasParameter("useMask")) bindMask(it) } }
        }

    // Hysteresis: the mask switches on above MIN_MASK_COVERAGE and only off again well below it, otherwise a
    // coverage hovering at the threshold flips the quad between panel and full wall every mask.
    private fun maskWanted(): Boolean {
        if (!wallClippingEnabled || !worldMask.hasData) return false
        if (worldMask.userEdited) return true // the user shaped the mask by hand: always show it
        val threshold = if (placedBig) MIN_MASK_COVERAGE / 3f else MIN_MASK_COVERAGE
        return worldMask.lastCoverage >= threshold
    }

    private val worldMask = WallMaskAccumulator()

    /** The second wall of a room corner ([WallCorner]): own anchor, quad, mask and material instance. */
    private class SideWall(val node: AnchorNode, val corner: WallCorner.Corner, onFloor: Boolean) {
        val mask = WallMaskAccumulator()
        val zMin = if (onFloor) 0f else -MASKED_WALL_HEIGHT_M / 2f
        var maskTex: Texture? = null
        var mi: MaterialInstance? = null
        var quad: Node? = null
        var shown: Boolean? = null
    }
    private var sideWall: SideWall? = null
    private var lastCorner: Pair<WallCorner.Corner, Long>? = null

    /** Two agreeing corner sightings (same side, within 10 cm) add the second wall; one frame never does. */
    private fun onCornerCandidate(view: ARSceneView, c: WallCorner.Corner, gen: Int) {
        if (sceneView !== view || gen != placementGen || sideWall != null) return
        val anchorNode = placedAnchorNode ?: return
        val now = android.os.SystemClock.elapsedRealtime()
        val prev = lastCorner
        lastCorner = c to now
        if (prev == null || now - prev.second > EDGE_AGREE_WINDOW_MS || prev.first.keepA != c.keepA ||
            kotlin.math.abs(prev.first.cornerX - c.cornerX) > 0.10f) {
            Log.i(TAG, "CORNER candidate at x=${"%.2f".format(c.cornerX)}m, waiting for agreement")
            return
        }
        val session = view.session ?: return
        if (anchorNode.anchor.trackingState != TrackingState.TRACKING) return
        if (cornerContradicted(view, c)) return
        val anchor = runCatching { session.createAnchor(uprightWallPose(c.point, c.normal)) }.getOrNull() ?: return
        val node = AnchorNode(engine = view.engine, anchor = anchor)
        view.addChildNode(node)
        val side = SideWall(node, c, placedOnFloor)
        sideWall = side
        rebuildSideQuad(view, side)
        lastSegRequestMs = 0L // outline the new wall on the next frame
        Log.i(TAG, "CORNER second wall added: corner x=${"%.2f".format(c.cornerX)}m keepA=${c.keepA} " +
            "n=(${"%.2f".format(c.normal[0])},${"%.2f".format(c.normal[2])}) seed=(${"%.2f".format(c.seedX)},${"%.2f".format(c.seedZ)})")
    }

    /**
     * An open doorway or a passage looks like a corner to the masks (the model calls a dark doorway "wall", and
     * its frame is a vertical line), but what is seen through it lies well behind the would-be second wall.
     * ARCore feature points in front of / on that plane confirm nothing (plain paint has none); several clearly
     * behind it reject the corner.
     */
    private fun cornerContradicted(view: ARSceneView, c: WallCorner.Corner): Boolean {
        val frame = view.frame ?: return false
        val cam = frame.camera.pose.translation
        val n = c.normal; val ub = floatArrayOf(-n[2], 0f, n[0])
        var behind = 0; var on = 0
        runCatching {
            frame.acquirePointCloud().use { pc ->
                val b = pc.points
                while (b.remaining() >= 4) {
                    val x = b.get(); val y = b.get(); val z = b.get(); val conf = b.get()
                    if (conf < 0.3f) continue
                    val d = floatArrayOf(x - cam[0], y - cam[1], z - cam[2])
                    val den = d[0] * n[0] + d[2] * n[2]
                    if (kotlin.math.abs(den) < 1e-4f) continue
                    // Fraction of the way to the point where its ray crosses the second wall's plane.
                    val f = ((c.point[0] - cam[0]) * n[0] + (c.point[2] - cam[2]) * n[2]) / den
                    if (f <= 0f) continue
                    val lx = (cam[0] + f * d[0] - c.point[0]) * ub[0] + (cam[2] + f * d[2] - c.point[2]) * ub[2]
                    if (lx * c.keepB !in 0f..MASKED_WALL_WIDTH_M / 2f) continue // not seen through that wall
                    val gap = (1f - f) * kotlin.math.sqrt(d[0] * d[0] + d[1] * d[1] + d[2] * d[2]) // metres beyond the plane
                    if (gap > 0.3f) behind++ else if (gap > -0.15f) on++
                }
            }
        }
        val rejected = behind >= 5 && behind > on
        if (rejected) Log.i(TAG, "CORNER rejected: $behind feature points behind the second wall (on it: $on), a doorway or passage")
        return rejected
    }

    /** The second wall gets a copy of the stone material (it needs its own wall->quad matrix and mask). */
    private fun rebuildSideQuad(view: ARSceneView, side: SideWall) {
        side.quad?.let { side.node.removeChildNode(it); it.destroy() }
        side.quad = null
        val src = pendingTexture?.takeIf { it.material.hasParameter("useMask") } ?: return
        val mi = MaterialInstance.duplicate(src, "side_wall")
        side.mi = mi
        side.maskTex?.let { bindSideMask(mi, it) }
        val patchH = texturePatchHeightM
        val quad = wallQuad(view, MASKED_WALL_WIDTH_M, MASKED_WALL_HEIGHT_M, patchH * textureAspect, patchH, mi, side.zMin == 0f)
        side.node.addChildNode(quad)
        side.quad = quad
        side.shown = null
    }

    private fun uploadSideMask(view: ARSceneView, side: SideWall, bytes: ByteArray) {
        val tex = side.maskTex ?: Texture.Builder().width(WallMaskAccumulator.W).height(WallMaskAccumulator.H)
            .sampler(Texture.Sampler.SAMPLER_2D).format(Texture.InternalFormat.RG8).levels(1).build(view.engine)
            .also { side.maskTex = it }
        val buf = java.nio.ByteBuffer.allocateDirect(bytes.size).put(bytes).also { it.flip() }
        tex.setImage(view.engine, 0, Texture.PixelBufferDescriptor(buf, Texture.Format.RG, Texture.Type.UBYTE))
        side.mi?.let { bindSideMask(it, tex) }
    }

    /** The second wall is always clipped: unclipped, its 8 m quad would cover the first wall and the room. */
    private fun bindSideMask(mi: MaterialInstance, tex: Texture) {
        mi.setParameter("maskMap", tex, com.google.android.filament.TextureSampler(
            com.google.android.filament.TextureSampler.MinFilter.LINEAR,
            com.google.android.filament.TextureSampler.MagFilter.LINEAR,
            com.google.android.filament.TextureSampler.WrapMode.CLAMP_TO_EDGE,
        ))
        mi.setParameter("useMask", 1f)
    }

    private fun sideReady(side: SideWall): Boolean =
        wallClippingEnabled && side.mask.hasData && side.mask.lastCoverage >= MIN_MASK_COVERAGE / 3f

    private fun clearSideWall() {
        val side = sideWall ?: return
        sideWall = null
        lastCorner = null
        sceneView?.removeChildNode(side.node)
        runCatching { side.node.anchor.detach() }
        side.node.destroy()
    }

    private fun quadZMin(): Float = if (placedOnFloor) 0f else -placedHeightM / 2f
    /** Bottom of the mask's region in quad space (the mask spans MASKED_WALL_HEIGHT_M, not the drawn quad). */
    private fun maskZMin(): Float = if (placedOnFloor) 0f else -MASKED_WALL_HEIGHT_M / 2f

    /** Keeps the material's world -> quad transform in step with the anchor (ARCore refines it every frame). */
    private fun updateQuadTransform() {
        val mi = pendingTexture ?: return
        val anchor = placedAnchorNode?.anchor ?: return
        quadTransform(mi, anchor, maskZMin())
    }

    private fun quadTransform(mi: MaterialInstance, anchor: Anchor, zMin: Float) {
        if (!mi.material.hasParameter("worldToQuad")) return
        val m = FloatArray(16).also { anchor.pose.toMatrix(it, 0) }
        val inv = FloatArray(16)
        if (!Matrix.invertM(inv, 0, m, 0)) return
        mi.setParameter("worldToQuad", MaterialInstance.FloatElement.MAT4, inv, 0, 1)
        mi.setParameter("quadSize", MASKED_WALL_WIDTH_M, MASKED_WALL_HEIGHT_M, zMin, 0f)
    }

    /** View-space wall probability (0..1) at a screen pixel, or null before the first mask. */
    private fun wallAt(view: ARSceneView, x: Float, y: Float): Float? {
        val m = latestMask ?: return null
        val cx = (x / view.width * WallSegmenter.MASK_W).toInt().coerceIn(0, WallSegmenter.MASK_W - 1)
        val cy = (y / view.height * WallSegmenter.MASK_H).toInt().coerceIn(0, WallSegmenter.MASK_H - 1)
        return (m[cy * WallSegmenter.MASK_W + cx].toInt() and 0xFF) / 255f
    }

    /** The confident wall cell closest to the upper-middle of the screen, in view pixels. */
    private fun wallProbePoint(view: ARSceneView): Pair<Float, Float>? {
        val m = latestMask ?: return null
        val tx = WallSegmenter.MASK_W / 2f; val ty = WallSegmenter.MASK_H * 0.4f
        var best = -1; var bestD = Float.MAX_VALUE
        for (y in 0 until WallSegmenter.MASK_H) for (x in 0 until WallSegmenter.MASK_W) {
            if ((m[y * WallSegmenter.MASK_W + x].toInt() and 0xFF) < 200) continue
            val d = (x - tx) * (x - tx) + (y - ty) * (y - ty)
            if (d < bestD) { bestD = d; best = y * WallSegmenter.MASK_W + x }
        }
        if (best < 0) return null
        return ((best % WallSegmenter.MASK_W + 0.5f) / WallSegmenter.MASK_W * view.width) to
            ((best / WallSegmenter.MASK_W + 0.5f) / WallSegmenter.MASK_H * view.height)
    }

    /** Does the placed design's quad lie under this screen pixel? */
    /** Turning from the placed wall to the corner's second wall is not "the wall moved": keep both. */
    private fun sideWallCovers(view: ARSceneView, frame: com.google.ar.core.Frame, sx: Float, sy: Float): Boolean {
        val side = sideWall ?: return false
        val anchor = side.node.anchor.takeIf { it.trackingState == TrackingState.TRACKING } ?: return false
        val pose = anchor.pose
        val (o, d) = tapRay(view, frame, sx, sy) ?: return false
        val n = pose.getTransformedAxis(1, 1f); val c = pose.translation
        val denom = d[0] * n[0] + d[1] * n[1] + d[2] * n[2]
        if (kotlin.math.abs(denom) < WALL_TURN_COS) return false
        val t = ((c[0] - o[0]) * n[0] + (c[1] - o[1]) * n[1] + (c[2] - o[2]) * n[2]) / denom
        if (t <= 0f) return false
        val local = pose.inverse().transformPoint(floatArrayOf(o[0] + t * d[0], o[1] + t * d[1], o[2] + t * d[2]))
        return local[0] * side.corner.keepB in 0f..MASKED_WALL_WIDTH_M / 2f &&
            local[2] in side.zMin..(side.zMin + MASKED_WALL_HEIGHT_M)
    }

    private fun placedQuadCovers(view: ARSceneView, frame: com.google.ar.core.Frame, sx: Float, sy: Float): Boolean {
        val anchor = placedAnchorNode?.anchor ?: return false
        if (anchor.trackingState != TrackingState.TRACKING) return false
        val pose = anchor.pose
        val (o, d) = tapRay(view, frame, sx, sy) ?: return true
        val n = pose.getTransformedAxis(1, 1f)
        val c = pose.translation
        val denom = d[0] * n[0] + d[1] * n[1] + d[2] * n[2]
        // Seen this edge-on, the placed wall is not what the user is looking at: turning to the next wall at a
        // corner still hits the old wall's (8 m wide) plane, so "inside the quad" alone kept the design stuck there.
        if (kotlin.math.abs(denom) < WALL_TURN_COS) return false
        val t = ((c[0] - o[0]) * n[0] + (c[1] - o[1]) * n[1] + (c[2] - o[2]) * n[2]) / denom
        if (t <= 0f) return false
        val local = pose.inverse().transformPoint(floatArrayOf(o[0] + t * d[0], o[1] + t * d[1], o[2] + t * d[2]))
        val zMin = if (placedOnFloor) 0f else -placedHeightM / 2f
        return kotlin.math.abs(local[0]) <= placedWidthM / 2f && local[2] in zMin..(zMin + placedHeightM)
    }

    private fun fillConfig(session: Session, config: Config) {
        config.planeFindingMode = Config.PlaneFindingMode.HORIZONTAL_AND_VERTICAL
        config.updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
        config.focusMode = Config.FocusMode.AUTO
        // Depth stays on only while DepthValidator has not ruled it out; its hits are gated separately.
        val depthAllowed = !depthForcedOff && (depthMeasureMode ||
            (depthValidator.state != DepthValidator.State.REJECTED && depthValidator.state != DepthValidator.State.UNAVAILABLE))
        config.depthMode = if (depthAllowed && session.isDepthModeSupported(Config.DepthMode.AUTOMATIC))
            Config.DepthMode.AUTOMATIC else Config.DepthMode.DISABLED
        // Off: the approximate placement computes its own pose on the tap ray, and the performance guide asks to
        // keep Instant Placement disabled once tracking runs.
        config.instantPlacementMode = Config.InstantPlacementMode.DISABLED
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
        runCatching {
            val all = session.getSupportedCameraConfigs(com.google.ar.core.CameraConfigFilter(session))
            Log.i(TAG, "CAMERA_CONFIGS current=${session.cameraConfig.textureSize}/${session.cameraConfig.imageSize} " +
                "supported=${all.joinToString { "${it.textureSize.width}x${it.textureSize.height}/${it.imageSize.width}x${it.imageSize.height}@${it.fpsRange}" }}")
        }
    }

    fun detachSceneView(view: ARSceneView) {
        if (sceneView === view) {
            sceneView = null
            forgetEngineObjects()
        }
    }

    // ── Session control ─────────────────────────────────────────────────

    // Wall-detection latency, logged as `WALL_TIMING` so it can be read from logcat on a real phone.
    private var sessionStartedAtMs = 0L
    private var firstWallLogged = false

    /**
     * The manager is a process singleton but destroy() runs when an AR screen's engine detaches. A destroyed
     * LifecycleRegistry can never be RESUMED again ("State is 'DESTROYED' and cannot be moved to RESUMED"), and
     * startSession can arrive before the next view attaches (opening the AR tab after the product AR page).
     */
    private fun reviveLifecycleIfDestroyed() {
        if (lifecycleOwner.registry.currentState == Lifecycle.State.DESTROYED) {
            lifecycleOwner = ManagerLifecycleOwner()
            configuredSession = null
            sceneView?.lifecycle = lifecycleOwner.lifecycle
        }
    }

    fun startSession() {
        sessionStartedAtMs = android.os.SystemClock.elapsedRealtime()
        firstWallLogged = false
        reviveLifecycleIfDestroyed()
        lifecycleOwner.registry.currentState = Lifecycle.State.RESUMED
    }

    fun pauseSession() {
        if (lifecycleOwner.registry.currentState == Lifecycle.State.DESTROYED) return
        lifecycleOwner.registry.currentState = Lifecycle.State.STARTED
    }

    fun resumeSession() {
        reviveLifecycleIfDestroyed()
        lifecycleOwner.registry.currentState = Lifecycle.State.RESUMED
    }

    fun destroy() {
        // INITIALIZED -> DESTROYED is an illegal transition; if AR never started
        // there is nothing to tear down and moving the state crashes the Activity.
        if (lifecycleOwner.registry.currentState == Lifecycle.State.INITIALIZED) return
        // Segmentation results still in flight post applyMask after this; with sceneView cleared they drop
        // out instead of writing into the destroyed engine ("Calling method on destroyed Engine" crash).
        sceneView = null
        forgetEngineObjects()
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
                // Each rebuild creates an anchor; refresh the growing wall at most ~2x a second, not every frame.
                val now = android.os.SystemClock.elapsedRealtime()
                if (existingId == selectedWallId && now - lastWallVizMs > 500) {
                    lastWallVizMs = now
                    updateWallVisualization()
                }
            }
        }
    }

    private fun mapTrackingFailure(reason: TrackingFailureReason?): String = when (reason) {
        TrackingFailureReason.EXCESSIVE_MOTION -> "LIMITED_EXCESSIVE_MOTION"
        TrackingFailureReason.INSUFFICIENT_FEATURES -> "LIMITED_INSUFFICIENT_FEATURES"
        TrackingFailureReason.INSUFFICIENT_LIGHT -> "LIMITED_INSUFFICIENT_LIGHT"
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

    // Dart sends the design before the AR view exists; keep it and apply it on attach instead of dropping it.
    private var queuedTexture: Triple<ByteArray, Float?, Boolean>? = null

    fun setTexture(imageData: ByteArray, patchHeightM: Float? = null, seamCut: Boolean = false) {
        queuedTexture = Triple(imageData, patchHeightM, seamCut)
        val view = sceneView ?: return
        try {
            val raw = BitmapFactory.decodeByteArray(imageData, 0, imageData.size) ?: return
            // Catalogue photos have a light border/vignette that tiles into a grid of seams; trim 8% per side.
            val trimmed = android.graphics.Bitmap.createBitmap(
                raw, raw.width * 8 / 100, raw.height * 8 / 100, raw.width * 84 / 100, raw.height * 84 / 100,
            )
            // Natural cultured stone: cut seamless along the mortar lines (the repeat edge disappears). Designed
            // patterns (chevrons, stripes, medallions) are left as photographed; the cut breaks their geometry.
            val bitmap = if (seamCut) SeamlessTile.make(trimmed) else trimmed
            Log.i(TAG, "TEXTURE ${raw.width}x${raw.height} seamCut=$seamCut")
            val texture = Texture.Builder()
                .width(bitmap.width)
                .height(bitmap.height)
                .sampler(Texture.Sampler.SAMPLER_2D)
                .format(Texture.InternalFormat.SRGB8_A8) // photo pixels are sRGB; RGBA8 rendered washed out
                .levels(0xFF)
                .build(view.engine)
            TextureHelper.setBitmap(view.engine, texture, 0, bitmap)
            texture.generateMipmaps(view.engine)
            // Plain REPEAT: the trimmed photo tiles cleanly; MIRRORED_REPEAT read as a kaleidoscope.
            val sampler = com.google.android.filament.TextureSampler(
                com.google.android.filament.TextureSampler.MinFilter.LINEAR_MIPMAP_LINEAR,
                com.google.android.filament.TextureSampler.MagFilter.LINEAR,
                com.google.android.filament.TextureSampler.WrapMode.REPEAT,
            ).apply { anisotropy = 8f } // keeps the stone sharp when the wall is seen at an angle
            // Lit PBR stone with a relief normal map, so the room light rakes across the stones like real cladding.
            // Falls back to the flat unlit image material if the ubershader is unavailable.
            texturePatchHeightM = patchHeightM ?: TEXTURE_PATCH_HEIGHT_M
            val (normal, height) = reliefTextures(view, bitmap)
            // `adb shell setprop debug.grazia.material masked|lit|unlit` forces one material for on-device A/B.
            val wanted = debugProp("debug.grazia.material") ?: "masked"
            pendingTexture = (if (wanted == "masked") runCatching { maskedStoneMaterial(view, texture, normal, height, sampler) }
                .onFailure { Log.w(TAG, "masked wall material failed, using lit stone", it) }
                .getOrNull() else null)
                ?: (if (wanted != "unlit") runCatching { litStoneMaterial(view, texture, normal, sampler) }
                .onFailure { Log.w(TAG, "lit stone material failed, using unlit", it) }
                .getOrNull() else null)
                ?: view.materialLoader.createImageInstance(texture, sampler).twoSided().also { Log.i(TAG, "TEXTURE unlit material") }
            textureAspect = bitmap.width.toFloat() / bitmap.height.coerceAtLeast(1)
            texturePatchHeightM = patchHeightM ?: TEXTURE_PATCH_HEIGHT_M
            updateWallVisualization()
            // Changing the stone keeps the accumulated wall outline: bind the existing mask to the new material now
            // instead of waiting up to a second for the next segmenter result.
            pendingTexture?.let { if (worldMask.hasData && it.material.hasParameter("useMask")) bindMask(it) }
            sideWall?.let { rebuildSideQuad(view, it) }
        } catch (e: Exception) {
            Log.e(TAG, "setTexture failed", e)
            onError?.invoke("Failed to set texture: ${e.message}")
        }
    }

    private var ubershader: com.google.android.filament.gltfio.UbershaderProvider? = null
    private var wallMaskedMaterial: com.google.android.filament.Material? = null

    /** Lit, normal-mapped stone clipped to the segmenter's wall mask (assets/materials/wall_masked.filamat). */
    private fun maskedStoneMaterial(
        view: ARSceneView, base: Texture, normal: Texture, height: Texture, sampler: com.google.android.filament.TextureSampler,
    ): MaterialInstance {
        val material = wallMaskedMaterial
            ?: view.materialLoader.createMaterial("materials/wall_masked.filamat").also { wallMaskedMaterial = it }
        val mi = material.createInstance()
        mi.setParameter("baseColorMap", base, sampler)
        mi.setParameter("normalMap", normal, sampler)
        // The parallax-relief material (heightMap / heightScale) rendered as a flat brown moiré on the OnePlus
        // test phone and was dropped from wall_masked.mat; these stay guarded so an experimental build can add it back.
        if (material.hasParameter("heightMap")) mi.setParameter("heightMap", height, sampler)
        if (material.hasParameter("heightScale")) {
            mi.setParameter("heightScale", (STONE_RELIEF_M / texturePatchHeightM).coerceAtMost(MAX_RELIEF_UV))
        }
        Log.i(TAG, "TEXTURE patchHeightM=$texturePatchHeightM aspect=${"%.3f".format(textureAspect)}")
        val identity = FloatArray(16).also { Matrix.setIdentityM(it, 0) }
        mi.setParameter("worldToQuad", MaterialInstance.FloatElement.MAT4, identity, 0, 1)
        mi.setParameter("quadSize", 1f, 1f, 0f, 0f)
        mi.setParameter("emissiveLevel", EMISSIVE_LEVEL)
        mi.setParameter("useMask", 0f)
        // Until the first mask arrives, bind a 1x1 "all wall" texture so the sampler is never unbound.
        val placeholder = Texture.Builder().width(1).height(1).sampler(Texture.Sampler.SAMPLER_2D)
            .format(Texture.InternalFormat.R8).levels(1).build(view.engine)
        placeholder.setImage(view.engine, 0, Texture.PixelBufferDescriptor(
            java.nio.ByteBuffer.allocateDirect(1).put(0xFF.toByte()).also { it.flip() }, Texture.Format.R, Texture.Type.UBYTE,
        ))
        mi.setParameter("maskMap", placeholder, sampler)
        if (maskReady) bindMask(mi)
        Log.i(TAG, "TEXTURE masked wall material ready")
        return mi
    }

    private fun litStoneMaterial(
        view: ARSceneView, base: Texture, normal: Texture, sampler: com.google.android.filament.TextureSampler,
    ): MaterialInstance {
        val provider = ubershader ?: com.google.android.filament.gltfio.UbershaderProvider(view.engine).also { ubershader = it }
        val key = com.google.android.filament.gltfio.MaterialProvider.MaterialKey().apply {
            doubleSided = true
            hasBaseColorTexture = true
            hasNormalTexture = true
            hasEmissiveTexture = true
        }
        val uvmap = IntArray(8)
        key.constrainMaterial(uvmap)
        val mi = provider.createMaterialInstance(key, uvmap, "grazia_stone", null)
            ?: error("ubershader returned no instance")
        val material = mi.material
        val identity = floatArrayOf(1f, 0f, 0f, 0f, 1f, 0f, 0f, 0f, 1f)
        fun set(name: String, block: () -> Unit) { if (material.hasParameter(name)) block() }
        set("baseColorMap") { mi.setParameter("baseColorMap", base, sampler) }
        set("baseColorIndex") { mi.setParameter("baseColorIndex", 0) }
        set("baseColorUvMatrix") { mi.setParameter("baseColorUvMatrix", MaterialInstance.FloatElement.MAT3, identity, 0, 1) }
        set("baseColorFactor") { mi.setParameter("baseColorFactor", 1f, 1f, 1f, 1f) }
        set("normalMap") { mi.setParameter("normalMap", normal, sampler) }
        set("normalIndex") { mi.setParameter("normalIndex", 0) }
        set("normalUvMatrix") { mi.setParameter("normalUvMatrix", MaterialInstance.FloatElement.MAT3, identity, 0, 1) }
        set("normalScale") { mi.setParameter("normalScale", 1f) }
        // Part of the photo's own colour is emitted, so a dim room never renders the stone black; the lit part
        // on top adds the relief shading and follows the room's light.
        set("emissiveMap") { mi.setParameter("emissiveMap", base, sampler) }
        set("emissiveIndex") { mi.setParameter("emissiveIndex", 0) }
        set("emissiveUvMatrix") { mi.setParameter("emissiveUvMatrix", MaterialInstance.FloatElement.MAT3, identity, 0, 1) }
        set("emissiveFactor") { mi.setParameter("emissiveFactor", EMISSIVE_LEVEL, EMISSIVE_LEVEL, EMISSIVE_LEVEL) }
        set("emissiveStrength") { mi.setParameter("emissiveStrength", 1f) }
        set("metallicFactor") { mi.setParameter("metallicFactor", 0f) }
        set("roughnessFactor") { mi.setParameter("roughnessFactor", 0.85f) } // natural, unpolished stone
        Log.i(TAG, "TEXTURE lit stone material ready")
        return mi
    }

    /**
     * Height map + matching tangent-space normal map from the photo's brightness: in stacked-stone cladding the
     * dark joints are the recessed parts, so luminance is a usable height field. 512 px is plenty for relief.
     */
    private fun reliefTextures(view: ARSceneView, src: android.graphics.Bitmap): Pair<Texture, Texture> {
        val scale = 512f / maxOf(src.width, src.height)
        val bmp = if (scale < 1f) android.graphics.Bitmap.createScaledBitmap(
            src, (src.width * scale).toInt().coerceAtLeast(2), (src.height * scale).toInt().coerceAtLeast(2), true,
        ) else src
        val w = bmp.width
        val h = bmp.height
        val px = IntArray(w * h).also { bmp.getPixels(it, 0, w, 0, 0, w, h) }
        val lum = FloatArray(w * h) { i ->
            val c = px[i]
            (0.299f * ((c shr 16) and 0xFF) + 0.587f * ((c shr 8) and 0xFF) + 0.114f * (c and 0xFF)) / 255f
        }
        fun wrap(x: Int, y: Int) = ((y + h) % h) * w + (x + w) % w
        // Height: lightly blurred brightness, stretched 2nd..98th percentile so every design gets full relief.
        val blurred = FloatArray(w * h) { i ->
            val x = i % w; val y = i / w
            var sum = 0f
            for (dy in -1..1) for (dx in -1..1) sum += lum[wrap(x + dx, y + dy)]
            sum / 9f
        }
        val sorted = blurred.sortedArray()
        val lo = sorted[(sorted.size * 0.02f).toInt()]
        val hi = sorted[(sorted.size * 0.98f).toInt().coerceAtMost(sorted.size - 1)]
        val range = (hi - lo).coerceAtLeast(1e-3f)
        val height = FloatArray(w * h) { ((blurred[it] - lo) / range).coerceIn(0f, 1f) }

        // 4 made every joint a 70+ degree slope that caught the environment light as a wet sheen; 1.5 keeps the
        // joints readable as relief without the glossy rims.
        val strength = 1.5f
        val normalBuf = java.nio.ByteBuffer.allocateDirect(w * h * 4)
        val heightBuf = java.nio.ByteBuffer.allocateDirect(w * h)
        for (y in 0 until h) for (x in 0 until w) {
            val dx = (height[wrap(x + 1, y)] - height[wrap(x - 1, y)]) * strength
            val dy = (height[wrap(x, y + 1)] - height[wrap(x, y - 1)]) * strength
            val inv = 1f / sqrt(dx * dx + dy * dy + 1f)
            // Image rows run downward while texture V runs upward, hence +dy for the green channel.
            normalBuf.put(((-dx * inv * 0.5f + 0.5f) * 255f).toInt().toByte())
            normalBuf.put(((dy * inv * 0.5f + 0.5f) * 255f).toInt().toByte())
            normalBuf.put(((inv * 0.5f + 0.5f) * 255f).toInt().toByte())
            normalBuf.put(0xFF.toByte())
            heightBuf.put((height[y * w + x] * 255f).toInt().toByte())
        }
        normalBuf.flip(); heightBuf.flip()
        val normal = Texture.Builder().width(w).height(h).sampler(Texture.Sampler.SAMPLER_2D)
            .format(Texture.InternalFormat.RGBA8).levels(0xFF).build(view.engine)
        normal.setImage(view.engine, 0, Texture.PixelBufferDescriptor(normalBuf, Texture.Format.RGBA, Texture.Type.UBYTE))
        normal.generateMipmaps(view.engine)
        val heightTex = Texture.Builder().width(w).height(h).sampler(Texture.Sampler.SAMPLER_2D)
            .format(Texture.InternalFormat.R8).levels(0xFF).build(view.engine)
        heightTex.setImage(view.engine, 0, Texture.PixelBufferDescriptor(heightBuf, Texture.Format.R, Texture.Type.UBYTE))
        heightTex.generateMipmaps(view.engine)
        return normal to heightTex
    }

    fun clearTexture() {
        pendingTexture = null
        clearPlacedWall() // the placed quad keeps its old material instance otherwise
        worldMask.reset()
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

        // ARCore's vertical-plane centerPose is rolled arbitrarily inside the wall, which drew the overlay
        // tilted. Re-derive an upright pose and measure the detected polygon along its true horizontal/up axes.
        val cam = view.frame?.camera?.pose?.translation ?: return
        val c = plane.centerPose.translation
        val raw = plane.centerPose.getTransformedAxis(1, 1f)
        val n = horizontalNormal(raw[0], raw[2], c, cam)
        val right = floatArrayOf(-n[2], 0f, n[0])
        val poly = plane.polygon.duplicate().apply { rewind() }
        var minR = Float.MAX_VALUE; var maxR = -Float.MAX_VALUE; var minU = Float.MAX_VALUE; var maxU = -Float.MAX_VALUE
        while (poly.remaining() >= 2) {
            val w = plane.centerPose.transformPoint(floatArrayOf(poly.get(), 0f, poly.get()))
            val r = (w[0] - c[0]) * right[0] + (w[2] - c[2]) * right[2]
            val u = w[1] - c[1]
            minR = minOf(minR, r); maxR = maxOf(maxR, r); minU = minOf(minU, u); maxU = maxOf(maxU, u)
        }
        if (maxR <= minR || maxU <= minU) return
        val mid = floatArrayOf(
            c[0] + right[0] * (minR + maxR) / 2f, c[1] + (minU + maxU) / 2f, c[2] + right[2] * (minR + maxR) / 2f,
        )
        val anchor = plane.createAnchor(uprightWallPose(mid, n)) ?: return
        val anchorNode = AnchorNode(engine = view.engine, anchor = anchor)

        val material = pendingTexture
            ?: view.materialLoader.createColorInstance(android.graphics.Color.argb(128, 255, 215, 0)).twoSided()
        // The catalogue photos show a patch of finished wall (many stones), not a
        // single tile. Repeat that patch at a realistic physical size instead of
        // stretching one photo over the whole wall, which is what looked fake.
        val patchH = texturePatchHeightM
        val patchW = patchH * textureAspect
        anchorNode.addChildNode(wallQuad(view, maxR - minR, maxU - minU, patchW, patchH, material, onFloor = false))
        view.addChildNode(anchorNode)
        wallNode = anchorNode
    }

    // ── Tap-to-place wall ────────────────────────────────────────────────

    private fun materialForWall(view: ARSceneView): MaterialInstance =
        pendingTexture ?: view.materialLoader.createColorInstance(android.graphics.Color.argb(128, 255, 215, 0)).twoSided()

    /**
     * SceneView's PlaneNode lies in its local XY plane facing +Z (Size.z = 0), NOT in XZ. Our wall anchors
     * use ARCore's vertical-plane convention (Y = wall normal, Z = vertical), so rotate the quad 90° about
     * X so its height runs along Z (up). Before this the quad stuck out
     * of the wall edge-on, or lay flat like a ceiling, which is why placement "never worked".
     * [onFloor]: the anchor is the wall's bottom edge, so lift the quad by half its height.
     */
    private fun wallQuad(
        view: ARSceneView, w: Float, h: Float, patchW: Float, patchH: Float, material: MaterialInstance, onFloor: Boolean,
    ): Node = PlaneNode(
        engine = view.engine,
        size = Size(x = w, y = h),
        uvScale = Float2(w / patchW, h / patchH),
        materialInstance = material,
    ).apply {
        // 180° about (0,1,1): quad X -> -X, Y (texture up) -> +Z (up), Z (front face) -> +Y (wall normal, toward
        // the camera). The front face must face the viewer for lighting to work, and the -X keeps the photo
        // un-mirrored (viewer's right is anchor -X). A plain +90° about X showed the lit back face (near-black).
        quaternion = dev.romainguy.kotlin.math.Quaternion(0f, 0.70710677f, 0.70710677f, 0f)
        if (onFloor) position = Position(z = h / 2f)
    }

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
        // With the wall mask on, the quad only has to be big enough; the mask draws the true wall outline.
        // With a confident wall mask the quad only has to be big enough (the mask draws the wall outline).
        // Without one, a wall-sized panel is the honest rendering, not wallpaper over the whole room.
        val big = wallMaskedMaterial != null && maskWanted()
        placedBig = big
        placedWidthM = if (big) MASKED_WALL_WIDTH_M else PLACED_WALL_WIDTH_M
        placedHeightM = if (big) MASKED_WALL_HEIGHT_M else PLACED_WALL_HEIGHT_M
        Log.i(TAG, "QUAD ${placedWidthM}x${placedHeightM}m patch=${"%.2f".format(patchW)}x${"%.2f".format(patchH)}m " +
            "uvScale=${"%.1f".format(placedWidthM / patchW)}x${"%.1f".format(placedHeightM / patchH)} material=${if (pendingTexture != null) "stone" else "placeholder"}")
        val quad = wallQuad(view, placedWidthM, placedHeightM, patchW, patchH, materialForWall(view), placedOnFloor)
        node.addChildNode(quad)
        placedQuad = quad
        // SceneView pushes visibility only to existing children: apply it again for the new quad.
        (!userHidden && designReady()).let { node.isVisible = it; shownState = it }
    }

    /**
     * Places the selected design on the real surface under a screen tap. Every stage is logged under
     * `PLACE` so a failure can be pinned to one step: native entry, tracking, hit list, per-hit verdict.
     * Only real ARCore hits are accepted: a vertical Plane inside its polygon, or a Depth/feature point
     * whose surface normal is roughly horizontal (a wall), never floors or ceilings.
     */
    fun placeWallAtScreenPoint(screenX: Float, screenY: Float, realWallOnly: Boolean = false): Map<String, Any>? {
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
                t is com.google.ar.core.DepthPoint ->
                    depthValidator.rejectHit(h.distance, screenX, screenY, android.os.SystemClock.elapsedRealtime())
                        ?: if (kotlin.math.abs(n[1]) > 0.6f) "floor_or_ceiling" else "ok"
                // A plane ARCore has stopped tracking or merged into another must not anchor anything.
                t is Plane && (t.trackingState != TrackingState.TRACKING || t.subsumedBy != null) -> "plane_not_tracking"
                // A detected wall patch is usually far smaller than the wall, and the wall continues past it.
                t is Plane && t.type == Plane.Type.VERTICAL -> "ok"
                t is Plane && !t.isPoseInPolygon(h.hitPose) -> "outside_plane_polygon"
                t is Plane -> "plane_${t.type}"
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

        val cam = frame.camera.pose
        val camT = cam.translation

        // 1. A real wall under the finger (vertical plane / feature point with a wall normal).
        chosen?.let { hit ->
            val n = hit.hitPose.getTransformedAxis(1, 1.0f)
            val p = hit.hitPose.translation
            val floorY = floorHeight(view)
            // Stand the wall on the floor when we know where it is, so it never floats.
            val base = if (floorY != null && floorY < p[1]) floatArrayOf(p[0], floorY, p[2]) else null
            return anchorWall(view, base ?: p, horizontalNormal(n[0], n[2], p, camT), onFloor = base != null,
                surface = hit.trackable.javaClass.simpleName, dist = hit.distance,
                // A plane anchor stays welded to the plane as ARCore refines it (Anchors guide).
                attachTo = hit.trackable as? Plane)
        }

        // 1b. The finger is on a wall ARCore already found, just beyond its small detected patch.
        rayOnWall(view, frame, screenX, screenY)?.let { (p, n) ->
            val floorY = floorHeight(view)
            val base = if (floorY != null && floorY < p[1]) floatArrayOf(p[0], floorY, p[2]) else null
            return anchorWall(view, base ?: p, horizontalNormal(n[0], n[2], p, camT), onFloor = base != null,
                surface = "wall_extended", dist = distance(p, camT))
        }

        // 1c. No ARCore plane yet, but feature points on the segmented wall agree on a vertical plane.
        wallFromPointCloud(view, frame, screenX, screenY)?.let { (p, n) ->
            val floorY = floorHeight(view)
            val base = if (floorY != null && floorY < p[1]) floatArrayOf(p[0], floorY, p[2]) else null
            return anchorWall(view, base ?: p, horizontalNormal(n[0], n[2], p, camT), onFloor = base != null,
                surface = "pointcloud", dist = distance(p, camT))
        }

        // Auto-placement only trusts a real wall surface; the floor-line and guessed branches need a user tap.
        if (realWallOnly) return mapOf("placed" to false, "reason" to "auto_no_wall")

        // 2. The tap is on the floor (or on the floor line): build the wall standing on that line.
        // Plain painted walls give ARCore nothing to track, but floors almost always do.
        val floorHit = hits.firstOrNull {
            val t = it.trackable
            t is Plane && t.type == Plane.Type.HORIZONTAL_UPWARD_FACING &&
                it.distance in MIN_HIT_DISTANCE_M..MAX_MEASURE_M
        }
        val floorPoint = floorHit?.hitPose?.translation ?: rayOnFloor(view, frame, screenX, screenY)
        if (floorPoint != null) {
            return anchorWall(view, floorPoint, horizontalNormal(0f, 0f, floorPoint, camT), onFloor = true,
                surface = "floor_line", dist = distance(floorPoint, camT))
        }

        // 3. No floor yet: approximate wall at a guessed distance (last resort, scale is a guess).
        if (firstRejection == "floor_or_ceiling") {
            Log.i(TAG, "PLACE stage=result placed=false reason=$firstRejection")
            return mapOf("placed" to false, "reason" to firstRejection)
        }
        // The guessed distance along the tap ray (what Instant Placement does, without keeping that subsystem running).
        val (ro, rd) = tapRay(view, frame, screenX, screenY) ?: run {
            Log.i(TAG, "PLACE stage=result placed=false reason=$firstRejection (no ray)")
            return mapOf("placed" to false, "reason" to firstRejection)
        }
        // tapRay's direction is near->far plane (~100 m long), not unit: normalise, or the guess lands 200 m away.
        val len = sqrt(rd[0] * rd[0] + rd[1] * rd[1] + rd[2] * rd[2]).coerceAtLeast(1e-6f)
        val ip = FloatArray(3) { ro[it] + rd[it] / len * approxDistanceM }
        return anchorWall(view, ip, horizontalNormal(0f, 0f, ip, camT), onFloor = false,
            surface = "approximate", dist = approxDistanceM)
    }

    /**
     * Moves the placed wall along its own normal so it lies [distanceM] in front of the camera, through the
     * screen centre. Returns false when nothing is placed or the geometry is degenerate.
     */
    private fun replaneAtDistance(view: ARSceneView, distanceM: Float, surface: String): Boolean {
        val frame = view.frame ?: return false
        val anchor = placedAnchorNode?.anchor ?: return false
        val n = anchor.pose.getTransformedAxis(1, 1f)
        val proj = FloatArray(16); val viewM = FloatArray(16)
        frame.camera.getProjectionMatrix(proj, 0, 0.05f, 100f)
        frame.camera.getViewMatrix(viewM, 0)
        val cam = WallEdges.cameraPosition(viewM)
        val ray = WallEdges.ray(view.width / 2f, view.height * 0.45f, view.width, view.height, proj, viewM)
        val p = WallCalibration.pointOnWall(cam, ray, n, distanceM) ?: return false
        val floorY = floorHeight(view)
        val base = if (placedOnFloor && floorY != null) floatArrayOf(p[0], floorY, p[2]) else p
        anchorWall(view, base, floatArrayOf(n[0], 0f, n[2]), onFloor = placedOnFloor && floorY != null, surface = surface, dist = distanceM)
        return true
    }

    /** Height of the floor: the lowest tracked upward-facing plane at least 0.5 m below the camera. */
    private fun floorHeight(view: ARSceneView): Float? {
        val camY = view.frame?.camera?.pose?.ty() ?: return null
        return view.session?.getAllTrackables(Plane::class.java).orEmpty()
            .filter {
                it.trackingState == TrackingState.TRACKING && it.subsumedBy == null &&
                    it.type == Plane.Type.HORIZONTAL_UPWARD_FACING && it.centerPose.ty() < camY - 0.5f
            }
            .minOfOrNull { it.centerPose.ty() }
    }

    /**
     * Intersects the tap ray with the INFINITE floor plane. The detected floor polygon rarely reaches the
     * wall, so a plain hitTest at the floor-wall line usually misses even though the floor is known.
     */
    private fun rayOnFloor(view: ARSceneView, frame: com.google.ar.core.Frame, sx: Float, sy: Float): FloatArray? {
        val floorY = floorHeight(view) ?: return null
        val (o, d) = tapRay(view, frame, sx, sy) ?: return null
        if (d[1] >= -1e-4f) return null // ray points at or above the horizon: it never meets the floor
        val t = (floorY - o[1]) / d[1]
        if (t <= 0f) return null
        val p = floatArrayOf(o[0] + t * d[0], floorY, o[2] + t * d[2])
        val horiz = sqrt((p[0] - o[0]) * (p[0] - o[0]) + (p[2] - o[2]) * (p[2] - o[2]))
        return if (horiz in 0.3f..MAX_MEASURE_M) p else null
    }

    /** Nearest hit of the tap ray on the INFINITE plane of any tracked wall: (point, wall normal). */
    private fun rayOnWall(
        view: ARSceneView, frame: com.google.ar.core.Frame, sx: Float, sy: Float,
    ): Pair<FloatArray, FloatArray>? {
        val (o, d) = tapRay(view, frame, sx, sy) ?: return null
        var best: Pair<FloatArray, FloatArray>? = null
        var bestDist = Float.MAX_VALUE
        for (plane in view.session?.getAllTrackables(Plane::class.java).orEmpty()) {
            if (plane.type != Plane.Type.VERTICAL || plane.trackingState != TrackingState.TRACKING ||
                plane.subsumedBy != null) continue
            val n = plane.centerPose.getTransformedAxis(1, 1f)
            val c = plane.centerPose.translation
            val denom = d[0] * n[0] + d[1] * n[1] + d[2] * n[2]
            if (kotlin.math.abs(denom) < 1e-4f) continue // ray runs along the wall
            val t = ((c[0] - o[0]) * n[0] + (c[1] - o[1]) * n[1] + (c[2] - o[2]) * n[2]) / denom
            if (t <= 0f) continue
            val p = floatArrayOf(o[0] + t * d[0], o[1] + t * d[1], o[2] + t * d[2])
            val dist = distance(p, o)
            if (dist in MIN_HIT_DISTANCE_M..MAX_MEASURE_M && dist < bestDist) { bestDist = dist; best = p to n }
        }
        return best
    }

    /** World-space tap ray (origin on the near plane, unnormalised direction). */
    /**
     * The wall under a screen pixel from ARCore's feature points: points that project onto segmenter wall
     * pixels (in the mask's own camera frame) are fitted to a vertical plane ([WallGeometry.fitVerticalPlane]),
     * the fit must agree with the previous frame's fit, and the probe ray is intersected with it.
     * Returns (point on the wall, plane normal) or null when there is no such agreement.
     */
    private fun wallFromPointCloud(
        view: ARSceneView, frame: com.google.ar.core.Frame, sx: Float, sy: Float,
    ): Pair<FloatArray, FloatArray>? {
        val mask = latestMask
        // The segmenter is only a filter when it actually sees wall somewhere; on surfaces it refuses (flat
        // primer, raw plaster) every feature point in the middle of the view is a candidate instead.
        val maskUsable = mask != null && mask.count { (it.toInt() and 0xFF) > 127 } > mask.size / 20
        val mvp = if (maskUsable) maskViewProj else FloatArray(16).also {
            val proj = FloatArray(16); val viewM = FloatArray(16)
            frame.camera.getProjectionMatrix(proj, 0, 0.05f, 100f)
            frame.camera.getViewMatrix(viewM, 0)
            Matrix.multiplyMM(it, 0, proj, 0, viewM, 0)
        }
        val cam = frame.camera.pose.translation
        val pts = ArrayList<FloatArray>()
        runCatching {
            frame.acquirePointCloud().use { pc ->
                val buf = pc.points
                val n = buf.remaining() / 4
                for (i in 0 until n) {
                    val x = buf.get(i * 4); val y = buf.get(i * 4 + 1); val z = buf.get(i * 4 + 2); val c = buf.get(i * 4 + 3)
                    if (c < PC_MIN_CONFIDENCE) continue
                    val d = distance(floatArrayOf(x, y, z), cam)
                    if (d < MIN_HIT_DISTANCE_M || d > MAX_MEASURE_M) continue
                    val cw = mvp[3] * x + mvp[7] * y + mvp[11] * z + mvp[15]
                    if (cw <= 1e-4f) continue
                    val nx = (mvp[0] * x + mvp[4] * y + mvp[8] * z + mvp[12]) / cw
                    val ny = (mvp[1] * x + mvp[5] * y + mvp[9] * z + mvp[13]) / cw
                    if (nx < -1f || nx > 1f || ny < -1f || ny > 1f) continue
                    if (maskUsable) {
                        val mx = ((nx * 0.5f + 0.5f) * WallSegmenter.MASK_W).toInt().coerceIn(0, WallSegmenter.MASK_W - 1)
                        val my = ((0.5f - ny * 0.5f) * WallSegmenter.MASK_H).toInt().coerceIn(0, WallSegmenter.MASK_H - 1)
                        if ((mask!![my * WallSegmenter.MASK_W + mx].toInt() and 0xFF) > 127) pts.add(floatArrayOf(x, y, z))
                    } else if (kotlin.math.abs(nx) < 0.6f && kotlin.math.abs(ny) < 0.6f) {
                        pts.add(floatArrayOf(x, y, z))
                    }
                }
            }
        }.onFailure { return null }
        val fit = WallGeometry.fitVerticalPlane(pts, iterations = PC_ITERATIONS, inlierM = PC_INLIER_M,
            minPoints = PC_MIN_POINTS, minSpreadM = PC_MIN_SPREAD_M) ?: run { lastPcFit = null; return null }

        // Two consecutive frames must agree (same normal, same plane offset) before a fit counts as a wall.
        val now = android.os.SystemClock.elapsedRealtime()
        val prev = lastPcFit
        lastPcFit = fit to now
        if (prev == null || now - prev.second > PC_AGREE_WINDOW_MS || !WallGeometry.agree(prev.first, fit, PC_AGREE_OFFSET_M)) {
            Log.i(TAG, "PLACE pointcloud candidate: ${pts.size} pts, ${fit.inliers} inliers, waiting for a second agreeing frame")
            return null
        }

        val n = fit.normal; val p0 = fit.point
        val (o, d) = tapRay(view, frame, sx, sy) ?: return null
        val denom = n[0] * d[0] + n[1] * d[1] + n[2] * d[2]
        if (kotlin.math.abs(denom) < 1e-4f) return null
        val t = (n[0] * (p0[0] - o[0]) + n[1] * (p0[1] - o[1]) + n[2] * (p0[2] - o[2])) / denom
        if (t <= 0f) return null
        val p = floatArrayOf(o[0] + d[0] * t, o[1] + d[1] * t, o[2] + d[2] * t)
        val dist = distance(p, cam)
        if (dist < MIN_HIT_DISTANCE_M || dist > MAX_HIT_DISTANCE_M) return null
        Log.i(TAG, "PLACE pointcloud plane: ${pts.size} wall points, ${fit.inliers} inliers (2 frames agree), " +
            "dist=${"%.2f".format(dist)}m n=(${"%.2f".format(n[0])},${"%.2f".format(n[1])},${"%.2f".format(n[2])})")
        return p to n
    }

    private var lastPcFit: Pair<WallGeometry.PlaneFit, Long>? = null

    private fun tapRay(
        view: ARSceneView, frame: com.google.ar.core.Frame, sx: Float, sy: Float,
    ): Pair<FloatArray, FloatArray>? {
        val proj = FloatArray(16); val viewM = FloatArray(16); val vp = FloatArray(16); val inv = FloatArray(16)
        frame.camera.getProjectionMatrix(proj, 0, 0.05f, 100f)
        frame.camera.getViewMatrix(viewM, 0)
        Matrix.multiplyMM(vp, 0, proj, 0, viewM, 0)
        if (!Matrix.invertM(inv, 0, vp, 0)) return null
        val nx = 2f * sx / view.width - 1f
        val ny = 1f - 2f * sy / view.height
        fun unproject(z: Float): FloatArray {
            val out = FloatArray(4)
            Matrix.multiplyMV(out, 0, inv, 0, floatArrayOf(nx, ny, z, 1f), 0)
            return floatArrayOf(out[0] / out[3], out[1] / out[3], out[2] / out[3])
        }
        val o = unproject(-1f); val f = unproject(1f)
        return o to floatArrayOf(f[0] - o[0], f[1] - o[1], f[2] - o[2])
    }

    /**
     * Horizontal wall normal that faces the camera. Uses the surface normal (nx, nz) when it has a usable
     * horizontal part, otherwise the direction from the wall point back to the camera.
     */
    private fun horizontalNormal(nx: Float, nz: Float, p: FloatArray, cam: FloatArray): FloatArray {
        val toCamX = cam[0] - p[0]; val toCamZ = cam[2] - p[2]
        var x = nx; var z = nz
        if (sqrt(x * x + z * z) < 0.3f) { x = toCamX; z = toCamZ }
        if (x * toCamX + z * toCamZ < 0) { x = -x; z = -z } // always the side the user is standing on
        val len = sqrt(x * x + z * z).takeIf { it > 1e-4f } ?: return floatArrayOf(0f, 0f, 1f)
        return floatArrayOf(x / len, 0f, z / len)
    }

    /**
     * Anchors the design as an upright wall at [p] with horizontal normal [n]. The pose is gravity-aligned
     * (local X along the wall, Y = normal, Z = up), the same convention as an ARCore vertical plane's
     * centerPose, so [wallQuad] works for both. With [onFloor], [p] is the bottom edge, not the centre.
     */
    private fun anchorWall(
        view: ARSceneView, p: FloatArray, n: FloatArray, onFloor: Boolean, surface: String, dist: Float,
        attachTo: Plane? = null, refCentreY: Float = p[1], refSizeM: Float = 0f,
    ): Map<String, Any> {
        val session = view.session ?: return mapOf("placed" to false, "reason" to "no_session")
        val nx = n[0]; val nz = n[2]
        val pose = uprightWallPose(p, n)
        clearPlacedWall()
        worldMask.reset()
        pendingTexture?.let { if (it.material.hasParameter("useMask")) it.setParameter("useMask", 0f) }
        val anchor = attachTo?.takeIf { it.trackingState == TrackingState.TRACKING }?.let { runCatching { it.createAnchor(pose) }.getOrNull() }
            ?: session.createAnchor(pose)
        val node = AnchorNode(engine = view.engine, anchor = anchor)
        view.addChildNode(node)
        placedAnchorNode = node
        placedAtMs = android.os.SystemClock.elapsedRealtime()
        lastSegRequestMs = 0L // segment the new wall on the next frame instead of up to one interval later
        placedSurface = surface
        placedDistanceM = dist
        placedOnFloor = onFloor
        // A design measured from an A4 sheet or a painting is anchored at that object's centre. Seeding the wall
        // flood fill there filled only the object (sheet: 2% of the quad), so the mask never switched on; seed
        // on the bare wall just below it instead (above it when it hangs low).
        placedSeedZ = if (refSizeM <= 0f) { if (onFloor) 1.0f else 0f } else {
            val centreZ = if (onFloor) refCentreY - p[1] else 0f
            val off = refSizeM / 2f + 0.12f
            if (onFloor && centreZ - off < 0.1f) centreZ + off else centreZ - off
        }
        clearWallNode() // a placed wall replaces any plane-based overlay
        rebuildPlacedQuad(view)
        Log.i(TAG, "PLACE stage=result placed=true surface=$surface onFloor=$onFloor dist=${"%.2f".format(dist)}m " +
            "p=(${"%.2f".format(p[0])},${"%.2f".format(p[1])},${"%.2f".format(p[2])}) n=(${"%.2f".format(nx)},${"%.2f".format(nz)})")
        return mapOf("placed" to true, "surface" to surface, "distanceM" to dist, "onFloor" to onFloor)
    }

    /** Gravity-aligned wall pose at [p]: columns X = (-nz, 0, nx), Y = normal (nx, 0, nz), Z = up; X × Y = Z. */
    private fun uprightWallPose(p: FloatArray, n: FloatArray): Pose {
        val nx = n[0]; val nz = n[2]
        return Pose(p, quaternionFromRotation(-nz, nx, 0f, 0f, 0f, 1f, nx, nz, 0f))
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

    /** A measured wall the camera turned away from: its own anchor (ARCore keeps correcting it) and provenance. */
    private class RememberedWall(val anchor: com.google.ar.core.Anchor, val surface: String, val dist: Float, val onFloor: Boolean, val seedZ: Float)
    private val rememberedWalls = ArrayList<RememberedWall>()

    private fun rememberMeasuredWall(view: ARSceneView) {
        val surface = placedSurface ?: return
        if (Placement.scale(surface) == Placement.Scale.APPROXIMATE) return
        val pose = placedAnchorNode?.anchor?.takeIf { it.trackingState == TrackingState.TRACKING }?.pose ?: return
        val anchor = runCatching { view.session?.createAnchor(pose) }.getOrNull() ?: return
        // One entry per wall: drop older entries for the same plane, and keep at most a few.
        rememberedWalls.removeAll { r -> sameWall(r.anchor.pose, pose).also { if (it) r.anchor.detach() } }
        rememberedWalls.add(RememberedWall(anchor, surface, placedDistanceM, placedOnFloor, placedSeedZ))
        while (rememberedWalls.size > MAX_REMEMBERED_WALLS) rememberedWalls.removeAt(0).anchor.detach()
        Log.i(TAG, "WALL_MEMORY stored $surface dist=${"%.2f".format(placedDistanceM)}m (${rememberedWalls.size} walls)")
    }

    /** Re-places a remembered measured wall if the probe ray meets it face-on enough and inside its extent. */
    private fun restoreMeasuredWall(view: ARSceneView, sx: Float, sy: Float): Boolean {
        val frame = view.frame ?: return false
        val (o, d) = tapRay(view, frame, sx, sy) ?: return false
        val hit = rememberedWalls.lastOrNull { r ->
            if (r.anchor.trackingState != TrackingState.TRACKING) return@lastOrNull false
            val pose = r.anchor.pose
            val n = pose.getTransformedAxis(1, 1f); val c = pose.translation
            val denom = d[0] * n[0] + d[1] * n[1] + d[2] * n[2]
            if (abs(denom) < WALL_TURN_COS) return@lastOrNull false
            val t = ((c[0] - o[0]) * n[0] + (c[1] - o[1]) * n[1] + (c[2] - o[2]) * n[2]) / denom
            if (t <= 0f) return@lastOrNull false
            val local = pose.inverse().transformPoint(floatArrayOf(o[0] + t * d[0], o[1] + t * d[1], o[2] + t * d[2]))
            abs(local[0]) <= MASKED_WALL_WIDTH_M / 2f
        } ?: return false
        rememberedWalls.remove(hit)
        val pose = hit.anchor.pose
        val n = pose.getTransformedAxis(1, 1f)
        anchorWall(view, pose.translation, floatArrayOf(n[0], 0f, n[2]), onFloor = hit.onFloor, surface = hit.surface, dist = hit.dist)
        placedSeedZ = hit.seedZ
        hit.anchor.detach()
        Log.i(TAG, "WALL_MEMORY restored ${hit.surface} dist=${"%.2f".format(hit.dist)}m")
        return true
    }

    /** Same physical wall: normals within ~8 degrees and planes within 15 cm. */
    private fun sameWall(a: Pose, b: Pose): Boolean {
        val na = a.getTransformedAxis(1, 1f); val nb = b.getTransformedAxis(1, 1f)
        if (na[0] * nb[0] + na[1] * nb[1] + na[2] * nb[2] < 0.99f) return false
        val ta = a.translation; val tb = b.translation
        return abs((tb[0] - ta[0]) * na[0] + (tb[1] - ta[1]) * na[1] + (tb[2] - ta[2]) * na[2]) < 0.15f
    }

    fun clearPlacedWall() {
        placementGen++
        clearSideWall()
        placedQuad = null
        placedSurface = null
        lastEdgeEstimate = null
        worldMask.reset() // a new placement starts from an empty mask; the old wall's outline must not reappear
        lastPcFit = null
        placedAnchorNode?.let {
            sceneView?.removeChildNode(it)
            runCatching { it.anchor.detach() } // release it so ARCore can drop the trackable (Anchors guide)
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

                    // RELATIVE_PATH / IS_PENDING are API 29+. Older Android needs WRITE_EXTERNAL_STORAGE for the
                    // gallery, which the app does not ask for: the photo is still saved for Share (uri = "").
                    if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.Q) {
                        Log.i(TAG, "SNAPSHOT saved to cache only (API ${android.os.Build.VERSION.SDK_INT})")
                        handler.post { done(mapOf("uri" to "", "path" to cacheFile.absolutePath), null) }
                        return@Thread
                    }

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
    /**
     * Feeds [depthValidator]: each tracked ARCore feature point (metric) is projected into the raw depth image
     * (with its confidence image) and the two distances are compared. ~1 check/s until a decision, then every 3 s.
     */
    private fun validateDepth(session: Session, frame: com.google.ar.core.Frame) {
        if (session.config.depthMode == Config.DepthMode.DISABLED) return
        if (depthMeasureMode) depthProbe(frame)
        val before = depthValidator.state
        if (before == DepthValidator.State.REJECTED || before == DepthValidator.State.UNAVAILABLE) return
        if (frame.camera.trackingState != TrackingState.TRACKING) return
        val now = android.os.SystemClock.elapsedRealtime()
        if (now - lastDepthCheckMs < (if (before == DepthValidator.State.TRUSTED) 3000L else 1000L)) return
        lastDepthCheckMs = now
        val proj = FloatArray(16); val viewM = FloatArray(16); val vp = FloatArray(16)
        frame.camera.getProjectionMatrix(proj, 0, 0.05f, 100f)
        frame.camera.getViewMatrix(viewM, 0)
        Matrix.multiplyMM(vp, 0, proj, 0, viewM, 0)
        // Feature points -> (depth along the optical axis, view-normalized u, v)
        val depths = ArrayList<Float>(); val uv = ArrayList<Float>()
        runCatching {
            frame.acquirePointCloud().use { pc ->
                val buf = pc.points
                for (i in 0 until buf.remaining() / 4) {
                    val x = buf.get(i * 4); val y = buf.get(i * 4 + 1); val z = buf.get(i * 4 + 2)
                    if (buf.get(i * 4 + 3) < 0.3f) continue
                    val cw = vp[3] * x + vp[7] * y + vp[11] * z + vp[15] // = depth along the optical axis
                    if (cw <= 0.05f) continue
                    val nx = (vp[0] * x + vp[4] * y + vp[8] * z + vp[12]) / cw
                    val ny = (vp[1] * x + vp[5] * y + vp[9] * z + vp[13]) / cw
                    if (nx < -1f || nx > 1f || ny < -1f || ny > 1f) continue
                    depths.add(cw); uv.add(nx * 0.5f + 0.5f); uv.add(0.5f - ny * 0.5f)
                }
            }
        }
        val samples = ArrayList<FloatArray>()
        var freshDepth = true
        if (depths.isNotEmpty()) {
            // The depth image follows the GPU texture (its aspect ratio, not the 4:3 CPU image's): per the Depth API
            // guide, map into TEXTURE_NORMALIZED and scale by the depth image size. Outside [0,1] = no depth there.
            val tex = FloatArray(uv.size)
            frame.transformCoordinates2d(Coordinates2d.VIEW_NORMALIZED, uv.toFloatArray(), Coordinates2d.TEXTURE_NORMALIZED, tex)
            try {
                // This phone (OnePlus NE2211) never delivers raw depth, only the smoothed image; without the
                // fallback the validator got 0 samples, went UNAVAILABLE and depth was switched off.
                val raw = try { frame.acquireRawDepthImage16Bits() } catch (e: com.google.ar.core.exceptions.NotYetAvailableException) { null }
                (raw ?: frame.acquireDepthImage16Bits()).use { depth ->
                    // Not every frame brings new raw depth; a repeat is a reprojection and must not count as a new check.
                    if (depth.timestamp == lastRawDepthTs) { freshDepth = false; return@use }
                    lastRawDepthTs = depth.timestamp
                    val conf = if (raw != null) runCatching { frame.acquireRawDepthConfidenceImage() }.getOrNull() else null
                    try {
                        val dw = depth.width; val dh = depth.height
                        val dPlane = depth.planes[0]
                        val dBuf = dPlane.buffer.order(java.nio.ByteOrder.nativeOrder())
                        val cPlane = conf?.planes?.get(0)
                        for (i in depths.indices) {
                            val tx = tex[i * 2]; val ty = tex[i * 2 + 1]
                            if (tx !in 0f..1f || ty !in 0f..1f) continue
                            val px = (tx * dw).toInt().coerceAtMost(dw - 1); val py = (ty * dh).toInt().coerceAtMost(dh - 1)
                            val mm = dBuf.getShort(py * dPlane.rowStride + px * dPlane.pixelStride).toInt() and 0xFFFF
                            val c = cPlane?.let { (it.buffer.get(py * it.rowStride + px * it.pixelStride).toInt() and 0xFF) / 255f } ?: -1f
                            samples.add(floatArrayOf(depths[i], mm / 1000f, c))
                        }
                    } finally {
                        conf?.close()
                    }
                }
            } catch (e: com.google.ar.core.exceptions.NotYetAvailableException) {
                // no depth frame yet: an empty check still runs the decision timeout
            } catch (e: Exception) {
                Log.w(TAG, "DEPTH_CHECK failed: ${e.javaClass.simpleName}: ${e.message}")
            }
        }
        if (!freshDepth) return
        val after = depthValidator.addCheck(samples, now)
        Log.i(TAG, "DEPTH_CHECK points=${depths.size} ${depthValidator.lastReport}")
        if (after != before) {
            Log.i(TAG, "DEPTH_DECISION $before -> $after (${depthValidator.lastReport})")
            if ((after == DepthValidator.State.REJECTED || after == DepthValidator.State.UNAVAILABLE) && !depthMeasureMode) {
                runCatching { applySessionConfig(session) } // fillConfig now turns depth off
            }
        }
    }

    /**
     * Measurement-mode log (once a second): what each depth source says about the wall at the screen centre.
     * raw = Raw Depth, confidence >= 128, median of a 9x9 window; smooth = full Depth API; vio = ARCore feature
     * points projecting near the centre (metric, independent of the Depth API); hits = frame.hitTest at the centre.
     * All are distances along the optical axis except hits (ray length), equal for a wall faced squarely.
     */
    private fun depthProbe(frame: com.google.ar.core.Frame) {
        val now = android.os.SystemClock.elapsedRealtime()
        if (now - lastProbeMs < 1000L) return
        lastProbeMs = now
        val view = sceneView ?: return
        val centre = floatArrayOf(0.5f, 0.5f); val tex = FloatArray(2)
        frame.transformCoordinates2d(Coordinates2d.VIEW_NORMALIZED, centre, Coordinates2d.TEXTURE_NORMALIZED, tex)
        fun windowMedian(img: android.media.Image, conf: android.media.Image?): Pair<Float, Int> {
            val w = img.width; val h = img.height; val pl = img.planes[0]
            val buf = pl.buffer.order(java.nio.ByteOrder.nativeOrder())
            val cx = (tex[0] * w).toInt(); val cy = (tex[1] * h).toInt()
            val vals = ArrayList<Float>()
            for (y in (cy - 4)..(cy + 4)) for (x in (cx - 4)..(cx + 4)) {
                if (x !in 0 until w || y !in 0 until h) continue
                val mm = buf.getShort(y * pl.rowStride + x * pl.pixelStride).toInt() and 0xFFFF
                if (mm == 0) continue
                if (conf != null) {
                    val cp = conf.planes[0]
                    if ((cp.buffer.get(y * cp.rowStride + x * cp.pixelStride).toInt() and 0xFF) < 128) continue
                }
                vals.add(mm / 1000f)
            }
            vals.sort()
            return (if (vals.isEmpty()) -1f else vals[vals.size / 2]) to vals.size
        }
        val raw = runCatching {
            frame.acquireRawDepthImage16Bits().use { d ->
                val c = runCatching { frame.acquireRawDepthConfidenceImage() }.getOrNull()
                try { windowMedian(d, c) } finally { c?.close() }
            }
        }.getOrNull()
        val smooth = runCatching { frame.acquireDepthImage16Bits().use { windowMedian(it, null) } }.getOrNull()
        // Feature points near the centre (within 8% of the view) -> median optical-axis depth.
        val proj = FloatArray(16); val viewM = FloatArray(16); val vp = FloatArray(16)
        frame.camera.getProjectionMatrix(proj, 0, 0.05f, 100f); frame.camera.getViewMatrix(viewM, 0)
        Matrix.multiplyMM(vp, 0, proj, 0, viewM, 0)
        val vio = ArrayList<Float>()
        runCatching {
            frame.acquirePointCloud().use { pc ->
                val b = pc.points
                for (i in 0 until b.remaining() / 4) {
                    if (b.get(i * 4 + 3) < 0.3f) continue
                    val x = b.get(i * 4); val y = b.get(i * 4 + 1); val z = b.get(i * 4 + 2)
                    val cw = vp[3] * x + vp[7] * y + vp[11] * z + vp[15]
                    if (cw <= 0.05f) continue
                    val nx = (vp[0] * x + vp[4] * y + vp[8] * z + vp[12]) / cw
                    val ny = (vp[1] * x + vp[5] * y + vp[9] * z + vp[13]) / cw
                    if (kotlin.math.abs(nx) < 0.16f && kotlin.math.abs(ny) < 0.16f) vio.add(cw)
                }
            }
        }
        vio.sort()
        val hits = runCatching { frame.hitTest(view.width / 2f, view.height / 2f) }.getOrDefault(emptyList())
            .take(3).joinToString(",", "[", "]") { "${it.trackable.javaClass.simpleName} ${"%.2f".format(it.distance)}m" }
        fun fmt(p: Pair<Float, Int>?) = if (p == null) "n/a" else if (p.first < 0) "none" else "${"%.2f".format(p.first)}m(n=${p.second})"
        Log.i(TAG, "DEPTH_PROBE raw=${fmt(raw)} smooth=${fmt(smooth)} vio=${if (vio.isEmpty()) "none" else "%.2fm(n=%d)".format(vio[vio.size / 2], vio.size)} " +
            "hits=$hits tracking=${frame.camera.trackingState} thermal=$thermalStatus validation=${depthValidator.state} " +
            "placement=${Placement.provenance(placedSurface)}/${Placement.scale(placedSurface)}")
    }

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
            Log.i(TAG, "AR_DIAG tracking=$state thermal=$thermalStatus depthMode=$depth depthValidation=${depthValidator.state} depthSupported[$depthSupport] allPlanes=$byType acceptedWalls=${wallPlanes.size} placed=${placedAnchorNode != null} updatedPlanes=$updatedPlanes")
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

        // Every length in metres and every area in m² ("unit"), whatever unit the tile size came in: mixing
        // display units with m² areas made the Flutter panel label m² as mm² and under-price the wall 10x.
        return mapOf(
            "wallWidth" to wallWidthM,
            "wallHeight" to wallHeightM,
            "wallArea" to wallAreaM2,
            "tileWidth" to tileWidthM,
            "tileHeight" to tileHeightM,
            "tileArea" to tileAreaM2,
            "baseQuantity" to baseQuantity,
            "wastagePercent" to wastagePercent,
            "recommendedQuantity" to recommendedQuantity,
            "unit" to "m",
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
    /**
     * User calibration: [lengthM] between screen points (x1, y1) and (x2, y2) on the placed wall, measured by the
     * user (a door's width, the wall's width...). Moves the wall to the distance that makes that true.
     */
    fun calibrateKnownLength(x1: Float, y1: Float, x2: Float, y2: Float, lengthM: Float): Map<String, Any> {
        val view = sceneView ?: return mapOf("ok" to false, "reason" to "no_view")
        val frame = view.frame ?: return mapOf("ok" to false, "reason" to "no_frame")
        val anchor = placedAnchorNode?.anchor ?: return mapOf("ok" to false, "reason" to "nothing_placed")
        val proj = FloatArray(16); val viewM = FloatArray(16)
        frame.camera.getProjectionMatrix(proj, 0, 0.05f, 100f)
        frame.camera.getViewMatrix(viewM, 0)
        val r1 = WallEdges.ray(x1, y1, view.width, view.height, proj, viewM)
        val r2 = WallEdges.ray(x2, y2, view.width, view.height, proj, viewM)
        val n = anchor.pose.getTransformedAxis(1, 1f)
        val d = WallCalibration.distanceForKnownLength(r1, r2, n, lengthM)
            ?: return mapOf("ok" to false, "reason" to "implausible").also {
                Log.i(TAG, "CALIBRATE rejected: length=${lengthM}m gives no plausible wall distance")
            }
        val before = placedDistanceM
        val ok = replaneAtDistance(view, d, "user_calibrated")
        Log.i(TAG, "CALIBRATE user length=${"%.2f".format(lengthM)}m -> wall ${"%.2f".format(d)}m (was ${"%.2f".format(before)}m) ok=$ok")
        return mapOf("ok" to ok, "distanceM" to d.toDouble())
    }

    /**
     * User calibration from a rectangle the user measured (a painting, a door, a switchboard, an A4 sheet): its
     * four tapped corners (screen px, any order) and its real [widthM] x [heightM]. Unlike one tapped length this
     * fixes the wall's angle too, so a wall seen at a slant gets the right distance.
     */
    fun calibrateRectangle(points: FloatArray, widthM: Float, heightM: Float): Map<String, Any> {
        val view = sceneView ?: return mapOf("ok" to false, "reason" to "no_view")
        val frame = view.frame ?: return mapOf("ok" to false, "reason" to "no_frame")
        if (points.size != 8 || widthM <= 0f || heightM <= 0f) return mapOf("ok" to false, "reason" to "bad_input")
        val proj = FloatArray(16); val viewM = FloatArray(16)
        frame.camera.getProjectionMatrix(proj, 0, 0.05f, 100f)
        frame.camera.getViewMatrix(viewM, 0)
        val c = A4Reference.cyclic(points)
        val rays = Array(4) { i -> WallEdges.ray(c[2 * i], c[2 * i + 1], view.width, view.height, proj, viewM) }
        // Hand taps land a few px off: a looser shape match than the automatic A4 finder.
        val m = A4Reference.measureRays(rays, widthM, heightM, maxRatioErr = 0.15f, maxCos = 0.2f)
        if (m == null || abs(m.normal[1]) > 0.35f || m.distanceM !in WallCalibration.MIN_DISTANCE_M..WallCalibration.MAX_DISTANCE_M) {
            Log.i(TAG, "CALIBRATE_RECT rejected: ${widthM}x${heightM}m taps=${c.toList()} ratio=${m?.ratio} nY=${m?.normal?.get(1)}")
            return mapOf("ok" to false, "reason" to "shape")
        }
        val cam = WallEdges.cameraPosition(viewM)
        val centre = floatArrayOf(cam[0] + m.centre[0], cam[1] + m.centre[1], cam[2] + m.centre[2])
        val floorY = floorHeight(view)
        val base = if (floorY != null) floatArrayOf(centre[0], floorY, centre[2]) else centre
        Log.i(TAG, "CALIBRATE_RECT_DBG taps=${c.joinToString(",") { "%.0f".format(it) }} view=${view.width}x${view.height} " +
            "proj0=${"%.4f".format(proj[0])} proj5=${"%.4f".format(proj[5])} proj8=${"%.4f".format(proj[8])} proj9=${"%.4f".format(proj[9])}")
        Log.i(TAG, "CALIBRATE_RECT ${widthM}x${heightM}m -> wall ${"%.3f".format(m.distanceM)}m " +
            "(fromShort=${"%.3f".format(m.distShortM)} fromLong=${"%.3f".format(m.distLongM)} ratio=${"%.3f".format(m.ratio)} " +
            "cos=${"%.3f".format(m.cosAngle)}) was ${"%.2f".format(placedDistanceM)}m surface=$placedSurface")
        anchorWall(view, base, floatArrayOf(m.normal[0], 0f, m.normal[2]), onFloor = floorY != null, surface = "user_rectangle", dist = m.distanceM,
            refCentreY = centre[1], refSizeM = maxOf(widthM, heightM))
        onWallStateChanged?.invoke("LOCKED")
        return mapOf("ok" to true, "distanceM" to m.distanceM.toDouble())
    }

    /** Portrait width / height of the camera texture ARCore draws behind the scene, or null before a session. */
    fun cameraAspect(): Double? = runCatching {
        val s = sceneView?.session?.cameraConfig?.textureSize ?: return null
        minOf(s.width, s.height).toDouble() / maxOf(s.width, s.height)
    }.getOrNull()

    /** Hide the placed design so the user can see and tap the real wall (a sheet, a switchboard) underneath. */
    fun setDesignVisible(visible: Boolean) {
        userHidden = !visible
        shownState = null
    }

    @Volatile private var userHidden = false
    private var shownState: Boolean? = null
    private var placedAtMs = 0L
    private var placedSeedZ = 0f
    @Volatile private var placementGen = 0

    /**
     * Whether the placed design may be drawn: only once the wall mask clips it to the real wall. Drawing it
     * unclipped right after placement covered the whole screen (furniture, floor) before the wall was found.
     */
    private fun designReady(): Boolean = !wallClippingEnabled || maskWanted() ||
        android.os.SystemClock.elapsedRealtime() - placedAtMs > SHOW_UNMASKED_AFTER_MS

    /** Provenance of the current placement for the AR screen's scale badge. */
    fun getPlacementInfo(): Map<String, Any> = mapOf(
        "placed" to (placedAnchorNode != null),
        "surface" to (placedSurface ?: ""),
        "provenance" to Placement.provenance(placedSurface),
        "scale" to Placement.scale(placedSurface).name.lowercase(),
        "distanceM" to placedDistanceM.toDouble(),
        // Where the camera stands now (the anchor stays put while the user walks): shown in the status pill.
        "liveDistanceM" to (sceneView?.let { anchorDistance(it) } ?: -1f).toDouble(),
        // A tracked floor turns the next floor-line estimate into a measured size; the UI asks for it.
        "floorTracked" to (sceneView?.let { floorHeight(it) } != null),
    )

    fun getWallState(): String {
        val placed = placedAnchorNode?.anchor
        val selected = selectedWallId?.let { wallPlanes[it] }
        val state = when {
            placed != null -> when {
                placed.trackingState != TrackingState.TRACKING || !inCameraView(placed.pose) -> "LOST"
                !designReady() -> "DETECTING"
                // A guessed-distance placement is not a detected wall; the UI must say so.
                Placement.scale(placedSurface) == Placement.Scale.APPROXIMATE -> "APPROXIMATE"
                else -> "TRACKING"
            }
            // The 200 ms poll used to overwrite autoPlace's NEED_TAP with SEARCHING, so a plain wall never
            // showed the tap hint and the user waited forever.
            wallPlanes.isEmpty() -> if (needTap) "NEED_TAP" else "SEARCHING"
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
