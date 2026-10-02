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
 * A component placed in the tree, with the data scope its relative paths resolve against.
 *
 * @param component The component.
 * @param scope The absolute data model path of the scope, `/` at the root, or the list item
 * path (e.g. `/items/0`) inside a template.
 * @param key A key that is unique among the siblings of this node and stable across updates.
 * @param depth The depth of the node in the tree. The root has depth 0.
 */
public data class A2uiNode(
    val component: A2uiComponent,
    val scope: String,
    val key: String,
    val depth: Int,
)

/**
 * Reads the properties of [node], resolving data bindings against the [state] data model.
 *
 * A property is either a literal (e.g. `"Book Now"`) or a binding `{ "path": "..." }`.
 */
public class A2uiNodeContext(
    public val state: A2uiSurfaceState,
    public val node: A2uiNode,
) {

    /**
     * The component of [node].
     */
    public val component: A2uiComponent
        get() = node.component

    /**
     * Returns the property [name] with data bindings resolved.
     */
    public fun value(name: String): Any? = resolve(component.properties[name])

    /**
     * Returns the property [name] as text. Numbers and booleans are converted to text.
     */
    public fun string(name: String): String? = value(name).toDisplayString()

    /**
     * Returns the property [name] as a boolean.
     */
    public fun boolean(name: String): Boolean? = value(name) as? Boolean

    /**
     * Returns the property [name] as a number.
     */
    public fun number(name: String): Double? = (value(name) as? Number)?.toDouble()

    /**
     * Returns the absolute data model path of the property [name] when it is a binding,
     * e.g. for the two-way `value` of an input. Returns null for literals.
     */
    public fun boundPath(name: String): String? =
        component.properties[name].bindingPath()?.let { JsonPointer.resolve(node.scope, it) }

    /**
     * Returns the single child referenced by the property [name], e.g. `child` of a `Card`.
     */
    public fun child(name: String = "child"): A2uiNode? {
        val id = component.properties[name] as? String ?: return null
        return childNode(id, node.scope, key = "${node.key}/$id")
    }

    /**
     * Returns the children referenced by the property [name]: either a list of component ids,
     * or a template `{ componentId, path }` that is repeated for every item at `path`.
     */
    public fun children(name: String = "children"): List<A2uiNode> {
        return when (val children = component.properties[name]) {
            is List<*> -> children.mapIndexedNotNull { index, id ->
                (id as? String)?.let { childNode(it, node.scope, key = "${node.key}/$index:$it") }
            }
            is Map<*, *> -> {
                val componentId = children["componentId"] as? String ?: return emptyList()
                val path = JsonPointer.resolve(node.scope, children["path"] as? String ?: return emptyList())
                val itemKeys = when (val items = state.valueAt(path)) {
                    is List<*> -> items.indices.map(Int::toString)
                    is Map<*, *> -> items.keys.filterIsInstance<String>()
                    else -> emptyList()
                }
                itemKeys.mapNotNull { itemKey ->
                    val itemScope = "${path.trimEnd('/')}/${itemKey.replace("~", "~0").replace("/", "~1")}"
                    childNode(componentId, itemScope, key = "${node.key}/$itemScope")
                }
            }
            else -> emptyList()
        }
    }

    /**
     * Returns the server event of the property [name] (e.g. `action` of a `Button`), with its
     * context resolved against the data model now. Returns null if there is no server event.
     */
    public fun action(name: String = "action"): A2uiEvent.ActionTriggered? {
        val event = component.properties[name].asStringMap()?.get("event").asStringMap() ?: return null
        val eventName = event["name"] as? String ?: return null
        val context = event["context"].asStringMap().orEmpty().mapValues { (_, value) -> resolve(value) }
        return A2uiEvent.ActionTriggered(eventName, context)
    }

    private fun resolve(property: Any?): Any? {
        val path = property.bindingPath() ?: return property.takeUnless { it.isFunctionCall() }
        return state.valueAt(JsonPointer.resolve(node.scope, path))
    }

    private fun childNode(id: String, scope: String, key: String): A2uiNode? {
        if (node.depth >= MAX_DEPTH) return null
        val component = state.components[id] ?: return null
        return A2uiNode(component, scope, key, node.depth + 1)
    }

    private companion object {
        /** Stops the tree at this depth, so that a component cycle can't loop forever. */
        const val MAX_DEPTH = 32
    }
}

private fun Any?.bindingPath(): String? {
    val map = asStringMap() ?: return null
    return if (map.size == 1) map["path"] as? String else null
}

// Client-side functions (`{ "call": ... }`) are not supported.
private fun Any?.isFunctionCall(): Boolean = asStringMap()?.containsKey("call") == true

private fun Any?.toDisplayString(): String? = when (this) {
    is String -> this
    is Double, is Float -> {
        val number = (this as Number).toDouble()
        if (number % 1.0 == 0.0 && number in Long.MIN_VALUE.toDouble()..Long.MAX_VALUE.toDouble()) {
            number.toLong().toString()
        } else {
            number.toString()
        }
    }
    is Number, is Boolean -> toString()
    else -> null
}
