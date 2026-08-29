import Flutter
import UIKit
import ARKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register ARKit platform view factory + method channel plugin.
    // `registrar` can be nil here (e.g. a debug build launched without Flutter
    // tooling attached, before the Flutter engine exists) — skip registration
    // rather than crashing; GeneratedPluginRegistrant re-registers everything
    // once the implicit engine is actually created (see didInitializeImplicitFlutterEngine).
    if let registrar = self.registrar(forPlugin: "ARKitPlugin") {
      registrar.register(ARKitViewFactory(), withId: "com.graziastones.ar/arkit_view")
      ARKitPlugin.register(with: registrar)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}