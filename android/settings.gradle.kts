// C:\dev\chikabooks_app\android\settings.gradle.kts
pluginManagement {
    // flutter.sdk (gradle.properties) → 없으면 FLUTTER_ROOT
    val flutterSdkPath: String = providers
        .gradleProperty("flutter.sdk")
        .orNull
        ?: System.getenv("FLUTTER_ROOT")
        ?: error(
            "flutter.sdk 가 gradle.properties 에 없고, FLUTTER_ROOT 환경변수도 없습니다."
        )

    // Flutter Gradle 플러그인 포함
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.21" apply false
}

include(":app")
