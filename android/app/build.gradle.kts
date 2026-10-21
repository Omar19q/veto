import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services") apply false
    id("dev.flutter.flutter-gradle-plugin")
}

// Explicit engineering build only. Ordinary/release package and notifications
// keep their existing Google Services configuration and application identity.
val vetoStagingBuild = providers.systemProperty("veto.stagingBuild").orNull == "true"
if (!vetoStagingBuild) {
    apply(plugin = "com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.isFile) {
    FileInputStream(keystorePropertiesFile).use { stream ->
        keystoreProperties.load(stream)
    }
}

val releaseKeyAlias = keystoreProperties.getProperty("keyAlias")?.trim().orEmpty()
val releaseKeyPassword = keystoreProperties.getProperty("keyPassword")?.trim().orEmpty()
val releaseStorePassword = keystoreProperties.getProperty("storePassword")?.trim().orEmpty()
val releaseStorePath = keystoreProperties.getProperty("storeFile")?.trim().orEmpty()
val releaseStoreFile = if (releaseStorePath.isNotEmpty()) rootProject.file(releaseStorePath) else null
val hasReleaseSigning = keystorePropertiesFile.isFile &&
    releaseKeyAlias.isNotEmpty() &&
    releaseKeyPassword.isNotEmpty() &&
    releaseStorePassword.isNotEmpty() &&
    releaseStoreFile?.isFile == true

android {
    namespace = "com.vetosanya.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = if (vetoStagingBuild) "com.vetosanya.app.staging" else "com.vetosanya.app"
        manifestPlaceholders["vetoAppLabel"] = if (vetoStagingBuild) "VETO SANYA STAGING" else "VETO SANYA"
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                storeFile = releaseStoreFile
                storePassword = releaseStorePassword
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.android.installreferrer:installreferrer:2.2")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("com.google.android.material:material:1.13.0")
    implementation("androidx.concurrent:concurrent-futures:1.3.0")
}
