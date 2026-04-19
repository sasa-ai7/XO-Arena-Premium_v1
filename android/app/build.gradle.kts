import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load keystore properties from android/key.properties (rootProject = android/)
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.sasa.xogame"
    // compileSdk = 36 is required by plugins (app_links, in_app_purchase, etc.)
    // This is different from targetSdk - compileSdk is only for building
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.sasa.xogame"
        // Kotlin DSL: use assignment syntax instead of Groovy-style minSdkVersion
        minSdk = flutter.minSdkVersion
        // targetSdk = 35 is safe and compatible with Play Store policy
        // Note: compileSdk (36) and targetSdk (35) can be different
        // compileSdk is for building, targetSdk is for runtime behavior
        targetSdk = 35
        // Version is automatically extracted from pubspec.yaml
        // Format: version: <versionName>+<versionCode> (e.g., "1.0.0+3")
        // versionCode must increase with each Google Play upload
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // ✅ Create release signing only if key.properties exists
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String

                // ✅ IMPORTANT: storeFile is relative to android/ (rootProject)
                // Your key.properties has: storeFile=keystore.jks
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)

                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // ✅ Use release signing if available, otherwise fail with clear error
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                throw GradleException(
                    "Missing android/key.properties. Create it and point to android/keystore.jks before building release."
                )
            }

            // ProGuard/R8 rules for code minification and optimization
            // Required by Google Play Console to reduce APK size
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )

            // Build optimizations for release
            isDebuggable = false
            isJniDebuggable = false
            isRenderscriptDebuggable = false
            renderscriptOptimLevel = 3

            // Enable R8 minification and resource shrinking to reduce APK size
            // This is required by Google Play Console
            isMinifyEnabled = true
            isShrinkResources = true
        }
        debug {
            // keep debug default signing
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}
