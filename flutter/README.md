# Stream Chat AI Assistant for [Flutter](https://getstream.io/blog/flutter-assistant/)

A Flutter chat app with an AI assistant, built on the Stream [Chat SDK](https://getstream.io/chat/)
and [`stream_chat_flutter_ai`](https://github.com/GetStream/stream-chat-flutter-ai/tree/main/packages/stream_chat_flutter_ai).

It opens straight into a "new chat" composer rather than a channel list. Type a message or tap a
suggestion, and an AI agent joins the conversation and streams its reply back as markdown. Past
conversations live in a drawer reached by edge-swiping from the left.

## Demo
| App Demo                                                                                      |
|-----------------------------------------------------------------------------------------------|
| <video src="https://github.com/user-attachments/assets/5c4ff0fc-e2d0-41ec-a825-6190fc481d2f"> |

## Features

- **Chat-first navigation**: no channel list and no app bar — the app is a composer, with history
  tucked into an edge-swipe drawer.
- **Automatic agent lifecycle**: the agent starts whenever a conversation becomes active, whether
  newly created or reopened from history. There's no "Start AI" button; the backend stops idle
  agents on its own.
- **Streaming responses**: replies render as plain markdown with `StreamingMessageView` — no avatar,
  no bubble.
- **Typing indicator**: `AITypingIndicatorView` reflects whether the assistant is thinking, checking
  sources, or generating.
- **AI composer**: `ChatComposer` with suggestion chips, attachments, speech-to-text, and a trailing
  control that flips to a stop button while a reply streams.
- **Client-side tools**: the assistant can trigger real behaviour in the app — see below.
- **AI-generated titles**: a new conversation is named after its first message, summarized by the
  backend.

## Client-side tools

Client-side tools let the assistant do things in the app rather than only talk about them: show an
alert, navigate, read a sensor. Two ship here, both in
[`lib/src/chat_ai_assistant_client_tools.dart`](lib/src/chat_ai_assistant_client_tools.dart):

| Tool | Arguments | Effect | Ask the assistant |
|---|---|---|---|
| `greetUser` | none | Shows an alert | "greet me" |
| `setThemeMode` | `mode`: `light` \| `dark` \| `system` | Switches the app's theme | "switch to dark mode" |

How a tool call travels:

1. Each tool implements `AIClientTool` and goes into an `AIToolRegistry`, created once in
   `ChatAIAssistantHomePage`.
2. When a conversation's agent starts, the registry's `registrationPayloads()` are POSTed to the
   backend's `/register-tools`, telling the model which tools exist.
3. The model calls one, and the agent sends a `custom_client_tool_invocation` event down the normal
   chat connection.
4. `ChatAIAssistantClientToolListener` parses that event and dispatches it to the registry, which
   runs the matching tool.

Two properties of this protocol shape the code, and are worth knowing before you add a tool:

- **Nothing is returned to the model.** A tool is a side effect, not a function call with a result,
  so none of them return a value.
- **Registrations are persisted by the backend** and re-applied when an agent restarts. A
  conversation registered by an older build of the app can therefore invoke a tool the current build
  no longer has, which is why `dispatch` returning `false` is normal rather than an error.

Tools hand back deferred actions instead of acting directly, since a tool object has no
`BuildContext` and can't know whether the app is even foregrounded. Those actions land in
`ChatAIAssistantToolActionHandler`, which the widget tree listens to.

## Getting started

For a step-by-step walkthrough of building this, see the
[Flutter AI assistant guide](https://getstream.io/blog/flutter-assistant/) on our blog.

### Prerequisites

- Flutter SDK >= 3.41.0
- A [Stream account](https://getstream.io/try-for-free/) and API key
- An OpenAI API key, for the backend

### 1. Run the backend

The app expects a backend on `http://localhost:3000`. Use
[`ai-sdk-sample`](../ai-sdk-sample) from this repository, which provides the agent
lifecycle, client-tool registration, and summarization endpoints this app calls:

```sh
cd ../ai-sdk-sample
cp .env.example .env   # fill in STREAM_API_KEY, STREAM_API_SECRET and OPENAI_API_KEY
npm install
npm start
```

Use the same Stream app for the backend and the Flutter app, or the agent will never appear in your
conversations.

### 2. Point at `stream_chat_flutter_ai`

This sample depends on `stream_chat_flutter_ai` via a **local path**, pointing at a sibling checkout
of [`GetStream/stream-chat-flutter-ai`](https://github.com/GetStream/stream-chat-flutter-ai):

```yaml
stream_chat_flutter_ai:
  path: ../../stream-chat-flutter-ai/packages/stream_chat_flutter_ai
```

Adjust the path to wherever you cloned it. Once the package is published to pub.dev this becomes a
version constraint like the other Stream dependencies.

### 3. Configure the app

Set your Stream API key and a user token in `lib/main.dart`:

```dart
final client = StreamChatClient('your_api_key');

final user = await client.connectUser(
  User(id: 'your_user_id'),
  'your_user_token',
);
```

### 4. Run it

```sh
flutter pub get
flutter run
```

## Usage

- **Start a conversation**: tap a suggestion chip or type a message. The agent joins automatically.
- **Browse history**: edge-swipe from the left, or tap "New chat" in that drawer to start over.
- **Try a tool**: ask the assistant to greet you, or to switch the app to dark mode.

## Project structure

- `lib/main.dart` — entry point: Stream client setup and app theme.
- `lib/src/chat_ai_assistant_home_page.dart` — the single screen: persistent composer, landing view,
  and history drawer.
- `lib/src/chat_ai_assistant_channel_page.dart` — the active conversation (message list and typing
  indicator).
- `lib/src/chat_ai_assistant_service.dart` — backend calls: start/stop the agent, register tools,
  summarize a title.
- `lib/src/chat_ai_assistant_typing_indicator_handler.dart` — AI typing-indicator state.
- `lib/src/chat_ai_assistant_client_tools.dart` — the client-side tools, the handler their effects
  land in, and the event listener feeding the registry.

---

Note: This project is an example implementation and is not intended for production use.
Contributions and improvements are welcome.

## 🛥 What is Stream?

Stream allows developers to rapidly deploy scalable feeds, chat messaging and video with an industry
leading 99.999% uptime SLA guarantee.

Stream provides UI components and state handling that make it easy to build real-time chat and video
calling for your app. Stream runs and maintains a global network of edge servers around the world,
ensuring optimal latency and reliability regardless of where your users are located.

## 📕 Tutorials

To learn more about integrating AI and chatbots into your application, we recommend checking out the
full list of tutorials across all of our supported frontend SDKs and providers. Stream's Chat SDK is
natively supported across:

* [React](https://getstream.io/blog/react-assistant/)
* [React Native](https://getstream.io/blog/react-native-assistant/)
* [Jetpack Compose](https://getstream.io/blog/android-assistant/)
* [Swift UI](https://getstream.io/blog/ios-assistant/)
* [Flutter](https://getstream.io/blog/flutter-assistant/)

## 👩‍💻 Free for Makers 👨‍💻

Stream is free for most side and hobby projects. To qualify, your project/company needs to have < 5
team members and < $10k in monthly revenue. Makers get $100 in monthly credit for video for free.
For more details, check out
the [Maker Account](https://getstream.io/maker-account?utm_source=Github&utm_medium=Github_Repo_Content&utm_content=Developer&utm_campaign=Github_Swift_AI_SDK&utm_term=DevRelOss).

## 💼 We are hiring!

We've recently closed
a [\$38 million Series B funding round](https://techcrunch.com/2021/03/04/stream-raises-38m-as-its-chat-and-activity-feed-apis-power-communications-for-1b-users/)
and we keep actively growing.
Our APIs are used by more than a billion end-users, and you'll have a chance to make a huge impact
on the product within a team of the strongest engineers all over the world.
Check out our current openings and apply via [Stream's website](https://getstream.io/team/#jobs).

## License

```
Copyright (c) 2014-2024 Stream.io Inc. All rights reserved.

Licensed under the Stream License;
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   https://github.com/GetStream/stream-chat-swift-ai/blob/main/LICENSE

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
