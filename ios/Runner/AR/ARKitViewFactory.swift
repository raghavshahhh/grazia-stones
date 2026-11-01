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

/// Holds the shared ARSCNView and sizes it to its own bounds on every layout. The view used to sit straight in
/// Flutter's platform-view slot with flexible autoresizing; reused across sessions and first laid out at zero
/// size, it was once scaled to 56128 px wide and SceneKit aborted allocating that render target (2026-10-30).
private final class ARKitContainerView: UIView {
    let sceneView: ARSCNView
    init(frame: CGRect, sceneView: ARSCNView) {
        self.sceneView = sceneView
        super.init(frame: frame)
        sceneView.removeFromSuperview()
        sceneView.autoresizingMask = []
        sceneView.frame = bounds
        addSubview(sceneView)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
    override func layoutSubviews() {
        super.layoutSubviews()
        if sceneView.superview !== self { addSubview(sceneView) }
        sceneView.frame = bounds
    }
}

class ARKitPlatformView: NSObject, FlutterPlatformView {
    private let container: ARKitContainerView
    private let manager: ARKitManager
    
    init(frame: CGRect, viewId: Int64, manager: ARKitManager) {
        self.manager = manager
        self.container = ARKitContainerView(frame: frame, sceneView: manager.sceneView)
        super.init()
    }
    
    func view() -> UIView {
        return container
    }
}