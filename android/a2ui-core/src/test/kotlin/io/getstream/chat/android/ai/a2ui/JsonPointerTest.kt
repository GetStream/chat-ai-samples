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
import org.junit.Test

internal class JsonPointerTest {

    private val model = mapOf(
        "title" to "Top 3",
        "items" to listOf(mapOf("name" to "A"), mapOf("name" to "B")),
        "a/b" to mapOf("m~n" to 1.0),
    )

    @Test
    fun `resolve keeps absolute paths and appends relative paths to the scope`() {
        assertEquals("/title", JsonPointer.resolve("/items/0", "/title"))
        assertEquals("/items/0/name", JsonPointer.resolve("/items/0", "name"))
        assertEquals("/name", JsonPointer.resolve("/", "name"))
        assertEquals("/items/0", JsonPointer.resolve("/items/0", ""))
    }

    @Test
    fun `get reads maps, list indices and escaped segments`() {
        assertEquals("Top 3", JsonPointer.get(model, "/title"))
        assertEquals("B", JsonPointer.get(model, "/items/1/name"))
        assertEquals(1.0, JsonPointer.get(model, "/a~1b/m~0n"))
        assertEquals(model, JsonPointer.get(model, "/"))
    }

    @Test
    fun `get returns null for missing values`() {
        assertNull(JsonPointer.get(model, "/missing"))
        assertNull(JsonPointer.get(model, "/items/5/name"))
        assertNull(JsonPointer.get(model, "/items/x"))
        assertNull(JsonPointer.get(model, "/title/deeper"))
    }

    @Test
    fun `set returns a new model and keeps the original unchanged`() {
        val updated = JsonPointer.set(model, "/items/0/name", "Z")

        assertEquals("Z", JsonPointer.get(updated, "/items/0/name"))
        assertEquals("A", JsonPointer.get(model, "/items/0/name"))
        assertEquals("Top 3", JsonPointer.get(updated, "/title"))
    }

    @Test
    fun `set creates missing parents and appends to lists`() {
        val created = JsonPointer.set(model, "/booking/party/size", "4")
        assertEquals(mapOf("party" to mapOf("size" to "4")), JsonPointer.get(created, "/booking"))

        val appended = JsonPointer.set(model, "/items/-", mapOf("name" to "C"))
        assertEquals("C", JsonPointer.get(appended, "/items/2/name"))
    }

    @Test
    fun `set with an invalid list index keeps the list unchanged`() {
        assertEquals(model, JsonPointer.set(model, "/items/5/name", "x"))
        assertEquals(model, JsonPointer.set(model, "/items/x", "x"))
        assertEquals(model, JsonPointer.set(model, "/items/-1", "x"))
    }

    @Test
    fun `set at the root replaces the whole model`() {
        assertEquals(mapOf("x" to 1.0), JsonPointer.set(model, "/", mapOf("x" to 1.0)))
    }

    @Test
    fun `remove deletes map keys and list items`() {
        val withoutTitle = JsonPointer.remove(model, "/title")
        assertNull(JsonPointer.get(withoutTitle, "/title"))
        assertEquals("A", JsonPointer.get(withoutTitle, "/items/0/name"))

        val withoutFirst = JsonPointer.remove(model, "/items/0")
        assertEquals("B", JsonPointer.get(withoutFirst, "/items/0/name"))
    }
}
