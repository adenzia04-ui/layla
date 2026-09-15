# Flutter's own engine classes are reached by reflection from the embedding.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# flutter_local_notifications keeps its scheduled payloads as Gson-serialised
# classes; stripping their fields loses every pending reminder on upgrade.
-keep class com.dexterous.** { *; }

# Play Core is referenced by the Flutter embedding's deferred-components code,
# which this app does not use. Without these the release build fails to link.
-dontwarn com.google.android.play.core.**
