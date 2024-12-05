## AI Assistant Node.js

This repo contains a sample project that shows you how you can integrate StreamChat with AI services, such as Anthropic and OpenAI.

The project exposes two endpoints:
- /start-ai-agent - this will create an AI agent, that will join a channel where it was invoked from.
- /stop-ai-agent - this will stop the AI agent and leave the channel.

Depending on your use-case, you can call these either on channel appearance or by tapping on a UI element (e.g. Ask AI button).

## Usage

In order to run the server locally, you would need to perform the following steps:

### Setup the `.env` file

There's a `.env.example` that you can use as a template. You should provide values for the following keys in your `.env` file:

```
ANTHROPIC_API_KEY=insert_your_key
STREAM_API_KEY=insert_your_key
STREAM_API_SECRET=insert_your_secret
OPENAI_API_KEY=insert_your_key
OPENWEATHER_API_KEY=insert_your_key
```

You can provide a key for either `ANTHROPIC_API_KEY` or `OPENAI_API_KEY`, depending on which one you would use. The `OPENWEATHER_API_KEY` is optional, in case you want to use the function calling example with OpenAI.

### Install the dependencies

In order to install the dependencies, you should run the following command:

```
npm install
```

### Running the project

In order to run the project, you should run:

```
npm start
```

This will start listening for requests on localhost:3000.

## Starting the AI Agent

When `start-ai-agent` endpoint is called the following happens:

- ai user with id `ai-bot-{channel-id}` is created using `admin` role, this way it can work on any channel by default
- the bot establishes a WS connection, joins the channel and starts watching it
- on the new message event, the bot starts talking to either Anthropic or OpenAI.
- a new empty message is created and a new event called `ai_indicator.update` with a `state` value of “AI_STATE_THINKING” is sent to the watchers.
- the message has a custom data field called `ai_generated` with the value of `true`, to tell the clients it’s AI generated. The sender is the AI Bot from the backend.
- when the response starts streaming, a new `ai_indicator.clear` event is sent to the watchers. In this case, the client should clear up the typing/thinking UI.
- in the meantime, the response is streamed, and every 15th chunk is updating the message’s text  (which is cumulative of all the new ones since the last update). At the start, more chunks are sent to improve responsiveness (this is handled server side).
- when the streaming finishes, the message is updated with its final state.
- while generating, the client UI shows a “stop generating” button. If a user taps on it, the client should send an event called `ai_indicator.stop`. This stops the generation of the AI response. The message is shown with its current state.
- we also have an error state `AI_STATE_ERROR` when something went wrong.
- Translations for the texts should be done client side, based on the state. Currently we have:
   - `AI_STATE_THINKING` → “Thinking”
   - `AI_STATE_CHECKING_SOURCES` → “Checking external sources”
   - in the other states, the indicator is not shown.

## Stopping the AI Agent

When the client doesn’t need the agent anymore, it should stop it, by calling the /stop-ai-agent endpoint. This will disconnect the user and stop watching the channel.

<a href="https://getstream.io?utm_source=Github&utm_medium=Github_Repo_Content&utm_content=Developer&utm_campaign=Github_Swift_AI_SDK&utm_term=DevRelOss">
<img src="https://user-images.githubusercontent.com/24237865/138428440-b92e5fb7-89f8-41aa-96b1-71a5486c5849.png" align="right" width="12%"/>
</a>

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