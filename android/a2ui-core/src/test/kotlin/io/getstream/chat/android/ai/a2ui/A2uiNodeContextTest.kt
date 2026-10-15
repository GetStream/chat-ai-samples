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
import org.junit.Assert.assertTrue
import org.junit.Test

internal class A2uiNodeContextTest {

    private val list = Fixtures.state(Fixtures.RESTAURANT_LIST)
    private val form = Fixtures.state(Fixtures.BOOKING_FORM)

    private fun A2uiSurfaceState.context(node: A2uiNode) = A2uiNodeContext(this, node)

    /** Returns the first node with [id] in a depth-first walk from the root. */
    private fun A2uiSurfaceState.find(id: String, node: A2uiNode = checkNotNull(root)): A2uiNode? {
        if (node.component.id == id) return node
        val context = context(node)
        return (listOfNotNull(context.child()) + context.children()).firstNotNullOfOrNull { find(id, it) }
    }

    private fun A2uiSurfaceState.findAll(id: String, node: A2uiNode = checkNotNull(root)): List<A2uiNode> {
        val context = context(node)
        val children = listOfNotNull(context.child()) + context.children()
        return listOfNotNull(node.takeIf { it.component.id == id }) + children.flatMap { findAll(id, it) }
    }

    @Test
    fun `resolves absolute bindings and static children`() {
        val root = list.context(checkNotNull(list.root))

        assertEquals(listOf("title-heading", "restaurant-list"), root.children().map { it.component.id })
        val heading = list.context(root.children().first())
        assertEquals("Top 3 restaurants in New York", heading.string("text"))
        assertEquals("h2", heading.string("variant"))
    }

    @Test
    fun `a template child list repeats the component for every item with its own scope`() {
        val listNode = checkNotNull(list.find("restaurant-list"))

        val cards = list.context(listNode).children()

        assertEquals(listOf("/items/0", "/items/1", "/items/2"), cards.map { it.scope })
        assertTrue(cards.all { it.component.id == "restaurant-card" })
        assertEquals(cards.size, cards.map { it.key }.toSet().size)
    }

    @Test
    fun `relative bindings inside a template resolve against the list item`() {
        val names = list.findAll("restaurant-name").map { list.context(it).string("text") }

        assertEquals((0..2).map { list.valueAt("/items/$it/name") }, names)
    }

    @Test
    fun `an action context resolves against the item of the pressed button`() {
        val secondButton = list.findAll("restaurant-book-button")[1]

        val action = list.context(secondButton).action()

        assertEquals(
            A2uiEvent.ActionTriggered(
                name = "book_restaurant",
                context = mapOf(
                    "restaurantName" to list.valueAt("/items/1/name"),
                    "address" to list.valueAt("/items/1/address"),
                    "imageUrl" to list.valueAt("/items/1/imageUrl"),
                ),
            ),
            action,
        )
    }

    @Test
    fun `an input exposes the absolute path of its two-way binding`() {
        val partySize = form.context(checkNotNull(form.find("booking-party")))

        assertEquals("/partySize", partySize.boundPath("value"))
        assertEquals("2", partySize.string("value"))
        assertNull(partySize.boundPath("label"))
        assertEquals("Party size", partySize.string("label"))
    }

    @Test
    fun `an action context reads the values the user entered`() {
        val edited = form
            .withValue("/partySize", "6")
            .withValue("/dietary", "Vegan")
        val submit = edited.context(checkNotNull(edited.find("booking-submit")))

        val action = checkNotNull(submit.action())

        assertEquals("submit_booking", action.name)
        assertEquals("6", action.context["partySize"])
        assertEquals("Vegan", action.context["dietary"])
        assertEquals(form.valueAt("/reservationTime"), action.context["reservationTime"])
        assertEquals(form.valueAt("/restaurantName"), action.context["restaurantName"])
    }

    @Test
    fun `numbers are shown without a trailing zero when they are whole`() {
        val component = A2uiComponent("root", "Text", mapOf("text" to mapOf("path" to "/n"), "w" to 2.5))
        val state = A2uiSurfaceState("s", components = mapOf("root" to component), dataModel = mapOf("n" to 4.0))
        val context = state.context(checkNotNull(state.root))

        assertEquals("4", context.string("text"))
        assertEquals("2.5", context.string("w"))
    }

    /** Returns all the nodes of the tree, depth first. */
    private fun A2uiSurfaceState.allNodes(node: A2uiNode = checkNotNull(root)): List<A2uiNode> {
        val context = context(node)
        return listOf(node) + (listOfNotNull(context.child()) + context.children()).flatMap { allNodes(it) }
    }

    @Test
    fun `missing children are skipped`() {
        val components = listOf(
            A2uiComponent("root", "Column", mapOf("children" to listOf("missing", "text"))),
            A2uiComponent("text", "Text", mapOf("text" to "Hi")),
        ).associateBy { it.id }
        val state = A2uiSurfaceState("s", components = components)

        assertEquals(listOf("text"), state.context(checkNotNull(state.root)).children().map { it.component.id })
    }

    @Test
    fun `a component that contains itself is not repeated`() {
        val components = listOf(
            A2uiComponent("root", "Column", mapOf("children" to listOf("loop"))),
            A2uiComponent("loop", "Card", mapOf("child" to "loop")),
        ).associateBy { it.id }
        val state = A2uiSurfaceState("s", components = components)

        assertEquals(listOf("root", "loop"), state.allNodes().map { it.component.id })
    }

    @Test
    fun `a cycle with many children stops at once`() {
        // Without the check, this doubles at every level until the depth limit.
        val root = A2uiComponent("root", "Column", mapOf("children" to listOf("root", "root")))
        val state = A2uiSurfaceState("s", components = mapOf("root" to root))

        assertEquals(1, state.allNodes().size)
    }

    @Test
    fun `a template can repeat itself for nested data`() {
        // A comment shows its text and then its replies, with the same component.
        val components = listOf(
            A2uiComponent("root", "List", mapOf("children" to mapOf("componentId" to "comment", "path" to "/comments"))),
            A2uiComponent("comment", "Column", mapOf("children" to listOf("comment-text", "replies"))),
            A2uiComponent("comment-text", "Text", mapOf("text" to mapOf("path" to "text"))),
            A2uiComponent("replies", "List", mapOf("children" to mapOf("componentId" to "comment", "path" to "replies"))),
        ).associateBy { it.id }
        val data = mapOf(
            "comments" to listOf(
                mapOf("text" to "First", "replies" to listOf(mapOf("text" to "Reply", "replies" to emptyList<Any>()))),
            ),
        )
        val state = A2uiSurfaceState("s", components = components, dataModel = data)

        val texts = state.allNodes().filter { it.component.id == "comment-text" }.map { state.context(it).string("text") }
        assertEquals(listOf("First", "Reply"), texts)
    }

    @Test
    fun `function calls are not resolved`() {
        val component = A2uiComponent("root", "Text", mapOf("text" to mapOf("call" to "formatDate", "args" to emptyMap<String, Any>())))
        val state = A2uiSurfaceState("s", components = mapOf("root" to component))

        assertNull(state.context(checkNotNull(state.root)).string("text"))
    }
}
