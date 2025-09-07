// Flutter 플러그인 로더를 '원격 저장소'가 아니라
// 프로젝트의 .dart_tool/flutter_build 에서 찾도록 연결
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
    // ★ 이 줄이 핵심: dev.flutter.flutter-plugin-loader 를 로컬 includeBuild로 제공
    includeBuild("../.dart_tool/flutter_build")
}

// Flutter가 요구하는 로더 플러그인 선언
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
}

// 일반 의존성 저장소
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "chikabooks_app"
include(":app")
