plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "io.getstream.chat.android.ai.a2ui.compose"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
        // DateTimeInput uses java.time, which needs desugaring below API 26.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        minSdk = 23
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildFeatures {
        compose = true
    }

    // A library has no targetSdk, so its test APK would target minSdk. Android then shows a
    // "This app was built for an older version of Android" dialog during the instrumented tests.
    testOptions {
        targetSdk = 36
    }

    lint {
        targetSdk = 36
    }

    sourceSets {
        // The instrumented tests render the same backend payloads as the core unit tests.
        getByName("androidTest").assets.srcDir("../a2ui-core/src/test/resources")
    }
}

kotlin {
    jvmToolchain(21)
    explicitApi()
}

dependencies {
    api(project(":a2ui-core"))

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.bundles.androidx.compose)
    implementation(libs.coil.compose)
    implementation(libs.coil.network.okhttp)

    coreLibraryDesugaring(libs.desugar.jdk.libs)

    debugImplementation(libs.androidx.compose.ui.tooling)

    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    androidTestImplementation(libs.androidx.test.ext.junit)
    androidTestImplementation(libs.androidx.test.runner)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
}
