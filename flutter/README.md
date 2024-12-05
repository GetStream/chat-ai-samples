# Stream Chat AI Assistant for Flutter

This project demonstrates the integration of AI assistant features in a Flutter application using
the Stream Chat SDK.

## Description

This Flutter project showcases how to implement an AI assistant in a chat application. The AI
assistant can be started and stopped within chat channels, and it provides automated responses to
user messages.

## Demo
| App Demo                                                                                      |
|-----------------------------------------------------------------------------------------------|
| <video src="https://github.com/user-attachments/assets/5c4ff0fc-e2d0-41ec-a825-6190fc481d2f"> |

## Features

- **AI Assistant Integration**: Start and stop the AI assistant in chat channels.
- **Custom Message Handling**: Customize the display of AI-generated messages.
- **AI Typing Indicator**: Show typing indicators when the AI assistant is generating a response.
- **Stream Chat SDK**: Utilize the Stream Chat SDK for chat functionalities.

## Getting Started

### Prerequisites

- Flutter SDK: ^3.24.0
- Stream Chat account and API key

### Installation

1. Clone the repository:
   ```sh
   git clone https://github.com/your-repo/stream_chat_ai_assistant_flutter_example.git
   cd stream_chat_ai_assistant_flutter_example
   ```

2. Install dependencies:
   ```sh
   flutter pub get
   ```

### Configuration

Update the `lib/main.dart` file with your Stream Chat API key:
   ```dart
   final client = StreamChatClient(
     'your_api_key',
     logLevel: Level.INFO,
   );
   ```

### Running the App

Run the app on an emulator or physical device:

```sh
flutter run
```

## Usage

- **AI Assistant Channels Page**: Displays a list of chat channels. Tap on a channel to open it.
- **AI Assistant Channel Page**: Shows the chat interface for a selected channel. Use the toggle
  button to start or stop the AI assistant.

## Project Structure

- `lib/main.dart`: Entry point of the application.
- `lib/src/chat_ai_assistant_service.dart`: Service for starting and stopping the AI assistant.
- `lib/src/chat_ai_assistant_channels_page.dart`: UI for displaying the list of chat channels.
- `lib/src/chat_ai_assistant_channel_page.dart`: UI for the chat interface within a channel.
- `lib/src/chat_ai_assistant_typing_indicator_handler.dart`: Handles the AI typing indicator state.

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

* [React](https://getstream.io/chat/react-chat/tutorial/)
* [React Native](https://getstream.io/chat/react-native-chat/tutorial/)
* [Angular](https://getstream.io/chat/angular/tutorial/)
* [Jetpack Compose](https://getstream.io/tutorials/android-chat/)
* [SwiftUI](https://getstream.io/tutorials/ios-chat/)
* [Flutter](https://getstream.io/chat/flutter/tutorial/)
* [Javascript/Bring your own](https://getstream.io/chat/docs/javascript/)

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