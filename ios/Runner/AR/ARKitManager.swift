//  ARKitManager.swift
//  GraziaStones
//
//  Native ARKit implementation for wall detection, tracking, and visualization.
//  Supports LiDAR depth, scene reconstruction, and world anchors.

import Foundation
import ARKit
import SceneKit
import MetalKit
import Photos
import Accelerate
import Vision

@objc public class ARKitManager: NSObject {
    
    // MARK: - Public Properties
    
    @objc public static let shared = ARKitManager()
    
    @objc public var session: ARSession {
        return arSession
    }
    
    @objc public var sceneView: ARSCNView {
        return arSceneView
    }
    
    @objc public var onWallDetected: ((String, [String: Any]) -> Void)?
    @objc public var onWallUpdated: ((String, [String: Any]) -> Void)?
    @objc public var onWallRemoved: ((String) -> Void)?
    @objc public var onTrackingStateChanged: ((String) -> Void)?
    @objc public var onError: ((String) -> Void)?
    @objc public var onWallStateChanged: ((String) -> Void)?
    @objc public var onMeasurementResult: (([String: Any]) -> Void)?
    @objc public var onObstacleDetected: (([String: Any]) -> Void)?
    
    // MARK: - Private Properties
    
    private let arSession = ARSession()
    private let arSceneView = ARSCNView()
    private var wallAnchors: [UUID: ARAnchor] = [:]
    private var wallPlanes: [UUID: ARPlaneAnchor] = [:]
    private var selectedWallId: UUID?
    private var textureNode: SCNNode?
    private var isSessionRunning = false
    private var hasLiDAR = false
    private var sceneReconstructionEnabled = false
    
    // Measurement
    private var measurementAnchors: [UUID: ARAnchor] = [:]
    private var measurementNodes: [UUID: SCNNode] = [:]
    private var measurementLineNode: SCNNode?
    private var measurementStartPoint: simd_float3?
    private var measurementEndPoint: simd_float3?
    
    // Calibration
    private var calibrationPoints: [simd_float3] = []
    private var calibrationUnit: String = "ft"
    private var pixelsPerMeter: Float = 0.0
    private var isCalibrating = false
    
    // Placed walls (tap-to-place), see placeWallAtScreenPoint. The latest placement is the primary; walls placed
    // earlier on other surfaces stay (up to maxPlacedWalls), like Android's room walls.
    fileprivate final class PlacedWall {
        let id: Int
        var anchor: ARAnchor
        var frame: simd_float4x4      // x = right, y = up, z = normal (toward camera), origin on the wall
        var surface: String
        var distanceM: Float          // camera to wall, perpendicular, at placement
        var selected = true
        var panel: SCNNode?                    // non-LiDAR / clipping off: plain panel; LiDAR: the depth-masked quad
        var meshNodes: [UUID: SCNNode] = [:]   // LiDAR: wall-class faces per mesh anchor (low-confidence fallback)
        var erased: [simd_float3] = []         // world-space centres of Erase brush dabs
        var frames: [[simd_float3]] = []       // world corners of paintings / switchboards found on it (see detectFrames)
        var rejected: [simd_float3] = []       // Restore-brush points: a frame found around one is not uncovered again
        // LiDAR depth mask: shared by the quad and every mesh node of this wall
        var quadMaterial: SCNMaterial?
        var meshMaterial: SCNMaterial?
        var matTexture: MTLTexture?
        var matPatch = simd_float2(0, 0)
        var maskTexture: MTLTexture?           // erase mask in wall space (1 = stone), see rebuildMask
        var planeId: UUID?                     // ARPlaneAnchor the frame follows as ARKit refines it (see refineWalls)
        var lastRefine: TimeInterval = 0
        // Corners (see updateCorners): world half-planes (n.xyz, d), stone kept where dot(n, p) + d >= 0, and the
        // pattern's u origin (a point on the shared corner line, or the wall origin). v is always world Y.
        var clips: [simd_float4] = []
        var uvOrigin: simd_float3?
        init(id: Int, anchor: ARAnchor, frame: simd_float4x4, surface: String, distanceM: Float) {
            self.id = id; self.anchor = anchor; self.frame = frame; self.surface = surface; self.distanceM = distanceM
        }
        var origin: simd_float3 { simd_float3(frame.columns.3.x, frame.columns.3.y, frame.columns.3.z) }
        var normal: simd_float3 { simd_float3(frame.columns.2.x, frame.columns.2.y, frame.columns.2.z) }
        var right: simd_float3 { simd_float3(frame.columns.0.x, frame.columns.0.y, frame.columns.0.z) }
        /// Pattern coordinates (metres) of world point [p]: u along the wall from uvOrigin, v = world height, so
        /// stone courses line up across walls and the pattern wraps a shared corner.
        func patternPoint(_ p: simd_float3) -> simd_float2 { simd_float2(simd_dot(p - (uvOrigin ?? origin), right), p.y) }
        /// Wall-local metres (x along right, y up) of world point [p].
        func local(_ p: simd_float3) -> simd_float2 { simd_float2(simd_dot(p - origin, right), p.y - origin.y) }
        /// Bounding boxes (min, max, wall-local) of the uncovered frames.
        var frameBoxes: [(simd_float2, simd_float2)] {
            frames.map { c in let l = c.map(local); return (l.dropFirst().reduce(l[0], simd_min), l.dropFirst().reduce(l[0], simd_max)) }
        }
    }
    private var placedWalls: [PlacedWall] = []
    private var primaryWallId: Int?
    private var nextWallId = 0
    private var designHidden = false
    // ponytail: one recursive lock for wall state shared by the main thread (channel calls) and the SceneKit
    // render thread (mesh updates); split it if contention ever shows up in profiles.
    private let wallsLock = NSRecursiveLock()
    private static let maxPlacedWalls = 4
    private static let brushRadiusM: Float = 0.08
    private var wallClippingEnabled = true
    private static let placedWallWidthM: Float = 3.0
    private static let placedWallHeightM: Float = 2.7
    private static let meshWallRangeM: Float = 4.0      // along the wall / up from the anchor
    private static let meshWallDepthM: Float = 0.12     // face must sit this close to the placed plane

    // LiDAR per-pixel depth mask (see stoneShader). Calibration knobs: tune these on device, not the shader.
    private static let depthTolBaseM: Float = 0.04      // keep stone where |scene depth - wall depth| < base + perM * distance
    private static let depthTolPerM: Float = 0.015
    private static let depthFeatherM: Float = 0.025     // soft edge width (at least ~1.5 px, see fwidth in the shader)
    private static let lowConfTolScale: Float = 2.5     // looser depth test where LiDAR confidence is low
    private static let quadBackOffsetM: Float = 0.03    // quad sits behind the wall so door/window occluders hide it
    private static let cornerMinAngleDeg: Float = 25   // walls closer to parallel than this share no corner
    private static let cornerMaxDistM: Float = 4.0      // the corner line must lie on both walls' drawn extent (meshWallRangeM)
    private static let cornerTolScale: Float = 2.0      // looser depth test at a corner line (LiDAR rounds corners; the clip cuts there)
    private static let frameShadeM: Float = 0.04        // contact shadow width beside an uncovered frame
    private static let maskSize = 512                   // erase mask texels across 2 * meshWallRangeM (1.6 cm each)
    private lazy var mtlDevice: MTLDevice? = MTLCreateSystemDefaultDevice()
    private var depthRing: [MTLTexture] = []            // r16Float scene depth, 3 so the CPU never writes one the GPU reads
    private var confRing: [MTLTexture] = []             // r8Unorm ARConfidenceLevel (0 low, 1 medium, 2 high)
    private var ringIndex = 0
    private var depthStaging: [UInt16] = []
    private var lastDepthStamp: TimeInterval = -1
    private var depthProp: SCNMaterialProperty?
    private var confProp: SCNMaterialProperty?
    private var cachedOrientation: UIInterfaceOrientation = .portrait   // read on the render thread
    // Paintings / switchboards (detectFrames): Vision rectangles on a placed wall, uncovered once seen twice.
    private let visionQueue = DispatchQueue(label: "com.graziastones.ar.frames", qos: .utility)
    private var framesBusy = false
    private var lastFramesRun: TimeInterval = 0
    private var frameCandidates: [(wallId: Int, corners: [simd_float3])] = []

    // Texture management
    private var currentTexture: MTLTexture?
    private var currentPatchHeightM: Float = ARKitManager.texturePatchHeightM
    private var preloadedTextures: [String: MTLTexture] = [:]
    private let textureQueue = DispatchQueue(label: "com.graziastones.ar.texture", qos: .userInitiated)
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        checkDeviceCapabilities()
        setupSceneView()
    }
    
    private func checkDeviceCapabilities() {
        hasLiDAR = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        sceneReconstructionEnabled = ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification)
        print("[ARKit] LiDAR available: \(hasLiDAR), Scene reconstruction: \(sceneReconstructionEnabled)")
    }
    
    private func setupSceneView() {
        arSceneView.session = arSession
        arSceneView.delegate = self
        arSceneView.automaticallyUpdatesLighting = true
        arSceneView.autoenablesDefaultLighting = true
        arSceneView.preferredFramesPerSecond = 60
        arSceneView.contentScaleFactor = 1.0
        
        // Enable statistics for debugging
        #if DEBUG
        arSceneView.showsStatistics = true
        #endif
    }
    
    // MARK: - Session Management
    
    @objc public func startSession() {
        guard !isSessionRunning else { return }
        
        clearPlacedWall()   // the reset below removes every anchor, so drop the walls built on them
        let configuration = createConfiguration()
        arSession.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isSessionRunning = true
        
        print("[ARKit] Session started with configuration: \(configuration)")
    }
    
    @objc public func pauseSession() {
        guard isSessionRunning else { return }
        arSession.pause()
        isSessionRunning = false
        print("[ARKit] Session paused")
    }
    
    @objc public func resumeSession() {
        guard !isSessionRunning else { return }
        let configuration = createConfiguration()
        arSession.run(configuration)
        isSessionRunning = true
        print("[ARKit] Session resumed")
    }
    
    private func createConfiguration() -> ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        
        // Plane detection - vertical for walls
        configuration.planeDetection = [.vertical]
        
        // Scene reconstruction for LiDAR devices
        if sceneReconstructionEnabled {
            configuration.sceneReconstruction = .meshWithClassification
        } else if hasLiDAR {
            configuration.sceneReconstruction = .mesh
        }
        
        // Frame semantics for depth
        // Smoothed depth (temporally filtered) gives a steadier stone boundary than raw sceneDepth.
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            configuration.frameSemantics.insert(.smoothedSceneDepth)
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        }
        
        // Environment texturing for realistic lighting
        configuration.environmentTexturing = .automatic
        // Which cameras ARKit offers for world tracking on this phone (ultra-wide question, 2026-10-30).
        print("[ARKit] FORMATS " + ARWorldTrackingConfiguration.supportedVideoFormats.map {
            "\($0.captureDeviceType.rawValue.replacingOccurrences(of: "AVCaptureDeviceTypeBuiltIn", with: "")) \(Int($0.imageResolution.width))x\(Int($0.imageResolution.height))@\($0.framesPerSecond)"
        }.joined(separator: ", "))
        
        return configuration
    }
    
    // MARK: - Wall Selection
    
    @objc public func selectWall(_ wallId: String) {
        guard let uuid = UUID(uuidString: wallId),
              wallAnchors[uuid] != nil else {
            print("[ARKit] Wall not found: \(wallId)")
            return
        }
        
        selectedWallId = uuid
        
        // Update visual feedback
        updateWallVisualization()
        
        // Notify Flutter
        if let plane = wallPlanes[uuid] {
            let wallData = planeToDictionary(plane)
            onWallUpdated?(wallId, wallData)
        }
    }
    
    @objc public func getWalls() -> [[String: Any]] {
        return wallPlanes.values.map { planeToDictionary($0) }
    }
    
    @objc public func getSelectedWallId() -> String? {
        return selectedWallId?.uuidString
    }
    
    // MARK: - Texture Management
    
    /// patchHeightM: real height of the texture photo in metres; 0 = use the default.
    /// trimFraction: border cut from each side of the photo (default 8 %).
    @objc public func setTexture(_ imageData: Data, patchHeightM: Double = 0, trimFraction: Double = 0.08) {
        let trim = min(max(trimFraction, 0), 0.45)
        // patchHeightM is the whole photo; createMetalTexture keeps its middle (1 - 2 * trim) (as Android does).
        self.currentPatchHeightM = (patchHeightM > 0 ? Float(patchHeightM) : ARKitManager.texturePatchHeightM) * Float(1 - 2 * trim)
        textureQueue.async { [weak self] in
            guard let self = self,
                  let texture = self.createMetalTexture(from: imageData, trim: trim) else { return }
            
            self.currentTexture = texture
            
            DispatchQueue.main.async {
                self.updateTextureOnNode(texture)
                self.refreshPlacedWalls()
            }
        }
    }
    
    private func createMetalTexture(from imageData: Data, trim: Double = 0.08) -> MTLTexture? {
        guard let device = MTLCreateSystemDefaultDevice(),
              let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
              let full = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else { return nil }
        // Catalogue photos have a light border / white backdrop that tiled into a grid of white seams; trim each side.
        let tx = Int(Double(full.width) * trim), ty = Int(Double(full.height) * trim)
        let cgImage = full.cropping(to: CGRect(x: tx, y: ty, width: full.width - 2 * tx, height: full.height - 2 * ty)) ?? full
        
        let textureLoader = MTKTextureLoader(device: device)
        do {
            let texture = try textureLoader.newTexture(cgImage: cgImage, options: [
                .SRGB: true, // photo pixels are sRGB; false washed brown stone out to pale grey on iPhone 13 Pro
                .generateMipmaps: true,
                .textureUsage: MTLTextureUsage.shaderRead.rawValue
            ])
            return texture
        } catch {
            print("[ARKit] Failed to create texture: \(error)")
            return nil
        }
    }
    
    /// The catalogue photos show a patch of finished wall (many stones), not a
    /// single tile. Repeat that patch at a realistic physical size instead of
    /// stretching one photo over the whole wall, which is what looked fake.
    // ponytail: assumed real height of one catalogue photo; add a per-stone value when the client supplies photo sizes.
    private static let texturePatchHeightM: Float = 0.9

    /// Real size (metres) of one repeat of [texture]: (width, height).
    private func patchSize(_ texture: MTLTexture) -> simd_float2 {
        let patchH = currentPatchHeightM
        return simd_float2(patchH * Float(texture.width) / Float(max(texture.height, 1)), patchH)
    }

    private func applyPatchScale(to material: SCNMaterial, texture: MTLTexture, wallWidth: Float, wallHeight: Float) {
        let p = patchSize(texture)
        material.diffuse.contentsTransform = SCNMatrix4MakeScale(wallWidth / p.x, wallHeight / p.y, 1)
    }

    private func updateTextureOnNode(_ texture: MTLTexture) {
        guard let textureNode = textureNode else { return }
        
        // Update the material's diffuse texture
        if let material = textureNode.geometry?.firstMaterial {
            material.diffuse.contents = texture
            material.diffuse.wrapS = .repeat
            material.diffuse.wrapT = .repeat
            material.isDoubleSided = true
            if let plane = textureNode.geometry as? SCNPlane {
                applyPatchScale(to: material, texture: texture, wallWidth: Float(plane.width), wallHeight: Float(plane.height))
            }
        }
    }
    
    @objc public func clearTexture() {
        textureQueue.async { [weak self] in
            self?.currentTexture = nil
            DispatchQueue.main.async {
                self?.textureNode?.geometry?.firstMaterial?.diffuse.contents = nil
                self?.clearPlacedWall()   // the Measure screen shares this singleton: no stale design there
            }
        }
    }

    // MARK: - Placed walls (tap-to-place)

    /// Places the design on the real surface under a screen point (view points, as Flutter's logical pixels).
    /// Raycast order: tracked vertical plane geometry, then a depth-estimated vertical plane (immediate on LiDAR),
    /// then the infinite extension of a tracked wall. Returns the same shape as the Android plugin:
    /// {placed, surface, distanceM, onFloor}.
    /// [auto] (the screen-centre scan while the camera pans): only a tracked wall plane counts once a wall is
    /// placed (a depth estimate is allowed for the first wall within 4 m), and a wall that already has the stone
    /// is left alone instead of re-anchored, so panning adds new walls without the placed ones jumping.
    @objc public func placeWallAtScreenPoint(_ screenPoint: CGPoint, auto: Bool = false) -> [String: Any]? {
        guard let frame = arSession.currentFrame else { return ["placed": false, "reason": "no_frame"] }
        if case .normal = frame.camera.trackingState {} else { return ["placed": false, "reason": "not_tracking"] }
        let attempts: [(ARRaycastQuery.Target, String)] = auto
            ? (placedWalls.isEmpty ? [(.existingPlaneGeometry, "Plane"), (.estimatedPlane, "estimated")] : [(.existingPlaneGeometry, "Plane")])
            : [(.existingPlaneGeometry, "Plane"), (.estimatedPlane, "estimated"), (.existingPlaneInfinite, "wall_extended")]
        let cam = position(frame.camera.transform)
        for (target, surface) in attempts {
            guard let query = arSceneView.raycastQuery(from: screenPoint, allowing: target, alignment: .vertical),
                  let hit = arSceneView.session.raycast(query).first else { continue }
            let t = hit.worldTransform
            let p = position(t)
            // A tracked vertical plane gives a steadier normal than the single hit (and keeps refining, see
            // refineWalls); otherwise a raycast result on a vertical plane carries the surface normal in its Y axis.
            let plane = (hit.anchor as? ARPlaneAnchor).flatMap { $0.alignment == .vertical ? $0 : nil }
            let nt = plane?.transform ?? t
            var n = simd_float3(nt.columns.1.x, nt.columns.1.y, nt.columns.1.z)
            if simd_dot(n, cam - p) < 0 { n = -n }
            n.y = 0
            if simd_length(n) < 0.05 { continue }   // a wall normal is horizontal
            n = simd_normalize(n)
            let dist = simd_distance(cam, p)
            guard dist > 0.3, dist < 8 else { continue }
            let perp = abs(simd_dot(cam - p, n))
            if auto {
                if surface == "estimated" && dist > 4 { continue }
                wallsLock.lock(); let known = placedWalls.contains { isSameWall($0, p, n) }; wallsLock.unlock()
                if known { return ["placed": false, "reason": "already_placed"] }
            }
            let wall = anchorPlacedWall(at: p, normal: n, surface: surface, distanceM: perp, planeId: plane?.identifier)
            print("[ARKit] PLACE placed=true surface=\(surface) wall=\(wallLabel(wall.id)) plane=\(plane != nil) dist=\(String(format: "%.2f", dist))m walls=\(placedWalls.count)")
            return ["placed": true, "surface": surface, "distanceM": Double(dist), "onFloor": false]
        }
        print("[ARKit] PLACE placed=false reason=no_hit")
        return ["placed": false, "reason": "no_hit"]
    }

    /// The same wall as [w]: normals within 15 degrees and the point within 0.4 m of its plane.
    private func isSameWall(_ w: PlacedWall, _ p: simd_float3, _ n: simd_float3) -> Bool {
        simd_dot(w.normal, n) > cos(Float.pi / 12) && abs(simd_dot(p - w.origin, w.normal)) < 0.4
    }

    /// Re-placing on a wall that already has the stone re-anchors that wall (same letter, selection, brush
    /// edits); a different wall is added beside the others, so panning across a room keeps every wall.
    private func anchorPlacedWall(at p: simd_float3, normal n: simd_float3, surface: String, distanceM: Float,
                                  planeId: UUID? = nil) -> PlacedWall {
        wallsLock.lock(); defer { wallsLock.unlock() }
        let up = simd_float3(0, 1, 0)
        let right = simd_normalize(simd_cross(up, n))
        let frameM = simd_float4x4(columns: (simd_float4(right, 0), simd_float4(up, 0), simd_float4(n, 0), simd_float4(p, 1)))
        let anchor = ARAnchor(name: "grazia_wall", transform: frameM)
        arSession.add(anchor: anchor)
        // The plane-based overlay would sit on top of the placed design.
        textureNode?.removeFromParentNode(); textureNode = nil
        let wall: PlacedWall
        if let same = placedWalls.first(where: { isSameWall($0, p, n) }) {
            arSession.remove(anchor: same.anchor)
            same.anchor = anchor
            same.frame = frameM
            same.distanceM = distanceM
            same.planeId = planeId
            if !same.surface.hasPrefix("user_") { same.surface = surface }   // keep the user's calibration
            wall = same
        } else {
            if placedWalls.count >= ARKitManager.maxPlacedWalls,
               let oldest = placedWalls.first(where: { $0.id != primaryWallId }) {
                print("[ARKit] ROOM dropping wall \(wallLabel(oldest.id)) (keeps at most \(ARKitManager.maxPlacedWalls))")
                removeWall(oldest)
            }
            wall = PlacedWall(id: nextWallId, anchor: anchor, frame: frameM, surface: surface, distanceM: distanceM)
            wall.planeId = planeId
            nextWallId += 1
            placedWalls.append(wall)
        }
        primaryWallId = wall.id
        // A changed corner moves the pattern origin / clip of the neighbours too.
        refreshPlacedWalls(updateCorners() ? nil : [wall])
        onWallStateChanged?("LOCKED")
        return wall
    }

    private func removeWall(_ w: PlacedWall) {
        w.panel?.removeFromParentNode(); w.panel = nil
        w.meshNodes.values.forEach { $0.removeFromParentNode() }
        w.meshNodes.removeAll()
        arSession.remove(anchor: w.anchor)
        placedWalls.removeAll { $0 === w }
    }

    /// Corners between placed walls. For each pair whose horizontal normals differ by more than cornerMinAngleDeg
    /// (and are not near-parallel opposites), the vertical line where their planes meet is a shared corner when it
    /// lies within cornerMaxDistM of both walls' placed points. Each wall then gets a clip half-plane through that
    /// line keeping its own side (the side holding its placed point), which works for concave room corners,
    /// convex pillar edges and any angle; and its pattern u origin moves onto the line so the stone wraps the
    /// corner. True when anything changed (the caller rebuilds every wall then).
    @discardableResult
    private func updateCorners() -> Bool {
        wallsLock.lock(); defer { wallsLock.unlock() }
        let walls = placedWalls.sorted { $0.id < $1.id }
        var clips: [Int: [simd_float4]] = [:]
        var uvOrigins: [Int: simd_float3] = [:]
        var lines: [String] = []
        let minSin = sin(ARKitManager.cornerMinAngleDeg * Float.pi / 180)
        for (i, a) in walls.enumerated() {
            for b in walls[(i + 1)...] {
                let na = simd_float2(a.normal.x, a.normal.z), nb = simd_float2(b.normal.x, b.normal.z)
                let det = na.x * nb.y - na.y * nb.x   // sin of the angle between the normals
                guard abs(det) > minSin else { continue }
                let oa = simd_float2(a.origin.x, a.origin.z), ob = simd_float2(b.origin.x, b.origin.z)
                let ca = simd_dot(na, oa), cb = simd_dot(nb, ob)
                let c = simd_float2((ca * nb.y - cb * na.y) / det, (na.x * cb - nb.x * ca) / det)
                guard simd_distance(c, oa) < ARKitManager.cornerMaxDistM, simd_distance(c, ob) < ARKitManager.cornerMaxDistM else { continue }
                // Half-plane through the line, normal along the wall toward the wall's own placed point.
                func clip(_ w: PlacedWall, _ o: simd_float2) -> simd_float4? {
                    let t = simd_normalize(simd_float2(w.right.x, w.right.z))
                    let s = simd_dot(o - c, t)
                    guard abs(s) > 0.05 else { return nil }   // tapped on the corner itself: no side to keep
                    let dir = s > 0 ? t : -t
                    return simd_float4(dir.x, 0, dir.y, -simd_dot(dir, c))
                }
                let corner = simd_float3(c.x, 0, c.y)
                for (w, o) in [(a, oa), (b, ob)] {
                    if let h = clip(w, o), clips[w.id, default: []].count < 3 { clips[w.id, default: []].append(h) }
                    if uvOrigins[w.id] == nil { uvOrigins[w.id] = corner }
                }
                let angle = acos(min(max(simd_dot(na, nb), -1), 1)) * 180 / Float.pi
                lines.append(String(format: "walls %@/%@ angle=%.1fdeg line at (%.3f, %.3f)", wallLabel(a.id), wallLabel(b.id), angle, c.x, c.y))
            }
        }
        func same(_ x: simd_float4, _ y: simd_float4) -> Bool { simd_length(x - y) < 0.002 }
        var changed = false
        for w in walls {
            let newClips = clips[w.id] ?? [], newOrigin = uvOrigins[w.id]
            let clipsSame = newClips.count == w.clips.count && zip(newClips, w.clips).allSatisfy { same($0, $1) }
            let originSame = (newOrigin == nil && w.uvOrigin == nil)
                || (newOrigin != nil && w.uvOrigin != nil && simd_distance(newOrigin!, w.uvOrigin!) < 0.002)
            if !clipsSame || !originSame { changed = true }
            w.clips = newClips
            w.uvOrigin = newOrigin
        }
        if changed {
            let counts = walls.map { "\(wallLabel($0.id)):\($0.clips.count)" }.joined(separator: " ")
            if lines.isEmpty { NSLog("[Corner] none, clips %@", counts) }
            for l in lines { NSLog("[Corner] %@, clips %@", l, counts) }
        }
        return changed
    }

    /// ARKit keeps refining a tracked plane; a wall placed on one follows it (half-way per step, at most every
    /// 0.5 s, only for changes over 1 deg / 15 mm) so the corner line settles on the real corner. Calibrated walls
    /// stay put. Brush dabs are world points, so they stay where they were painted. Runs on the render thread.
    fileprivate func refineWalls(from plane: ARPlaneAnchor) {
        guard wallsLock.try() else { return }
        defer { wallsLock.unlock() }
        let now = CACurrentMediaTime()
        let pt = plane.transform
        let planePoint = simd_float3(pt.columns.3.x, pt.columns.3.y, pt.columns.3.z)
        var changed = false
        var pn = simd_float3(pt.columns.1.x, 0, pt.columns.1.z)
        guard plane.alignment == .vertical, simd_length(pn) > 0.05 else { return }
        pn = simd_normalize(pn)
        // A wall placed on a depth estimate (far walls, before ARKit tracks them) adopts the tracked plane that
        // ARKit later finds under it, so its noisy normal gets refined and it can meet its neighbours at a corner.
        for w in placedWalls where w.planeId == nil && abs(simd_dot(pn, w.normal)) > cos(Float.pi / 12)
            && abs(simd_dot(w.origin - planePoint, pn)) < 0.15 {
            w.planeId = plane.identifier
            print("[ARKit] ROOM wall \(wallLabel(w.id)) adopted tracked plane")
        }
        for w in placedWalls where w.planeId == plane.identifier && !w.surface.hasPrefix("user_") && now - w.lastRefine > 0.5 {
            var n = pn   // exactly vertical wall
            if simd_dot(n, w.normal) < 0 { n = -n }
            let target = w.origin - n * simd_dot(w.origin - planePoint, n)
            let angle = acos(min(simd_dot(n, w.normal), 1))
            // Coarser steps than ARKit's own jitter, so the stone and corner do not crawl while it settles.
            guard angle > 1.0 * Float.pi / 180 || simd_distance(target, w.origin) > 0.015 else { continue }
            var ns = simd_normalize(w.normal + n)   // half-way
            ns.y = 0; ns = simd_normalize(ns)
            let o = (w.origin + target) / 2
            let up = simd_float3(0, 1, 0)
            w.frame = simd_float4x4(columns: (simd_float4(simd_normalize(simd_cross(up, ns)), 0), simd_float4(up, 0),
                                              simd_float4(ns, 0), simd_float4(o, 1)))
            w.lastRefine = now
            changed = true
        }
        guard changed else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.updateCorners()
            self.refreshPlacedWalls()
        }
    }

    private func wallLabel(_ id: Int) -> String { String(UnicodeScalar(UInt8(65 + id % 26))) }

    /// Rebuilds [walls] (default: all) for the current texture / clipping mode. With LiDAR and clipping on, the
    /// stone is a depth-masked quad per wall (buildDepthQuad) plus the wall-class mesh faces as the low-confidence
    /// fallback (updateMeshWall); the shader decides per pixel which of the two draws.
    private func refreshPlacedWalls(_ walls: [PlacedWall]? = nil) {
        wallsLock.lock(); defer { wallsLock.unlock() }
        let targets = walls ?? placedWalls
        targets.forEach { $0.panel?.removeFromParentNode(); $0.panel = nil }
        if hasLiDAR && wallClippingEnabled {
            if Thread.isMainThread, let o = arSceneView.window?.windowScene?.interfaceOrientation, o != .unknown {
                cachedOrientation = o
            }
            if let texture = currentTexture {
                for w in targets {
                    buildDepthQuad(w, texture: texture)
                    rebuildMask(w)   // the mask is in wall space; a re-anchor moves the wall origin
                }
            }
            if #available(iOS 13.4, *), let anchors = arSession.currentFrame?.anchors {
                for case let m as ARMeshAnchor in anchors {
                    if let node = arSceneView.node(for: m) { updateMeshWall(m, on: node, walls: targets) }
                }
            }
            return
        }
        for w in targets {
            let plane = SCNPlane(width: CGFloat(ARKitManager.placedWallWidthM), height: CGFloat(ARKitManager.placedWallHeightM))
            plane.materials = [stoneMaterial(wallWidth: ARKitManager.placedWallWidthM, wallHeight: ARKitManager.placedWallHeightM)]
            let node = SCNNode(geometry: plane)
            var t = w.frame
            t.columns.3 += simd_float4(w.normal * 0.012, 0)
            node.simdTransform = t
            node.renderingOrder = 3   // after every LiDAR occluder (-10 and 1)
            arSceneView.scene.rootNode.addChildNode(node)
            w.panel = node
            applyVisibility(w)
        }
    }

    private func applyVisibility(_ w: PlacedWall) {
        let hide = designHidden || !w.selected
        w.panel?.isHidden = hide
        w.meshNodes.values.forEach { $0.isHidden = hide }
    }

    private func stoneMaterial(wallWidth: Float, wallHeight: Float) -> SCNMaterial {
        let material = SCNMaterial()
        if let texture = currentTexture {
            material.diffuse.contents = texture
            material.diffuse.wrapS = .repeat
            material.diffuse.wrapT = .repeat
            material.lightingModel = .constant
            applyPatchScale(to: material, texture: texture, wallWidth: wallWidth, wallHeight: wallHeight)
        } else {
            material.diffuse.contents = UIColor.systemYellow.withAlphaComponent(0.5)
        }
        material.isDoubleSided = true
        return material
    }

    // MARK: - LiDAR depth mask

    /// SceneKit surface modifier for the stone on a LiDAR wall. Per pixel: project the fragment to the screen,
    /// map that through the inverse display transform into the (landscape) depth image, and keep the stone only
    /// where the real scene depth matches the wall's own depth. Closer = something stands in front, farther = an
    /// opening (doorway, window): both are cut, with a soft edge. Low confidence loosens the test; the wall-class
    /// mesh faces (classification gate) fill in only where there is no depth.
    /// The Erase brush is a wall-space mask texture; wall-local metres = diffuse UV * patch size - stonePatch.zw.
    /// Corner clips (clip0..2, world half-planes, inactive = (0,0,0,1)) cut the other side of a shared corner
    /// with a 3 mm feather, and loosen the depth tolerance within 10 cm of the corner line.
    private static func stoneShader(meshLayer: Bool) -> String {
        func f(_ x: Float) -> String { String(format: "%.4f", x) }
        let r = meshWallRangeM
        // The quad sits quadBackOffsetM behind the wall: the real wall is that much nearer along the view axis.
        let frag = meshLayer ? "-gsVp.z" : "-gsVp.z - \(f(quadBackOffsetM)) * abs(_surface.normal.z)"
        // Confidence used to pick the layer per pixel, and edge pixels flipped between the two every frame
        // (flicker). Now the quad decides wherever there is depth, low confidence only loosens its test, and the
        // mesh layer fills just where there is no depth at all.
        let keep = meshLayer ? "gsValid ? 0.0 : 1.0" : "gsValid ? gsNear : 0.0"
        return """
        #pragma arguments
        texture2d<float> depthTex;
        texture2d<float> confTex;
        texture2d<float> maskTex;
        float4 dispA;
        float4 dispB;
        float4 stonePatch;
        float4 clip0;
        float4 clip1;
        float4 clip2;
        #pragma body
        constexpr sampler gsLinear(filter::linear, address::clamp_to_edge);
        float3 gsVp = _surface.position;
        float4 gsClip = scn_frame.projectionTransform * float4(gsVp, 1.0);
        float3 gsView = float3(gsClip.x / gsClip.w * 0.5 + 0.5, 0.5 - gsClip.y / gsClip.w * 0.5, 1.0);
        float2 gsImg = float2(dot(dispA.xyz, gsView), dot(dispB.xyz, gsView));
        // 5-tap average: the 256x192 LiDAR depth is noisy per pixel, which made the cut edge crawl.
        float2 gsTx = 1.0 / float2(depthTex.get_width(), depthTex.get_height());
        float gsScene = (depthTex.sample(gsLinear, gsImg).r * 2.0
                         + depthTex.sample(gsLinear, gsImg + float2(gsTx.x, 0)).r + depthTex.sample(gsLinear, gsImg - float2(gsTx.x, 0)).r
                         + depthTex.sample(gsLinear, gsImg + float2(0, gsTx.y)).r + depthTex.sample(gsLinear, gsImg - float2(0, gsTx.y)).r) / 6.0;
        float gsConf = saturate(confTex.sample(gsLinear, gsImg).r * 255.0);
        bool gsValid = isfinite(gsScene) && gsScene > 0.05 && all(gsImg >= 0.0) && all(gsImg <= 1.0);
        float gsFrag = \(frag);
        float gsDiff = abs(gsScene - gsFrag);
        float3 gsWorld = (scn_frame.inverseViewTransform * float4(gsVp, 1.0)).xyz;
        float3 gsClipD = float3(dot(clip0.xyz, gsWorld) + clip0.w, dot(clip1.xyz, gsWorld) + clip1.w,
                                dot(clip2.xyz, gsWorld) + clip2.w);
        float gsCorner = min(abs(gsClipD.x), min(abs(gsClipD.y), abs(gsClipD.z)));
        float gsTol = (\(f(depthTolBaseM)) + \(f(depthTolPerM)) * gsFrag) * mix(\(f(lowConfTolScale)), 1.0, gsConf)
                      * mix(\(f(cornerTolScale)), 1.0, smoothstep(0.03, 0.10, gsCorner));
        float gsFeather = max(\(f(depthFeatherM)), fwidth(gsDiff) * 1.5);
        float gsNear = 1.0 - smoothstep(gsTol, gsTol + gsFeather, gsDiff);
        float gsKeep = \(keep);
        gsKeep *= smoothstep(-0.0015, 0.0015, min(gsClipD.x, min(gsClipD.y, gsClipD.z)));
        float2 gsMaskUV = (_surface.diffuseTexcoord * stonePatch.xy - stonePatch.zw + \(f(r))) / \(f(2 * r));
        // Mask: 0 = uncovered, ramping to 1 away from the edge. A crisp cut a few mm wide, and the stone a little
        // darker right beside it, like the shadow along a real cladding edge around a painting or switchboard.
        float gsMask = maskTex.sample(gsLinear, gsMaskUV).r;
        gsKeep *= smoothstep(0.02, 0.10, gsMask);
        if (gsKeep < 0.004) { discard_fragment(); }
        float gsShade = mix(0.62, 1.0, smoothstep(0.08, 1.0, gsMask));
        _surface.diffuse = float4(_surface.diffuse.rgb * gsShade, _surface.diffuse.a) * gsKeep;
        """
    }
    private static let quadShader = stoneShader(meshLayer: false)
    private static let meshShader = stoneShader(meshLayer: true)

    private func makeTexture(_ format: MTLPixelFormat, _ width: Int, _ height: Int) -> MTLTexture? {
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: width, height: height, mipmapped: false)
        d.usage = .shaderRead
        d.storageMode = .shared
        return mtlDevice?.makeTexture(descriptor: d)
    }

    /// Placeholder depth/confidence (1x1 zero = no depth: the mesh fallback draws) until the first frame arrives.
    private func ensureDepthProps() {
        guard depthProp == nil, let d = makeTexture(.r16Float, 1, 1), let c = makeTexture(.r8Unorm, 1, 1) else { return }
        var zero16: UInt16 = 0, zero8: UInt8 = 0
        d.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: &zero16, bytesPerRow: 2)
        c.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: &zero8, bytesPerRow: 1)
        depthProp = SCNMaterialProperty(contents: d)
        confProp = SCNMaterialProperty(contents: c)
    }

    /// The quad and mesh materials of [w] for [texture]; rebuilt only when the texture or its patch size changes.
    private func ensureMaterials(_ w: PlacedWall, texture: MTLTexture) {
        let patch = patchSize(texture)
        if w.matTexture === texture, w.matPatch == patch, w.quadMaterial != nil, w.meshMaterial != nil { return }
        ensureDepthProps()
        var newMask = false
        if w.maskTexture == nil {
            w.maskTexture = makeTexture(.r8Unorm, ARKitManager.maskSize, ARKitManager.maskSize)
            newMask = true
        }
        func make(_ shader: String) -> SCNMaterial {
            let m = SCNMaterial()
            m.diffuse.contents = texture
            m.diffuse.wrapS = .repeat
            m.diffuse.wrapT = .repeat
            m.lightingModel = .constant
            m.isDoubleSided = true
            m.transparency = 0.999          // forces the blended pass so the feathered alpha edge composites
            m.writesToDepthBuffer = false
            m.shaderModifiers = [.surface: shader]
            if let p = depthProp { m.setValue(p, forKey: "depthTex") }
            if let p = confProp { m.setValue(p, forKey: "confTex") }
            if let mask = w.maskTexture { m.setValue(SCNMaterialProperty(contents: mask), forKey: "maskTex") }
            m.setValue(NSValue(scnVector4: SCNVector4(1, 0, 0, 0)), forKey: "dispA")
            m.setValue(NSValue(scnVector4: SCNVector4(0, 1, 0, 0)), forKey: "dispB")
            return m
        }
        w.quadMaterial = make(ARKitManager.quadShader)
        w.meshMaterial = make(ARKitManager.meshShader)
        w.matTexture = texture
        w.matPatch = patch
        for node in w.meshNodes.values { node.geometry?.materials = [w.meshMaterial!] }
        applyWallUniforms(w)
        if newMask { rebuildMask(w) }
    }

    /// Patch size, pattern -> wall-local shift (for the erase mask) and corner clips of [w] on both its materials.
    private func applyWallUniforms(_ w: PlacedWall) {
        let o = w.origin, shift = w.patternPoint(o)   // pattern coords of the wall origin = wall-local (0, 0)
        let patch = w.matPatch
        let inactive = simd_float4(0, 0, 0, 1)
        for m in [w.quadMaterial, w.meshMaterial].compactMap({ $0 }) {
            m.setValue(NSValue(scnVector4: SCNVector4(patch.x, patch.y, shift.x, shift.y)), forKey: "stonePatch")
            for i in 0..<3 {
                let c = i < w.clips.count ? w.clips[i] : inactive
                m.setValue(NSValue(scnVector4: SCNVector4(c.x, c.y, c.z, c.w)), forKey: "clip\(i)")
            }
        }
    }

    /// One quad per wall covering the whole design region (2 * meshWallRangeM square), UV-mapped in wall space
    /// exactly like the mesh faces. The depth test in the shader, not the mesh triangulation, draws its outline.
    private func buildDepthQuad(_ w: PlacedWall, texture: MTLTexture) {
        ensureMaterials(w, texture: texture)
        applyWallUniforms(w)   // the frame or a corner may have moved since the materials were made
        guard let material = w.quadMaterial else { return }
        let r = ARKitManager.meshWallRangeM
        let p = patchSize(texture)
        let corners: [simd_float2] = [simd_float2(-r, -r), simd_float2(r, -r), simd_float2(r, r), simd_float2(-r, r)]
        let geometry = SCNGeometry(sources: [
            SCNGeometrySource(vertices: corners.map { SCNVector3($0.x, $0.y, 0) }),
            SCNGeometrySource(normals: corners.map { _ in SCNVector3(0, 0, 1) }),
            SCNGeometrySource(textureCoordinates: corners.map { c -> CGPoint in
                let uv = w.patternPoint(w.origin + w.right * c.x + simd_float3(0, c.y, 0)) / p
                return CGPoint(x: CGFloat(uv.x), y: CGFloat(uv.y))
            }),
        ], elements: [SCNGeometryElement(indices: [UInt16(0), 1, 2, 0, 2, 3], primitiveType: .triangles)])
        geometry.materials = [material]
        let node = SCNNode(geometry: geometry)
        var t = w.frame
        t.columns.3 -= simd_float4(w.normal * ARKitManager.quadBackOffsetM, 0)
        node.simdTransform = t
        node.renderingOrder = 0   // after door/window occluders (-10), before table/seat occluders (1)
        arSceneView.scene.rootNode.addChildNode(node)
        w.panel = node
        applyVisibility(w)
    }

    /// Bakes [w]'s Erase dabs into its wall-space mask: 0 within brushRadiusM of a dab, 1 elsewhere, with a
    /// depthFeatherM soft rim. Row j / column i = wall-local (y, x), matching the shader's mask UV.
    private func rebuildMask(_ w: PlacedWall) {
        guard let tex = w.maskTexture else { return }
        let n = ARKitManager.maskSize, range = ARKitManager.meshWallRangeM
        let texel = 2 * range / Float(n)
        let r = ARKitManager.brushRadiusM, feather = ARKitManager.depthFeatherM
        let right = simd_float3(w.frame.columns.0.x, w.frame.columns.0.y, w.frame.columns.0.z)
        let up = simd_float3(w.frame.columns.1.x, w.frame.columns.1.y, w.frame.columns.1.z)
        var px = [UInt8](repeating: 255, count: n * n)
        let reach = r + feather
        for dab in w.erased {
            let d = dab - w.origin
            let x = simd_dot(d, right), y = simd_dot(d, up)
            let i0 = max(0, Int((x - reach + range) / texel)), i1 = min(n - 1, Int((x + reach + range) / texel))
            let j0 = max(0, Int((y - reach + range) / texel)), j1 = min(n - 1, Int((y + reach + range) / texel))
            guard i0 <= i1, j0 <= j1 else { continue }
            for j in j0...j1 {
                let ty = (Float(j) + 0.5) * texel - range - y
                for i in i0...i1 {
                    let tx = (Float(i) + 0.5) * texel - range - x
                    let k = min(max((sqrt(tx * tx + ty * ty) - (r - feather / 2)) / feather, 0), 1)
                    let v = UInt8(k * k * (3 - 2 * k) * 255)
                    if v < px[j * n + i] { px[j * n + i] = v }
                }
            }
        }
        let shade = ARKitManager.frameShadeM
        for (lo, hi) in w.frameBoxes {
            let c = (lo + hi) / 2, h = (hi - lo) / 2 + 0.005   // 5 mm margin: the stone stops at the frame
            let i0 = max(0, Int((c.x - h.x - shade + range) / texel)), i1 = min(n - 1, Int((c.x + h.x + shade + range) / texel))
            let j0 = max(0, Int((c.y - h.y - shade + range) / texel)), j1 = min(n - 1, Int((c.y + h.y + shade + range) / texel))
            guard i0 <= i1, j0 <= j1 else { continue }
            for j in j0...j1 {
                let dy = abs((Float(j) + 0.5) * texel - range - c.y) - h.y
                for i in i0...i1 {
                    let dx = abs((Float(i) + 0.5) * texel - range - c.x) - h.x
                    let k = min(max(max(dx, dy) / shade, 0), 1)   // linear, so bilinear sampling keeps the edge exact
                    let v = UInt8(k * 255)
                    if v < px[j * n + i] { px[j * n + i] = v }
                }
            }
        }
        tex.replace(region: MTLRegionMake2D(0, 0, n, n), mipmapLevel: 0, withBytes: px, bytesPerRow: n)
    }

    /// Paintings, frames and switchboards sit 0-4 cm off the wall, inside the depth tolerance, so the depth mask
    /// paints over them. Once a second, Vision looks for rectangles in the camera image; one whose four corners
    /// land on a placed wall, level, 15 cm to 2 m a side, and found again on the next run, is cut out of that
    /// wall's mask like an Erase stroke. The Restore brush on it brings the stone back for good.
    private func detectFrames(_ time: TimeInterval) {
        guard hasLiDAR, wallClippingEnabled, !framesBusy, time - lastFramesRun > 1.0, !placedWalls.isEmpty,
              let frame = arSession.currentFrame, case .normal = frame.camera.trackingState else { return }
        lastFramesRun = time
        framesBusy = true
        let image = frame.capturedImage, cam = frame.camera
        visionQueue.async { [weak self] in
            let request = VNDetectRectanglesRequest()
            request.minimumSize = 0.08
            request.maximumObservations = 6
            request.minimumConfidence = 0.75
            request.quadratureTolerance = 20
            request.minimumAspectRatio = 0.2
            try? VNImageRequestHandler(cvPixelBuffer: image, orientation: .up).perform([request])
            let rects = request.results ?? []
            DispatchQueue.main.async { self?.acceptFrames(rects, camera: cam, imageSize: CGSize(width: CVPixelBufferGetWidth(image), height: CVPixelBufferGetHeight(image))) }
        }
    }

    private func acceptFrames(_ rects: [VNRectangleObservation], camera: ARCamera, imageSize: CGSize) {
        wallsLock.lock(); defer { wallsLock.unlock(); framesBusy = false }
        let k = camera.intrinsics, t = camera.transform
        let camPos = position(t)
        func ray(_ p: CGPoint) -> simd_float3 {   // Vision: normalized, origin bottom-left, in the landscape image
            let px = Float(p.x * imageSize.width), py = Float((1 - p.y) * imageSize.height)
            let d = simd_float3((px - k[2][0]) / k[0][0], -(py - k[2][1]) / k[1][1], -1)
            let w = t * simd_float4(d, 0)
            return simd_normalize(simd_float3(w.x, w.y, w.z))
        }
        var found: [(PlacedWall, [simd_float3])] = []
        for r in rects {
            let dirs = [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft].map(ray)
            for w in placedWalls {
                let hits: [simd_float3] = dirs.compactMap { d in
                    let den = simd_dot(d, w.normal)
                    guard abs(den) > 1e-3 else { return nil }
                    let s = simd_dot(w.origin - camPos, w.normal) / den
                    return s > 0.2 && s < 6 ? camPos + d * s : nil
                }
                guard hits.count == 4 else { continue }
                let l = hits.map(w.local)
                guard l.allSatisfy({ abs($0.x) < ARKitManager.meshWallRangeM && abs($0.y) < ARKitManager.meshWallRangeM }),
                      hits.allSatisfy({ p in w.clips.allSatisfy { simd_dot(simd_float3($0.x, $0.y, $0.z), p) + $0.w >= 0 } })
                else { continue }
                // Level (every edge runs along or across the wall; Vision's "top" is the landscape image's, so it
                // can be either) and sized like a painting or a switchboard, not a floor tile or the whole wall.
                let level = (0..<4).allSatisfy { i in
                    let e = l[(i + 1) % 4] - l[i]
                    return min(abs(e.x), abs(e.y)) < 0.18 * simd_length(e)
                }
                let lo = l.dropFirst().reduce(l[0], simd_min), hi = l.dropFirst().reduce(l[0], simd_max)
                let size = hi - lo
                guard level, size.x > 0.15, size.x < 2, size.y > 0.15, size.y < 2 else {
                    print(String(format: "[ARKit] FRAME skip wall=%@ level=%d size=%.2fx%.2f", wallLabel(w.id), level ? 1 : 0, size.x, size.y))
                    break
                }
                if w.rejected.contains(where: { let q = w.local($0); return all(q .>= lo) && all(q .<= hi) }) { continue }
                found.append((w, hits))
                break
            }
        }
        if !rects.isEmpty { print("[ARKit] FRAME rects=\(rects.count) onWall=\(found.count)") }
        func centre(_ c: [simd_float3]) -> simd_float3 { c.reduce(.zero, +) / Float(c.count) }
        var changed = Set<Int>()
        var nextCandidates: [(wallId: Int, corners: [simd_float3])] = []
        for (w, c) in found {
            if let i = w.frames.firstIndex(where: { simd_distance(centre($0), centre(c)) < 0.1 }) {
                w.frames[i] = zip(w.frames[i], c).map { ($0 * 3 + $1) / 4 }   // settle on repeated sightings
                changed.insert(w.id)
            } else if frameCandidates.contains(where: { $0.wallId == w.id && simd_distance(centre($0.corners), centre(c)) < 0.08 }) {
                if w.frames.count < 8 { w.frames.append(c); changed.insert(w.id) }
                print("[ARKit] FRAME uncovered on wall \(wallLabel(w.id)) (\(w.frames.count) total)")
            } else {
                nextCandidates.append((w.id, c))
            }
        }
        frameCandidates = nextCandidates
        for w in placedWalls where changed.contains(w.id) { rebuildMask(w) }
    }

    /// Copies this frame's LiDAR depth (as half floats) and confidence into the next ring texture: one small
    /// (256 x 192) upload per frame, shared by every wall's materials.
    private func uploadDepth(_ depth: ARDepthData) {
        let dm = depth.depthMap
        let width = CVPixelBufferGetWidth(dm), height = CVPixelBufferGetHeight(dm)
        if depthRing.first.map({ $0.width != width || $0.height != height }) ?? true {
            depthRing = (0..<3).compactMap { _ in makeTexture(.r16Float, width, height) }
            confRing = (0..<3).compactMap { _ in makeTexture(.r8Unorm, width, height) }
            depthStaging = [UInt16](repeating: 0, count: width * height)
        }
        guard depthRing.count == 3, confRing.count == 3 else { return }
        ringIndex = (ringIndex + 1) % 3
        let region = MTLRegionMake2D(0, 0, width, height)
        let depthTex = depthRing[ringIndex], confTex = confRing[ringIndex]

        CVPixelBufferLockBaseAddress(dm, .readOnly)
        if let base = CVPixelBufferGetBaseAddress(dm) {
            var src = vImage_Buffer(data: base, height: vImagePixelCount(height), width: vImagePixelCount(width),
                                    rowBytes: CVPixelBufferGetBytesPerRow(dm))
            depthStaging.withUnsafeMutableBytes { p in
                var dst = vImage_Buffer(data: p.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width),
                                        rowBytes: width * 2)
                vImageConvert_PlanarFtoPlanar16F(&src, &dst, vImage_Flags(kvImageNoFlags))
                depthTex.replace(region: region, mipmapLevel: 0, withBytes: p.baseAddress!, bytesPerRow: width * 2)
            }
        }
        CVPixelBufferUnlockBaseAddress(dm, .readOnly)

        if let cm = depth.confidenceMap, CVPixelBufferGetWidth(cm) == width, CVPixelBufferGetHeight(cm) == height {
            CVPixelBufferLockBaseAddress(cm, .readOnly)
            if let base = CVPixelBufferGetBaseAddress(cm) {
                confTex.replace(region: region, mipmapLevel: 0, withBytes: base, bytesPerRow: CVPixelBufferGetBytesPerRow(cm))
            }
            CVPixelBufferUnlockBaseAddress(cm, .readOnly)
        } else {
            let medium = [UInt8](repeating: 1, count: width * height)   // no confidence map: trust the depth
            confTex.replace(region: region, mipmapLevel: 0, withBytes: medium, bytesPerRow: width)
        }
        depthProp?.contents = depthTex
        confProp?.contents = confTex
    }

    /// Per frame, on the render thread: upload the new depth, then hand every stone material the depth textures
    /// and the view -> depth-image transform.
    fileprivate func updateDepthMask(viewport: CGSize) {
        guard hasLiDAR, wallClippingEnabled, viewport.width > 0, viewport.height > 0, wallsLock.try() else { return }
        defer { wallsLock.unlock() }
        let materials = placedWalls.flatMap { [$0.quadMaterial, $0.meshMaterial] }.compactMap { $0 }
        guard !materials.isEmpty, let frame = arSession.currentFrame else { return }
        if frame.timestamp != lastDepthStamp, let depth = frame.smoothedSceneDepth ?? frame.sceneDepth {
            lastDepthStamp = frame.timestamp
            uploadDepth(depth)
        }
        // displayTransform maps normalized image coords to normalized view coords (both top-left origin).
        let t = frame.displayTransform(for: cachedOrientation, viewportSize: viewport).inverted()
        let rowA = NSValue(scnVector4: SCNVector4(Float(t.a), Float(t.c), Float(t.tx), 0))
        let rowB = NSValue(scnVector4: SCNVector4(Float(t.b), Float(t.d), Float(t.ty), 0))
        for m in materials {
            m.setValue(rowA, forKey: "dispA")
            m.setValue(rowB, forKey: "dispB")
            if let p = depthProp { m.setValue(p, forKey: "depthTex") }
            if let p = confProp { m.setValue(p, forKey: "confTex") }
        }
    }

    /// LiDAR wall clipping: the faces of [meshAnchor] that ARKit classifies as wall and that lie on a placed
    /// wall's plane get the stone texture, UV-mapped in that wall's own frame so the pattern is continuous across
    /// mesh chunks. Doors, windows, pictures and furniture are other classes (or occluders), so they stay bare.
    /// With the depth mask these faces only draw where LiDAR confidence is low (stoneShader); the Erase brush is
    /// applied in the shader. Runs on the SceneKit render thread.
    @available(iOS 13.4, *)
    fileprivate func updateMeshWall(_ meshAnchor: ARMeshAnchor, on node: SCNNode, walls: [PlacedWall]? = nil) {
        // Never block the render thread: it may hold SceneKit's lock while the main thread holds ours and waits on it.
        // A skipped update is harmless, ARKit refines the mesh again within a second.
        guard wallsLock.try() else { return }
        defer { wallsLock.unlock() }
        let id = meshAnchor.identifier
        let targets = walls ?? placedWalls
        let mesh = meshAnchor.geometry
        guard wallClippingEnabled, hasLiDAR, let texture = currentTexture, let cls = mesh.classification, !targets.isEmpty else {
            for w in targets { w.meshNodes[id]?.removeFromParentNode(); w.meshNodes[id] = nil }
            return
        }
        let faces = mesh.faces
        let v = mesh.vertices
        let toWorld = meshAnchor.transform
        var world = [simd_float3](); world.reserveCapacity(v.count)
        for i in 0..<v.count {
            let ptr = v.buffer.contents().advanced(by: v.offset + v.stride * i).assumingMemoryBound(to: Float.self)
            let w = toWorld * simd_float4(ptr[0], ptr[1], ptr[2], 1)
            world.append(simd_float3(w.x, w.y, w.z))
        }
        var wallFaces = [UInt32](); wallFaces.reserveCapacity(faces.count * 3)   // 3 indices per wall-class face
        for i in 0..<faces.count {
            let raw = cls.buffer.contents().advanced(by: cls.offset + cls.stride * i).assumingMemoryBound(to: UInt8.self).pointee
            guard ARMeshClassification(rawValue: Int(raw)) == .wall else { continue }
            for j in 0..<3 {
                let at = (i * 3 + j) * faces.bytesPerIndex
                wallFaces.append(faces.buffer.contents().advanced(by: at).assumingMemoryBound(to: UInt32.self).pointee)
            }
        }
        for w in targets {
            ensureMaterials(w, texture: texture)
            guard let material = w.meshMaterial else { continue }
            let origin = w.origin, normal = w.normal
            let right = simd_float3(w.frame.columns.0.x, w.frame.columns.0.y, w.frame.columns.0.z)
            let up = simd_float3(w.frame.columns.1.x, w.frame.columns.1.y, w.frame.columns.1.z)
            var indices = [UInt32]()
            var f = 0
            while f < wallFaces.count {
                let a = Int(wallFaces[f]), b = Int(wallFaces[f + 1]), c = Int(wallFaces[f + 2])
                f += 3
                // on this wall's plane, and inside the region the design covers
                let onWall = [a, b, c].allSatisfy { i in
                    let d = world[i] - origin
                    return abs(simd_dot(d, normal)) <= ARKitManager.meshWallDepthM
                        && abs(simd_dot(d, right)) <= ARKitManager.meshWallRangeM && abs(simd_dot(d, up)) <= ARKitManager.meshWallRangeM
                }
                guard onWall else { continue }
                indices.append(contentsOf: [UInt32(a), UInt32(b), UInt32(c)])
            }
            guard !indices.isEmpty else { w.meshNodes[id]?.removeFromParentNode(); w.meshNodes[id] = nil; continue }

            // Texture coordinates in wall space: one photo patch per (patchW x patchH) metres.
            let patch = patchSize(texture)
            let uvs = world.map { w.patternPoint($0) / patch }   // same pattern space as the quad
            let posSource = SCNGeometrySource(buffer: v.buffer, vertexFormat: v.format, semantic: .vertex,
                                              vertexCount: v.count, dataOffset: v.offset, dataStride: v.stride)
            let uvData = Data(bytes: uvs, count: uvs.count * MemoryLayout<simd_float2>.size)
            let uvSource = SCNGeometrySource(data: uvData, semantic: .texcoord, vectorCount: v.count, usesFloatComponents: true,
                                             componentsPerVector: 2, bytesPerComponent: MemoryLayout<Float>.size,
                                             dataOffset: 0, dataStride: MemoryLayout<simd_float2>.size)
            let element = SCNGeometryElement(data: Data(bytes: indices, count: indices.count * MemoryLayout<UInt32>.size),
                                             primitiveType: .triangles, primitiveCount: indices.count / 3,
                                             bytesPerIndex: MemoryLayout<UInt32>.size)
            let geometry = SCNGeometry(sources: [posSource, uvSource], elements: [element])
            geometry.materials = [material]
            if let existing = w.meshNodes[id] {
                existing.geometry = geometry
            } else {
                let wallNode = SCNNode(geometry: geometry)
                wallNode.renderingOrder = 2   // after every occluder of the mesh (-10 and 1)
                // mesh vertices are anchor-local; the anchor node already carries the anchor transform
                node.addChildNode(wallNode)
                w.meshNodes[id] = wallNode
            }
            applyVisibility(w)
        }
    }

    @objc public func clearPlacedWall() {
        wallsLock.lock(); defer { wallsLock.unlock() }
        placedWalls.forEach { removeWall($0) }
        primaryWallId = nil
        nextWallId = 0
    }

    @objc public func setWallClipping(_ enabled: Bool) {
        wallsLock.lock(); defer { wallsLock.unlock() }
        wallClippingEnabled = enabled
        if !enabled {
            for w in placedWalls { w.meshNodes.values.forEach { $0.removeFromParentNode() }; w.meshNodes.removeAll() }
        }
        refreshPlacedWalls()
    }

    /// Hide the placed design (every wall) so the user can see and tap the real wall underneath.
    @objc public func setDesignVisible(_ visible: Bool) {
        wallsLock.lock(); defer { wallsLock.unlock() }
        designHidden = !visible
        placedWalls.forEach { applyVisibility($0) }
    }

    /// Put the stone on (or take it off) one of the placed walls ([id] from getPlacementInfo's `walls`).
    @objc public func setWallSelected(_ id: Int, selected: Bool) -> Bool {
        wallsLock.lock(); defer { wallsLock.unlock() }
        guard let w = placedWalls.first(where: { $0.id == id }) else { return false }
        w.selected = selected
        applyVisibility(w)
        print("[ARKit] ROOM wall \(wallLabel(id)) \(selected ? "selected" : "deselected")")
        return true
    }

    // MARK: - Placement info (scale provenance), as ARCoreManager.getPlacementInfo

    /// Same tags as Android's Placement.provenance. "estimated" is a depth hit on LiDAR, a guess without it.
    private func provenance(_ surface: String?) -> String {
        switch surface {
        case nil: return "none"
        case "Plane", "wall_extended": return "real_plane"
        case "estimated": return hasLiDAR ? "validated_depth" : "approximate"
        case "user_calibrated", "user_rectangle": return "user_calibrated"
        default: return "approximate"
        }
    }

    private func scale(_ surface: String?) -> String {
        switch provenance(surface) {
        case "user_calibrated": return "user"
        case "approximate", "none": return "approximate"
        default: return "measured"
        }
    }

    private func position(_ t: simd_float4x4) -> simd_float3 { simd_float3(t.columns.3.x, t.columns.3.y, t.columns.3.z) }

    /// Perpendicular distance from the camera to [w]'s plane right now.
    private func liveDistance(_ w: PlacedWall, _ frame: ARFrame) -> Float {
        abs(simd_dot(position(frame.camera.transform) - w.origin, w.normal))
    }

    /// Whether [w] is on screen: its anchor point projects inside the view, or the screen centre looks at it.
    private func inView(_ w: PlacedWall, _ frame: ARFrame, centreWall: PlacedWall?) -> Bool {
        if centreWall === w { return true }
        let inCam = simd_mul(simd_inverse(frame.camera.transform), simd_float4(w.origin, 1))
        guard inCam.z < -0.05 else { return false }
        let s = arSceneView.projectPoint(SCNVector3(w.origin.x, w.origin.y, w.origin.z))
        return arSceneView.bounds.contains(CGPoint(x: CGFloat(s.x), y: CGFloat(s.y)))
    }

    private func centreWall() -> PlacedWall? {
        let b = arSceneView.bounds
        return wallHit(at: CGPoint(x: b.midX, y: b.midY))?.wall
    }

    @objc public func getPlacementInfo() -> [String: Any] {
        wallsLock.lock(); defer { wallsLock.unlock() }
        let frame = arSession.currentFrame
        let primary = placedWalls.first { $0.id == primaryWallId }
        var tracking = false
        if let f = frame, case .normal = f.camera.trackingState { tracking = true }
        let centre = centreWall()
        let walls: [[String: Any]] = placedWalls.sorted { $0.id < $1.id }.map { w in
            let state = frame == nil || !tracking ? "LOST" : (inView(w, frame!, centreWall: centre) ? "IN_VIEW" : "OUT_OF_VIEW")
            return [
                "id": w.id, "label": wallLabel(w.id), "primary": w.id == primaryWallId, "selected": w.selected,
                "state": state, "scale": scale(w.surface), "angle": "own", "angleDeg": 0.0,
                "distanceM": Double(frame.map { liveDistance(w, $0) } ?? -1),
            ]
        }
        return [
            "placed": primary != nil,
            "surface": primary?.surface ?? "",
            "provenance": provenance(primary?.surface),
            "scale": scale(primary?.surface),
            "distanceM": Double(primary?.distanceM ?? -1),
            "liveDistanceM": Double(primary.flatMap { p in frame.map { liveDistance(p, $0) } } ?? -1),
            // Only vertical planes are detected; LiDAR depth sizes the wall without a floor.
            "floorTracked": false,
            "walls": walls,
        ]
    }

    /// Portrait width / height of the camera image.
    @objc public func getCameraAspect() -> NSNumber? {
        guard let res = arSession.currentFrame?.camera.imageResolution, res.width > 0, res.height > 0 else { return nil }
        return NSNumber(value: Double(min(res.width, res.height) / max(res.width, res.height)))
    }

    // MARK: - Calibration against the placed wall (LiDAR: a check of the measured scale, not a rescale)

    /// Where the camera ray through [screenPoint] (view points) meets the nearest placed wall plane facing the
    /// camera, within the region the design covers. Uses the placed plane, not a fresh raycast, so taps on a
    /// painting or a sheet (other mesh classes) still land on the wall behind them.
    private func wallHit(at screenPoint: CGPoint) -> (wall: PlacedWall, point: simd_float3)? {
        guard let q = arSceneView.raycastQuery(from: screenPoint, allowing: .estimatedPlane, alignment: .any) else { return nil }
        let o = q.origin, d = simd_normalize(q.direction)
        var best: (wall: PlacedWall, point: simd_float3, t: Float)?
        for w in placedWalls {
            let den = simd_dot(d, w.normal)
            guard den < -0.2 else { continue }   // the wall faces the camera, not seen edge-on
            let t = simd_dot(w.origin - o, w.normal) / den
            guard t > 0.05 else { continue }
            let p = o + d * t
            let rel = p - w.origin
            let right = simd_float3(w.frame.columns.0.x, w.frame.columns.0.y, w.frame.columns.0.z)
            guard abs(simd_dot(rel, right)) <= ARKitManager.meshWallRangeM, abs(rel.y) <= ARKitManager.meshWallRangeM else { continue }
            if best == nil || t < best!.t { best = (w, p, t) }
        }
        return best.map { ($0.wall, $0.point) }
    }

    /// Hits for all [points] on one wall, logged; nil (with the reason) when a tap misses or lands on another wall.
    private func wallCorners(_ points: [CGPoint]) -> (wall: PlacedWall, corners: [simd_float3])?  {
        var wall: PlacedWall?
        var corners: [simd_float3] = []
        for (i, sp) in points.enumerated() {
            guard let hit = wallHit(at: sp) else {
                NSLog("[Calibrate] tap %d (%.0f, %.0f) misses every placed wall", i, sp.x, sp.y); return nil
            }
            if wall == nil { wall = hit.wall }
            guard hit.wall === wall else {
                NSLog("[Calibrate] tap %d is on wall %@, not %@", i, wallLabel(hit.wall.id), wallLabel(wall!.id)); return nil
            }
            // LiDAR cross-check: how far the depth surface under the tap sits from the placed plane.
            let depthOff = surfacePoint(at: sp).map { simd_dot($0 - hit.wall.origin, hit.wall.normal) }
            NSLog("[Calibrate] tap %d (%.0f, %.0f) -> wall %@ (%.3f, %.3f, %.3f) depthOffset=%@", i, sp.x, sp.y,
                  wallLabel(hit.wall.id), hit.point.x, hit.point.y, hit.point.z,
                  depthOff.map { String(format: "%.3fm", $0) } ?? "none")
            corners.append(hit.point)
        }
        return wall.map { ($0, corners) }
    }

    /// Four tapped corners (screen points, any order, [x0, y0, x1, y1, ...]) of something the user measured,
    /// [widthM] x [heightM]. LiDAR already gives metric depth, so the 3D quad's size verifies the wall's scale
    /// (scaleRatio = measured / entered). ok=false, reason "shape", when it is off by more than 15 %.
    @objc public func calibrateRectangle(_ pts: [Double], widthM: Float, heightM: Float) -> [String: Any] {
        wallsLock.lock(); defer { wallsLock.unlock() }
        func fail(_ reason: String, _ extra: [String: Any] = [:]) -> [String: Any] {
            NSLog("[Calibrate] rect failed: %@ (%.3f x %.3f m)", reason, widthM, heightM)
            return extra.merging(["ok": false, "reason": reason]) { _, new in new }
        }
        NSLog("[Calibrate] rect start %.3f x %.3f m taps=%@ view=%.0fx%.0f walls=%d", widthM, heightM,
              pts.map { String(format: "%.0f", $0) }.joined(separator: ","), arSceneView.bounds.width, arSceneView.bounds.height,
              placedWalls.count)
        guard pts.count == 8, widthM > 0, heightM > 0 else { return fail("bad_input") }
        guard let frame = arSession.currentFrame else { return fail("no_frame") }
        guard case .normal = frame.camera.trackingState else { return fail("not_tracking") }
        guard !placedWalls.isEmpty else { return fail("nothing_placed") }
        let taps = (0..<4).map { CGPoint(x: pts[2 * $0], y: pts[2 * $0 + 1]) }
        guard let (wall, corners) = wallCorners(taps) else { return fail("off_wall") }

        // Corners in the wall's own 2D frame (x = along, y = up), sorted around their centre: taps come in any order.
        let right = simd_float3(wall.frame.columns.0.x, wall.frame.columns.0.y, wall.frame.columns.0.z)
        let flat = corners.map { simd_float2(simd_dot($0 - wall.origin, right), $0.y - wall.origin.y) }
        let c = flat.reduce(.zero, +) / 4
        let q = flat.sorted { atan2($0.y - c.y, $0.x - c.x) < atan2($1.y - c.y, $1.x - c.x) }
        let e = (0..<4).map { q[($0 + 1) % 4] - q[$0] }
        let sideA = (simd_length(e[0]) + simd_length(e[2])) / 2, sideB = (simd_length(e[1]) + simd_length(e[3])) / 2
        let aIsWidth = abs(e[0].x) + abs(e[2].x) >= abs(e[0].y) + abs(e[2].y)
        let measW = aIsWidth ? sideA : sideB, measH = aIsWidth ? sideB : sideA
        let rW = measW / widthM, rH = measH / heightM
        let dist = liveDistance(wall, frame)
        NSLog("[Calibrate] rect wall %@ measured %.3f x %.3f m vs entered %.3f x %.3f m ratioW=%.3f ratioH=%.3f wallDist=%.3f m surface=%@",
              wallLabel(wall.id), measW, measH, widthM, heightM, rW, rH, dist, wall.surface)
        let measured: [String: Any] = ["measuredWidthM": Double(measW), "measuredHeightM": Double(measH),
                                       "scaleRatio": Double((rW + rH) / 2), "distanceM": Double(dist)]
        guard abs(rW - 1) <= 0.15, abs(rH - 1) <= 0.15 else { return fail("shape", measured) }
        wall.surface = "user_rectangle"
        onWallStateChanged?("LOCKED")
        NSLog("[Calibrate] rect ok: wall %@ scale confirmed (ratio %.3f)", wallLabel(wall.id), (rW + rH) / 2)
        return measured.merging(["ok": true]) { _, new in new }
    }

    /// Two screen points [lengthM] apart on the placed wall: verifies the measured scale like calibrateRectangle.
    @objc public func calibrateKnownLength(_ a: CGPoint, _ b: CGPoint, lengthM: Float) -> [String: Any] {
        wallsLock.lock(); defer { wallsLock.unlock() }
        NSLog("[Calibrate] length start %.3f m taps=(%.0f, %.0f) (%.0f, %.0f)", lengthM, a.x, a.y, b.x, b.y)
        guard lengthM > 0 else { return ["ok": false, "reason": "bad_input"] }
        guard let frame = arSession.currentFrame, case .normal = frame.camera.trackingState else {
            NSLog("[Calibrate] length failed: not_tracking"); return ["ok": false, "reason": "not_tracking"]
        }
        guard let (wall, p) = wallCorners([a, b]) else {
            NSLog("[Calibrate] length failed: off_wall"); return ["ok": false, "reason": placedWalls.isEmpty ? "nothing_placed" : "off_wall"]
        }
        let measured = simd_distance(p[0], p[1]), ratio = measured / lengthM
        let dist = liveDistance(wall, frame)
        NSLog("[Calibrate] length wall %@ measured %.3f m vs entered %.3f m ratio=%.3f wallDist=%.3f m",
              wallLabel(wall.id), measured, lengthM, ratio, dist)
        let out: [String: Any] = ["measuredLengthM": Double(measured), "scaleRatio": Double(ratio), "distanceM": Double(dist)]
        guard abs(ratio - 1) <= 0.15 else {
            NSLog("[Calibrate] length failed: shape"); return out.merging(["ok": false, "reason": "shape"]) { _, new in new }
        }
        wall.surface = "user_calibrated"
        onWallStateChanged?("LOCKED")
        return out.merging(["ok": true]) { _, new in new }
    }

    // MARK: - Erase / Restore brush

    /// Erase hides the stone within brushRadiusM of where the finger meets the wall; Restore brings it back.
    /// LiDAR clipping only (the plain panel has no mask). False when no wall is under the finger.
    @objc public func editMask(_ screenPoint: CGPoint, erase: Bool) -> Bool {
        wallsLock.lock(); defer { wallsLock.unlock() }
        guard hasLiDAR, wallClippingEnabled, let (w, p) = wallHit(at: screenPoint) else { return false }
        let r = ARKitManager.brushRadiusM
        if erase {
            if w.erased.contains(where: { simd_distance($0, p) < r * 0.4 }) { return true }   // already erased here
            w.erased.append(p)
            // ponytail: capped dab list re-baked into the mask per dab (~0.5 ms); paint the mask incrementally if strokes lag.
            if w.erased.count > 400 { w.erased.removeFirst() }
        } else {
            let before = w.erased.count + w.frames.count
            w.erased.removeAll { simd_distance($0, p) < r * 1.5 }
            let q = w.local(p)
            w.frames.removeAll { c in
                let l = c.map(w.local), lo = l.dropFirst().reduce(l[0], simd_min), hi = l.dropFirst().reduce(l[0], simd_max)
                return all(q .>= lo - 0.03) && all(q .<= hi + 0.03)
            }
            if w.erased.count + w.frames.count == before { return true }
            if !w.rejected.contains(where: { simd_distance($0, p) < 0.1 }) { w.rejected.append(p) }
        }
        rebuildMask(w)   // the shader reads it next frame, no mesh rebuild
        return true
    }

    /// Saves what the AR view shows (camera + design) to Photos and to a temp file for sharing.
    @objc public func captureSnapshot(_ done: @escaping ([String: String]?, String?) -> Void) {
        let image = arSceneView.snapshot()
        guard let jpeg = image.jpegData(compressionQuality: 0.92) else { done(nil, "Could not capture the AR view"); return }
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Grazia_AR_\(stamp).jpg")
        do { try jpeg.write(to: url) } catch { done(nil, "Could not save the photo: \(error.localizedDescription)"); return }
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { ok, error in
            DispatchQueue.main.async {
                // The file is always there for Share; the gallery copy depends on the Photos permission.
                if let error = error { print("[ARKit] SNAPSHOT photos save failed: \(error)") }
                done(["uri": ok ? "photos://saved" : "", "path": url.path], nil)
            }
        }
    }
    
    // MARK: - Measurement
    
    @objc public func startMeasurement() {
        measurementStartPoint = nil
        measurementEndPoint = nil
        measurementAnchors.values.forEach { arSession.remove(anchor: $0) }
        measurementAnchors.removeAll()
    }
    
    @objc public func addMeasurementPoint(_ point: simd_float3) -> String {
        var transform = matrix_identity_float4x4
        transform.columns.3 = simd_float4(point.x, point.y, point.z, 1.0)
        let anchor = ARAnchor(name: "measurement", transform: transform)
        arSession.add(anchor: anchor)
        measurementAnchors[anchor.identifier] = anchor

        if measurementStartPoint == nil {
            measurementStartPoint = point
        } else if measurementEndPoint == nil {
            measurementEndPoint = point
        }

        return anchor.identifier.uuidString
    }

    /// Hit-tests a screen-space tap (in ARSCNView points) against detected wall planes
    /// and returns the resulting world-space point. This is the ONLY supported way to
    /// place a measurement point — it always resolves to a real ARKit world anchor,
    /// never a raw screen coordinate.
    /// Resolves a screen tap to a world-space point on a vertical surface.
    ///
    /// Uses ARKit raycasting rather than the deprecated `hitTest(_:types:)`. On a
    /// LiDAR device this matters: raycasting consults the reconstructed scene
    /// geometry and depth data, so a tap lands correctly on a wall that ARKit has
    /// not yet promoted to a full ARPlaneAnchor. `.existingPlaneGeometry` is tried
    /// first (most precise), then `.estimatedPlane` (depth-driven, works early).
    /// The legacy hit-test remains as a last resort so behaviour never regresses
    /// on non-LiDAR hardware.
    private func verticalWorldPoint(at screenPoint: CGPoint) -> simd_float3? {
        let alignments: [ARRaycastQuery.TargetAlignment] = [.vertical, .any]
        let targets: [ARRaycastQuery.Target] = [.existingPlaneGeometry, .estimatedPlane]

        for alignment in alignments {
            for target in targets {
                guard let query = arSceneView.raycastQuery(
                    from: screenPoint,
                    allowing: target,
                    alignment: alignment
                ) else { continue }

                let results = arSceneView.session.raycast(query)
                guard !results.isEmpty else { continue }

                // Prefer a hit on the wall the user already selected if vertical
                let preferred = results.first { result in
                    guard let id = (result.anchor as? ARPlaneAnchor)?.identifier else { return false }
                    return id == selectedWallId
                }

                if let hit = preferred ?? results.first {
                    let t = hit.worldTransform
                    return simd_float3(t.columns.3.x, t.columns.3.y, t.columns.3.z)
                }
            }
        }

        // Fallback: devices/sessions where raycasting yields nothing
        let legacy = arSceneView.hitTest(screenPoint, types: [.existingPlaneUsingGeometry, .existingPlaneUsingExtent, .featurePoint])
        if let hit = legacy.first {
            let t = hit.worldTransform
            return simd_float3(t.columns.3.x, t.columns.3.y, t.columns.3.z)
        }
        return nil
    }

    /// Nearest real surface of ANY orientation under a screen point (table, flower pot, tile, wall, floor).
    /// Raycast order: existing plane geometry first (most precise), then depth-driven estimated planes.
    private func surfacePoint(at screenPoint: CGPoint) -> simd_float3? {
        for target in [ARRaycastQuery.Target.existingPlaneGeometry, .estimatedPlane] {
            guard let query = arSceneView.raycastQuery(from: screenPoint, allowing: target, alignment: .any),
                  let hit = arSceneView.session.raycast(query).first else { continue }
            let t = hit.worldTransform
            return simd_float3(t.columns.3.x, t.columns.3.y, t.columns.3.z)
        }
        return nil
    }

    @objc public func hitTestWallAtScreenPoint(_ screenPoint: CGPoint) -> [String: Any]? {
        guard let point = surfacePoint(at: screenPoint) else { return nil }
        // Pins and lines are drawn by the Flutter overlay from projectMeasurementAnchors, so no 3D marker here.
        let anchorId = addMeasurementPoint(point)
        return ["anchorId": anchorId, "x": point.x, "y": point.y, "z": point.z]
    }

    /// Live crosshair probe: same raycast as placing a point, but creates no anchor.
    @objc public func probeSurfaceAtScreenPoint(_ screenPoint: CGPoint) -> [String: Any]? {
        guard let point = surfacePoint(at: screenPoint),
              let cam = arSession.currentFrame?.camera.transform else { return nil }
        let camPos = simd_float3(cam.columns.3.x, cam.columns.3.y, cam.columns.3.z)
        return ["x": point.x, "y": point.y, "z": point.z, "distanceM": simd_distance(camPos, point)]
    }

    /// Current screen position (view points) of measurement anchors; `visible` is false when behind the camera.
    @objc public func projectMeasurementAnchors(_ ids: [String]) -> [[String: Any]] {
        guard let frame = arSession.currentFrame else { return [] }
        let inverseCam = simd_inverse(frame.camera.transform)
        return ids.map { id in
            guard let uuid = UUID(uuidString: id), let anchor = measurementAnchors[uuid] else {
                return ["visible": false, "x": 0.0, "y": 0.0]
            }
            let c = anchor.transform.columns.3
            let inCam = simd_mul(inverseCam, simd_float4(c.x, c.y, c.z, 1))
            guard inCam.z < -0.01 else { return ["visible": false, "x": 0.0, "y": 0.0] }
            let p = arSceneView.projectPoint(SCNVector3(c.x, c.y, c.z))
            return ["visible": true, "x": Double(p.x), "y": Double(p.y)]
        }
    }

    private func drawMeasurementLine(from start: simd_float3, to end: simd_float3) {
        measurementLineNode?.removeFromParentNode()

        let lineGeometry = SCNCylinder(radius: 0.003, height: CGFloat(distance(start, end)))
        lineGeometry.firstMaterial?.diffuse.contents = UIColor.white
        lineGeometry.firstMaterial?.emission.contents = UIColor.white.withAlphaComponent(0.3)
        let lineNode = SCNNode(geometry: lineGeometry)

        let midPoint = (start + end) / 2
        lineNode.position = SCNVector3(midPoint.x, midPoint.y, midPoint.z)

        // Orient the cylinder (default up-axis Y) to point from start to end.
        let direction = simd_normalize(end - start)
        let up = simd_float3(0, 1, 0)
        let dotProduct = simd_dot(up, direction)
        if abs(dotProduct) < 0.9999 {
            let axis = simd_normalize(simd_cross(up, direction))
            let angle = acos(dotProduct)
            lineNode.simdRotate(by: simd_quatf(angle: angle, axis: axis), aroundTarget: simd_float3(0, 0, 0))
        }

        arSceneView.scene.rootNode.addChildNode(lineNode)
        measurementLineNode = lineNode
    }

    public func getMeasurementDistance() -> Float? {
        guard let start = measurementStartPoint, let end = measurementEndPoint else { return nil }
        return distance(start, end)
    }

    @objc public func clearMeasurement() {
        measurementAnchors.values.forEach { arSession.remove(anchor: $0) }
        measurementAnchors.removeAll()
        measurementNodes.values.forEach { $0.removeFromParentNode() }
        measurementNodes.removeAll()
        measurementLineNode?.removeFromParentNode()
        measurementLineNode = nil
        measurementStartPoint = nil
        measurementEndPoint = nil
    }
    
    // MARK: - Wall Visualization
    
    private func updateWallVisualization() {
        // Remove existing texture node
        textureNode?.removeFromParentNode()
        textureNode = nil
        
        // A placed wall draws its own stone; a plane overlay on top would be a second layer.
        guard placedWalls.isEmpty, let wallId = selectedWallId,
              let plane = wallPlanes[wallId] else { return }
        
        // ARPlaneAnchor.extent is (width, 0, length): the wall's size is x by z (y is always 0).
        let width = CGFloat(plane.extent.x)
        let height = CGFloat(plane.extent.z)
        guard width > 0.05, height > 0.05 else { return }

        let planeGeometry = SCNPlane(width: width, height: height)

        let node = SCNNode(geometry: planeGeometry)
        node.simdTransform = wallFrame(for: plane)

        if let texture = currentTexture {
            let material = SCNMaterial()
            material.diffuse.contents = texture
            material.diffuse.wrapS = .repeat
            material.diffuse.wrapT = .repeat
            material.isDoubleSided = true
            material.lightingModel = .constant   // the photo already carries its own lighting
            applyPatchScale(to: material, texture: texture, wallWidth: Float(width), wallHeight: Float(height))
            planeGeometry.materials = [material]
        } else {
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.systemYellow.withAlphaComponent(0.5)
            planeGeometry.materials = [material]
        }

        node.renderingOrder = 3   // after the LiDAR occluders (-10 and 1), so furniture hides the overlay
        arSceneView.scene.rootNode.addChildNode(node)

        textureNode = node
    }
    
    /// World transform of a quad lying on the wall: x = right, y = world-up projected onto the wall,
    /// z = wall normal facing the camera, nudged 1.2 cm off the wall so it never z-fights the LiDAR mesh.
    private func wallFrame(for plane: ARPlaneAnchor) -> simd_float4x4 {
        let t = plane.transform
        let c4 = t * simd_float4(plane.center.x, plane.center.y, plane.center.z, 1)
        let center = simd_float3(c4.x, c4.y, c4.z)
        var n = simd_normalize(simd_float3(t.columns.1.x, t.columns.1.y, t.columns.1.z))
        if let cam = arSceneView.pointOfView?.simdWorldPosition, simd_dot(n, cam - center) < 0 { n = -n }
        var up = simd_float3(0, 1, 0) - n * n.y
        if simd_length(up) < 0.1 {   // wall is not upright: fall back to the anchor's own axis
            up = -simd_float3(t.columns.2.x, t.columns.2.y, t.columns.2.z)
        }
        up = simd_normalize(up)
        let right = simd_normalize(simd_cross(up, n))
        let pos = center + n * 0.012
        return simd_float4x4(columns: (simd_float4(right, 0), simd_float4(up, 0), simd_float4(n, 0), simd_float4(pos, 1)))
    }

    /// LiDAR furniture occlusion: classified mesh faces (sofa, TV, table, door...) are drawn into the
    /// depth buffer only, so the wall overlay is hidden behind them. Wall/floor/ceiling/unclassified
    /// faces are skipped on purpose: they would sit on the overlay and hide it.
    @available(iOS 13.4, *)
    fileprivate func updateOccluder(_ meshAnchor: ARMeshAnchor, on node: SCNNode) {
        let mesh = meshAnchor.geometry
        guard let cls = mesh.classification else { return }
        let faces = mesh.faces
        // Doors and windows hide the depth-masked quad too (it sits behind the wall, so a flush closed door
        // still cuts it); tables and seats render after the quad, so they only hide the mesh fallback: the
        // depth mask already cuts real furniture with a cleaner edge than these coarse faces.
        var openings = [UInt32](), objects = [UInt32]()
        for i in 0..<faces.count {
            let raw = cls.buffer.contents().advanced(by: cls.offset + cls.stride * i).assumingMemoryBound(to: UInt8.self).pointee
            guard let kind = ARMeshClassification(rawValue: Int(raw)) else { continue }
            if kind == .none || kind == .wall || kind == .floor || kind == .ceiling { continue }
            let isOpening = kind == .door || kind == .window
            for j in 0..<3 {
                let at = (i * 3 + j) * faces.bytesPerIndex
                let index = faces.buffer.contents().advanced(by: at).assumingMemoryBound(to: UInt32.self).pointee
                if isOpening { openings.append(index) } else { objects.append(index) }
            }
        }
        let v = mesh.vertices
        func depthOnly(_ indices: [UInt32]) -> SCNGeometry? {
            guard !indices.isEmpty else { return nil }
            let source = SCNGeometrySource(buffer: v.buffer, vertexFormat: v.format, semantic: .vertex,
                                           vertexCount: v.count, dataOffset: v.offset, dataStride: v.stride)
            let element = SCNGeometryElement(data: Data(bytes: indices, count: indices.count * MemoryLayout<UInt32>.size),
                                             primitiveType: .triangles, primitiveCount: indices.count / 3,
                                             bytesPerIndex: MemoryLayout<UInt32>.size)
            let geometry = SCNGeometry(sources: [source], elements: [element])
            let material = SCNMaterial()
            material.colorBufferWriteMask = []     // invisible...
            material.writesToDepthBuffer = true    // ...but hides what is behind it
            material.isDoubleSided = true
            geometry.materials = [material]
            return geometry
        }
        node.geometry = depthOnly(openings)
        node.renderingOrder = -10
        let objectNode: SCNNode
        if let existing = node.childNode(withName: "grazia_object_occluder", recursively: false) {
            objectNode = existing
        } else {
            objectNode = SCNNode()
            objectNode.name = "grazia_object_occluder"
            objectNode.renderingOrder = 1   // after the quad (0), before the mesh fallback (2)
            node.addChildNode(objectNode)
        }
        objectNode.geometry = depthOnly(objects)
    }

    private func planeToDictionary(_ plane: ARPlaneAnchor) -> [String: Any] {
        let center = plane.center
        let extent = plane.extent
        let transform = plane.transform
        
        // Calculate corners
        let halfWidth = extent.x / 2
        let halfHeight = extent.z / 2
        
        let corners = [
            simd_float3(-halfWidth, 0, -halfHeight),
            simd_float3(halfWidth, 0, -halfHeight),
            simd_float3(halfWidth, 0, halfHeight),
            simd_float3(-halfWidth, 0, halfHeight)
        ].map { localPoint in
            let worldPoint = transform * simd_float4(localPoint.x, localPoint.y, localPoint.z, 1)
            return ["x": worldPoint.x, "y": worldPoint.y, "z": worldPoint.z]
        }
        
        return [
            "id": plane.identifier.uuidString,
            "center": ["x": center.x, "y": center.y, "z": center.z],
            "extent": ["width": extent.x, "height": extent.z],
            "alignment": plane.alignment == .vertical ? "vertical" : "horizontal",
            "corners": corners,
            "area": extent.x * extent.z,
            // no "confidence": ARKit exposes none for a plane anchor
            "isSelected": plane.identifier == selectedWallId
        ]
    }
    
    // MARK: - Calibration
    
    @objc public func startCalibration(_ unit: String) {
        calibrationUnit = unit
        calibrationPoints = []
        isCalibrating = true
        pixelsPerMeter = 0.0
        print("[ARKit] Calibration started with unit: \(unit)")
    }
    
    @objc public func addCalibrationPoint(_ point: simd_float3) -> String {
        guard isCalibrating else { return "" }
        calibrationPoints.append(point)
        
        if calibrationPoints.count == 2 {
            let distance = simd_distance(calibrationPoints[0], calibrationPoints[1])
            // Store the pixel distance for calibration
            // The actual pixels per meter will be calculated in finishCalibration
            let anchorId = addMeasurementPoint(calibrationPoints[0])
            _ = addMeasurementPoint(calibrationPoints[1])
            return anchorId
        }
        return ""
    }
    
    @objc public func finishCalibration(_ realLength: Float) -> Bool {
        guard isCalibrating, calibrationPoints.count == 2 else { return false }
        
        let pixelDistance = simd_distance(calibrationPoints[0], calibrationPoints[1])
        
        // Convert real length to meters based on unit
        var realLengthMeters: Float = realLength
        switch calibrationUnit {
        case "ft":
            realLengthMeters = realLength * 0.3048
        case "m":
            realLengthMeters = realLength
        case "in":
            realLengthMeters = realLength * 0.0254
        case "cm":
            realLengthMeters = realLength * 0.01
        default:
            realLengthMeters = realLength * 0.3048
        }
        
        pixelsPerMeter = pixelDistance / realLengthMeters
        isCalibrating = false
        
        print("[ARKit] Calibration finished: \(pixelDistance) pixels = \(realLengthMeters) meters, \(pixelsPerMeter) pixels/meter")
        return true
    }
    
    @objc public func getCalibration() -> [String: Any]? {
        guard pixelsPerMeter > 0 else { return nil }
        return [
            "pixelsPerUnit": pixelsPerMeter,
            "unit": calibrationUnit,
            "isCalibrated": true
        ]
    }
    
    /// Distance in metres between two screen taps, resolved through ARKit world
    /// anchors.
    ///
    /// Deliberately does NOT require `pixelsPerMeter`. Both points come back as
    /// real world-space coordinates already in metres, so the pixel calibration
    /// is irrelevant here — the old `guard pixelsPerMeter > 0` made every
    /// measurement return nil until an unrelated calibration step had been run.
    public func measureDistance(_ screenPoint1: CGPoint, _ screenPoint2: CGPoint) -> Float? {
        guard let p1 = verticalWorldPoint(at: screenPoint1),
              let p2 = verticalWorldPoint(at: screenPoint2) else { return nil }

        return simd_distance(p1, p2)
    }
    
    // MARK: - Tile Quantity Calculation
    
    @objc public func calculateTileQuantity(tileWidth: Float, tileHeight: Float, tileUnit: String, wastagePercent: Float) -> [String: Any]? {
        let wallWidthM: Float, wallHeightM: Float, wallAreaM2: Float
        var wallCount = 1
        if let c = placedCoverage() {
            (wallWidthM, wallHeightM, wallAreaM2, wallCount) = c
        } else {
            guard let selectedWallId = selectedWallId, let plane = wallPlanes[selectedWallId] else { return nil }
            wallWidthM = plane.extent.x
            wallHeightM = plane.extent.z
            wallAreaM2 = wallWidthM * wallHeightM
        }
        
        // Convert tile dimensions to meters
        var tileWidthM = tileWidth
        var tileHeightM = tileHeight
        switch tileUnit {
        case "mm":
            tileWidthM = tileWidth / 1000.0
            tileHeightM = tileHeight / 1000.0
        case "cm":
            tileWidthM = tileWidth / 100.0
            tileHeightM = tileHeight / 100.0
        case "ft":
            tileWidthM = tileWidth * 0.3048
            tileHeightM = tileHeight * 0.3048
        case "in":
            tileWidthM = tileWidth * 0.0254
            tileHeightM = tileHeight * 0.0254
        case "m":
            // already in meters
            break
        default:
            tileWidthM = tileWidth / 1000.0
            tileHeightM = tileHeight / 1000.0
        }
        
        let tileAreaM2 = tileWidthM * tileHeightM
        guard tileAreaM2 > 0 else { return nil }
        
        let baseQuantity = Int(ceil(wallAreaM2 / tileAreaM2))
        let wastage = Int(ceil(Float(baseQuantity) * wastagePercent / 100.0))
        let recommendedQuantity = baseQuantity + wastage
        
        // Every length in metres and every area in m² ("unit"), as Android: converting only the wall's sides to
        // the tile's unit made the Flutter card label m² as mm² and hide the cost.
        return [
            "wallWidth": wallWidthM,
            "wallHeight": wallHeightM,
            "wallArea": wallAreaM2,
            "tileWidth": tileWidthM,
            "tileHeight": tileHeightM,
            "tileArea": tileAreaM2,
            "baseQuantity": baseQuantity,
            "wastagePercent": wastagePercent,
            "recommendedQuantity": recommendedQuantity,
            "walls": wallCount,
            "unit": "m"
        ]
    }

    /// Area the stone covers on the placed walls, from the LiDAR mesh: wall-class faces on each wall's plane, on
    /// its side of any corner, outside erased spots and uncovered frames, marked on a 10 cm grid per wall (so
    /// overlapping mesh chunks count once). Width = summed widths along the walls, height = tallest wall.
    /// Grows as more of the wall is scanned. Nil without LiDAR or before any wall face is meshed.
    // ponytail: walks every mesh face on the calling thread (~10-30 ms); move to a queue if the 2 s poll stutters.
    private func placedCoverage() -> (Float, Float, Float, Int)? {
        wallsLock.lock(); defer { wallsLock.unlock() }
        guard hasLiDAR, !placedWalls.isEmpty, let anchors = arSession.currentFrame?.anchors else { return nil }
        let cell: Float = 0.1, range = ARKitManager.meshWallRangeM
        let n = Int(2 * range / cell)
        var grids = placedWalls.map { _ in [Bool](repeating: false, count: n * n) }
        for case let m as ARMeshAnchor in anchors {
            let mesh = m.geometry
            guard let cls = mesh.classification else { continue }
            let v = mesh.vertices, faces = mesh.faces
            func vert(_ i: Int) -> simd_float3 {
                let ptr = v.buffer.contents().advanced(by: v.offset + v.stride * i).assumingMemoryBound(to: Float.self)
                let w = m.transform * simd_float4(ptr[0], ptr[1], ptr[2], 1)
                return simd_float3(w.x, w.y, w.z)
            }
            for f in 0..<faces.count {
                let raw = cls.buffer.contents().advanced(by: cls.offset + cls.stride * f).assumingMemoryBound(to: UInt8.self).pointee
                guard ARMeshClassification(rawValue: Int(raw)) == .wall else { continue }
                var c = simd_float3.zero
                for j in 0..<3 {
                    let at = (f * 3 + j) * faces.bytesPerIndex
                    c += vert(Int(faces.buffer.contents().advanced(by: at).assumingMemoryBound(to: UInt32.self).pointee))
                }
                c /= 3
                for (k, w) in placedWalls.enumerated() {
                    guard abs(simd_dot(c - w.origin, w.normal)) <= ARKitManager.meshWallDepthM,
                          w.clips.allSatisfy({ simd_dot(simd_float3($0.x, $0.y, $0.z), c) + $0.w >= 0 }) else { continue }
                    let l = w.local(c)
                    let i = Int((l.x + range) / cell), j = Int((l.y + range) / cell)
                    guard i >= 0, i < n, j >= 0, j < n else { continue }
                    grids[k][j * n + i] = true
                    break
                }
            }
        }
        var area: Float = 0, width: Float = 0, height: Float = 0, walls = 0
        for (k, w) in placedWalls.enumerated() {
            let boxes = w.frameBoxes, r = ARKitManager.brushRadiusM
            var minI = n, maxI = -1, minJ = n, maxJ = -1, cells = 0
            for j in 0..<n { for i in 0..<n where grids[k][j * n + i] {
                let l = simd_float2((Float(i) + 0.5) * cell - range, (Float(j) + 0.5) * cell - range)
                if boxes.contains(where: { all(l .>= $0.0) && all(l .<= $0.1) }) { continue }
                if w.erased.contains(where: { simd_distance(w.local($0), l) < r }) { continue }
                cells += 1
                minI = min(minI, i); maxI = max(maxI, i); minJ = min(minJ, j); maxJ = max(maxJ, j)
            } }
            guard cells > 0 else { continue }
            walls += 1
            area += Float(cells) * cell * cell
            width += Float(maxI - minI + 1) * cell
            height = max(height, Float(maxJ - minJ + 1) * cell)
        }
        return walls > 0 ? (width, height, area, walls) : nil
    }
    
    // MARK: - Wall State
    
    @objc public func getWallState() -> String {
        var tracking = false
        if let f = arSession.currentFrame, case .normal = f.camera.trackingState { tracking = true }
        let state = wallState(tracking: tracking)
        onWallStateChanged?(state)
        return state
    }

    /// As Android: a placed wall reads LOST while tracking is limited or no placed wall is on screen.
    private func wallState(tracking: Bool) -> String {
        wallsLock.lock(); defer { wallsLock.unlock() }
        if !placedWalls.isEmpty {
            guard tracking, let frame = arSession.currentFrame else { return "LOST" }
            let centre = centreWall()
            guard let shown = placedWalls.first(where: { $0.selected && inView($0, frame, centreWall: centre) })
                ?? placedWalls.first(where: { inView($0, frame, centreWall: centre) }) else { return "LOST" }
            return scale(shown.surface) == "approximate" ? "APPROXIMATE" : "TRACKING"
        }
        if wallPlanes.isEmpty { return "SEARCHING" }
        if let id = selectedWallId, wallPlanes[id] != nil { return "TRACKING" }
        return "DETECTING"
    }
    
    // MARK: - Texture Preloading
    
    @objc public func preloadTexture(_ textureUrl: String) {
        textureQueue.async { [weak self] in
            guard let self = self else { return }
            // For asset URLs, load from bundle
            // For network URLs, download and create texture
            if textureUrl.hasPrefix("assets/") {
                guard let data = NSData(contentsOfFile: Bundle.main.path(forResource: textureUrl, ofType: nil) ?? "") as Data?,
                      let texture = self.createMetalTexture(from: data) else { return }
                self.preloadedTextures[textureUrl] = texture
            }
        }
    }
}

// MARK: - ARSCNViewDelegate

extension ARKitManager: ARSCNViewDelegate {
    
    public func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        updateDepthMask(viewport: renderer.currentViewport.size)
        detectFrames(time)
    }

    public func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if #available(iOS 13.4, *), let meshAnchor = anchor as? ARMeshAnchor {
            updateOccluder(meshAnchor, on: node)
            updateMeshWall(meshAnchor, on: node)
            return
        }
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        // Only track vertical planes (walls)
        guard planeAnchor.alignment == .vertical else { return }
        
        wallAnchors[planeAnchor.identifier] = planeAnchor
        wallPlanes[planeAnchor.identifier] = planeAnchor
        
        print("[ARKit] Wall plane detected: \(planeAnchor.identifier) extent: \(planeAnchor.extent)")
        
        // Notify Flutter
        let wallData = planeToDictionary(planeAnchor)
        onWallDetected?(planeAnchor.identifier.uuidString, wallData)
        
        // Auto-select first wall if none selected (the plane overlay is the non-placed fallback)
        if selectedWallId == nil {
            selectedWallId = planeAnchor.identifier
            if placedWalls.isEmpty { updateWallVisualization() }
        }
    }
    
    public func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        if #available(iOS 13.4, *), let meshAnchor = anchor as? ARMeshAnchor {
            updateOccluder(meshAnchor, on: node)
            updateMeshWall(meshAnchor, on: node)
            return
        }
        guard let planeAnchor = anchor as? ARPlaneAnchor,
              planeAnchor.alignment == .vertical else { return }
        
        wallPlanes[planeAnchor.identifier] = planeAnchor
        refineWalls(from: planeAnchor)   // placed walls on this plane follow ARKit's refinement
        
        // Update visualization if this is the selected wall (never while a design is placed by tap)
        if planeAnchor.identifier == selectedWallId && placedWalls.isEmpty {
            updateWallVisualization()
        }
        
        // Notify Flutter
        let wallData = planeToDictionary(planeAnchor)
        onWallUpdated?(planeAnchor.identifier.uuidString, wallData)
    }
    
    public func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor,
              planeAnchor.alignment == .vertical else { return }
        
        wallAnchors.removeValue(forKey: planeAnchor.identifier)
        wallPlanes.removeValue(forKey: planeAnchor.identifier)
        
        // If selected wall was removed, clear selection
        if selectedWallId == planeAnchor.identifier {
            selectedWallId = nil
            textureNode?.removeFromParentNode()
            textureNode = nil
        }
        
        // Notify Flutter
        onWallRemoved?(planeAnchor.identifier.uuidString)
    }
    
    public func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        var state = "UNKNOWN"
        
        switch camera.trackingState {
        case .normal:
            state = "TRACKING"
        case .notAvailable:
            state = "UNAVAILABLE"
        case .limited(let reason):
            switch reason {
            case .excessiveMotion:
                state = "LIMITED_EXCESSIVE_MOTION"
            case .insufficientFeatures:
                state = "LIMITED_INSUFFICIENT_FEATURES"
            case .initializing:
                state = "INITIALIZING"
            case .relocalizing:
                state = "RELOCALIZING"
            @unknown default:
                state = "LIMITED"
            }
        }
        
        print("[ARKit] Tracking state: \(state)")
        onTrackingStateChanged?(state)
        // Placed walls: LOST while tracking is limited, back to TRACKING once it recovers.
        if !placedWalls.isEmpty {
            var normal = false
            if case .normal = camera.trackingState { normal = true }
            onWallStateChanged?(wallState(tracking: normal))
        }
    }
    
    public func session(_ session: ARSession, didFailWithError error: Error) {
        print("[ARKit] Session failed: \(error)")
        onError?(error.localizedDescription)
    }
    
    public func sessionWasInterrupted(_ session: ARSession) {
        print("[ARKit] Session interrupted")
        onTrackingStateChanged?("INTERRUPTED")
        if !placedWalls.isEmpty { onWallStateChanged?("LOST") }
    }

    /// ARKit resumes the session on its own; relocalizing keeps the placed walls' anchors where they were
    /// (the old reset here wiped every placed wall after a phone call or Control Centre).
    public func sessionInterruptionEnded(_ session: ARSession) {
        print("[ARKit] Session interruption ended, relocalizing")
    }

    public func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool { true }
}