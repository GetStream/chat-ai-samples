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

package io.getstream.chat.android.ai.compose.sample.presentation.chat

import com.squareup.moshi.Moshi
import com.squareup.moshi.Types
import io.getstream.chat.android.ai.a2ui.A2uiEvent
import io.getstream.chat.android.ai.a2ui.A2uiParser
import io.getstream.chat.android.ai.a2ui.A2uiReducer
import io.getstream.chat.android.ai.a2ui.A2uiSurfaceState
import io.getstream.chat.android.models.User
import io.getstream.chat.android.models.Message as StreamMessage

/** Message extraData field with the A2UI v0.9 payload sent by ai-sdk-sample. */
internal const val A2UI_PAYLOAD_KEY = "a2ui_v09"

/** Message extraData field with the user action, as a JSON string. */
internal const val A2UI_INTERACTION_KEY = "a2ui_interaction"

/** Message extraData field with the id of the surface the action comes from. */
internal const val A2UI_SURFACE_ID_KEY = "a2ui_surface_id"

/**
 * Keeps the A2UI surface of each message, by message id.
 *
 * The surface is built from the message payload once, then user input is applied on top of
 * it. So input survives message list updates, scrolling and configuration changes (the store
 * lives in the ViewModel). It is not thread-safe: use it from the main thread.
 */
internal class A2uiSurfaceStore {

    private class Entry(val payload: Any?, val state: A2uiSurfaceState?)

    private val entries = mutableMapOf<String, Entry>()

    /**
     * Returns the surface of [message], or null if it has no A2UI payload. The surface is
     * rebuilt only when the payload of the message changes.
     */
    fun surfaceOf(message: StreamMessage): A2uiSurfaceState? {
        val payload = message.extraData[A2UI_PAYLOAD_KEY] ?: return null
        val entry = entries[message.id]?.takeIf { it.payload == payload }
            ?: Entry(payload, A2uiParser.parsePayload(payload)?.let(A2uiReducer::reduce))
                .also { entries[message.id] = it }
        return entry.state
    }

    /**
     * Applies [event] to the surface of the message [messageId].
     *
     * @return The new surface, or null if the message has no surface.
     */
    fun apply(messageId: String, event: A2uiEvent): A2uiSurfaceState? {
        val entry = entries[messageId] ?: return null
        val state = entry.state?.let { A2uiReducer.reduce(it, event) } ?: return null
        entries[messageId] = Entry(entry.payload, state)
        return state
    }
}

private val interactionAdapter = Moshi.Builder().build().adapter<Map<String, Any?>>(
    Types.newParameterizedType(Map::class.java, String::class.java, Any::class.java),
)

/**
 * Builds the user message that reports [action] of [surfaceId] to the backend:
 * `a2ui_interaction` is `{"userAction":{"name":...,"context":{...}}}` as a JSON string.
 */
internal fun buildA2uiActionMessage(
    surfaceId: String,
    action: A2uiEvent.ActionTriggered,
    userId: String,
): StreamMessage = StreamMessage(
    text = action.readableText(),
    user = User(id = userId),
    extraData = mapOf(
        A2UI_INTERACTION_KEY to interactionAdapter.toJson(
            mapOf("userAction" to mapOf("name" to action.name, "context" to action.context)),
        ),
        A2UI_SURFACE_ID_KEY to surfaceId,
    ),
)

private fun A2uiEvent.ActionTriggered.readableText(): String {
    val restaurant = context["restaurantName"] as? String
    return when (name) {
        "book_restaurant" -> restaurant?.let { "Book a table at $it" } ?: "Book a table"
        "submit_booking" -> restaurant?.let { "Confirm the reservation at $it" } ?: "Confirm the reservation"
        // e.g. "submit_contact_form" becomes "Submit contact form"
        else -> name.replace('_', ' ').replaceFirstChar(Char::uppercase)
    }
}
