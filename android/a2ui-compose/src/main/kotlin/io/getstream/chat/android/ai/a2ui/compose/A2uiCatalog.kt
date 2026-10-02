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
import androidx.compose.runtime.Immutable
import io.getstream.chat.android.ai.a2ui.compose.component.A2uiButton
import io.getstream.chat.android.ai.a2ui.compose.component.A2uiCard
import io.getstream.chat.android.ai.a2ui.compose.component.A2uiColumn
import io.getstream.chat.android.ai.a2ui.compose.component.A2uiDateTimeInput
import io.getstream.chat.android.ai.a2ui.compose.component.A2uiImage
import io.getstream.chat.android.ai.a2ui.compose.component.A2uiList
import io.getstream.chat.android.ai.a2ui.compose.component.A2uiRow
import io.getstream.chat.android.ai.a2ui.compose.component.A2uiText
import io.getstream.chat.android.ai.a2ui.compose.component.A2uiTextField

/**
 * Renders one component type.
 */
public typealias A2uiComponentRenderer = @Composable (scope: A2uiComponentScope) -> Unit

/**
 * The renderers of a component catalog, by component type (e.g. `Text`).
 *
 * Start from [Basic] and override or add types:
 *
 * ```
 * val catalog = A2uiCatalog.Basic.with("Card") { scope -> MyCard(scope) }
 * ```
 */
@Immutable
public class A2uiCatalog(
    public val renderers: Map<String, A2uiComponentRenderer>,
) {

    /** Returns the renderer of [type], or null if the catalog doesn't have one. */
    public operator fun get(type: String): A2uiComponentRenderer? = renderers[type]

    /** Returns a copy of the catalog that renders [type] with [renderer]. */
    public fun with(type: String, renderer: A2uiComponentRenderer): A2uiCatalog =
        A2uiCatalog(renderers + (type to renderer))

    /** Returns a catalog with the renderers of both. The ones of [other] win. */
    public operator fun plus(other: A2uiCatalog): A2uiCatalog = A2uiCatalog(renderers + other.renderers)

    public companion object {
        /**
         * The components of the A2UI v0.9 basic catalog that this module supports.
         */
        public val Basic: A2uiCatalog = A2uiCatalog(
            mapOf(
                "Text" to renderer { A2uiText(it) },
                "Image" to renderer { A2uiImage(it) },
                "Row" to renderer { A2uiRow(it) },
                "Column" to renderer { A2uiColumn(it) },
                "List" to renderer { A2uiList(it) },
                "Card" to renderer { A2uiCard(it) },
                "Button" to renderer { A2uiButton(it) },
                "TextField" to renderer { A2uiTextField(it) },
                "DateTimeInput" to renderer { A2uiDateTimeInput(it) },
            ),
        )

        private fun renderer(render: A2uiComponentRenderer): A2uiComponentRenderer = render
    }
}
