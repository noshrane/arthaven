# Flutter Proguard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ONNX Runtime
-keep class com.masicai.flutteronnxruntime.** { *; }
-keep class ai.onnxruntime.** { *; }

# MediaPipe
-keep class com.google.mediapipe.** { *; }
-keep class com.cornpip.mediapipe_face_mesh.** { *; }

# JNI classes generally
-keepattributes Signature,Exceptions,*Annotation*,InnerClasses
-keepclasseswithmembernames class * {
    native <methods>;
}

# Flutter Play Store Split / Deferred Components (Optional)
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.gms.internal.**
