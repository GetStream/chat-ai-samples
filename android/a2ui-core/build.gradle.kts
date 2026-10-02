plugins {
    alias(libs.plugins.kotlin.jvm)
}

kotlin {
    jvmToolchain(21)
    explicitApi()
}

dependencies {
    testImplementation(libs.junit)
    // Parses the JSON fixtures into maps the same way Stream parses message extraData.
    testImplementation(libs.moshi)
}
