plugins {
    id("com.android.application")

    id("dev.flutter.flutter-gradle-plugin")

    id("com.google.gms.google-services")
}

android {
    namespace = "com.prombt.prombt_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.prombt.prombt_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
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
