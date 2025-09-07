// android/settings.gradle.kts  (전체)
import java.util.Properties
import java.io.FileInputStream

pluginManagement {
    // 1) local.properties에서 flutter.sdk 읽기
    val localProps = Properties().apply {
        val f = File(rootDir, "local.properties")
        if (f.exists()) FileInputStream(f).use { load(it) }
    }

    // 2) 경로 우선순위: local.properties(flutter.sdk) → 환경변수(FLUTTER_ROOT)
    val flutterSdkPath: String = (
        localProps.getProperty("flutter.sdk")
            ?: System.getenv("FLUTTER_ROOT")
    ) ?: error(
        """
        ───────────────────────────────────────────────
        flutter.sdk 를 android/local.properties 에 적어주세요.
        또는 FLUTTER_ROOT 환경변수를 설정해 주세요.
        예)
          flutter.sdk=C:\\SDK\\2nd_account\\flutter
        ───────────────────────────────────────────────
        """.trimIndent()
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
