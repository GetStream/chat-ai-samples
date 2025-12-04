/*
 * Copyright (c) 2014-2025 Stream.io Inc. All rights reserved.
 *
 * Licensed under the Stream License;
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    https://github.com/GetStream/stream-chat-android-ai/blob/main/LICENSE
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package io.getstream.chat.android.ai.compose.sample

import android.app.Application
import android.os.StrictMode
import io.getstream.chat.android.client.ChatClient
import io.getstream.chat.android.client.logger.ChatLogLevel
import io.getstream.chat.android.models.User
import io.getstream.chat.android.offline.plugin.factory.StreamOfflinePluginFactory
import io.getstream.chat.android.state.plugin.config.StatePluginConfig
import io.getstream.chat.android.state.plugin.factory.StreamStatePluginFactory
import io.getstream.log.AndroidStreamLogger
import io.getstream.log.streamLog

class App : Application() {

    lateinit var chatDependencies: ChatDependencies
        private set

    override fun onCreate() {
        setupStrictMode()
        super.onCreate()

        chatDependencies = ChatDependencies(
            baseUrl = "http://10.0.2.2:3000", // Android emulator localhost
            enableLogging = BuildConfig.DEBUG,
        )

        initializeStreamChat()
    }

    /**
     * initialize a global instance of the [ChatClient].
     * The ChatClient is the main entry point for all low-level operations on chat. e.g,
     * connect/disconnect user to the server, send/update/pin message, etc.
     */
    private fun initializeStreamChat() {
        AndroidStreamLogger.installOnDebuggableApp(this)

        val logLevel = if (BuildConfig.DEBUG) ChatLogLevel.ALL else ChatLogLevel.NOTHING
        val offlinePluginFactory = StreamOfflinePluginFactory(appContext = applicationContext)
        val statePluginFactory = StreamStatePluginFactory(
            config = StatePluginConfig(backgroundSyncEnabled = true, userPresence = true),
            appContext = applicationContext,
        )
        val chatClient = ChatClient.Builder("uun7ywwamhs9", applicationContext)
            .withPlugins(offlinePluginFactory, statePluginFactory)
            .logLevel(logLevel)
            .build()

        val user = User(
            id = "andrerego",
            name = "André Rêgo",
            image = "https://ca.slack-edge.com/T02RM6X6B-U083JCB6ZEY-2da235988b74-512",
        )

        // https://getstream.io/chat/docs/php/token_generator/
        val token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiYW5kcmVyZWdvIn0.DfzvkOT8-cnpTFzD5E3XL5P3nI8GJFo5Suxf23kvHuo"
        chatClient.connectUser(user, token)
            .enqueue { result ->
                if (result.isFailure) {
                    streamLog { "Can't connect user. Please check the app README.md" }
                }
            }
    }
}

private fun setupStrictMode() {
    StrictMode.ThreadPolicy.Builder().detectAll()
        .penaltyLog()
        .build()
        .apply {
            StrictMode.setThreadPolicy(this)
        }

    StrictMode.VmPolicy.Builder()
        .detectAll()
        .penaltyLog()
        .build()
        .apply {
            StrictMode.setVmPolicy(this)
        }
}
