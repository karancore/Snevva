import com.android.build.api.variant.LibraryAndroidComponentsExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
    // Force a consistent desugar_jdk_libs version across all modules to satisfy AAR metadata checks
    configurations.all {
        resolutionStrategy.force("com.android.tools:desugar_jdk_libs:2.1.4")
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Temporary workaround: disable unit test task creation for audioplayers_android
// This prevents a third-party plugin in the audioplayers_android package from
// failing during project configuration. Keep this temporary and remove after
// upgrading the plugin or toolchain.
gradle.projectsEvaluated {
    rootProject.subprojects.find { it.name == "audioplayers_android" }?.let { proj ->
        proj.tasks.matching { task ->
            val n = task.name.lowercase()
            n.endsWith("unittest") || n.endsWith("debugunittest") || n.contains("test")
        }.configureEach {
            enabled = false
        }
    }
}

subprojects {
    if (name == "audioplayers_android") {
        plugins.withId("com.android.library") {
            extensions.configure(LibraryAndroidComponentsExtension::class.java) {
                beforeVariants(selector().all()) { variantBuilder ->
                    variantBuilder.enableUnitTest = false
                }
            }
        }
    }

    if (name == "camera_android_camerax") {
        afterEvaluate {
            dependencies.add("implementation", "androidx.concurrent:concurrent-futures:1.2.0")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
