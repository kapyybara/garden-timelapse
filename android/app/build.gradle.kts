import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing config. Credentials live in android/key.properties,
// which is git-ignored; the keystore (android/app/release.keystore) is kept
// in git so releases can be rebuilt. Without key.properties, release
// builds fall back to the debug key.
// (`Properties` must be imported: in a Gradle script the bare name `java`
// resolves to the Project's java extension, not the java.* packages.)
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    signingConfigs {
        create("release") {
            val storeFile = keystoreProperties["storeFile"] as? String
            if (storeFile != null) {
                this.storeFile = file(storeFile)
                storePassword = keystoreProperties["storePassword"] as? String
                keyAlias = keystoreProperties["keyAlias"] as? String
                keyPassword = keystoreProperties["keyPassword"] as? String
            }
        }
    }

    namespace = "com.garden.garden_timelapse"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications (exact-alarm APIs).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.garden.garden_timelapse"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signed with the release keystore (see signingConfigs above).
            // Falls back to the debug key when key.properties is absent.
            val releaseCfg = signingConfigs.findByName("release")
            signingConfig =
                if (releaseCfg?.storeFile != null) releaseCfg else signingConfigs.getByName("debug")
            // R8/minification left off: several plugins ship classes that
            // break under aggressive shrinking in this early stage. Revisit
            // before the Play Store release and add a proguard-rules.pro.
            isMinifyEnabled = false
            isShrinkResources = false
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

dependencies {
    // Required because core library desugaring is enabled (flutter_local_notifications).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
