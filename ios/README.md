The AI UI components are designed specifically for AI-first applications written in SwiftUI. When paired with our real-time [Chat API](https://getstream.io/chat/), it makes integrating with and rendering responses from LLM providers such as ChatGPT, Gemini, Anthropic or any custom backend easier, by providing rich with out-of-the-box components able to render Markdown, Code blocks, tables, thinking indicators, images, charts etc.

This library includes the following components which assist with this task:

- `StreamingMessageView` - a component that is able to render text, markdown and code in real-time, using character-by-character animation, similar to ChatGPT.
- `ComposerView` - a fully featured prompt composer with attachments, suggestion chips and speech input.
- `SpeechToTextButton` - a reusable button that records voice input and streams the recognized transcript back into your UI.
- `AITypingIndicatorView` - a component that can display different states of the LLM (thinking, checking external sources, etc).

## Installation

The AI components are available via the Swift Package Manager (SPM). Use the following steps to add the SDK via SPM in Xcode:

- Select "Add Packages…" in File menu
- Paste the URL <https://github.com/GetStream/stream-chat-swift-ai.git>
- In the option "Dependency Rule" choose "Up to next major version", and in the text inputs next to it, enter "0.1.0" and "1.0.0" accordingly.

You can also add the components in your package file as a dependency:

```swift
.package(url: "https://github.com/GetStream/stream-chat-swift-ai.git", from: "0.1.0")
```

### Streaming Message View

The `StreamingMessageView` is a component that can render markdown content efficiently. It has code syntax highlighting, supporting all the major languages. It can render most of the standard markdown content, such as tables, images, charts, etc.

Under the hood, it implements letter by letter animation, with a character queue, similar to ChatGPT.

Here's an example how to use it.

```swift
StreamingMessageView(
    content: content,
    isGenerating: true
)
```

Additionally, you can specify the speed of the animation, with the `letterInterval` parameter. The default value is 0.005 (5ms).

### AI Typing Indicator View

The `AITypingIndicatorView` is used to present different states of the LLM, such as "Thinking", "Checking External Sources", etc. You can specify any text you need. There's also a nice animation when the indicator is shown.

```swift
AITypingIndicatorView(text: "Thinking")
```

### Composer View

The `ComposerView` gives users a modern text-entry surface with attachment previews, suggestions, and an integrated send button. Inject a `ComposerViewModel` to handle state and pass a closure that receives every `MessageData` payload when the user taps send.

```swift
@available(iOS 16, *)
ComposerView(
    viewModel: ComposerViewModel(),
    colors: colors
) { message in
    print(message.text, message.attachments)
}
```

The view also exposes chat options (e.g. "agent" mode) via `chatOptions` on the view model and automatically resets attachments once a message is sent.

### Speech to Text Button

`SpeechToTextButton` turns voice input into text using Apple's Speech framework. When tapped it asks for microphone access, records audio, and forwards the recognized transcript through its closure.

```swift
SpeechToTextButton(
    locale: Locale(identifier: "en-US"),
    colors: colors
) { transcript in
    print("User said:", transcript)
}
```

Display it alongside `ComposerView` to let users dictate prompts when their hands are busy.

These components are designed to work seamlessly with our existing Swift UI [Chat SDK](https://getstream.io/tutorials/ios-chat/). Our [developer guide](https://getstream.io/chat/solutions/ai-integration/) explains how to get started building AI integrations with Stream and Swift UI.

### Customizing Colors

The `Colors` class centralizes the palette that the AI components use. Create a single instance and inject it into the views you render to keep them in sync:

```swift
let colors = Colors(
    composer: .init(
        attachmentButtonIcon: .pink,
        selectedOptionForeground: .purple
    ),
    suggestions: .init(background: .mint.opacity(0.3)),
    transcription: .init(icon: .orange)
)

ComposerView(colors: colors) { message in
    // Handle message
}

SuggestionsView(
    suggestions: ["What are the docs for the AI SDK?"],
    colors: colors,
    onMessageSend: handleSuggestion
)

SpeechToTextButton(colors: colors) { transcript in
    print(transcript)
}
```

## 👩‍💻 Free for Makers 👨‍💻

Stream is free for most side and hobby projects. To qualify, your project/company needs to have < 5 team members and < $10k in monthly revenue. Makers get $100 in monthly credit for video for free.
For more details, check out the [Maker Account](https://getstream.io/maker-account?utm_source=Github).

## 💼 We are hiring!

We've closed a [\$38 million Series B funding round](https://techcrunch.com/2021/03/04/stream-raises-38m-as-its-chat-and-activity-feed-apis-power-communications-for-1b-users/) in 2021 and we keep actively growing.
Our APIs are used by more than a billion end-users, and you'll have a chance to make a huge impact on the product within a team of the strongest engineers all over the world.
Check out our current openings and apply via [Stream's website](https://getstream.io/team/#jobs).