allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Plugins in the pub cache still declare Java 11 / Kotlin 1.8 targets, and
// Gradle refuses to compile a module whose Java and Kotlin targets disagree
// (flutter_timezone was the first to fail). Pinning every subproject to 17
// — the same level the app itself uses — keeps them consistent without
// touching the plugins' own sources.
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { ext ->
            val android = ext as com.android.build.gradle.BaseExtension
            android.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
            // Same reason, one level up: some plugins are still pinned to
            // compileSdk 33 while their own dependencies demand 34 or later
            // (geocoding_android was the first). The app compiles against 36,
            // so every module does.
            if (project.name != "app") {
                android.compileSdkVersion(36)
            }
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
            .configureEach {
                compilerOptions.jvmTarget.set(
                    org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17,
                )
            }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
