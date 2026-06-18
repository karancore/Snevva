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


# Google Sign-In
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.signin.** { *; }
-keep class com.google.android.gms.tasks.** { *; }

# Firebase Auth
-keep class com.google.firebase.auth.** { *; }

# Play Services Auth
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.auth.api.credentials.** { *; }

# Flutter Google Sign In plugin
-keep class io.flutter.plugins.googlesignin.** { *; }