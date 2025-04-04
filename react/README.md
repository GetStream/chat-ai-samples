# React AI Components Sample App

This repository contains a sample AI assistant app that integrates Stream's AI UI components from the [Stream Chat React SDK](https://github.com/GetStream/stream-chat-react). The sample shows how to render responses from LLM providers such as ChatGPT, Gemini, Anthropic or any custom backend by using our AI components and server-side SDKs. Our UI components are able to render Markdown, Code blocks, tables, thinking indicators, images, etc.

The sample shows you how to integrate the following hooks and views:
- `useMessageTextStreaming` - control how streaming responses from the LLM are handled.
- `StreamedMessageText` - a component that can display a streaming response from the LLM.
- `AIStateIndicator` - a component that can display different states of the LLM (thinking, checking external sources, etc).

 Our [developer guide](https://getstream.io/chat/solutions/ai-integration/) explains how to get started building AI integrations with Stream and React. 

The app consists of the standard StreamChat channel list and channel view. The channel view header is enhanced with a button to start and stop AI agents. When the agent is started, it listens to all the sent messages in the channel and connects to an LLM to receive AI-generated responses.

There's also an example that shows you how to present the different states of the LLM, by reacting to the new AI events in the SDK. 

## Project overview

A tutorial how to build the entire project can be found [here](https://getstream.io/blog/react-assistant/). See a demo video of what the project looks like below:

https://github.com/user-attachments/assets/47afc01b-8e40-48a9-a28b-5cf61b7c2d3f

## ⚙️ Usage

Running the app is simple. You can run this project with the following commands:

```bash
npm run install
npm run dev
```

For it to connect to an API, you also need to run a backend. We have a sample ready for you in the[nodejs-ai-assistant](../nodejs-ai-assistant/) folder (check the [README](../nodejs-ai-assistant/README.md) for more detailed information).

## 🛥 What is Stream?

Stream allows developers to rapidly deploy scalable feeds, chat messaging and video with an industry leading 99.999% uptime SLA guarantee.

Stream provides UI components and state handling that make it easy to build real-time chat and video calling for your app. Stream runs and maintains a global network of edge servers around the world, ensuring optimal latency and reliability regardless of where your users are located.

## 📕 Tutorials

To learn more about integrating AI and chatbots into your application, we recommend checking out the full list of tutorials across all of our supported frontend SDKs and providers. Stream's Chat SDK is natively supported across:

* [React](https://getstream.io/chat/react-chat/tutorial/)
* [React Native](https://getstream.io/chat/react-native-chat/tutorial/)
* [Angular](https://getstream.io/chat/angular/tutorial/)
* [Jetpack Compose](https://getstream.io/tutorials/android-chat/)
* [SwiftUI](https://getstream.io/tutorials/ios-chat/)
* [Flutter](https://getstream.io/chat/flutter/tutorial/)
* [Javascript/Bring your own](https://getstream.io/chat/docs/javascript/)


## 👩‍💻 Free for Makers 👨‍💻

Stream is free for most side and hobby projects. To qualify, your project/company needs to have < 5 team members and < $10k in monthly revenue. Makers get $100 in monthly credit for video for free.
For more details, check out the [Maker Account](https://getstream.io/maker-account?utm_source=Github&utm_medium=Github_Repo_Content&utm_content=Developer&utm_campaign=Github_Swift_AI_SDK&utm_term=DevRelOss).

## 💼 We are hiring!

We've recently closed a [\$38 million Series B funding round](https://techcrunch.com/2021/03/04/stream-raises-38m-as-its-chat-and-activity-feed-apis-power-communications-for-1b-users/) and we keep actively growing.
Our APIs are used by more than a billion end-users, and you'll have a chance to make a huge impact on the product within a team of the strongest engineers all over the world.
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
