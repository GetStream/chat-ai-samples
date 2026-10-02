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

/**
 * JSON Pointer ([RFC 6901](https://www.rfc-editor.org/rfc/rfc6901)) operations on immutable
 * JSON values (maps, lists and primitives).
 *
 * A2UI also allows relative paths (without a leading `/`). Use [resolve] to turn them into
 * absolute paths against a scope, e.g. a list item.
 */
public object JsonPointer {

    /**
     * Resolves [path] against [scope]. Absolute paths (starting with `/`) are returned
     * unchanged. Relative paths are appended to [scope], e.g. `name` in scope `/items/0`
     * becomes `/items/0/name`.
     */
    public fun resolve(scope: String, path: String): String = when {
        path.startsWith("/") -> path
        path.isEmpty() -> scope
        scope.isEmpty() || scope == "/" -> "/$path"
        else -> "${scope.trimEnd('/')}/$path"
    }

    /**
     * Splits an absolute [path] into unescaped segments. `/` and the empty string return no
     * segments, which means the whole document.
     */
    public fun segments(path: String): List<String> {
        if (path.isEmpty() || path == "/") return emptyList()
        return path.removePrefix("/").split("/").map { segment ->
            segment.replace("~1", "/").replace("~0", "~")
        }
    }

    /**
     * Returns the value at the absolute [path] in [root], or null if there is none.
     */
    public fun get(root: Any?, path: String): Any? =
        segments(path).fold(root) { node, segment ->
            when (node) {
                is Map<*, *> -> node[segment]
                is List<*> -> segment.toIntOrNull()?.let(node::getOrNull)
                else -> return null
            }
        }

    /**
     * Returns a copy of [root] with [value] at the absolute [path]. Missing parents are
     * created as maps. In a list, the index `-` or the list size appends a new item.
     */
    public fun set(root: Any?, path: String, value: Any?): Any? = set(root, segments(path), value)

    /**
     * Returns a copy of [root] without the key or list item at the absolute [path].
     */
    public fun remove(root: Any?, path: String): Any? {
        val segments = segments(path)
        if (segments.isEmpty()) return null
        return remove(root, segments)
    }

    private fun set(node: Any?, segments: List<String>, value: Any?): Any? {
        if (segments.isEmpty()) return value
        val key = segments.first()
        val rest = segments.drop(1)
        if (node is List<*>) {
            val index = if (key == "-") node.size else key.toIntOrNull()
            if (index != null && index in 0..node.size) {
                val list = node.toMutableList()
                if (index == node.size) list.add(set(null, rest, value)) else list[index] = set(node[index], rest, value)
                return list
            }
        }
        val map = LinkedHashMap<String, Any?>()
        node.asStringMap()?.let(map::putAll)
        map[key] = set(map[key], rest, value)
        return map
    }

    private fun remove(node: Any?, segments: List<String>): Any? {
        val key = segments.first()
        val rest = segments.drop(1)
        return when (node) {
            is Map<*, *> -> {
                val map = LinkedHashMap<String, Any?>()
                node.asStringMap()?.let(map::putAll)
                if (key !in map) return node
                if (rest.isEmpty()) map.remove(key) else map[key] = remove(map[key], rest)
                map
            }
            is List<*> -> {
                val index = key.toIntOrNull()?.takeIf { it in node.indices } ?: return node
                val list = node.toMutableList()
                if (rest.isEmpty()) list.removeAt(index) else list[index] = remove(node[index], rest)
                list
            }
            else -> node
        }
    }
}
