import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") version "4.4.4" apply false
}
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}
android {
    namespace = "com.coretegra.snevva"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.coretegra.snevva"
        //minSdk = flutter.minSdkVersion
        minSdk = flutter.minSdkVersion

        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = file(keystoreProperties.getProperty("storeFile"))
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            signingConfig = signingConfigs.getByName("release")

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }


    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true  // <-- Kotlin DSL uses `isCoreLibraryDesugaringEnabled`
    }

    // Migrate deprecated jvmTarget to compilerOptions (Kotlin Gradle plugin 1.7.20+)
    kotlinOptions {
        // ...existing code...
        // Use compilerOptions API when available; fall back to jvmTarget for older plugin versions
        try {
            val compilerOptions = this::class.java.getMethod("getCompilerOptions").invoke(this)
            // If compilerOptions exists, configure jvmTarget via the DSL
            val setJvmTarget = compilerOptions::class.java.getMethod("setJvmTarget", String::class.java)
            setJvmTarget.invoke(compilerOptions, "17")
        } catch (e: Exception) {
            // Fallback for older Kotlin Gradle versions
            jvmTarget = "17"
        }
    }


}
val multiDexVersion by extra("2.0.1")

// Explicit dependency coordinates (replacing version catalog `libs` usage)
val firebaseBomVersion = "32.2.0" // adjust if you need a different BOM version
val firebaseAnalyticsVersion = "com.google.firebase:firebase-analytics-ktx"
val multidexVersion = "androidx.multidex:multidex:2.0.1"
val playServicesAuth = "com.google.android.gms:play-services-auth:20.7.0"
val desugarJdkLibs = "com.android.tools:desugar_jdk_libs:2.1.4"

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:$firebaseBomVersion"))
    implementation(firebaseAnalyticsVersion)

    implementation(multidexVersion)
    implementation(playServicesAuth)

    coreLibraryDesugaring(desugarJdkLibs)
}



flutter {
    source = "../.."
}

subprojects {
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
        options.compilerArgs.add("-Xlint:-options")
    }
}
