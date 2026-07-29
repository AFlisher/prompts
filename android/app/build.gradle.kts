import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.prombt.prombt_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    defaultConfig {
        applicationId = "com.prombt.prombt_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    // SEC-0.1: Play Integrity, Standard API. Google's official library - a
    // security control should not sit behind a third-party Flutter wrapper
    // (the best-adopted one on pub.dev has ~1.8k downloads/month and no
    // public source repository). The Dart surface needed is two calls, so
    // MainActivity binds this directly over a MethodChannel.
    implementation("com.google.android.play:integrity:1.6.0")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// google_mobile_ads 9.0.0 -> com.google.android.gms:play-services-ads-api:25.3.0
// still depends on androidx.work:work-runtime:2.7.0, which drags in the
// 2020-era androidx.room:room-runtime:2.2.5. That old Room version's bundled
// consumer proguard.txt only keeps "* extends RoomDatabase", not the
// androidx.room.Room factory class itself, so R8 full mode (default since
// AGP 8+) strips androidx.room.Room as unreachable. WorkManagerInitializer
// then crashes on first launch trying to build WorkDatabase via Room.
// Forcing a current WorkManager (which requires/pulls a current Room+SQLite)
// removes the broken dependency instead of just papering over it.
configurations.all {
    resolutionStrategy {
        force("androidx.work:work-runtime:2.9.1")
        force("androidx.work:work-runtime-ktx:2.9.1")
    }
}