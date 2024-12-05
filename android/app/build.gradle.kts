/*
 * Copyright (c) 2014-2024 Stream.io Inc. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import java.io.FileInputStream
import java.util.Properties

plugins {
  alias(libs.plugins.android.application)
  alias(libs.plugins.kotlin.android)
  alias(libs.plugins.kotlin.parcelize)
  alias(libs.plugins.kotlinx.serialization)
  alias(libs.plugins.compose.compiler)
  alias(libs.plugins.ksp)
  alias(libs.plugins.hilt.plugin)
}

val localProperties = Properties()
localProperties.load(FileInputStream(rootProject.file("local.properties")))

android {
  namespace = "io.getstream.ai.assistant.android"
  compileSdk = 35

  defaultConfig {
    applicationId = "io.getstream.ai.assistant.android"
    minSdk = 24
    targetSdk = 35
    versionCode = 1
    versionName = "1.0"
    buildConfigField("String", "STREAM_API_KEY", localProperties["STREAM_API_KEY"].toString())
    testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
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
    buildConfig = true
  }
}

dependencies {
  implementation(libs.stream.ai.assistant)
  implementation(libs.stream.offline)

  // compose
  implementation(libs.androidx.activity.compose)
  implementation(libs.androidx.compose.ui)
  implementation(libs.androidx.compose.runtime)
  implementation(libs.androidx.compose.foundation)
  implementation(libs.androidx.compose.animation)
  implementation(libs.androidx.compose.material3)
  implementation(libs.androidx.compose.foundation)
  implementation(libs.androidx.compose.foundation.layout)
  implementation(libs.androidx.lifecycle.viewModelCompose)

  // image loading
  implementation(libs.landscapist.glide)
  implementation(libs.landscapist.animation)
  implementation(libs.landscapist.placeholder)

  // ui
  implementation(libs.compose.shimmer)
  implementation(libs.compose.markdown)

  // di
  implementation(libs.hilt.android)
  ksp(libs.hilt.compiler)

  // coroutines
  implementation(libs.kotlinx.coroutines.android)

  // network
  implementation(libs.sandwich)
  implementation(platform(libs.retrofit.bom))
  implementation(platform(libs.okhttp.bom))
  implementation(libs.bundles.retrofitBundle)
  implementation(libs.sandwich)

  // stream chat
  implementation(libs.bundles.streamBundle)

  // json parsing
  implementation(libs.serialization)
}