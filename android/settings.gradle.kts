pluginManagement {
    val flutterSdkPath: String =
        providers.gradleProperty("flutter.sdk")
            .orNull
            ?: System.getenv("FLUTTER_ROOT")
            ?: error(
                """
                ───────────────────────────────────────────────
                 flutter.sdk 가 local.properties 에 없고
                FLUTTER_ROOT 환경변수도 없습니다.
                ───────────────────────────────────────────────
                """.trimIndent()
            )

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
}

include(":app")