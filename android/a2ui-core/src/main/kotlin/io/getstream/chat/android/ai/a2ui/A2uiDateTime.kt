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

import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException
import java.time.temporal.ChronoUnit

/**
 * Converts between ISO 8601 strings in the data model and date-times, for `DateTimeInput`.
 */
public object A2uiDateTime {

    /**
     * Parses an ISO 8601 date-time, date or time into a date-time in [zone].
     *
     * - A date-time with an offset (e.g. `2026-10-02T19:00:00Z`) is converted to [zone].
     * - A date-time without an offset is read in [zone].
     * - A date is read as the start of that day, a time as that time today.
     *
     * @return The date-time, or null if [value] is not a valid ISO 8601 value.
     */
    public fun parse(value: String?, zone: ZoneId, today: LocalDate = LocalDate.now(zone)): ZonedDateTime? {
        if (value.isNullOrBlank()) return null
        val text = value.trim()
        return parseOrNull { OffsetDateTime.parse(text).atZoneSameInstant(zone) }
            ?: parseOrNull { LocalDateTime.parse(text).atZone(zone) }
            ?: parseOrNull { LocalDate.parse(text).atStartOfDay(zone) }
            ?: parseOrNull { LocalTime.parse(text).atDate(today).atZone(zone) }
    }

    /**
     * Formats [dateTime] as the narrowest ISO 8601 value the input allows:
     *
     * - date and time: `2026-10-02T19:00:00+01:00` (with the offset of [dateTime]),
     * - date only: `2026-10-02`,
     * - time only: `19:00:00`.
     *
     * When both [enableDate] and [enableTime] are false, the input is treated as date only.
     */
    public fun format(dateTime: ZonedDateTime, enableDate: Boolean, enableTime: Boolean): String {
        val value = dateTime.truncatedTo(ChronoUnit.SECONDS)
        return when {
            enableDate && enableTime -> value.toOffsetDateTime().format(DateTimeFormatter.ISO_OFFSET_DATE_TIME)
            enableTime -> value.toLocalTime().format(DateTimeFormatter.ISO_LOCAL_TIME)
            else -> value.toLocalDate().format(DateTimeFormatter.ISO_LOCAL_DATE)
        }
    }

    private inline fun parseOrNull(parse: () -> ZonedDateTime): ZonedDateTime? = try {
        parse()
    } catch (_: DateTimeParseException) {
        null
    }
}
