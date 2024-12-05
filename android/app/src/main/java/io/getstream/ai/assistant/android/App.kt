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
package io.getstream.ai.assistant.android

import android.app.Application
import io.getstream.chat.android.client.ChatClient
import io.getstream.chat.android.client.logger.ChatLogLevel
import io.getstream.chat.android.models.ConnectionData
import io.getstream.chat.android.models.User
import io.getstream.chat.android.offline.plugin.factory.StreamOfflinePluginFactory
import io.getstream.chat.android.state.plugin.config.StatePluginConfig
import io.getstream.chat.android.state.plugin.factory.StreamStatePluginFactory
import io.getstream.log.AndroidStreamLogger
import io.getstream.log.streamLog
import io.getstream.result.call.Call
import kotlin.random.Random

class App : Application() {

  override fun onCreate() {
    super.onCreate()

    // initialise the Stream logger
    AndroidStreamLogger.installOnDebuggableApp(this)

    /**
     * initialize a global instance of the [ChatClient].
     * The ChatClient is the main entry point for all low-level operations on chat.
     * e.g, connect/disconnect user to the server, send/update/pin message, etc.
     */
    val logLevel = if (BuildConfig.DEBUG) ChatLogLevel.ALL else ChatLogLevel.NOTHING
    val offlinePluginFactory = StreamOfflinePluginFactory(
      appContext = applicationContext
    )
    val statePluginFactory = StreamStatePluginFactory(
      config = StatePluginConfig(
        backgroundSyncEnabled = true,
        userPresence = true
      ),
      appContext = applicationContext
    )
    val chatClient = ChatClient.Builder("zcgvnykxsfm8", applicationContext)
      .withPlugins(offlinePluginFactory, statePluginFactory)
      .logLevel(logLevel)
      .build()

    val user = User(
      id = "AIStreamUser1",
      name = "AI Android Stream",
      image = "https://picsum.photos/id/${Random.nextInt(1000)}/300/300"
    )

    // https://getstream.io/chat/docs/php/token_generator/
    val token =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiQUlTdHJlYW1Vc2VyMSJ9.3Kb4ZfCJIG02M24eqOR4SdNmouq1SgXGu-_4pBKEjjI"
    chatClient.connectUser(user, token).enqueue(object : Call.Callback<ConnectionData> {
      override fun onResult(result: io.getstream.result.Result<ConnectionData>) {
        if (result.isFailure) {
          streamLog {
            "Can't connect user. Please check the app README.md and ensure " +
              "**Disable Auth Checks** is ON in the Dashboard"
          }
        }
      }
    })
  }
}
