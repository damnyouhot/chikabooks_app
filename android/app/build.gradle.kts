plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

import java.util.Properties
import java.io.FileInputStream

android {
    // [핵심 1] 소스 코드의 실제 폴더 위치 (이걸 바꿔버리면 파일을 못 찾아서 에러가 납니다)
    namespace = "com.example.chikabooks_app"
    
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // [핵심 2] 앱의 진짜 ID (Firebase의 google-services.json 패키지명과 일치)
        applicationId = "com.chikabooks.tenth"
        
        minSdk = 23
        targetSdk = 36 // SDK 36으로 통일
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // 🔐 Google Maps API Key를 local.properties에서 읽어서 AndroidManifest에 전달
        val localProperties = Properties()
        val localPropertiesFile = rootProject.file("local.properties")
        if (localPropertiesFile.exists()) {
            FileInputStream(localPropertiesFile).use { localProperties.load(it) }
        }
        val mapsApiKey = localProperties.getProperty("MAPS_API_KEY") ?: ""
        manifestPlaceholders["mapsApiKey"] = mapsApiKey
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    implementation("androidx.appcompat:appcompat:1.6.1")
}

flutter {
    source = "../.."
}