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

package io.getstream.chat.android.ai.a2ui.compose

import androidx.compose.runtime.Composable
import androidx.compose.runtime.ProvidableCompositionLocal
import androidx.compose.runtime.Stable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.getstream.chat.android.ai.a2ui.A2uiComponent
import io.getstream.chat.android.ai.a2ui.A2uiEvent
import io.getstream.chat.android.ai.a2ui.A2uiNode
import io.getstream.chat.android.ai.a2ui.A2uiNodeContext
import io.getstream.chat.android.ai.a2ui.A2uiSurfaceState

/**
 * Renders an A2UI surface. The composable is stateless: it renders [state] and reports user
 * input through [onEvent]. Apply [A2uiEvent.ValueChanged] to the state (for example with
 * `A2uiReducer.reduce`) so inputs show the new value.
 *
 * @param state The surface to render.
 * @param onEvent Called with the input changes and the actions of the user.
 * @param modifier The modifier for the root component.
 * @param catalog The renderers for each component type. Unknown types are not rendered.
 */
@Composable
public fun A2uiSurface(
    state: A2uiSurfaceState,
    onEvent: (A2uiEvent) -> Unit,
    modifier: Modifier = Modifier,
    catalog: A2uiCatalog = A2uiCatalog.Basic,
) {
    val root = state.root ?: return
    RenderNode(state, root, catalog, onEvent, modifier)
}

/**
 * What a component renderer receives: the component with its resolved properties, the
 * modifier to apply, and a way to render children and send events.
 */
@Stable
public class A2uiComponentScope internal constructor(
    /** Reads the component properties, with data bindings resolved. */
    public val context: A2uiNodeContext,
    /** The modifier from the parent, e.g. a weight in a `Row`. Apply it to the outer element. */
    public val modifier: Modifier,
    private val onEvent: (A2uiEvent) -> Unit,
    private val catalog: A2uiCatalog,
) {

    /** The component to render. */
    public val component: A2uiComponent
        get() = context.component

    /** Sends [event] to the owner of the surface. */
    public fun send(event: A2uiEvent) {
        onEvent(event)
    }

    /** Renders the child [node] with the same catalog. */
    @Composable
    public fun Child(node: A2uiNode, modifier: Modifier = Modifier) {
        RenderNode(context.state, node, catalog, onEvent, modifier)
    }
}

/**
 * The outer margin of leaf components (text, images, inputs, cards and buttons). Containers
 * (`Row`, `Column`, `List`) add no spacing, so nesting them doesn't add up space.
 */
public val LocalA2uiLeafMargin: ProvidableCompositionLocal<Dp> = staticCompositionLocalOf { 4.dp }

@Composable
private fun RenderNode(
    state: A2uiSurfaceState,
    node: A2uiNode,
    catalog: A2uiCatalog,
    onEvent: (A2uiEvent) -> Unit,
    modifier: Modifier,
) {
    val renderer = catalog[node.component.type] ?: return
    renderer(A2uiComponentScope(A2uiNodeContext(state, node), modifier, onEvent, catalog))
}
