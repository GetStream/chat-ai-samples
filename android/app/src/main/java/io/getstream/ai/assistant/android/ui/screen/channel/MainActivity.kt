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
package io.getstream.ai.assistant.android.ui.screen.channel

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dagger.hilt.android.AndroidEntryPoint
import io.getstream.ai.assistant.android.R
import io.getstream.ai.assistant.android.ui.screen.messages.MessageActivity
import io.getstream.chat.android.client.ChatClient
import io.getstream.chat.android.compose.ui.channels.ChannelsScreen
import io.getstream.chat.android.compose.ui.theme.ChatTheme
import io.getstream.chat.android.models.InitializationState

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

  private val mainViewModel: MainViewModel by viewModels()

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    setContent {
      val clientInitialisationState
        by ChatClient.instance().clientState.initializationState.collectAsStateWithLifecycle()

      when (clientInitialisationState) {
        InitializationState.COMPLETE -> {
          ChatTheme {
            ChannelsScreen(
              title = stringResource(id = R.string.app_name),
              isShowingHeader = true,
              onHeaderActionClick = { mainViewModel.createChannel() },
              onChannelClick = { channel ->
                startActivity(MessageActivity.getIntent(this, channel.cid))
              },
              onBackPressed = { finish() }
            )
          }
        }

        InitializationState.INITIALIZING -> {
          Box(modifier = Modifier.fillMaxSize()) {
            CircularProgressIndicator(
              modifier = Modifier.align(Alignment.Center)
            )
          }
        }

        InitializationState.NOT_INITIALIZED -> {
          Text(text = "Not initialized...")
        }
      }
    }
  }
}
