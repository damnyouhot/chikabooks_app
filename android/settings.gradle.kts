// C:\dev\chikabooks_app\android\settings.gradle.kts

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

// [수정] 이 파일의 맨 아래에 중복으로 존재하던 pluginManagement 블록을 완전히 삭제했습니다.