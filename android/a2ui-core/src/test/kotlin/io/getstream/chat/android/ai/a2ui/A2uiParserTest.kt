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

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Test

internal class A2uiParserTest {

    @Test
    fun `parses the restaurant list payload from the backend`() {
        val payload = Fixtures.payload(Fixtures.RESTAURANT_LIST)

        assertEquals("restaurant-finder", payload.surfaceId)
        val (create, components, data) = payload.messages
        assertEquals(
            A2uiMessage.CreateSurface(
                surfaceId = "restaurant-finder",
                catalogId = "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json",
            ),
            create,
        )
        components as A2uiMessage.UpdateComponents
        val card = components.components.first { it.id == "restaurant-card" }
        assertEquals("Card", card.type)
        assertEquals(mapOf("child" to "restaurant-card-body"), card.properties)
        assertEquals(1f, components.components.first { it.id == "restaurant-image" }.weight)
        data as A2uiMessage.UpdateDataModel
        assertEquals("/", data.path)
        assertFalse(data.removesValue)
    }

    @Test
    fun `parses all backend payloads`() {
        listOf(Fixtures.RESTAURANT_LIST, Fixtures.BOOKING_FORM, Fixtures.BOOKING_CONFIRMATION).forEach { name ->
            assertEquals(name, 3, Fixtures.payload(name).messages.size)
        }
    }

    @Test
    fun `an update without value removes the key`() {
        val message = A2uiParser.parseMessage(
            Fixtures.json("""{"version":"v0.9","updateDataModel":{"surfaceId":"s","path":"/a"}}"""),
        )

        assertEquals(A2uiMessage.UpdateDataModel("s", "/a", value = null, removesValue = true), message)
    }

    @Test
    fun `skips messages of another version and unknown messages`() {
        assertNull(A2uiParser.parseMessage(Fixtures.json("""{"version":"v0.8","deleteSurface":{"surfaceId":"s"}}""")))
        assertNull(A2uiParser.parseMessage(Fixtures.json("""{"version":"v0.9","unknown":{"surfaceId":"s"}}""")))
        assertNull(A2uiParser.parsePayload(Fixtures.json("""{"version":"v0.8","surfaceId":"s","messages":[]}""")))
    }

    @Test
    fun `rejects values that are not payloads`() {
        assertNull(A2uiParser.parsePayload(null))
        assertNull(A2uiParser.parsePayload("not a payload"))
        assertNull(A2uiParser.parsePayload(mapOf("version" to "v0.9", "messages" to emptyList<Any>())))
    }

    @Test
    fun `skips components without id or type`() {
        val message = A2uiParser.parseMessage(
            Fixtures.json(
                """{"version":"v0.9","updateComponents":{"surfaceId":"s","components":[
                  {"id":"root","component":"Text","text":"Hi"},{"component":"Text"},{"id":"x"}]}}""",
            ),
        ) as A2uiMessage.UpdateComponents

        assertEquals(listOf("root"), message.components.map { it.id })
        assertEquals(mapOf("text" to "Hi"), message.components.single().properties)
    }
}
