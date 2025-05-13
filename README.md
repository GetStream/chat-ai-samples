# Stream Chat AI Integration Examples

![Integrating Stream Chat with AI](/assets/repo_cover.png)

## **Quick Links** 🔗
- [Stream Chat](https://getstream.io/chat/)
- [Getting Started Guide](https://getstream.io/blog/ai-assistant/)

## Prerequisites ✅

Before you begin, you'll need:
- A Stream API Key ([Register for free](https://getstream.io/try-for-free/))
- OpenAI API credentials ([Sign up](https://platform.openai.com/signup))
- Anthropic API credentials ([Sign up](https://www.anthropic.com/api))

## Overview 😎

> This repository showcases official Stream sample projects demonstrating Generative AI integration with Chat API and UI Kits.

### Samples:

Frontend SDKs:
- [React](https://getstream.io/blog/react-assistant/) for web apps
- [React Native](https://getstream.io/blog/react-native-assistant/) for mobile apps
- [Jetpack Compose](https://getstream.io/blog/android-assistant/) for Android
- [Swift UI](https://getstream.io/blog/ios-assistant/) for iOS
- [Flutter](https://getstream.io/blog/flutter-assistant/) for cross-platform development

Backend Examples:
- [NodeJS](https://getstream.io/blog/nodejs-assistant/) implementation
- [Python AI Chat](https://getstream.io/blog/python-assistant/) implementation


You can use our pre-built OpenAI/Anthropic integrations or extend the Agent class to work with any external LLM provider.

## Architecture Overview 🏗️

The repository implements a modular architecture that connects Stream's Chat functionality with various LLM providers:

![Stream Chat AI Integration Architecture](/assets/arch_diagram.png)

**Key features**:
- Pre-built integrations with OpenAI and Anthropic
- Extensible Agent class for custom LLM provider integration
- Built-in UI components that handle:
  - Loading states
  - Code block rendering
  - Markdown formatting
  - Table displays
  - Image rendering

## Getting Started 🚀

1. Clone the repo
2. Configure environment variables:
```sh
cp .env.example .env
```

3. Add the following credentials to your `.env`:
- [Stream Chat app api key and secret](https://getstream.io/try-for-free/)
- [User ID and token](https://getstream.io/chat/docs/javascript/tokens_and_authentication/?language=javascript&q=secret#manually-generating-tokens)
- [OpenAI API key](https://openai.com/product)
- [Anthropic API key](https://www.anthropic.com/api)

## Setup ⚙️

### **Backend**

- Follow the setup instructions in the [nodejs-ai-assistant](https://github.com/GetStream/chat-ai-samples/tree/main/nodejs-ai-assistant) directory
- Start reading our comprehensive [backend integration guide](https://getstream.io/blog/nodejs-assistant/) written by Stream engineers explaining the setup and integration with Stream Chat.

### Frontend Integration

Select your preferred SDK to get started.

* [How to Build an AI Assistant with React](https://getstream.io/blog/react-assistant/)
* [How to Build an AI Assistant with React Native](https://getstream.io/blog/react-native-assistant/)
* [How to Build an AI Assistant for Android Using Compose](https://getstream.io/blog/android-assistant/)
* [How to Build an AI Assistant for iOS Using Swift UI](https://getstream.io/blog/ios-assistant/)
* [How to Build an AI Assistant with Flutter](https://getstream.io/blog/flutter-assistant/)

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
