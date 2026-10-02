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
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Test

internal class A2uiReducerTest {

    private val surface = A2uiSurfaceState(surfaceId = "s", catalogId = "catalog")

    @Test
    fun `builds the restaurant list state from the backend payload`() {
        val state = Fixtures.state(Fixtures.RESTAURANT_LIST)

        assertEquals("restaurant-finder", state.surfaceId)
        assertEquals("root", state.root?.component?.id)
        assertEquals("Top 3 restaurants in New York", state.valueAt("/title"))
        assertEquals(3, (state.valueAt("/items") as List<*>).size)
    }

    @Test
    fun `createSurface starts an empty surface`() {
        val state = A2uiReducer.reduce(
            surface.copy(dataModel = mapOf("a" to 1.0)),
            A2uiMessage.CreateSurface("s", "other"),
        )

        assertEquals(A2uiSurfaceState("s", "other"), state)
    }

    @Test
    fun `updateComponents adds new components and replaces the ones with the same id`() {
        val first = A2uiComponent("root", "Text", mapOf("text" to "A"))
        val replaced = A2uiComponent("root", "Text", mapOf("text" to "B"))
        val added = A2uiComponent("other", "Text", emptyMap())

        val state = listOf(
            A2uiMessage.UpdateComponents("s", listOf(first)),
            A2uiMessage.UpdateComponents("s", listOf(replaced, added)),
        ).fold(surface as A2uiSurfaceState?, A2uiReducer::reduce)

        assertEquals(mapOf("root" to replaced, "other" to added), state?.components)
    }

    @Test
    fun `updateDataModel sets, replaces and removes values`() {
        val state = listOf(
            A2uiMessage.UpdateDataModel("s", "/", mapOf("a" to 1.0, "b" to 2.0)),
            A2uiMessage.UpdateDataModel("s", "/c/d", "x"),
            A2uiMessage.UpdateDataModel("s", "/a", null, removesValue = true),
        ).fold(surface as A2uiSurfaceState?, A2uiReducer::reduce)

        assertEquals(mapOf("b" to 2.0, "c" to mapOf("d" to "x")), state?.dataModel)
    }

    @Test
    fun `deleteSurface removes the surface`() {
        assertNull(A2uiReducer.reduce(surface, A2uiMessage.DeleteSurface("s")))
    }

    @Test
    fun `messages for another surface are ignored`() {
        assertSame(surface, A2uiReducer.reduce(surface, A2uiMessage.DeleteSurface("other")))
    }

    @Test
    fun `ValueChanged writes to the data model and ActionTriggered keeps the state`() {
        val form = Fixtures.state(Fixtures.BOOKING_FORM)

        val changed = A2uiReducer.reduce(form, A2uiEvent.ValueChanged("/partySize", "6"))

        assertEquals("6", changed.valueAt("/partySize"))
        assertEquals("2", form.valueAt("/partySize"))
        assertSame(form, A2uiReducer.reduce(form, A2uiEvent.ActionTriggered("submit_booking", emptyMap())))
    }
}
