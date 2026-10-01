# Flutter's own engine classes are reached by reflection from the embedding.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# flutter_local_notifications keeps its scheduled payloads as Gson-serialised
# classes; stripping their fields loses every pending reminder on upgrade.
-keep class com.dexterous.** { *; }

# Play Core is referenced by the Flutter embedding's deferred-components code,
# which this app does not use. Without these the release build fails to link.
-dontwarn com.google.android.play.core.**

# ONNX Runtime (the prayer-mat scan). Its native library looks Java classes
# up by name over JNI — ai/onnxruntime/OnnxTensor and friends — so renaming
# or removing them makes the first scan abort the whole app.
-keep class ai.onnxruntime.** { *; }
-keepclasseswithmembernames class ai.onnxruntime.** { native <methods>; }

# Gson, used by flutter_local_notifications to store scheduled reminders.
# Its TypeToken reads generic signatures at runtime; stripped, the boot and
# app-update receiver crashed the app and every pending reminder was lost.
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
