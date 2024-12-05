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
package io.getstream.ai.assistant.android.ui.screen.messages

import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dagger.hilt.android.AndroidEntryPoint
import io.getstream.chat.android.ai.assistant.AiMessagesScreen
import io.getstream.chat.android.compose.ui.theme.ChatTheme
import io.getstream.chat.android.compose.viewmodel.messages.MessagesViewModelFactory

@AndroidEntryPoint
class MessageActivity : ComponentActivity() {

  private val cid by lazy { intent.getStringExtra(KEY_CHANNEL_ID)!! }
  private val messageViewModel: MessageViewModel by viewModels()

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    messageViewModel.subscribeEvents(cid = cid)

    val viewModelFactory = MessagesViewModelFactory(
      context = this,
      channelId = cid,
      messageLimit = 30
    )

    setContent {
      ChatTheme {
        val isAiStarted by messageViewModel.isAiStarted.collectAsStateWithLifecycle()
        val typingState by messageViewModel.typingState.collectAsStateWithLifecycle()

        Box(modifier = Modifier.fillMaxSize()) {
          AiMessagesScreen(
            isAiStarted = isAiStarted,
            viewModelFactory = viewModelFactory,
            onStartAiAssistant = { messageViewModel.startAiAssistant(cid = cid) },
            onStopAiAssistant = { messageViewModel.stopAiAssistant(cid = cid) },
            onBackPressed = { finish() },
            typingState = typingState
          )
        }
      }
    }
  }

  companion object {
    private const val KEY_CHANNEL_ID = "channelId"

    fun getIntent(context: Context, channelId: String): Intent {
      return Intent(context, MessageActivity::class.java).apply {
        putExtra(KEY_CHANNEL_ID, channelId)
      }
    }
  }
}
