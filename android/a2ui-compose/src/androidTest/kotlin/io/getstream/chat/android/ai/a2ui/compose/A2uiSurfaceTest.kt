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

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.input.InputMode
import androidx.compose.ui.input.InputModeManager
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.platform.LocalInputModeManager
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.ExperimentalTestApi
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertContentDescriptionContains
import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsFocused
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performKeyInput
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.test.pressKey
import androidx.compose.ui.test.performTextReplacement
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import io.getstream.chat.android.ai.a2ui.A2uiDateTime
import io.getstream.chat.android.ai.a2ui.A2uiEvent
import io.getstream.chat.android.ai.a2ui.A2uiParser
import io.getstream.chat.android.ai.a2ui.A2uiReducer
import io.getstream.chat.android.ai.a2ui.A2uiSurfaceState
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.time.ZoneId

/**
 * Renders the payloads of the ai-sdk-sample backend (see `a2ui-core/scripts`) and checks the
 * events the surface sends.
 */
@RunWith(AndroidJUnit4::class)
internal class A2uiSurfaceTest {

    @get:Rule
    val composeRule = createComposeRule()

    private val events = mutableListOf<A2uiEvent>()

    private lateinit var inputModeManager: InputModeManager

    /** Renders [initial] like an owner would: value changes are applied to the state. */
    private fun render(initial: A2uiSurfaceState, catalog: A2uiCatalog = A2uiCatalog.Basic) {
        composeRule.setContent {
            var state by remember { mutableStateOf(initial) }
            inputModeManager = LocalInputModeManager.current
            MaterialTheme {
                A2uiSurface(
                    state = state,
                    onEvent = { event ->
                        events += event
                        state = A2uiReducer.reduce(state, event)
                    },
                    catalog = catalog,
                )
            }
        }
    }

    @Test
    fun restaurantList_rendersEveryItemAndSendsTheContextOfThePressedCard() {
        val state = fixture("restaurant-list")
        render(state)

        composeRule.onNodeWithText("Top 3 restaurants in New York").assertIsDisplayed()
        composeRule.onAllNodesWithTag("restaurant-card").fetchSemanticsNodes().let { assertEquals(3, it.size) }
        composeRule.onNodeWithText(state.valueAt("/items/1/name") as String).assertExists()

        composeRule.onAllNodesWithTag("restaurant-book-button")[1].performClick()

        assertEquals(
            listOf(
                A2uiEvent.ActionTriggered(
                    name = "book_restaurant",
                    context = mapOf(
                        "restaurantName" to state.valueAt("/items/1/name"),
                        "address" to state.valueAt("/items/1/address"),
                        "imageUrl" to state.valueAt("/items/1/imageUrl"),
                    ),
                ),
            ),
            events,
        )
    }

    @Test
    fun bookingForm_sendsTheEnteredValuesWithTheSubmitAction() {
        val state = fixture("booking-form")
        render(state)

        composeRule.onNodeWithTag("booking-party").performTextReplacement("6")
        composeRule.onNodeWithTag("booking-dietary").performTextReplacement("Vegan")
        composeRule.onNodeWithTag("booking-submit").performClick()

        assertEquals(A2uiEvent.ValueChanged("/partySize", "6"), events.first())
        val submit = events.last() as A2uiEvent.ActionTriggered
        assertEquals("submit_booking", submit.name)
        assertEquals(
            mapOf(
                "restaurantName" to state.valueAt("/restaurantName"),
                "address" to state.valueAt("/address"),
                "imageUrl" to state.valueAt("/imageUrl"),
                "partySize" to "6",
                "reservationTime" to state.valueAt("/reservationTime"),
                "dietary" to "Vegan",
            ),
            submit.context,
        )
    }

    @Test
    fun dateTimeInput_isEnabledAndWritesTheSelectionAsIso8601() {
        val state = fixture("booking-form")
        render(state)

        val field = composeRule.onNodeWithTag("booking-time")
        field.assertIsEnabled()
        field.performClick()
        composeRule.onNodeWithText("OK").performClick() // Date picker
        composeRule.onNodeWithText("OK").performClick() // Time picker

        val change = events.single() as A2uiEvent.ValueChanged
        assertEquals("/reservationTime", change.path)
        val zone = ZoneId.systemDefault()
        // Confirming both pickers without changes keeps the same moment.
        assertEquals(
            A2uiDateTime.parse(state.valueAt("/reservationTime") as String, zone)?.toInstant(),
            A2uiDateTime.parse(change.value as String, zone)?.toInstant(),
        )
        assertNotNull(Regex("""\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(Z|[+-]\d{2}:\d{2})""").matchEntire(change.value as String))
    }

    @Test
    fun dateTimeInput_isOneButtonWithItsLabelAndValue() {
        render(fixture("booking-form"))

        composeRule.onNodeWithTag("booking-time")
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.Button))
            .assertHasClickAction()
            .assertContentDescriptionContains("Reservation time", substring = true)
    }

    @Test
    fun dateTimeInput_opensWithTheAccessibilityClickAction() {
        render(fixture("booking-form"))

        composeRule.onNodeWithTag("booking-time").performSemanticsAction(SemanticsActions.OnClick)

        composeRule.onNodeWithText("OK").assertIsDisplayed()
    }

    @OptIn(ExperimentalTestApi::class)
    @Test
    fun dateTimeInput_opensWithTheEnterKey() {
        render(fixture("booking-form"))

        // Like a hardware keyboard user: in keyboard mode, the field can take focus.
        composeRule.runOnIdle { inputModeManager.requestInputMode(InputMode.Keyboard) }
        val field = composeRule.onNodeWithTag("booking-time")
        field.performSemanticsAction(SemanticsActions.RequestFocus)
        field.assertIsFocused()
        field.performKeyInput { pressKey(Key.Enter) }

        composeRule.onNodeWithText("OK").assertIsDisplayed()
    }

    @Test
    fun bookingConfirmation_rendersTheDetails() {
        val state = fixture("booking-confirmation")
        render(state)

        composeRule.onNodeWithText(state.valueAt("/title") as String).assertIsDisplayed()
        composeRule.onNodeWithText(state.valueAt("/bookingDetails") as String).assertExists()
    }

    @Test
    fun catalog_canOverrideAComponentType() {
        render(fixture("booking-confirmation"), A2uiCatalog.Basic.with("Text") { Text("custom") })

        composeRule.onAllNodesWithText("custom").fetchSemanticsNodes().let { assertEquals(3, it.size) }
    }

    private fun fixture(name: String): A2uiSurfaceState {
        val assets = InstrumentationRegistry.getInstrumentation().context.assets
        val json = assets.open("fixtures/$name.json").bufferedReader().use { it.readText() }
        val payload = checkNotNull(A2uiParser.parsePayload(JSONObject(json).toKotlin()))
        return checkNotNull(A2uiReducer.reduce(payload))
    }

    private fun Any?.toKotlin(): Any? = when (this) {
        is JSONObject -> keys().asSequence().associateWith { get(it).toKotlin() }
        is JSONArray -> (0 until length()).map { get(it).toKotlin() }
        JSONObject.NULL -> null
        else -> this
    }
}
