import java.util.Properties
import java.io.FileInputStream

/************* 플러그인 영역 *************/
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")      // ← Google Services 플러그인
    id("dev.flutter.flutter-gradle-plugin") // ← Flutter Gradle 플러그인
}

/************* 로컬 프로퍼티 로드 *************/
fun localProperties(): Properties = Properties().apply {
    val propFile = rootProject.file("local.properties")
    if (propFile.exists()) {
        FileInputStream(propFile).use { load(it) }
    }
}

val flutterProps = localProperties()
val flutterVersionCode = flutterProps.getProperty("flutter.versionCode")?.toInt() ?: 1
val flutterVersionName = flutterProps.getProperty("flutter.versionName") ?: "1.0.0"

/************* Android 설정 *************/
android {
    namespace = "com.chikabooks.appnew"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.chikabooks.appnew"
        minSdk = 23
        targetSdk = 35
        versionCode = flutterVersionCode
        versionName = flutterVersionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = "11"
    }

    sourceSets["main"].java.srcDirs("src/main/kotlin")

    buildTypes {
        release {
            // 릴리스 전용키 없을 때는 debug 로 임시 서명
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

/************* Flutter 소스 위치 *************/
flutter {
    source = "../.."
}

/************* 의존성 *************/
dependencies {
    // Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:33.15.0"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth-ktx")
    implementation("com.google.android.gms:play-services-auth")
}
