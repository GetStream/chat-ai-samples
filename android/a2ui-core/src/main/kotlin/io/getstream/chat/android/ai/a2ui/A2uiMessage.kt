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
 * The A2UI protocol version this module understands.
 */
public const val A2UI_VERSION: String = "v0.9"

/**
 * A server-to-client A2UI v0.9 message.
 */
public sealed interface A2uiMessage {

    /**
     * The surface this message applies to.
     */
    public val surfaceId: String

    /**
     * Creates a new surface that renders components from the catalog [catalogId].
     */
    public data class CreateSurface(
        override val surfaceId: String,
        val catalogId: String?,
    ) : A2uiMessage

    /**
     * Adds the [components] to the surface, or replaces the ones with the same id.
     */
    public data class UpdateComponents(
        override val surfaceId: String,
        val components: List<A2uiComponent>,
    ) : A2uiMessage

    /**
     * Sets [value] at [path] in the surface data model. The path `/` replaces the whole model.
     * When [removesValue] is true, the key at [path] is removed and [value] is ignored.
     */
    public data class UpdateDataModel(
        override val surfaceId: String,
        val path: String,
        val value: Any?,
        val removesValue: Boolean = false,
    ) : A2uiMessage

    /**
     * Deletes the surface.
     */
    public data class DeleteSurface(
        override val surfaceId: String,
    ) : A2uiMessage
}

/**
 * A component from an `updateComponents` message.
 *
 * @param id The unique id of the component in its surface.
 * @param type The component type in the catalog, e.g. `Text`.
 * @param properties All the other properties of the component, as received.
 */
public data class A2uiComponent(
    val id: String,
    val type: String,
    val properties: Map<String, Any?>,
) {
    /**
     * The relative weight of the component inside a `Row` or `Column`, if set.
     */
    public val weight: Float?
        get() = (properties["weight"] as? Number)?.toFloat()
}

/**
 * The A2UI payload attached to a chat message: a list of messages for one surface.
 */
public data class A2uiPayload(
    val surfaceId: String,
    val messages: List<A2uiMessage>,
)

/**
 * Parses A2UI v0.9 messages from already decoded JSON values (maps, lists, strings, numbers,
 * booleans and nulls), like Stream message `extraData`.
 *
 * Unknown messages and messages of another protocol version are skipped.
 */
public object A2uiParser {

    /**
     * Parses a payload in the form `{ version, surfaceId, messages: [...] }`.
     *
     * @return The payload, or null if [raw] is not a valid v0.9 payload.
     */
    public fun parsePayload(raw: Any?): A2uiPayload? {
        val map = raw.asStringMap() ?: return null
        val version = map["version"] as? String
        if (version != null && version != A2UI_VERSION) return null
        val messages = (map["messages"] as? List<*>).orEmpty().mapNotNull(::parseMessage)
        val surfaceId = map["surfaceId"] as? String ?: messages.firstOrNull()?.surfaceId ?: return null
        if (messages.isEmpty()) return null
        return A2uiPayload(surfaceId = surfaceId, messages = messages)
    }

    /**
     * Parses one message, e.g. `{ "version": "v0.9", "createSurface": { ... } }`.
     *
     * @return The message, or null if [raw] is not a valid v0.9 message.
     */
    public fun parseMessage(raw: Any?): A2uiMessage? {
        val map = raw.asStringMap() ?: return null
        if (map["version"] != A2UI_VERSION) return null
        map["createSurface"].asStringMap()?.let { body ->
            val surfaceId = body["surfaceId"] as? String ?: return null
            return A2uiMessage.CreateSurface(surfaceId, body["catalogId"] as? String)
        }
        map["updateComponents"].asStringMap()?.let { body ->
            val surfaceId = body["surfaceId"] as? String ?: return null
            val components = (body["components"] as? List<*>).orEmpty().mapNotNull(::parseComponent)
            return A2uiMessage.UpdateComponents(surfaceId, components)
        }
        map["updateDataModel"].asStringMap()?.let { body ->
            val surfaceId = body["surfaceId"] as? String ?: return null
            val path = body["path"] as? String ?: "/"
            return A2uiMessage.UpdateDataModel(
                surfaceId = surfaceId,
                path = path,
                value = body["value"],
                removesValue = !body.containsKey("value"),
            )
        }
        map["deleteSurface"].asStringMap()?.let { body ->
            val surfaceId = body["surfaceId"] as? String ?: return null
            return A2uiMessage.DeleteSurface(surfaceId)
        }
        return null
    }

    private fun parseComponent(raw: Any?): A2uiComponent? {
        val map = raw.asStringMap() ?: return null
        val id = map["id"] as? String ?: return null
        val type = map["component"] as? String ?: return null
        return A2uiComponent(id = id, type = type, properties = map - "id" - "component")
    }
}

@Suppress("UNCHECKED_CAST")
internal fun Any?.asStringMap(): Map<String, Any?>? =
    (this as? Map<*, *>)?.takeIf { map -> map.keys.all { it is String } } as Map<String, Any?>?
