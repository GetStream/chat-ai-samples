/*
 * Copyright (c) 2014-2026 Stream.io Inc. All rights reserved.
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

package io.getstream.chat.android.ai.a2ui

import com.squareup.moshi.Moshi

/**
 * Payloads generated from the ai-sdk-sample backend by `scripts/generate-fixtures.ts`.
 */
internal object Fixtures {

    private val adapter = Moshi.Builder().build().adapter(Any::class.java)

    /** Decodes JSON the way Stream decodes message extraData: maps, lists and doubles. */
    fun json(text: String): Any? = adapter.fromJson(text)

    fun raw(name: String): Any? {
        val stream = checkNotNull(javaClass.getResourceAsStream("/fixtures/$name.json")) { "Missing fixture $name" }
        return json(stream.bufferedReader().use { it.readText() })
    }

    fun payload(name: String): A2uiPayload = checkNotNull(A2uiParser.parsePayload(raw(name)))

    fun state(name: String): A2uiSurfaceState = checkNotNull(A2uiReducer.reduce(payload(name)))

    const val RESTAURANT_LIST = "restaurant-list"
    const val BOOKING_FORM = "booking-form"
    const val BOOKING_CONFIRMATION = "booking-confirmation"
}
