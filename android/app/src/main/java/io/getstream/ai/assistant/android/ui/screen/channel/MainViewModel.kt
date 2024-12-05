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

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import io.getstream.chat.android.client.ChatClient
import io.getstream.log.streamLog
import kotlinx.coroutines.launch
import javax.inject.Inject
import kotlin.random.Random

@HiltViewModel
class MainViewModel @Inject constructor() : ViewModel() {

  private val chatClient by lazy { ChatClient.instance() }

  fun createChannel() {
    viewModelScope.launch {
      val number = Random.nextInt(10000)
      chatClient.createChannel(
        channelType = "messaging",
        channelId = "channel$number",
        memberIds = listOf(chatClient.getCurrentUser()?.id.orEmpty()),
        extraData = mapOf()
      ).await().onSuccess {
        streamLog { "Created a new channel" }
      }.onError {
        streamLog { "error: $it" }
      }
    }
  }
}
