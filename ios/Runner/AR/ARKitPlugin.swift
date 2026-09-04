//  ARKitPlugin.swift
//  GraziaStones
//
//  Flutter method channel handler for ARKit native functionality.

import Flutter
import ARKit
import SceneKit
import MetalKit

public class ARKitPlugin: NSObject, FlutterPlugin {
    private let arKitManager = ARKitManager.shared
    private var eventSink: FlutterEventSink?
    private let channelName = "com.graziastones.ar/native"
    private let eventChannelName = "com.graziastones.ar/events"
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = ARKitPlugin()
        
        // Method channel
        let methodChannel = FlutterMethodChannel(name: instance.channelName, binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        
        // Event channel
        let eventChannel = FlutterEventChannel(name: instance.eventChannelName, binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)
        
        // Set up callbacks
        instance.setupCallbacks()
        
        print("[ARKitPlugin] Registered with Flutter")
    }
    
    private func setupCallbacks() {
        arKitManager.onWallDetected = { [weak self] wallId, data in
            self?.sendEvent(type: "wallDetected", data: ["id": wallId, "data": data])
        }
        
        arKitManager.onWallUpdated = { [weak self] wallId, data in
            self?.sendEvent(type: "wallUpdated", data: ["id": wallId, "data": data])
        }
        
        arKitManager.onWallRemoved = { [weak self] wallId in
            self?.sendEvent(type: "wallRemoved", data: ["id": wallId])
        }
        
        arKitManager.onTrackingStateChanged = { [weak self] state in
            self?.sendEvent(type: "trackingStateChanged", data: ["state": state])
        }
        
        arKitManager.onWallStateChanged = { [weak self] state in
            self?.sendEvent(type: "wallStateChanged", data: ["state": state])
        }
        
        arKitManager.onMeasurementResult = { [weak self] data in
            self?.sendEvent(type: "measurementResult", data: data)
        }
        
        arKitManager.onError = { [weak self] error in
            self?.sendEvent(type: "error", data: ["message": error])
        }
    }
    
    private func sendEvent(type: String, data: [String: Any]) {
        let event: [String: Any] = ["type": type, "data": data]
        eventSink?(event)
    }
}

// MARK: - FlutterPlugin

extension ARKitPlugin {
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startSession":
            arKitManager.startSession()
            result(nil)
            
        case "pauseSession":
            arKitManager.pauseSession()
            result(nil)

        // Dart calls this on teardown; without a case here the channel raised
        // MissingPluginException every time the AR screen was closed.
        case "stopCamera":
            arKitManager.pauseSession()
            result(nil)
            
        case "resumeSession":
            arKitManager.resumeSession()
            result(nil)
            
        case "selectWall":
            if let args = call.arguments as? [String: Any],
               let wallId = args["wallId"] as? String {
                arKitManager.selectWall(wallId)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing wallId", details: nil))
            }
            
        case "getWalls":
            let walls = arKitManager.getWalls()
            result(walls)
            
        case "getSelectedWallId":
            result(arKitManager.getSelectedWallId())
            
        case "setTexture":
            if let args = call.arguments as? [String: Any],
               let imageData = args["imageData"] as? FlutterStandardTypedData {
                arKitManager.setTexture(imageData.data)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing imageData", details: nil))
            }
            
        case "clearTexture":
            arKitManager.clearTexture()
            result(nil)
            
        case "startMeasurement":
            arKitManager.startMeasurement()
            result(nil)
            
        case "addMeasurementPoint":
            if let args = call.arguments as? [String: Any],
               let x = args["x"] as? Double,
               let y = args["y"] as? Double,
               let z = args["z"] as? Double {
                let point = simd_float3(Float(x), Float(y), Float(z))
                let anchorId = arKitManager.addMeasurementPoint(point)
                result(anchorId)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing point coordinates", details: nil))
            }

        case "hitTestWallAtScreenPoint":
            if let args = call.arguments as? [String: Any],
               let sx = args["screenX"] as? Double,
               let sy = args["screenY"] as? Double {
                let hit = arKitManager.hitTestWallAtScreenPoint(CGPoint(x: sx, y: sy))
                result(hit)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing screen coordinates", details: nil))
            }
            
        case "getMeasurementDistance":
            if let distance = arKitManager.getMeasurementDistance() {
                result(distance)
            } else {
                result(nil)
            }
            
        case "clearMeasurement":
            arKitManager.clearMeasurement()
            result(nil)
            
        case "isARSupported":
            let supported = ARWorldTrackingConfiguration.isSupported
            result(supported)
            
        case "hasLiDAR":
            if #available(iOS 13.4, *) {
                result(ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh))
            } else {
                result(false)
            }
            
        case "startCalibration":
            if let args = call.arguments as? [String: Any],
               let unit = args["unit"] as? String {
                arKitManager.startCalibration(unit)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing unit", details: nil))
            }
            
        case "finishCalibration":
            if let args = call.arguments as? [String: Any],
               let realLength = args["realLength"] as? Double {
                let success = arKitManager.finishCalibration(Float(realLength))
                result(success)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing realLength", details: nil))
            }
            
        case "getCalibration":
            if let calibration = arKitManager.getCalibration() {
                result(calibration)
            } else {
                result(nil)
            }
            
        case "measureDistance":
            if let args = call.arguments as? [String: Any],
               let x1 = args["x1"] as? Double,
               let y1 = args["y1"] as? Double,
               let x2 = args["x2"] as? Double,
               let y2 = args["y2"] as? Double {
                let distance = arKitManager.measureDistance(CGPoint(x: x1, y: y1), CGPoint(x: x2, y: y2))
                result(distance)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing screen coordinates", details: nil))
            }
            
        case "calculateTileQuantity":
            if let args = call.arguments as? [String: Any],
               let tileWidth = args["tileWidth"] as? Double,
               let tileHeight = args["tileHeight"] as? Double {
                let tileUnit = args["tileUnit"] as? String ?? "ft"
                let wastagePercent = args["wastagePercent"] as? Double ?? 10.0
                let quantity = arKitManager.calculateTileQuantity(
                    tileWidth: Float(tileWidth),
                    tileHeight: Float(tileHeight),
                    tileUnit: tileUnit,
                    wastagePercent: Float(wastagePercent)
                )
                result(quantity)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing tile dimensions", details: nil))
            }
            
        case "getWallState":
            let state = arKitManager.getWallState()
            result(state)
            
        case "preloadTexture":
            if let args = call.arguments as? [String: Any],
               let textureUrl = args["textureUrl"] as? String {
                arKitManager.preloadTexture(textureUrl)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing textureUrl", details: nil))
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

// MARK: - FlutterStreamHandler

extension ARKitPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        print("[ARKitPlugin] Event stream started")
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        print("[ARKitPlugin] Event stream cancelled")
        return nil
    }
}