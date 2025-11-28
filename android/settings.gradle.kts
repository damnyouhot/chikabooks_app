// android/settings.gradle.kts

pluginManagement {
    val flutterSdkPath = runCatching {
        val properties = java.util.Properties()
        properties.load(java.io.File(settingsDir, "local.properties").inputStream())
        properties.getProperty("flutter.sdk")
    }.getOrNull()

    if (flutterSdkPath != null) {
        includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")
    }

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.0" apply false // 버전은 자동생성된 것 유지
    id("org.jetbrains.kotlin.android") version "1.8.22" apply false // 버전은 자동생성된 것 유지
    
    // [▼ 이 줄을 추가해주세요]
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")