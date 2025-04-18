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
package io.getstream.ai.assistant.android.network

import io.getstream.ai.assistant.android.model.AiAgentRequest
import io.getstream.ai.assistant.android.model.AiAgentResponse
import retrofit2.http.Body
import retrofit2.http.POST

interface AiService {

  @POST("start-ai-agent")
  suspend fun startAiAgent(@Body request: AiAgentRequest): AiAgentResponse

  @POST("stop-ai-agent")
  suspend fun stopAiAgent(@Body request: AiAgentRequest): AiAgentResponse
}
