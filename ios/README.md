## AI Components

The AI UI components are designed specifically for AI-first applications written in SwiftUI. When paired with our real-time [Chat API](https://getstream.io/chat/), it makes integrating with and rendering responses from LLM providers such as ChatGPT, Gemini, Anthropic or any custom backend easier, by providing rich with out-of-the-box components able to render Markdown, Code blocks, tables, thinking indicators, images, charts etc.

This library includes the following components which assist with this task:

- `StreamingMessageView` - a component that is able to render text, markdown and code in real-time, using character-by-character animation, similar to ChatGPT.
- `ComposerView` - a fully featured prompt composer with attachments, suggestion chips and speech input.
- `SpeechToTextButton` - a reusable button that records voice input and streams the recognized transcript back into your UI.
- `AITypingIndicatorView` - a component that can display different states of the LLM (thinking, checking external sources, etc).

## Sample Project

This sample project showcase the usage of the AI components, how they integrate with Stream Chat's SwiftUI SDK and how to connect to a backend API.

The project is a ChatGPT clone, with the following features:
- Streaming messages with a message list optimized for AI assistants
- Composer with photos, camera, agent modes, speech to text button
- Conversation suggestions
- Thinking indicators
- Conversation history with a summary as the title of the channel
- Sidebar view, commonly seen in AI assistants

## Sample backend project 

You will also need a backend project that will provide the AI capabilities to the chat experience. 

You can try one of our NodeJS integrations with the [AI SDK](https://github.com/GetStream/chat-ai-samples/tree/main/ai-sdk-sample) or [Langchain](https://github.com/GetStream/chat-ai-samples/tree/main/langchain-sample), and run it locally. 

When you decide to deploy your backend, make sure to update the `baseURL` in `AgentService`.

## Project details

### Streaming Message View

The `StreamingMessageView` is a component that can render markdown content efficiently. It has code syntax highlighting, supporting all the major languages. It can render most of the standard markdown content, such as tables, images, charts, etc.

Under the hood, it implements letter by letter animation, with a character queue, similar to ChatGPT.

In the project, the streaming message view is integrated with the SwiftUI SDK as a custom attachment.

```swift
@ViewBuilder
func makeCustomAttachmentViewType(
    for message: ChatMessage,
    isFirst: Bool,
    availableWidth: CGFloat,
    scrolledId: Binding<String?>
) -> some View {
    let isGenerating = message.extraData["generating"]?.boolValue == true
    StreamingMessageView(
        content: message.text,
        isGenerating: isGenerating
    )
    .padding()
}
```

### AI Typing Indicator View

The `AITypingIndicatorView` is used to present different states of the LLM, such as "Thinking", "Checking External Sources", etc. You can specify any text you need. There's also a nice animation when the indicator is shown.

```swift
AITypingIndicatorView(text: "Thinking")
```

In the sample, the thinking indicator is added via the message list modifier from the SwiftUI SDK:

```swift
// In the View Factory:
func makeMessageListContainerModifier() -> some ViewModifier {
    CustomMessageListContainerModifier(typingIndicatorHandler: typingIndicatorHandler)
}

// Somewhere in your code:
struct CustomMessageListContainerModifier: ViewModifier {
    
    @ObservedObject var typingIndicatorHandler: TypingIndicatorHandler
    
    func body(content: Content) -> some View {
        content.overlay {
            AIAgentOverlayView(typingIndicatorHandler: typingIndicatorHandler)
        }
    }
}

struct AIAgentOverlayView: View {
    
    @ObservedObject var typingIndicatorHandler: TypingIndicatorHandler
    
    var body: some View {
        VStack {
            Spacer()
            if typingIndicatorHandler.typingIndicatorShown {
                HStack {
                    AITypingIndicatorView(text: typingIndicatorHandler.state)
                    Spacer()
                }
                .padding()
                .frame(height: 60)
                .background(Color(UIColor.secondarySystemBackground))
            }
        }
    }
}
```

### Composer View

The `ComposerView` gives users a modern text-entry surface with attachment previews, suggestions, and an integrated send and speech to text buttons. Inject a `ComposerViewModel` to handle state and pass a closure that receives every `MessageData` payload when the user taps send.

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

### Conversation History 

You can take the conversation history with StreamChat's API, via the `ChatChannelListViewModel`.

```swift
struct ConversationListView: View {
    
    @ObservedObject var viewModel: ChatChannelListViewModel
    var onChannelSelected: (ChatChannel) -> Void
    var onNewChat: () -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack {
                HStack {
                    Text("Conversations")
                        .font(.headline)
                    
                    Spacer()

                    Button(action: onNewChat) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.accentColor)
                    }
                    .accessibilityLabel("New chat")
                    .buttonStyle(.plain)
                }
                .padding()

                ForEach(viewModel.channels) { channel in
                    HStack {
                        Text(channel.name ?? channel.id)
                            .multilineTextAlignment(.leading)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onChannelSelected(channel)
                    }
                    .onAppear {
                        if let index = viewModel.channels.firstIndex(of: channel) {
                            viewModel.checkForChannels(index: index)
                        }
                    }
                }
            }
        }
    }
}
```

### Suggestions

You can use the `SuggestionsView` to show some conversation starters with the assistant. This view expects a list of strings.

In the callback, when a suggestion is tapped, typically you would send the message to the channel.

```swift
SuggestionsView(suggestions: predefinedOptions) { messageData in
    sendMessage(messageData)
}
```

## 👩‍💻 Free for Makers 👨‍💻

Stream is free for most side and hobby projects. To qualify, your project/company needs to have < 5 team members and < $10k in monthly revenue. Makers get $100 in monthly credit for video for free.
For more details, check out the [Maker Account](https://getstream.io/maker-account?utm_source=Github).

## 💼 We are hiring!

We've closed a [\$38 million Series B funding round](https://techcrunch.com/2021/03/04/stream-raises-38m-as-its-chat-and-activity-feed-apis-power-communications-for-1b-users/) in 2021 and we keep actively growing.
Our APIs are used by more than a billion end-users, and you'll have a chance to make a huge impact on the product within a team of the strongest engineers all over the world.
Check out our current openings and apply via [Stream's website](https://getstream.io/team/#jobs).