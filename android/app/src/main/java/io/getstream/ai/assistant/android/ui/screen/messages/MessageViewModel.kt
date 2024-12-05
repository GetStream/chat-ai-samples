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

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.skydoves.sandwich.messageOrNull
import com.skydoves.sandwich.onFailure
import com.skydoves.sandwich.onSuccess
import dagger.hilt.android.lifecycle.HiltViewModel
import io.getstream.ai.assistant.android.model.AiAgentRequest
import io.getstream.ai.assistant.android.network.NetworkModule
import io.getstream.chat.android.ai.assistant.TypingState
import io.getstream.chat.android.ai.assistant.TypingState.Companion.toTypingState
import io.getstream.chat.android.client.ChatClient
import io.getstream.chat.android.client.events.AIIndicatorClearEvent
import io.getstream.chat.android.client.events.AIIndicatorStopEvent
import io.getstream.chat.android.client.events.AIIndicatorUpdatedEvent
import io.getstream.chat.android.client.extensions.cidToTypeAndId
import io.getstream.log.streamLog
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class MessageViewModel @Inject constructor() : ViewModel() {

  private val chatClient by lazy { ChatClient.instance() }

  private val _isAiStarted: MutableStateFlow<Boolean> = MutableStateFlow(false)
  val isAiStarted: StateFlow<Boolean> = _isAiStarted

  private val _typingState: MutableStateFlow<TypingState> = MutableStateFlow(TypingState.Nothing)
  val typingState: StateFlow<TypingState> = _typingState

  fun subscribeEvents(cid: String) {
    chatClient.channel(cid).subscribeFor(
      AIIndicatorUpdatedEvent::class.java,
      AIIndicatorClearEvent::class.java,
      AIIndicatorStopEvent::class.java
    ) { event ->
      if (event is AIIndicatorUpdatedEvent) {
        _typingState.value = event.aiState.toTypingState(event.messageId)
      } else if (event is AIIndicatorClearEvent) {
        _typingState.value = TypingState.Clear
      }
    }
  }

  fun startAiAssistant(cid: String) {
    val (_, id) = cid.cidToTypeAndId()
    viewModelScope.launch {
      _isAiStarted.value = true
      NetworkModule.aiService.startAiAgent(
        request = AiAgentRequest(id)
      ).onSuccess {
        streamLog { "success start: $data" }
      }.onFailure {
        streamLog { "failure stop: $messageOrNull" }
      }
    }
  }

  fun stopAiAssistant(cid: String) {
    val (_, id) = cid.cidToTypeAndId()
    viewModelScope.launch {
      _isAiStarted.value = false
      NetworkModule.aiService.stopAiAgent(
        request = AiAgentRequest(id)
      ).onSuccess {
        streamLog { "success stop: $data" }
      }.onFailure {
        streamLog { "failure stop: $messageOrNull" }
      }
    }
  }
}
