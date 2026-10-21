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
    
    // Placed wall (tap-to-place), see placeWallAtScreenPoint
    private var placedAnchor: ARAnchor?
    private var placedNode: SCNNode?            // the panel (non-LiDAR, or clipping off)
    private var placedFrame: simd_float4x4?     // x = right, y = up, z = normal (toward camera), origin on the wall
    private var placedSurface: String?
    private var meshWallNodes: [UUID: SCNNode] = [:]   // LiDAR: textured wall faces per mesh anchor
    private var wallClippingEnabled = true
    private static let placedWallWidthM: Float = 3.0
    private static let placedWallHeightM: Float = 2.7
    private static let meshWallRangeM: Float = 4.0      // along the wall / up from the anchor
    private static let meshWallDepthM: Float = 0.12     // face must sit this close to the placed plane

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
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        }
        
        // Environment texturing for realistic lighting
        configuration.environmentTexturing = .automatic
        
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
    @objc public func setTexture(_ imageData: Data, patchHeightM: Double = 0) {
        self.currentPatchHeightM = patchHeightM > 0 ? Float(patchHeightM) : ARKitManager.texturePatchHeightM
        textureQueue.async { [weak self] in
            guard let self = self,
                  let texture = self.createMetalTexture(from: imageData) else { return }
            
            self.currentTexture = texture
            
            DispatchQueue.main.async {
                self.updateTextureOnNode(texture)
                self.refreshPlacedWall()
            }
        }
    }
    
    private func createMetalTexture(from imageData: Data) -> MTLTexture? {
        guard let device = MTLCreateSystemDefaultDevice(),
              let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else { return nil }
        
        let textureLoader = MTKTextureLoader(device: device)
        do {
            let texture = try textureLoader.newTexture(cgImage: cgImage, options: [
                .SRGB: false,
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

    private func applyPatchScale(to material: SCNMaterial, texture: MTLTexture, wallWidth: Float, wallHeight: Float) {
        let patchH = currentPatchHeightM
        let patchW = patchH * Float(texture.width) / Float(max(texture.height, 1))
        material.diffuse.contentsTransform = SCNMatrix4MakeScale(wallWidth / patchW, wallHeight / patchH, 1)
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

    // MARK: - Placed wall (tap-to-place)

    /// Places the design on the real surface under a screen point. Raycast order: tracked vertical plane
    /// geometry, then a depth-estimated vertical plane (immediate on LiDAR), then the infinite extension of a
    /// tracked wall. Returns the same shape as the Android plugin: {placed, surface, distanceM, onFloor}.
    @objc public func placeWallAtScreenPoint(_ screenPoint: CGPoint) -> [String: Any]? {
        guard let frame = arSession.currentFrame else { return ["placed": false, "reason": "no_frame"] }
        if case .normal = frame.camera.trackingState {} else { return ["placed": false, "reason": "not_tracking"] }
        let attempts: [(ARRaycastQuery.Target, String)] = [
            (.existingPlaneGeometry, "Plane"), (.estimatedPlane, "estimated"), (.existingPlaneInfinite, "wall_extended"),
        ]
        let camT = frame.camera.transform
        let cam = simd_float3(camT.columns.3.x, camT.columns.3.y, camT.columns.3.z)
        for (target, surface) in attempts {
            guard let query = arSceneView.raycastQuery(from: screenPoint, allowing: target, alignment: .vertical),
                  let hit = arSceneView.session.raycast(query).first else { continue }
            let t = hit.worldTransform
            let p = simd_float3(t.columns.3.x, t.columns.3.y, t.columns.3.z)
            // A raycast result on a vertical plane carries the surface normal in its Y axis.
            var n = simd_float3(t.columns.1.x, t.columns.1.y, t.columns.1.z)
            if simd_dot(n, cam - p) < 0 { n = -n }
            n.y = 0
            if simd_length(n) < 0.05 { continue }   // a wall normal is horizontal
            n = simd_normalize(n)
            let dist = simd_distance(cam, p)
            guard dist > 0.3, dist < 8 else { continue }
            anchorPlacedWall(at: p, normal: n, surface: surface)
            print("[ARKit] PLACE placed=true surface=\(surface) dist=\(String(format: "%.2f", dist))m")
            return ["placed": true, "surface": surface, "distanceM": Double(dist), "onFloor": false]
        }
        print("[ARKit] PLACE placed=false reason=no_hit")
        return ["placed": false, "reason": "no_hit"]
    }

    private func anchorPlacedWall(at p: simd_float3, normal n: simd_float3, surface: String) {
        clearPlacedWall()
        let up = simd_float3(0, 1, 0)
        let right = simd_normalize(simd_cross(up, n))
        let frameM = simd_float4x4(columns: (simd_float4(right, 0), simd_float4(up, 0), simd_float4(n, 0), simd_float4(p, 1)))
        let anchor = ARAnchor(name: "grazia_wall", transform: frameM)
        arSession.add(anchor: anchor)
        placedAnchor = anchor
        placedFrame = frameM
        placedSurface = surface
        // The plane-based overlay would sit on top of the placed design; one wall at a time.
        textureNode?.removeFromParentNode(); textureNode = nil
        refreshPlacedWall()
        onWallStateChanged?("LOCKED")
    }

    /// Rebuilds the panel for the current texture / clipping mode. With LiDAR and clipping on, the stone is
    /// drawn on the reconstructed wall faces instead (see updateMeshWall), so the panel stays hidden.
    private func refreshPlacedWall() {
        placedNode?.removeFromParentNode(); placedNode = nil
        guard let frameM = placedFrame else { return }
        if hasLiDAR && wallClippingEnabled {
            if #available(iOS 13.4, *), let anchors = arSession.currentFrame?.anchors {
                for case let m as ARMeshAnchor in anchors {
                    if let node = arSceneView.node(for: m) { updateMeshWall(m, on: node) }
                }
            }
            return
        }
        let plane = SCNPlane(width: CGFloat(ARKitManager.placedWallWidthM), height: CGFloat(ARKitManager.placedWallHeightM))
        plane.materials = [stoneMaterial(wallWidth: ARKitManager.placedWallWidthM, wallHeight: ARKitManager.placedWallHeightM)]
        let node = SCNNode(geometry: plane)
        var t = frameM
        let n = simd_float3(frameM.columns.2.x, frameM.columns.2.y, frameM.columns.2.z)
        t.columns.3 += simd_float4(n * 0.012, 0)
        node.simdTransform = t
        node.renderingOrder = 0
        arSceneView.scene.rootNode.addChildNode(node)
        placedNode = node
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

    /// LiDAR wall clipping: the faces of [meshAnchor] that ARKit classifies as wall and that lie on the placed
    /// plane get the stone texture, UV-mapped in the wall's own frame so the pattern is continuous across mesh
    /// chunks. Doors, windows, pictures and furniture are other classes (or occluders), so they stay bare.
    @available(iOS 13.4, *)
    fileprivate func updateMeshWall(_ meshAnchor: ARMeshAnchor, on node: SCNNode) {
        let id = meshAnchor.identifier
        guard let frameM = placedFrame, wallClippingEnabled, hasLiDAR, let texture = currentTexture else {
            meshWallNodes[id]?.removeFromParentNode(); meshWallNodes[id] = nil; return
        }
        let mesh = meshAnchor.geometry
        guard let cls = mesh.classification else { return }
        let faces = mesh.faces
        let v = mesh.vertices
        let origin = simd_float3(frameM.columns.3.x, frameM.columns.3.y, frameM.columns.3.z)
        let right = simd_float3(frameM.columns.0.x, frameM.columns.0.y, frameM.columns.0.z)
        let up = simd_float3(frameM.columns.1.x, frameM.columns.1.y, frameM.columns.1.z)
        let normal = simd_float3(frameM.columns.2.x, frameM.columns.2.y, frameM.columns.2.z)
        let toWorld = meshAnchor.transform
        func vertex(_ i: Int) -> simd_float3 {
            let ptr = v.buffer.contents().advanced(by: v.offset + v.stride * i).assumingMemoryBound(to: Float.self)
            let w = toWorld * simd_float4(ptr[0], ptr[1], ptr[2], 1)
            return simd_float3(w.x, w.y, w.z)
        }
        var indices = [UInt32](); indices.reserveCapacity(faces.count * 3)
        for i in 0..<faces.count {
            let raw = cls.buffer.contents().advanced(by: cls.offset + cls.stride * i).assumingMemoryBound(to: UInt8.self).pointee
            guard ARMeshClassification(rawValue: Int(raw)) == .wall else { continue }
            var ids = [UInt32](repeating: 0, count: 3)
            var ok = true
            for j in 0..<3 {
                let at = (i * 3 + j) * faces.bytesPerIndex
                ids[j] = faces.buffer.contents().advanced(by: at).assumingMemoryBound(to: UInt32.self).pointee
                let d = vertex(Int(ids[j])) - origin
                // on the placed plane, and inside the region the design covers
                let along = simd_dot(d, right), rise = simd_dot(d, up)
                if abs(simd_dot(d, normal)) > ARKitManager.meshWallDepthM || abs(along) > ARKitManager.meshWallRangeM
                    || abs(rise) > ARKitManager.meshWallRangeM { ok = false; break }
            }
            if ok { indices.append(contentsOf: ids) }
        }
        guard !indices.isEmpty else { meshWallNodes[id]?.removeFromParentNode(); meshWallNodes[id] = nil; return }

        // Texture coordinates in wall space: one photo patch per (patchW x patchH) metres.
        let patchH = currentPatchHeightM
        let patchW = patchH * Float(texture.width) / Float(max(texture.height, 1))
        var uvs = [simd_float2](repeating: .zero, count: v.count)
        for i in 0..<v.count {
            let d = vertex(i) - origin
            uvs[i] = simd_float2(simd_dot(d, right) / patchW, simd_dot(d, up) / patchH)
        }
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
        let material = SCNMaterial()
        material.diffuse.contents = texture
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .repeat
        material.lightingModel = .constant
        material.isDoubleSided = true
        geometry.materials = [material]
        if let existing = meshWallNodes[id] {
            existing.geometry = geometry
        } else {
            let wallNode = SCNNode(geometry: geometry)
            wallNode.renderingOrder = 1   // after the occluders of the same mesh (-10)
            // mesh vertices are anchor-local; the anchor node already carries the anchor transform
            node.addChildNode(wallNode)
            meshWallNodes[id] = wallNode
        }
    }

    @objc public func clearPlacedWall() {
        placedNode?.removeFromParentNode(); placedNode = nil
        meshWallNodes.values.forEach { $0.removeFromParentNode() }
        meshWallNodes.removeAll()
        if let a = placedAnchor { arSession.remove(anchor: a) }
        placedAnchor = nil
        placedFrame = nil
        placedSurface = nil
    }

    @objc public func setWallClipping(_ enabled: Bool) {
        wallClippingEnabled = enabled
        if !enabled {
            meshWallNodes.values.forEach { $0.removeFromParentNode() }
            meshWallNodes.removeAll()
        }
        refreshPlacedWall()
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
        
        guard let wallId = selectedWallId,
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

        node.renderingOrder = 0   // after the LiDAR occluders (-10), so furniture hides the overlay
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
        var indices = [UInt32]()
        indices.reserveCapacity(faces.count * 3)
        for i in 0..<faces.count {
            let raw = cls.buffer.contents().advanced(by: cls.offset + cls.stride * i).assumingMemoryBound(to: UInt8.self).pointee
            guard let kind = ARMeshClassification(rawValue: Int(raw)) else { continue }
            if kind == .none || kind == .wall || kind == .floor || kind == .ceiling { continue }
            for j in 0..<3 {
                let at = (i * 3 + j) * faces.bytesPerIndex
                indices.append(faces.buffer.contents().advanced(by: at).assumingMemoryBound(to: UInt32.self).pointee)
            }
        }
        guard !indices.isEmpty else { node.geometry = nil; return }

        let v = mesh.vertices
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
        node.geometry = geometry
        node.renderingOrder = -10
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
            "confidence": 0.9, // ARKit doesn't expose confidence directly
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
        guard let selectedWallId = selectedWallId,
              let plane = wallPlanes[selectedWallId] else { return nil }
        
        // Wall dimensions in meters
        let wallWidthM = plane.extent.x
        let wallHeightM = plane.extent.z
        let wallAreaM2 = wallWidthM * wallHeightM
        
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
        
        // Convert back to requested unit for display
        var displayWallWidth = wallWidthM
        var displayWallHeight = wallHeightM
        var displayUnit = "m"
        switch tileUnit {
        case "ft":
            displayWallWidth = wallWidthM / 0.3048
            displayWallHeight = wallHeightM / 0.3048
            displayUnit = "ft"
        case "in":
            displayWallWidth = wallWidthM / 0.0254
            displayWallHeight = wallHeightM / 0.0254
            displayUnit = "in"
        case "cm":
            displayWallWidth = wallWidthM * 100.0
            displayWallHeight = wallHeightM * 100.0
            displayUnit = "cm"
        case "mm":
            displayWallWidth = wallWidthM * 1000.0
            displayWallHeight = wallHeightM * 1000.0
            displayUnit = "mm"
        default:
            displayUnit = "m"
        }
        
        return [
            "wallWidth": displayWallWidth,
            "wallHeight": displayWallHeight,
            "wallArea": wallAreaM2,
            "tileWidth": tileWidthM,
            "tileHeight": tileHeightM,
            "tileArea": tileAreaM2,
            "baseQuantity": baseQuantity,
            "wastagePercent": wastagePercent,
            "recommendedQuantity": recommendedQuantity,
            "unit": displayUnit,
            "isCalibrated": pixelsPerMeter > 0,
            "calibrationUnit": calibrationUnit
        ]
    }
    
    // MARK: - Wall State
    
    @objc public func getWallState() -> String {
        var state = "SEARCHING"
        
        if placedAnchor != nil {
            state = "TRACKING"
        } else if wallPlanes.isEmpty {
            state = "SEARCHING"
        } else if selectedWallId != nil, wallPlanes[selectedWallId!] != nil {
            state = "TRACKING"
        } else {
            state = "DETECTING"
        }
        
        onWallStateChanged?(state)
        return state
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
            if placedAnchor == nil { updateWallVisualization() }
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
        
        // Update visualization if this is the selected wall (never while a design is placed by tap)
        if planeAnchor.identifier == selectedWallId && placedAnchor == nil {
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
    }
    
    public func session(_ session: ARSession, didFailWithError error: Error) {
        print("[ARKit] Session failed: \(error)")
        onError?(error.localizedDescription)
    }
    
    public func sessionWasInterrupted(_ session: ARSession) {
        print("[ARKit] Session interrupted")
        onTrackingStateChanged?("INTERRUPTED")
    }
    
    public func sessionInterruptionEnded(_ session: ARSession) {
        print("[ARKit] Session interruption ended")
        // Restart session
        let configuration = createConfiguration()
        arSession.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
}