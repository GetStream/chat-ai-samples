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
- **Rich replies**: fenced code is syntax-highlighted, LaTeX is typeset, chart fences render as
  charts, and links open in the browser. The package renders the chrome but ships no grammars or
  math engine — `lib/src/code_highlighter.dart` and the `mathBuilder` in
  `lib/src/ai_message_item.dart` are where this app supplies them.
- **Typing indicator**: `AITypingIndicatorView` reflects whether the assistant is thinking, checking
  sources, or generating.
- **AI composer**: `ChatComposer` with suggestion chips, attachments, speech-to-text, and a trailing
  control that flips to a stop button while a reply streams.
- **Client-side tools**: the assistant can trigger real behaviour in the app — see below.
- **AI-generated titles**: a new conversation is named after its first message, summarized by the
  backend.
- **Connection banner**: a strip at the top of the screen while the realtime connection is
  reconnecting or offline. Without it a dropped connection is invisible — AI replies land empty and
  tool invocations are missed, which reads as the assistant misbehaving rather than as a network
  problem.

## Client-side tools

Client-side tools let the assistant do things in the app rather than only talk about them: show an
alert, navigate, read a sensor. Two ship here, both in
[`lib/src/client_tools.dart`](lib/src/client_tools.dart):

| Tool | Arguments | Effect | Ask the assistant |
|---|---|---|---|
| `greetUser` | none | Shows an alert | "greet me" |
| `setThemeMode` | `mode`: `light` \| `dark` \| `system` | Switches the app's theme | "switch to dark mode" |

How a tool call travels:

1. Each tool implements `AIClientTool` and goes into an `AIToolRegistry`, created once in
   `HomePage`.
2. When a conversation's agent starts, the registry's `registrationPayloads()` are POSTed to the
   backend's `/register-tools`, telling the model which tools exist.
3. The model calls one, and the agent sends a `custom_client_tool_invocation` event down the normal
   chat connection.
4. `ClientToolListener` parses that event and dispatches it to the registry, which
   runs the matching tool.

Two properties of this protocol shape the code, and are worth knowing before you add a tool:

- **Nothing is returned to the model.** A tool is a side effect, not a function call with a result:
  the invocation event carries no field for one, so none of the tools here return a value.
- **Registrations are kept by the backend** (in memory, in `ai-sdk-sample`) and re-applied when an agent restarts. A
  conversation registered by an older build of the app can therefore invoke a tool the current build
  no longer has, which is why `dispatch` returning `false` is normal rather than an error.

Tools hand back deferred actions instead of acting directly, so the registry decides when they run.
Each tool here takes a callback — `HomePage` passes one that shows the dialog or changes the theme.

### "Client tool … invocation dispatched."

Running against `ai-sdk-sample`, every tool call is followed by an assistant message reading
`Client tool "greetUser" invocation dispatched.` That text comes from the **backend**, not from this
app and not from `stream_chat_flutter_ai`. The Node SDK wraps each registered tool so that, once it
has sent the invocation event, it returns that string as the tool's result to the model — which then
lands in the channel like any other reply.

It reports that the event was *dispatched*, not that your tool ran: it is returned as soon as the
event is sent, so it says the same thing whether the tool succeeded, threw, or belongs to a build of
the app that no longer registers it.

None of this is part of the protocol `stream_chat_flutter_ai` implements — it takes no backend
dependency, and a different backend can return something else, or nothing, or not surface it as a
message at all. If you don't want the line in your transcripts, change what your backend returns.

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

On the Android emulator, the app connects to `http://10.0.2.2:3000`, the emulator's address for your
machine, so no extra setup is needed. On a physical Android device, forward the port and point the
app at `localhost`:

```sh
adb reverse tcp:3000 tcp:3000
flutter run --dart-define=AGENT_BASE_URL=http://localhost:3000
```

If the backend can't be reached, the app says so in a snackbar when you start or open a conversation.

### 2. Configure the app

`lib/main.dart` ships with a demo API key and user token. Replace them with your own:

```dart
final client = StreamChatClient('your_api_key');
await client.connectUser(User(id: 'your_user_id'), 'your_user_token');
```

The API key must belong to the same Stream app as the backend's `.env`, and the token must be signed
with that app's secret.

### 3. Run it

```sh
flutter pub get
flutter run
```

`lib/main_dev.dart` runs the same app with the Marionette binding, so the Marionette MCP server can
drive it:

```sh
flutter run -t lib/main_dev.dart
```

## Usage

- **Start a conversation**: tap a suggestion chip or type a message. The agent joins automatically.
- **Browse history**: edge-swipe from the left, or tap "New chat" in that drawer to start over.
- **Try a tool**: ask the assistant to greet you, or to switch the app to dark mode.

## Project structure

- `lib/main.dart` — entry point: Stream client setup and app theme.
- `lib/main_dev.dart` — the same app with the Marionette binding, for driving it from tools.
- `lib/src/home_page.dart` — the single screen: persistent composer, landing view, and history
  drawer.
- `lib/src/conversation_view.dart` — the active conversation: message list and typing indicator.
- `lib/src/ai_message_item.dart` — how an AI message renders, including code, math and links.
- `lib/src/agent_service.dart` — backend calls: start the agent, register tools, summarize a title.
- `lib/src/typing_state_handler.dart` — the assistant's typing state, from `ai_indicator.*` events.
- `lib/src/client_tools.dart` — the client-side tools and the event listener feeding the registry.
- `lib/src/connection_banner.dart` — the reconnecting / offline banner.
- `lib/src/code_highlighter.dart` — `re_highlight` grammars supplied to the package's
  `codeHighlighter` seam. Drop languages you do not need; an unregistered one renders plain.

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
