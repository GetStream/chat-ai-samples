# Stream Chat AI Integration Examples

![Integrating Stream Chat with AI](/assets/repo_cover.png)

This repo contains sample projects that integrate our UI components for building AI chat assistants, as well as server-side integrations with Vercel's AI SDK and Langchain:
- Our UI components (available on iOS, Android, React, and React Native) work well with Stream Chat, but can also be used standalone. These components facilitate the development of AI assistants such as ChatGPT, Grok, Gemini, and others.
- NodeJS packages - **stream-chat-js-ai-sdk** and **stream-chat-langchain** - which provide seamless integrations with Vercel’s AI SDK and LangChain, respectively. Stream Chat delivers the realtime layer and conversational memory, while the AI SDK and LangChain each offer a clean interface to multiple LLMs and support more advanced AI workflows. Additionally, we provide an example that uses a single backend server (NodeJS or Python) to manage the lifecycle of agents and handle the connection to external providers.

## Architecture Overview 🏗️

Here’s an overview of the general approach you can take to integrate Stream Chat with different LLMs.

![Stream Chat AI Integration Architecture](/assets/arch_diagram.png)

The customer app can use our AI components to build the chat assistant’s UI faster:
- streaming message view with advanced rendering support (markdown, code syntax highlighting, charts, tables)
- standalone composer with different options such as agent modes and photo picker
- speech to text component
- conversation suggestions 
- converstation history
- and much more.

Your backend can use one of the provided packages to facilitate the integration with popular AI SDKs, such as Langchain and Vercel’s AI SDK. Or, in case you don’t want to depend on these packages, you can use our standalone NodeJS and Python examples, that show you how to integrate with Stream Chat’s server-side client and various LLMs (OpenAI and Anthropic are provided as examples).

## Choose Your Platform

To get started building with AI and Stream, simply pick the example most suited to your application and follow the step by step instructions outlined in each:

- **iOS**: Learn how to create an assistant for iOS apps with Stream's iOS chat SDK.
    - Sample app: https://github.com/GetStream/chat-ai-samples/tree/main/ios
- **Android**: Build powerful and responsive assistants for Android applications with Stream's Android chat SDK.
    - Sample app: https://github.com/GetStream/chat-ai-samples/tree/main/android
- **React**: Develop chat assistants for web applications with Stream's React chat SDK.
    - Sample app: https://github.com/GetStream/chat-ai-samples/tree/main/react-native
- **React Native**: Step into the world of AI-enhanced chat apps with Stream's React Native SDK and our tutorial.
    - Sample app: https://github.com/GetStream/chat-ai-samples/tree/main/react

For your backend integration, you can try out one of these options:

- **AI SDK integration**: Integrate StreamChat server-side with the popular AI SDK from Vercel.
    - Docs: TODO: add link
    - Sample app: https://github.com/GetStream/chat-ai-samples/tree/main/ai-sdk-sample
- **Langchain integration**: Another StreamChat server-side integration with the popular agentic framework Langchain.
- **Standalone samples**: If you prefer not to use additional dependencies, kick start your integration with our sample projects in Python and NodeJS.
    - Python sample: https://github.com/GetStream/chat-ai-samples/tree/main/nodejs-ai-assistant
    - NodeJS sample: https://github.com/GetStream/chat-ai-samples/tree/main/python-ai-assistant

## **Quick Links** 🔗
- [Stream Chat](https://getstream.io/chat/)
- [Getting Started Guide](https://getstream.io/blog/ai-assistant/)

## Prerequisites ✅

Before you begin, you'll need:
- A Stream API Key ([Register for free](https://getstream.io/try-for-free/))
- Credentials of the LLM you want to use in your integration (OpenAI, Anthropic, xAI and others)
- Optional mem0 key for memory and context across conversations

## AI Guides 📚  
These guides explore more of how AI can be used across our SDKs and products.

- [How to Build an AI Chat Android App With Google’s Generative AI](https://getstream.io/blog/android-generative-ai/)
- [How to Build an LLM-powered Chatbot For Your Documentation](https://getstream.io/blog/llm-chatbot-docs/)
- [How to Build an AI bot Using Stream Chat, HuggingFace, and DialogGPT](https://getstream.io/blog/conversational-ai-flutter/)
- [How to Build AI-Powered Chatbot Apps for Android Using Firebase](https://getstream.io/blog/ai-chat-firebase/)
- [How to Add RAG-Based AI to Team Chat With Stream](https://getstream.io/blog/ai-team-chat/)
- [How to Build an Agentic RAG System With OpenAI, LanceDB, and Phidata](https://getstream.io/blog/agentic-ai-rag/)
- [How to Chat With Any Book Using Pinecone, OpenAI, and Stream](https://getstream.io/blog/ai-book-chat/)


## Community Writing 📝 
Check out what the community has built using Stream.

- [How to Build a Therapy Marketplace Using Next.js and Firebase](https://getstream.io/blog/build-therapy-app/)
- [How to Build a React Native Mental Health App with Stream Chat & Video Call](https://getstream.io/blog/mental-health-react-native/)
- [How to Build a Remote Interview App with React & Next.js](https://getstream.io/blog/interview-app-react-nextjs/)
- [How to Implement Context-Aware AI Responses in Your Chat App](https://getstream.io/blog/ai-chat-memory/)
- [How to Build a Job Application and Interview Platform with Next.js, Stream, and Firebase](https://getstream.io/blog/job-app-interview-platform/)
- [How We Built an AI Wine Sommelier App Using Stream Video & GPT](https://getstream.io/blog/ai-wine-sommelier/)
- [How to Build Video Calling Into Your App With Amazon Chime, AWS Lambda & Stream](https://getstream.io/blog/video-calling-amazon-lambda-chime/)
- [How to Add Real-Time Chat Translation Using Stream](https://getstream.io/blog/real-time-chat-translation/)
- [How a Global Airline Streamlines Team Operations With Stream Chat](https://getstream.io/blog/airline-team-chat/)
- [How to Build a RAG AI Chatbot with Stream](https://getstream.io/blog/rag-ai-chatbot/)
- [How to Add Real-Time Chat to Your AWS Application](https://getstream.io/blog/aws-chat-app/)
- [How to Add RAG-Based AI to Team Chat With Stream](https://getstream.io/blog/ai-team-chat/)


## What Creators Are Building 🚀 
Explore real-world apps built by developers using Stream SDKs, featured on YouTube.

- [Build a ChatGPT Clone with Stream and Neon – Brad Traversy](https://youtu.be/VR3p7almo_c?feature=shared)  
  A full-stack AI chatbot app with conversational context and auth, built from scratch by Brad Traversy.

- [Build a Language Exchange Platform with Real-Time Chat & Video – Burak (Codesistency)](https://www.youtube.com/watch?v=ZuwigEmwsTM)  
  A multilingual video calling platform using Stream, JWT auth, and DaisyUI themes.

- [How to Build a Remote Interview Platform with Stream – Burak (Codesistency)](https://youtu.be/xEnnRNH_lyw?si=UD2M4PDXzMYakpns)  
  A remote interview app built with React, TypeScript, Tailwind, and Stream Video SDK designed for remote hiring use cases.

- [Build a React Native Mental Health App with Stream Chat & Video – Simon](https://youtu.be/A8gJFybTPr0?si=aeWu1Ne9twoWWvha)  
  A cross-platform app for therapy and support sessions with integrated real-time messaging and video calling.

## Contributing 🤔

We welcome contributions that improve functionality or fix issues:

1. Fork the repository
2. Create a feature branch
3. Implement your changes
4. Add tests if applicable
5. Submit a PR with a clear description/changes

### Sample App Submissions

We encourage you to try the tutorials and submit new sample apps 🥳

- How can I submit a sample app?
  - Open a pr with a proper description and we'll review it as soon as possible.

### Bug Reports 🕷
- Open an issue with:
  - Clear steps to reproduce
  - Add screenshots/videos if possible
  - Expected behavior
  - Actual behavior
  - Platform/environment details
