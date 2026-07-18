import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Tracked synthetic defaults at repo root; optional local overrides only.
// applicationId remains D1-owned in this file until AF-013 wires placeholders.
val agentForgeProps = Properties().apply {
    val tracked = rootProject.file("../agentforge-config.properties")
    require(tracked.exists()) {
        "missing tracked agentforge-config.properties (synthetic defaults)"
    }
    tracked.inputStream().use { load(it) }
    val local = rootProject.file("../agentforge-config.local.properties")
    if (local.exists()) local.inputStream().use { load(it) }
}

android {
    namespace = "com.avidullu.agentforge"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.avidullu.agentforge"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Available for AF-013+ manifest placeholders; unused by product yet.
        manifestPlaceholders["agentforgeHost"] =
            agentForgeProps.getProperty("forgejo.host", "forge.example.test")
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
