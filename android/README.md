## AI Components

The Android AI UI components are built with Jetpack Compose and shipped in the `stream-chat-android-ai-compose` artifact. They are tailored for AI-first assistants that sit on top of Stream Chat and Stream's [real-time Chat API](https://getstream.io/chat/). Pair them with responses from providers such as OpenAI, Gemini, Anthropic, or your own backend to render markdown, code, tables, and thinking indicators with just a few lines of Compose.

This library includes the following components which assist with this task:


- `StreamingText` – renders markdown/code in real-time with a character queue so AI responses feel alive.
- `ChatComposer` – a full-featured prompt composer with attachment previews, stop buttons, and gradient-friendly surfaces.
- `AITypingIndicator` – visualizes agent states like "Thinking" or "Checking sources".
- `SpeechToTextButton` – records microphone input, streams partial transcripts, and emits recognized text in real time.

## Sample Project

This sample project is a ChatGPT-style assistant that demonstrates how the Compose components glue together with Stream Chat's Android SDK and a backend agent service. The sample includes:

- Streaming responses with markdown and syntax highlighting via `StreamingText`.
- A modern composer with media attachments, stop generation, and smooth gradient overlays.
- Thinking/checking/generating indicators that mirror the assistant's real status.
- A drawer-based conversation list with "New chat" and delete actions.
- Conversation history titles that come from Stream channels so sessions feel persistent.
- Agent-generated UI (A2UI): restaurant cards, a booking form, and a confirmation, rendered from the AI message.

## Sample backend project 

You also need a backend that provides the AI responses used by the app. Run one of the provided NodeJS integrations locally, such as the [AI SDK sample](https://github.com/GetStream/chat-ai-samples/tree/main/ai-sdk-sample) or [Langchain sample](https://github.com/GetStream/chat-ai-samples/tree/main/langchain-sample).

When you deploy your backend, update the `baseUrl` you pass into `ChatDependencies` inside `android/app/src/main/kotlin/io/getstream/chat/android/ai/compose/sample/App.kt` so the Retrofit client points at the correct service.

## Agent-generated UI (A2UI)

The sample renders [A2UI](https://a2ui.org) v0.9 surfaces that the AI SDK sample attaches to AI messages. To try it, set these values in `ai-sdk-sample/.env` and start the backend:

```
OPENAI_API_KEY=your_api_key
A2UI_PROTOCOL=v0.9
```

Then ask "Top 3 restaurants in New York", tap **Book Now** on a card, change the booking form, and tap **Confirm reservation**.

The renderer is local to this sample and has two modules:

- `a2ui-core`: pure Kotlin, with JVM unit tests. It parses the `a2ui_v09` message field, applies the messages to an immutable surface state, and resolves data bindings, list templates, and the context of actions.
- `a2ui-compose`: `A2uiSurface(state, onEvent)`, a stateless Compose renderer. It supports `Text`, `Image`, `Row`, `Column`, `List`, `Card`, `Button`, `TextField`, and `DateTimeInput` from the basic catalog.

`ChatViewModel` keeps the surface of each message, so form input survives scrolling and configuration changes. `ChatMessageItem` renders the surface below the text of the assistant message:

```kotlin
A2uiSurface(
    state = surface,
    onEvent = { event -> chatViewModel.onA2uiEvent(message.id, event) },
)
```

When the user taps a button, the sample sends a user message with the action in `a2ui_interaction` (a JSON string) and the surface id in `a2ui_surface_id`. The backend answers these actions itself, without the LLM.

To change how a component looks, override it in the catalog:

```kotlin
A2uiSurface(
    state = surface,
    onEvent = onEvent,
    catalog = A2uiCatalog.Basic.with("Card") { scope -> MyCard(scope) },
)
```

To update the test payloads after a backend change, run `node --import ../../ai-sdk-sample/ts-esm-loader.mjs scripts/generate-fixtures.ts` from `android/a2ui-core`.

## Project details

### Streaming Text

`StreamingText` renders markdown efficiently and animates token streams in place. Inject it anywhere you display an assistant message to get ChatGPT-like streaming:

```kotlin
StreamingText(
    text = message.content,
    animate = message.isGenerating,
)
```

In `ChatMessageItem` the component sits inside `SelectionContainer` so users can copy code while responses are still streaming.

### AI Typing Indicator

`AITypingIndicator` presents real-time agent states such as "Thinking", "Checking sources", or "Generating response". Drive it with whatever state enum or sealed class you expose from your `ChatUiState`.

```kotlin
val label = when (assistantState) {
    ChatUiState.AssistantState.Thinking -> "Thinking"
    ChatUiState.AssistantState.CheckingSources -> "Checking sources"
    ChatUiState.AssistantState.Generating -> "Generating response"
    else -> null
}

if (label != null) {
    AITypingIndicator(
        modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp),
        label = { Text(text = label) },
    )
}
```

Attach it to the bottom of your `LazyColumn` so the indicator appears right where new responses will eventually land.

### Chat Composer

`ChatComposer` offers a modern entry field with attachment pills, send/stop buttons, and gradient support so it blends on top of any list.

```kotlin
ChatComposer(
    onSendClick = chatViewModel::sendMessage,
    onStopClick = chatViewModel::stopStreaming,
    isGenerating = state.assistantState.isBusy(),
)
```

The composer keeps its own text and attachments, and passes them to `onSendClick` as `MessageData`. Because the component simply emits callbacks, you can plug it into any view model or state container.

### Speech to Text Button

`SpeechToTextButton` wraps Android's speech recognizer with Compose-friendly state so you can turn microphone dictation into prompts. It requests audio permission, toggles recording, and returns partial and final transcripts via a single callback.

```kotlin
val speechState = rememberSpeechToTextButtonState(
    onFinalResult = { transcript -> onTextChange(transcript) },
)

SpeechToTextButton(state = speechState)
```

Its included into the composer `ChatComposer` but you can embed it directly inside custom toolbars to let users dictate prompts hands-free.

### Rendering Attachments

User responses reuse Stream's Compose attachment renderers so media previews mirror what you already get in the chat SDK:

```kotlin
if (message.attachments.isNotEmpty()) {
    ChatTheme {
        MediaAttachmentContent(
            state = AttachmentState(
                message = Message(text = message.content, attachments = message.attachments),
                isMine = true,
            ),
        )
    }
}
```

`ChatViewModel` uses `AttachmentStorageHelper` to convert attachments from device storage into Stream-ready payloads before they are sent to your backend and to other clients.

### Conversation History Drawer

A `ConversationListViewModel` observes the current user's channels using `queryChannelsAsState` and feeds the drawer UI so people can hop between chats like they would in any desktop AI assistant.

```kotlin
val request = QueryChannelsRequest(
    filter = Filters.and(
        Filters.eq("type", "messaging"),
        Filters.`in`("members", listOf(currentUserId)),
    ),
    querySort = QuerySortByField.descByName("last_updated"),
)

chatClient.queryChannelsAsState(request, viewModelScope)
    .filterNotNull()
    .flatMapLatest { it.channels.filterNotNull() }
    .onEach { channels ->
        _uiState.update { state ->
            state.copy(conversations = channels.map(Channel::toConversation))
        }
    }
```

`ChatDrawer` then renders the list, highlights the selected conversation, and exposes "New chat"/"Delete" actions to keep the demo feeling familiar to anyone who has used an AI side panel.

## 👩‍💻 Free for Makers 👨‍💻

Stream is free for most side and hobby projects. To qualify, your project/company needs to have < 5 team members and < $10k in monthly revenue. Makers get $100 in monthly credit for video for free.
For more details, check out the [Maker Account](https://getstream.io/maker-account?utm_source=Github).

## 💼 We are hiring!

We've closed a [\$38 million Series B funding round](https://techcrunch.com/2021/03/04/stream-raises-38m-as-its-chat-and-activity-feed-apis-power-communications-for-1b-users/) in 2021 and we keep actively growing.
Our APIs are used by more than a billion end-users, and you'll have a chance to make a huge impact on the product within a team of the strongest engineers all over the world.
Check out our current openings and apply via [Stream's website](https://getstream.io/team/#jobs).
