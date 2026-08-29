package com.graziastones.grazia_stones

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import com.graziastones.grazia_stones.ar.ARCorePlugin
import com.graziastones.grazia_stones.ar.ARCoreViewFactory

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        // Register ARCore platform view factory
        val registrar = flutterEngine.platformViewsController.registry
        registrar.registerViewFactory(
            "com.graziastones.ar/arcore_view",
            ARCoreViewFactory(flutterEngine.dartExecutor.binaryMessenger)
        )

        // Register ARCore method channel plugin
        ARCorePlugin.registerWith(flutterEngine.plugins)
    }
}