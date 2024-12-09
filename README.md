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
- Python implementation (coming soon)

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

- [Build an AI Chat Android App With Google’s Generative AI](https://getstream.io/blog/android-generative-ai/)
- [Create LLM-powered Chatbot For Your Documentation](https://getstream.io/blog/llm-chatbot-docs/)
- [Conversational AI Using Stream Chat, HuggingFace, and DialogGPT](https://getstream.io/blog/conversational-ai-flutter/)

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
