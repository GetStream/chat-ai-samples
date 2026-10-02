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
 * The immutable state of one A2UI surface: its components and its data model.
 *
 * Build it with [A2uiReducer], for example `A2uiReducer.reduce(payload)`.
 *
 * @param surfaceId The id of the surface.
 * @param catalogId The catalog the surface components come from.
 * @param components The components by id. The tree starts at [ROOT_COMPONENT_ID].
 * @param dataModel The surface data model, a JSON object.
 */
public data class A2uiSurfaceState(
    val surfaceId: String,
    val catalogId: String? = null,
    val components: Map<String, A2uiComponent> = emptyMap(),
    val dataModel: Map<String, Any?> = emptyMap(),
) {

    /**
     * The root node of the component tree, or null if the root component has not arrived yet.
     */
    public val root: A2uiNode?
        get() = components[ROOT_COMPONENT_ID]?.let { A2uiNode(it, scope = "/", key = it.id, depth = 0) }

    /**
     * Returns the value at the absolute [path] of the data model.
     */
    public fun valueAt(path: String): Any? = JsonPointer.get(dataModel, path)

    /**
     * Returns a copy of the state with [value] at the absolute [path] of the data model.
     */
    public fun withValue(path: String, value: Any?): A2uiSurfaceState =
        copy(dataModel = JsonPointer.set(dataModel, path, value).asStringMap().orEmpty())

    public companion object {
        /**
         * The id of the component at the root of every surface.
         */
        public const val ROOT_COMPONENT_ID: String = "root"
    }
}

/**
 * An event sent by the rendered surface.
 */
public sealed interface A2uiEvent {

    /**
     * The user changed an input bound to the absolute [path] of the data model.
     */
    public data class ValueChanged(val path: String, val value: Any?) : A2uiEvent

    /**
     * The user triggered the server event [name], e.g. by tapping a button. The [context]
     * values are already resolved against the data model.
     */
    public data class ActionTriggered(val name: String, val context: Map<String, Any?>) : A2uiEvent
}

/**
 * Applies A2UI messages and UI events to [A2uiSurfaceState]. All functions are pure.
 */
public object A2uiReducer {

    /**
     * Builds the state of a surface by applying all the messages of [payload].
     *
     * @return The state, or null if the surface ends up deleted or never created.
     */
    public fun reduce(payload: A2uiPayload): A2uiSurfaceState? =
        payload.messages
            .filter { it.surfaceId == payload.surfaceId }
            .fold(null as A2uiSurfaceState?, ::reduce)

    /**
     * Applies one message to [state]. Messages for another surface are ignored.
     *
     * @return The new state, or null if the message deletes the surface.
     */
    public fun reduce(state: A2uiSurfaceState?, message: A2uiMessage): A2uiSurfaceState? {
        if (state != null && state.surfaceId != message.surfaceId) return state
        // Be lenient when createSurface is missing: start an empty surface.
        val current = state ?: A2uiSurfaceState(surfaceId = message.surfaceId)
        return when (message) {
            is A2uiMessage.CreateSurface -> A2uiSurfaceState(message.surfaceId, message.catalogId)
            is A2uiMessage.UpdateComponents -> current.copy(
                components = current.components + message.components.associateBy { it.id },
            )
            is A2uiMessage.UpdateDataModel -> {
                val model = if (message.removesValue) {
                    JsonPointer.remove(current.dataModel, message.path)
                } else {
                    JsonPointer.set(current.dataModel, message.path, message.value)
                }
                current.copy(dataModel = model.asStringMap().orEmpty())
            }
            is A2uiMessage.DeleteSurface -> null
        }
    }

    /**
     * Applies a UI event to [state]. [A2uiEvent.ValueChanged] writes the value to the data
     * model. [A2uiEvent.ActionTriggered] does not change the state.
     */
    public fun reduce(state: A2uiSurfaceState, event: A2uiEvent): A2uiSurfaceState = when (event) {
        is A2uiEvent.ValueChanged -> state.withValue(event.path, event.value)
        is A2uiEvent.ActionTriggered -> state
    }
}
