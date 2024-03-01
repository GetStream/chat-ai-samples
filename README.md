![Integrating Stream Chat with AI](/assets/repo_cover.png)

## **Quick Links** 🔗
- [Register](https://getstream.io/try-for-free/) to get an API key for Stream
- [ReactJS Example](https://github.com/GetStream/chat-ai-samples/tree/main/react-chat)
- [ChatGPT Node Server](https://github.com/GetStream/chat-ai-samples/blob/main/server/ai/openAI.js)
- [Gemini Node Server](https://github.com/GetStream/chat-ai-samples/blob/main/server/ai/geminiAI.js)

## Repo Overview 😎
This repo contains Stream's official sample projects demonstrating how Generative AI can be used in our Chat products. It includes sample backend servers for ChatGPT and Gemini, which can be used as a reference guide when using Gen AI with Stream.

Sample integrations in ReactJS, Android, and Flutter are located in the "frontends" directory, which also demonstrates working with and rendering real-time message chunks as they are sent from AI providers.

## **Projects/Packages 🚀**
- **Backend**
    - [ChatGPT Server](https://github.com/GetStream/chat-ai-samples/blob/main/server/ai/openAI.js): Node server that connects to both OpenAI and Stream chat to intercept and respond to messages in real time.
    - [Gemini Server](https://github.com/GetStream/chat-ai-samples/blob/main/server/ai/geminiAI.js): Node server that connects Stream Chat with Gemini, allowing for sending, receiving, and replying to messages.
- **Frontend**
    - [React/NextJS](https://github.com/GetStream/chat-ai-samples/tree/main/react-chat): NextJs app, which interacts with ChatGPT and implements streaming responses.
    - Android: Jetpack Compose app written in Kotlin which integrates Google’s Gemini and our Jetpack Compose SDK. Please see the sub-directory for detailed getting started instructions.


## How to Run 🏃

### **Setup environment variables**

```sh
cp .env.example .env
```

Add following credentials to `.env` file:

1. Stream Chat app api key and secret
2. [User ID and token](https://getstream.io/pr-previews/5538/chat/docs/javascript/tokens_and_authentication/?language=javascript&q=secret#manually-generating-tokens)
2. [OpenAI API key](https://openai.com/product)
3. Or [Gemini API key](https://ai.google.dev/tutorials/node_quickstart?authuser=3#set-up-api-key)

### **Backend**

To start the backend server, you can choose between ChatGPT and Gemini. The server will listen for messages and respond with AI-generated responses. You need to configure this server url as a webhook for your Stream Chat app.

```sh
cd server
yarn;

# Start ChatGPT server
yarn start:openai

# Or start Gemini server
yarn start:gemini
```

### **Configure Ngrok webhook**

To expose the local server to the internet, you can use ngrok. Follow the instructions here to set up ngrok and configure the webhook URL for your Stream Chat app:

https://getstream.io/chat/docs/react/debugging_with_ngrok/

### **Frontend**

```sh
cd react-chat
yarn; yarn start
```


## AI Guides 📚
These guides explore more of how AI can be used across our SDKs and products.  

- [Implementing ChatGPT with Stream Chat](https://getstream.io/blog/implement-chatgpt/)
- [Build an AI Chat Android App With Google’s Generative AI](https://getstream.io/blog/android-generative-ai/)
- [Create LLM-powered Chatbot For Your Documentation](https://getstream.io/blog/llm-chatbot-docs/)
- [Conversational AI Using Stream Chat, HuggingFace, and DialogGPT](https://getstream.io/blog/conversational-ai-flutter/)



## Contributing 🤔
- How can I submit a sample app?
    - Apps submissions are always welcomed! 🥳 Open a pr with a proper description and we'll review it as soon as possible
- Spot a bug 🕷 ?
    - We welcome code changes that improve the apps or fix a problem. Please make sure to follow all best practices and add tests if applicable before submitting a Pull Request on Github.
