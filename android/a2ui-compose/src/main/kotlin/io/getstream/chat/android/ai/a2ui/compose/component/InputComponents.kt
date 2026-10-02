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

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.TimePickerDialog
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.focusProperties
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.input.VisualTransformation
import io.getstream.chat.android.ai.a2ui.A2uiDateTime
import io.getstream.chat.android.ai.a2ui.A2uiEvent
import io.getstream.chat.android.ai.a2ui.compose.A2uiComponentScope
import io.getstream.chat.android.ai.a2ui.compose.LocalA2uiLeafMargin
import io.getstream.chat.android.ai.a2ui.compose.R
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

/**
 * Renders `TextField` with the variants `shortText` (default), `longText`, `number` and
 * `obscured`. The `value` is a two-way binding: every change is sent as
 * [A2uiEvent.ValueChanged].
 */
@Composable
public fun A2uiTextField(scope: A2uiComponentScope) {
    val path = scope.context.boundPath("value")
    val value = scope.context.string("value").orEmpty()
    val variant = scope.context.string("variant")
    val validation = scope.context.string("validationRegexp")?.let { runCatching { Regex(it) }.getOrNull() }

    // While the user types, the field is the source of truth: the value in the state can be
    // an older text that is still on its way back. A change from outside (e.g. a new data
    // model) replaces the text when the field doesn't have focus.
    var field by remember { mutableStateOf(TextFieldValue(value, TextRange(value.length))) }
    var focused by remember { mutableStateOf(false) }
    LaunchedEffect(value, focused) {
        if (!focused && field.text != value) field = TextFieldValue(value, TextRange(value.length))
    }

    OutlinedTextField(
        value = field,
        onValueChange = { newValue ->
            val changed = newValue.text != field.text
            field = newValue
            if (path != null && changed) scope.send(A2uiEvent.ValueChanged(path, newValue.text))
        },
        modifier = scope.modifier
            .fillMaxWidth()
            .padding(LocalA2uiLeafMargin.current)
            .onFocusChanged { focused = it.isFocused }
            .testTag(scope.component.id),
        label = scope.context.string("label")?.let { label -> { Text(label) } },
        isError = validation != null && field.text.isNotEmpty() && !validation.matches(field.text),
        singleLine = variant != "longText",
        minLines = if (variant == "longText") 3 else 1,
        visualTransformation = if (variant == "obscured") PasswordVisualTransformation() else VisualTransformation.None,
        keyboardOptions = KeyboardOptions(
            keyboardType = when (variant) {
                "number" -> KeyboardType.Number
                "obscured" -> KeyboardType.Password
                else -> KeyboardType.Text
            },
        ),
    )
}

/**
 * Renders `DateTimeInput` as a read-only field that opens a date picker, a time picker, or
 * both, depending on `enableDate` and `enableTime`. The `value` is ISO 8601 in the data model
 * and is shown in the local format of the device.
 *
 * The whole field, including its icon, is one button: it opens the picker on a tap, with the
 * keyboard (Enter, D-pad center), TalkBack and Switch Access.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
public fun A2uiDateTimeInput(scope: A2uiComponentScope) {
    val path = scope.context.boundPath("value")
    val raw = scope.context.string("value")
    val enableTime = scope.context.boolean("enableTime") == true
    // With neither flag set, the input picks a date.
    val enableDate = scope.context.boolean("enableDate") == true || !enableTime
    val label = scope.context.string("label")
    val zone = remember { ZoneId.systemDefault() }
    val dateTime = remember(raw, zone) { A2uiDateTime.parse(raw, zone) }
    val shown = dateTime?.format(displayFormatter(enableDate, enableTime)) ?: raw.orEmpty()

    var picker by rememberSaveable { mutableStateOf(Picker.None) }
    var pickedDate by rememberSaveable { mutableStateOf<String?>(null) }
    val initial = dateTime ?: ZonedDateTime.now(zone)

    Box(
        modifier = scope.modifier
            .fillMaxWidth()
            .padding(LocalA2uiLeafMargin.current),
    ) {
        // readOnly (not disabled) keeps the normal colors of an input. The field is only for
        // the look: the layer on top handles input and accessibility.
        OutlinedTextField(
            value = shown,
            onValueChange = {},
            readOnly = true,
            singleLine = true,
            label = label?.let { { Text(it) } },
            trailingIcon = {
                Icon(painterResource(R.drawable.a2ui_ic_calendar), contentDescription = null)
            },
            modifier = Modifier
                .fillMaxWidth()
                .focusProperties { canFocus = false }
                .clearAndSetSemantics {},
        )
        Box(
            modifier = Modifier
                .matchParentSize()
                .clickable(role = Role.Button) {
                    picker = if (enableDate) Picker.Date else Picker.Time
                }
                .semantics { contentDescription = listOfNotNull(label, shown.ifEmpty { null }).joinToString(", ") }
                .testTag(scope.component.id),
        )
    }

    fun write(date: LocalDate, time: LocalTime) {
        val value = A2uiDateTime.format(ZonedDateTime.of(date, time, zone), enableDate, enableTime)
        if (path != null) scope.send(A2uiEvent.ValueChanged(path, value))
    }

    when (picker) {
        Picker.Date -> {
            val state = rememberDatePickerState(
                initialSelectedDateMillis = initial.toLocalDate().atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli(),
            )
            DatePickerDialog(
                onDismissRequest = { picker = Picker.None },
                confirmButton = {
                    TextButton(
                        onClick = {
                            // The picker returns the selected day at midnight UTC.
                            val date = state.selectedDateMillis
                                ?.let { Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate() }
                                ?: initial.toLocalDate()
                            if (enableTime) {
                                pickedDate = date.toString()
                                picker = Picker.Time
                            } else {
                                write(date, initial.toLocalTime())
                                picker = Picker.None
                            }
                        },
                    ) { Text(stringResource(android.R.string.ok)) }
                },
                dismissButton = {
                    TextButton(onClick = { picker = Picker.None }) { Text(stringResource(android.R.string.cancel)) }
                },
            ) {
                DatePicker(state = state)
            }
        }
        Picker.Time -> {
            val state = rememberTimePickerState(initialHour = initial.hour, initialMinute = initial.minute)
            TimePickerDialog(
                onDismissRequest = {
                    pickedDate = null
                    picker = Picker.None
                },
                title = { label?.let { Text(it) } },
                confirmButton = {
                    TextButton(
                        onClick = {
                            val date = pickedDate?.let(LocalDate::parse) ?: initial.toLocalDate()
                            write(date, LocalTime.of(state.hour, state.minute))
                            pickedDate = null
                            picker = Picker.None
                        },
                    ) { Text(stringResource(android.R.string.ok)) }
                },
                dismissButton = {
                    TextButton(
                        onClick = {
                            pickedDate = null
                            picker = Picker.None
                        },
                    ) { Text(stringResource(android.R.string.cancel)) }
                },
            ) {
                TimePicker(state = state)
            }
        }
        Picker.None -> Unit
    }
}

private enum class Picker { None, Date, Time }

private fun displayFormatter(enableDate: Boolean, enableTime: Boolean): DateTimeFormatter = when {
    enableDate && enableTime -> DateTimeFormatter.ofLocalizedDateTime(FormatStyle.MEDIUM, FormatStyle.SHORT)
    enableTime -> DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT)
    else -> DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM)
}
