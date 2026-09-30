plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.graziastones.grazia_stones"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.graziastones.grazia_stones"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24 // ARCore requires minSdk 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val keyPasswordVal = keystoreProperties.getProperty("keyPassword")
            val keyAliasVal = keystoreProperties.getProperty("keyAlias")
            val storePasswordVal = keystoreProperties.getProperty("storePassword")
            val storeFileVal = keystoreProperties.getProperty("storeFile")
            if (keyPasswordVal != null && keyAliasVal != null && storePasswordVal != null && storeFileVal != null) {
                keyAlias = keyAliasVal
                keyPassword = keyPasswordVal
                storeFile = file(storeFileVal)
                storePassword = storePasswordVal
            }
        }
    }

    buildTypes {
        release {
            val releaseSigning = signingConfigs.getByName("release")
            signingConfig = if (releaseSigning.storeFile != null && releaseSigning.storeFile!!.exists()) {
                releaseSigning
            } else {
                // Local `flutter run --release` convenience only. bundleRelease
                // refuses to run without a real keystore (see below).
                signingConfigs.getByName("debug")
            }

            // Opt-in until verified on a device: R8 can strip ARCore/Filament
            // reflection targets. Try with `flutter build appbundle -PenableMinify=true`.
            if (project.hasProperty("enableMinify")) {
                isMinifyEnabled = true
                isShrinkResources = true
                proguardFiles(
                    getDefaultProguardFile("proguard-android-optimize.txt"),
                    "proguard-rules.pro"
                )
            }
        }
    }
}

// A Play Store upload must never be debug-signed: fail loudly instead of
// silently producing an AAB Play will reject. Match the app's own task path only:
// substring matching also hits plugin tasks like `bundleReleaseAar` that appear in
// ordinary `assembleRelease` (apk) builds.
gradle.taskGraph.whenReady {
    val releaseSigning = android.signingConfigs.getByName("release")
    val hasRealKey = releaseSigning.storeFile?.exists() == true
    if (!hasRealKey && allTasks.any { it.path == ":app:bundleRelease" }) {
        throw GradleException(
            "bundleRelease needs a real upload keystore. Create android/key.properties " +
                "(see android/key.properties.example and scripts/generate_upload_keystore.sh)."
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // ARCore
    implementation("com.google.ar:core:1.38.0")

    // SceneView — ARCore + Filament wrapped in a Kotlin-friendly View
    // (ARSceneView, PlaneNode, AnchorNode, MaterialLoader). Real plane
    // detection, anchors and texture mapping for the Android AR path;
    // replaces the honest-stub ARCoreManager.
    implementation("io.github.sceneview:arsceneview:2.3.0")

    // CameraX for camera preview
    implementation("androidx.camera:camera-core:1.3.1")
    implementation("androidx.camera:camera-camera2:1.3.1")
    implementation("androidx.camera:camera-lifecycle:1.3.1")
    implementation("androidx.camera:camera-view:1.3.1")

    // Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")

    // Lifecycle
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
}

flutter {
    source = "../.."
}