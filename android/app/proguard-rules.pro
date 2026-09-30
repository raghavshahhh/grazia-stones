# Only used when building with -PenableMinify=true.
# Flutter engine/plugins ship their own consumer rules; these cover the native AR stack.
-keep class com.google.ar.** { *; }
-keep class io.github.sceneview.** { *; }
-keep class com.google.android.filament.** { *; }
-keep class com.graziastones.grazia_stones.** { *; }
-dontwarn com.google.ar.**
-dontwarn com.google.android.filament.**
-dontwarn io.github.sceneview.**
-dontwarn kotlinx.coroutines.**
