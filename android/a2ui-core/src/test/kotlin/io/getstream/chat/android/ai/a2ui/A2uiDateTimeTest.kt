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

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime

internal class A2uiDateTimeTest {

    private val lisbon = ZoneId.of("Europe/Lisbon")
    private val today = LocalDate.of(2026, 10, 2)

    @Test
    fun `a date-time with an offset is converted to the zone`() {
        assertEquals(
            ZonedDateTime.of(2026, 10, 2, 20, 0, 0, 0, lisbon),
            A2uiDateTime.parse("2026-10-02T19:00:00Z", lisbon),
        )
    }

    @Test
    fun `values without an offset are read in the zone`() {
        assertEquals(ZonedDateTime.of(2026, 10, 2, 19, 0, 0, 0, lisbon), A2uiDateTime.parse("2026-10-02T19:00", lisbon))
        assertEquals(ZonedDateTime.of(2026, 10, 2, 0, 0, 0, 0, lisbon), A2uiDateTime.parse("2026-10-02", lisbon))
        assertEquals(
            ZonedDateTime.of(2026, 10, 2, 19, 30, 0, 0, lisbon),
            A2uiDateTime.parse("19:30", lisbon, today),
        )
    }

    @Test
    fun `invalid values are not parsed`() {
        assertNull(A2uiDateTime.parse(null, lisbon))
        assertNull(A2uiDateTime.parse("", lisbon))
        assertNull(A2uiDateTime.parse("Today at 7:00 PM", lisbon))
        assertNull(A2uiDateTime.parse("2026-10-02T25:00:00Z", lisbon))
    }

    @Test
    fun `formats the narrowest value the input allows`() {
        val dateTime = ZonedDateTime.of(2026, 10, 2, 19, 0, 30, 500, lisbon)

        assertEquals("2026-10-02T19:00:30+01:00", A2uiDateTime.format(dateTime, enableDate = true, enableTime = true))
        assertEquals("2026-10-02", A2uiDateTime.format(dateTime, enableDate = true, enableTime = false))
        assertEquals("19:00:30", A2uiDateTime.format(dateTime, enableDate = false, enableTime = true))
        assertEquals("2026-10-02", A2uiDateTime.format(dateTime, enableDate = false, enableTime = false))
    }

    @Test
    fun `a date-time in UTC is formatted with Z`() {
        val utc = ZonedDateTime.of(2026, 10, 2, 19, 0, 0, 0, ZoneId.of("UTC"))

        assertEquals("2026-10-02T19:00:00Z", A2uiDateTime.format(utc, enableDate = true, enableTime = true))
    }

    @Test
    fun `a formatted value parses back to the same instant`() {
        val dateTime = ZonedDateTime.of(2026, 10, 2, 19, 15, 0, 0, lisbon)

        val parsed = A2uiDateTime.parse(A2uiDateTime.format(dateTime, true, true), lisbon)

        assertEquals(dateTime.toInstant(), parsed?.toInstant())
    }
}
