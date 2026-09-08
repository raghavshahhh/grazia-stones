import Flutter
import UIKit
import ARKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private func registerARPlugin(with registry: FlutterPluginRegistry) {
    if let registrar = registry.registrar(forPlugin: "ARKitPlugin") {
      registrar.register(ARKitViewFactory(), withId: "com.graziastones.ar/arkit_view")
      ARKitPlugin.register(with: registrar)
      print("[AppDelegate] ARKitPlugin and ARKitViewFactory registered")
    }
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // ARKitPlugin registration happens once, in didInitializeImplicitFlutterEngine
    // below — that's where GeneratedPluginRegistrant also registers. Calling
    // registerARPlugin(with: self) here too hit the same underlying registry a
    // second time and crashed every launch with "Duplicate plugin key: ARKitPlugin".
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerARPlugin(with: engineBridge.pluginRegistry)
  }
}