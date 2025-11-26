# ---- Flutter Core ----
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.util.** { *; }

# ---- Flutter Background Service ----
-keep class id.flutter.flutter_background_service.** { *; }

# ---- Local Notifications ----
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# ---- Hive ----
-keep class com.example.hive.** { *; }
-keepclassmembers class * extends io.flutter.embedding.engine.plugins.FlutterPlugin { *; }

# ---- Prevent warnings ----
-dontwarn io.flutter.**
-dontwarn androidx.lifecycle.DefaultLifecycleObserver
