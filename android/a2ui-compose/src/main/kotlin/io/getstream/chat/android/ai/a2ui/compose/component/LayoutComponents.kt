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

package io.getstream.chat.android.ai.a2ui.compose.component

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.key
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import io.getstream.chat.android.ai.a2ui.A2uiNode
import io.getstream.chat.android.ai.a2ui.compose.A2uiComponentScope

/**
 * Renders `Row`: children side by side, with `justify`, `align` and the child `weight`.
 */
@Composable
public fun A2uiRow(scope: A2uiComponentScope) {
    val justify = scope.context.string("justify")
    val align = scope.context.string("align")
    Row(
        modifier = scope.modifier
            .fillMaxWidth()
            .then(if (align == "stretch") Modifier.height(IntrinsicSize.Min) else Modifier)
            .testTag(scope.component.id),
        horizontalArrangement = horizontalArrangement(justify),
        verticalAlignment = when (align) {
            "center" -> Alignment.CenterVertically
            "end" -> Alignment.Bottom
            else -> Alignment.Top
        },
    ) {
        scope.context.children().forEach { child ->
            key(child.key) {
                val weight = child.weight(justify)
                scope.Child(
                    node = child,
                    modifier = Modifier
                        .then(if (weight != null) Modifier.weight(weight) else Modifier)
                        .then(if (align == "stretch") Modifier.fillMaxHeight() else Modifier),
                )
            }
        }
    }
}

/**
 * Renders `Column`: children one below the other, with `justify` and `align`.
 *
 * The child `weight` is ignored: a surface in a chat message has no height limit, and weighted
 * children of an unbounded column get no height.
 */
@Composable
public fun A2uiColumn(scope: A2uiComponentScope) {
    val justify = scope.context.string("justify")
    val align = scope.context.string("align")
    Column(
        modifier = scope.modifier.fillMaxWidth().testTag(scope.component.id),
        verticalArrangement = verticalArrangement(justify),
        horizontalAlignment = horizontalAlignment(align),
    ) {
        scope.context.children().forEach { child ->
            key(child.key) {
                scope.Child(child, if (align == "stretch") Modifier.fillMaxWidth() else Modifier)
            }
        }
    }
}

/**
 * Renders `List` with the `direction` `vertical` (default) or `horizontal`.
 *
 * All the items are composed at once: the surface is inside a chat message, which is already
 * in a lazy list, and the lists of a surface are short.
 */
@Composable
public fun A2uiList(scope: A2uiComponentScope) {
    val align = scope.context.string("align")
    val children = scope.context.children()
    if (scope.context.string("direction") == "horizontal") {
        Row(
            modifier = scope.modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState())
                .testTag(scope.component.id),
            verticalAlignment = when (align) {
                "center" -> Alignment.CenterVertically
                "end" -> Alignment.Bottom
                else -> Alignment.Top
            },
        ) {
            children.forEach { child ->
                key(child.key) { scope.Child(child, Modifier.widthIn(max = 280.dp)) }
            }
        }
    } else {
        Column(
            modifier = scope.modifier.fillMaxWidth().testTag(scope.component.id),
            horizontalAlignment = horizontalAlignment(align),
        ) {
            children.forEach { child ->
                key(child.key) {
                    scope.Child(child, if (align == "stretch") Modifier.fillMaxWidth() else Modifier)
                }
            }
        }
    }
}

/** The weight of [this] child, or 1 for every child when the container uses `stretch`. */
private fun A2uiNode.weight(justify: String?): Float? =
    component.weight?.takeIf { it > 0f } ?: if (justify == "stretch") 1f else null

private fun horizontalArrangement(justify: String?): Arrangement.Horizontal = when (justify) {
    "center" -> Arrangement.Center
    "end" -> Arrangement.End
    "spaceBetween" -> Arrangement.SpaceBetween
    "spaceAround" -> Arrangement.SpaceAround
    "spaceEvenly" -> Arrangement.SpaceEvenly
    else -> Arrangement.Start
}

private fun verticalArrangement(justify: String?): Arrangement.Vertical = when (justify) {
    "center" -> Arrangement.Center
    "end" -> Arrangement.Bottom
    "spaceBetween" -> Arrangement.SpaceBetween
    "spaceAround" -> Arrangement.SpaceAround
    "spaceEvenly" -> Arrangement.SpaceEvenly
    else -> Arrangement.Top
}

private fun horizontalAlignment(align: String?): Alignment.Horizontal = when (align) {
    "center" -> Alignment.CenterHorizontally
    "end" -> Alignment.End
    else -> Alignment.Start
}
