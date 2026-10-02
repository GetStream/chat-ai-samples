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

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedCard
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import io.getstream.chat.android.ai.a2ui.compose.A2uiComponentScope
import io.getstream.chat.android.ai.a2ui.compose.LocalA2uiLeafMargin
import io.getstream.chat.android.ai.a2ui.compose.R

/**
 * Renders `Text`. Supports the variants `h1` to `h5`, `caption` and `body` (default).
 * Simple Markdown markers (`#` headings, `**` and `__`) are removed.
 */
@Composable
public fun A2uiText(scope: A2uiComponentScope) {
    val text = scope.context.string("text") ?: return
    val variant = scope.context.string("variant")
    val typography = MaterialTheme.typography
    val style: TextStyle = when (variant) {
        "h1" -> typography.headlineMedium
        "h2" -> typography.headlineSmall
        "h3" -> typography.titleLarge
        "h4" -> typography.titleMedium
        "h5" -> typography.titleSmall
        "caption" -> typography.bodySmall
        else -> typography.bodyMedium
    }
    val color = LocalContentColor.current.let { if (variant == "caption") it.copy(alpha = 0.7f) else it }
    Text(
        text = text.stripMarkdown(),
        modifier = scope.modifier.padding(LocalA2uiLeafMargin.current).testTag(scope.component.id),
        style = style,
        color = color,
    )
}

/**
 * Renders `Image` with its `fit` and size `variant`. Shows a placeholder when the image
 * can't be loaded.
 */
@Composable
public fun A2uiImage(scope: A2uiComponentScope) {
    val url = scope.context.string("url")
    val contentScale = when (scope.context.string("fit")) {
        "cover" -> ContentScale.Crop
        "fill" -> ContentScale.FillBounds
        "none" -> ContentScale.None
        "scaleDown" -> ContentScale.Inside
        else -> ContentScale.Fit
    }
    val variant = scope.context.string("variant")
    val shape = if (variant == "avatar") CircleShape else RoundedCornerShape(8.dp)
    val size = when (variant) {
        "icon" -> Modifier.size(24.dp)
        "avatar" -> Modifier.size(40.dp)
        "smallFeature" -> Modifier.size(100.dp)
        "largeFeature" -> Modifier.fillMaxWidth().height(280.dp)
        "header" -> Modifier.fillMaxWidth().height(200.dp)
        else -> Modifier.fillMaxWidth().height(180.dp)
    }
    var failed by remember(url) { mutableStateOf(url.isNullOrBlank()) }
    Box(
        modifier = scope.modifier
            .padding(LocalA2uiLeafMargin.current)
            .then(size)
            .clip(shape)
            .testTag(scope.component.id),
    ) {
        if (failed) {
            ImagePlaceholder()
        } else {
            AsyncImage(
                model = url,
                contentDescription = scope.context.string("description"),
                contentScale = contentScale,
                onError = { failed = true },
                modifier = Modifier.fillMaxSize(),
            )
        }
    }
}

@Composable
private fun ImagePlaceholder() {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.surfaceVariant),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            painter = painterResource(R.drawable.a2ui_ic_image_placeholder),
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

/**
 * Renders `Card` as an outlined card around its `child`.
 */
@Composable
public fun A2uiCard(scope: A2uiComponentScope) {
    val child = scope.context.child()
    OutlinedCard(modifier = scope.modifier.padding(LocalA2uiLeafMargin.current).testTag(scope.component.id)) {
        child?.let { scope.Child(it, Modifier.padding(8.dp)) }
    }
}

/**
 * Renders `Button` with the variants `primary`, `default` and `borderless`. A tap sends the
 * server event of `action`, with its context resolved at that moment.
 */
@Composable
public fun A2uiButton(scope: A2uiComponentScope) {
    val child = scope.context.child()
    val focusManager = LocalFocusManager.current
    val onClick: () -> Unit = {
        // Close the keyboard of a text field, so the answer to the action is visible.
        focusManager.clearFocus()
        scope.context.action()?.let(scope::send)
    }
    val modifier = scope.modifier.padding(LocalA2uiLeafMargin.current).testTag(scope.component.id)
    val content: @Composable () -> Unit = {
        // The button already has inner padding, so its content needs no margin.
        CompositionLocalProvider(LocalA2uiLeafMargin provides 0.dp) {
            child?.let { scope.Child(it) }
        }
    }
    when (scope.context.string("variant")) {
        "primary" -> Button(onClick = onClick, modifier = modifier) { content() }
        "borderless" -> TextButton(onClick = onClick, modifier = modifier) { content() }
        else -> OutlinedButton(onClick = onClick, modifier = modifier) { content() }
    }
}

private val headingMarker = Regex("^#{1,6}\\s+", RegexOption.MULTILINE)

private fun String.stripMarkdown(): String =
    replace(headingMarker, "").replace("**", "").replace("__", "")
