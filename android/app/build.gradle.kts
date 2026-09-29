import java.util.Properties

import com.android.build.gradle.LibraryExtension
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Signing rilis — pola sama dengan Android 1.0 (key.properties opsional;
// bila tidak ada, rilis memakai debug key agar build tetap jalan).
val keystoreProperties = Properties().apply {
    val file = file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasKeystore = keystoreProperties.isNotEmpty()

android {
    // Paritas 1.0 (SPEC §17): id aplikasi, minSdk, versi.
    namespace = "com.dompetku.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.dompetku.app"
        minSdk = 24 // sama dengan Android 1.0
        targetSdk = flutter.targetSdkVersion
        // Versi dari pubspec.yaml (1.0.0+1 -> versionName 1.0.0, versionCode 1).
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
