## AI Components

The Android AI UI components are built with Jetpack Compose and shipped in the `stream-chat-android-ai-compose` artifact. They are tailored for AI-first assistants that sit on top of Stream Chat and Stream's [real-time Chat API](https://getstream.io/chat/). Pair them with responses from providers such as OpenAI, Gemini, Anthropic, or your own backend to render markdown, code, tables, thinking indicators, and multi-turn context with just a few lines of Compose.

This sample shows how to wire up:

- `StreamingText` – renders markdown/code in real-time with a character queue so AI responses feel alive.
- `ChatComposer` – a full-featured prompt composer with attachment previews, stop buttons, and gradient-friendly surfaces.
- `AITypingIndicator` – visualizes agent states like "Thinking" or "Checking sources".
- `ChatDrawer` + `ConversationListViewModel` – a sidebar for conversation history and quick navigation, built on Stream's state layer.

## Sample Project

`android/stream-chat-android-ai-compose-sample` is a ChatGPT-style assistant that demonstrates how the Compose components glue together with Stream Chat's Android SDK and a backend agent service. The sample includes:

- Streaming responses with markdown and syntax highlighting via `StreamingText`.
- A modern composer with media attachments, stop generation, and smooth gradient overlays.
- Thinking/checking/generating indicators that mirror the assistant's real status.
- A drawer-based conversation list with "New chat" and delete actions.
- Conversation history titles that come from Stream channels so sessions feel persistent.

## Sample backend project 

You also need a backend that provides the AI responses used by the app. Run one of the provided NodeJS integrations locally, such as the [AI SDK sample](https://github.com/GetStream/chat-ai-samples/tree/main/ai-sdk-sample) or [Langchain sample](https://github.com/GetStream/chat-ai-samples/tree/main/langchain-sample).

When you deploy your backend, update the `baseUrl` you pass into `ChatDependencies` inside `android/stream-chat-android-ai-compose-sample/src/main/kotlin/io/getstream/chat/android/ai/compose/sample/App.kt` so the Retrofit client points at the correct service.

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
    text = state.inputText,
    attachments = state.attachments,
    onTextChange = chatViewModel::onInputTextChange,
    onAttachmentsAdded = chatViewModel::onAttachmentsAdded,
    onAttachmentRemoved = chatViewModel::onAttachmentRemoved,
    onSendClick = chatViewModel::sendMessage,
    onStopClick = chatViewModel::stopStreaming,
    isStreaming = state.assistantState.isBusy(),
)
```

Because the component simply emits callbacks, you can plug it into any view model or state container.

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

Combined with the `StorageHelperWrapper`, attachments from device storage are converted into Stream-ready payloads before being sent to your backend and to other clients.

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
