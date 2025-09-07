// C:\dev\chikabooks_app\android\settings.gradle.kts
pluginManagement {

    // flutter.sdk(local.properties) → 없으면 FLUTTER_ROOT 환경변수 사용
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

    // Flutter 그레이들 플러그인 포함
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    // Flutter 로더 플러그인
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
}

include(":app")
