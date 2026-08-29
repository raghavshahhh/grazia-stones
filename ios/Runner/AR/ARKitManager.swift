//  ARKitManager.swift
//  GraziaStones
//
//  Native ARKit implementation for wall detection, tracking, and visualization.
//  Supports LiDAR depth, scene reconstruction, and world anchors.

import Foundation
import ARKit
import SceneKit
import MetalKit

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
    
    // Texture management
    private var currentTexture: MTLTexture?
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
    
    @objc public func setTexture(_ imageData: Data) {
        textureQueue.async { [weak self] in
            guard let self = self,
                  let texture = self.createMetalTexture(from: imageData) else { return }
            
            self.currentTexture = texture
            
            DispatchQueue.main.async {
                self.updateTextureOnNode(texture)
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
    
    private func updateTextureOnNode(_ texture: MTLTexture) {
        guard let textureNode = textureNode else { return }
        
        // Update the material's diffuse texture
        if let material = textureNode.geometry?.firstMaterial {
            material.diffuse.contents = texture
            material.diffuse.wrapS = .repeat
            material.diffuse.wrapT = .repeat
            material.isDoubleSided = true
        }
    }
    
    @objc public func clearTexture() {
        textureQueue.async { [weak self] in
            self?.currentTexture = nil
            DispatchQueue.main.async {
                self?.textureNode?.geometry?.firstMaterial?.diffuse.contents = nil
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
    @objc public func hitTestWallAtScreenPoint(_ screenPoint: CGPoint) -> [String: Any]? {
        let results = arSceneView.hitTest(screenPoint, types: [.existingPlaneUsingGeometry, .existingPlaneUsingExtent])

        // Prefer a hit on the currently selected wall; fall back to any vertical plane hit.
        let preferred = results.first { result in
            guard let planeAnchor = result.anchor as? ARPlaneAnchor,
                  planeAnchor.alignment == .vertical else { return false }
            return selectedWallId == nil || planeAnchor.identifier == selectedWallId
        }

        guard let hit = preferred ?? results.first(where: { ($0.anchor as? ARPlaneAnchor)?.alignment == .vertical }) else {
            return nil
        }

        let worldTransform = hit.worldTransform
        let point = simd_float3(worldTransform.columns.3.x, worldTransform.columns.3.y, worldTransform.columns.3.z)
        let anchorId = addMeasurementPoint(point)
        addMeasurementMarkerNode(at: point, anchorId: anchorId)

        return [
            "anchorId": anchorId,
            "x": point.x,
            "y": point.y,
            "z": point.z,
        ]
    }

    private func addMeasurementMarkerNode(at point: simd_float3, anchorId: String) {
        guard let uuid = UUID(uuidString: anchorId) else { return }

        let sphere = SCNSphere(radius: 0.012)
        sphere.firstMaterial?.diffuse.contents = UIColor.systemYellow
        sphere.firstMaterial?.emission.contents = UIColor.systemYellow.withAlphaComponent(0.6)
        let node = SCNNode(geometry: sphere)
        node.position = SCNVector3(point.x, point.y, point.z)

        arSceneView.scene.rootNode.addChildNode(node)
        measurementNodes[uuid] = node

        // If this is the second point, draw a connecting line and cache the distance.
        if let start = measurementStartPoint, let end = measurementEndPoint {
            drawMeasurementLine(from: start, to: end)
        }
    }

    private func drawMeasurementLine(from start: simd_float3, to end: simd_float3) {
        measurementLineNode?.removeFromParentNode()

        let lineGeometry = SCNCylinder(radius: 0.003, height: CGFloat(distance(start, end)))
        lineGeometry.firstMaterial?.diffuse.contents = UIColor.systemYellow
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
        
        // Create plane geometry matching wall dimensions
        let width = CGFloat(plane.extent.x)
        let height = CGFloat(plane.extent.y)
        
        let planeGeometry = SCNPlane(width: width, height: height)
        planeGeometry.cornerRadius = 0.02
        
        let node = SCNNode(geometry: planeGeometry)
        node.position = SCNVector3(plane.center.x, plane.center.y, plane.center.z)
        node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0) // Rotate to vertical
        node.transform = SCNMatrix4(plane.transform)
        
        // Apply texture if available
        if let texture = currentTexture {
            let material = SCNMaterial()
            material.diffuse.contents = texture
            material.diffuse.wrapS = .repeat
            material.diffuse.wrapT = .repeat
            material.isDoubleSided = true
            planeGeometry.materials = [material]
        } else {
            // Placeholder material
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.systemYellow.withAlphaComponent(0.5)
            planeGeometry.materials = [material]
        }
        
        // Add wireframe outline
        let outlineGeometry = SCNPlane(width: width + 0.02, height: height + 0.02)
        outlineGeometry.cornerRadius = 0.03
        let outlineNode = SCNNode(geometry: outlineGeometry)
        outlineNode.position = node.position
        outlineNode.eulerAngles = node.eulerAngles
        outlineNode.transform = node.transform
        
        let outlineMaterial = SCNMaterial()
        outlineMaterial.diffuse.contents = UIColor.systemYellow
        outlineMaterial.fillMode = .lines
        outlineGeometry.materials = [outlineMaterial]
        
        arSceneView.scene.rootNode.addChildNode(outlineNode)
        arSceneView.scene.rootNode.addChildNode(node)
        
        textureNode = node
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
    
    public func measureDistance(_ screenPoint1: CGPoint, _ screenPoint2: CGPoint) -> Float? {
        guard pixelsPerMeter > 0 else { return nil }
        
        // Hit test both points against wall planes
        let hit1 = arSceneView.hitTest(screenPoint1, types: [.existingPlaneUsingGeometry, .existingPlaneUsingExtent])
            .first(where: { ($0.anchor as? ARPlaneAnchor)?.alignment == .vertical })
        let hit2 = arSceneView.hitTest(screenPoint2, types: [.existingPlaneUsingGeometry, .existingPlaneUsingExtent])
            .first(where: { ($0.anchor as? ARPlaneAnchor)?.alignment == .vertical })
        
        guard let h1 = hit1, let h2 = hit2 else { return nil }
        
        let p1 = simd_float3(h1.worldTransform.columns.3.x, h1.worldTransform.columns.3.y, h1.worldTransform.columns.3.z)
        let p2 = simd_float3(h2.worldTransform.columns.3.x, h2.worldTransform.columns.3.y, h2.worldTransform.columns.3.z)
        
        let worldDistance = simd_distance(p1, p2)
        return worldDistance
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
        
        if wallPlanes.isEmpty {
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
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        // Only track vertical planes (walls)
        guard planeAnchor.alignment == .vertical else { return }
        
        wallAnchors[planeAnchor.identifier] = planeAnchor
        wallPlanes[planeAnchor.identifier] = planeAnchor
        
        print("[ARKit] Wall plane detected: \(planeAnchor.identifier) extent: \(planeAnchor.extent)")
        
        // Notify Flutter
        let wallData = planeToDictionary(planeAnchor)
        onWallDetected?(planeAnchor.identifier.uuidString, wallData)
        
        // Auto-select first wall if none selected
        if selectedWallId == nil {
            selectedWallId = planeAnchor.identifier
            updateWallVisualization()
        }
    }
    
    public func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor,
              planeAnchor.alignment == .vertical else { return }
        
        wallPlanes[planeAnchor.identifier] = planeAnchor
        
        // Update visualization if this is the selected wall
        if planeAnchor.identifier == selectedWallId {
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