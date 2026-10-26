import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.matsavin.pixelpals"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.matsavin.pixelpals"
        minSdk = 29
        targetSdk = 35
        versionCode = 3
        versionName = "1.2"
    }

    // The release key stays on the maintainer's machine (~/.android), never in the repo. Without it
    // the release build falls back to the debug key, so anyone can still build and install.
    val releaseKey = File(System.getProperty("user.home"), ".android/pixelpals-release.properties")
    signingConfigs {
        if (releaseKey.exists()) {
            create("release") {
                val props = Properties().apply { releaseKey.inputStream().use { load(it) } }
                storeFile = file(props.getProperty("storeFile"))
                storePassword = props.getProperty("password")
                keyAlias = props.getProperty("alias")
                keyPassword = props.getProperty("password")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        compose = true
    }
    androidResources {
        // Lets Android 13+ offer the app's languages in Settings › Apps › Pixel Pals › Language.
        generateLocaleConfig = true
    }
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2024.12.01"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.core:core-splashscreen:1.0.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
}
