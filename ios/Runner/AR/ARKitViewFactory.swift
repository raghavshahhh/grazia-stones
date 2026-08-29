//  ARKitViewFactory.swift
//  GraziaStones
//
//  Factory for creating ARSCNView platform views for Flutter.

import Flutter
import ARKit
import SceneKit

class ARKitViewFactory: NSObject, FlutterPlatformViewFactory {
    private let arKitManager = ARKitManager.shared
    
    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return ARKitPlatformView(frame: frame, viewId: viewId, manager: arKitManager)
    }
    
    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

class ARKitPlatformView: NSObject, FlutterPlatformView {
    private let arSceneView: ARSCNView
    private let manager: ARKitManager
    
    init(frame: CGRect, viewId: Int64, manager: ARKitManager) {
        self.manager = manager
        self.arSceneView = manager.sceneView
        super.init()
        
        arSceneView.frame = frame
        arSceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    
    func view() -> UIView {
        return arSceneView
    }
}