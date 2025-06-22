// C:\dev\chikabooks_app\android\build.gradle.kts
import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory

/************* Google-services classpath만 제공 *************/
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")   // 플러그인만 제공
    }
}

/************* 공통 저장소 *************/
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

/************* 빌드 디렉터리 위치 통일(선택 사항) *************/
val newBuildDir: Directory =
    rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val subDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(subDir)
    evaluationDependsOn(":app")
}

/************* clean 태스크 *************/
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
