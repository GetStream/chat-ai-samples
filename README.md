![Integrating Stream Chat with AI](/assets/repo_cover.png)

## **Quick Links** 🔗
- [Register](https://getstream.io/try-for-free/) to get a free Stream API Key
- [Getting Started Guide](#todo)
- [Stream Chat](https://getstream.io/chat/)

## Repo Overview 😎
This repo contains Stream's official sample projects demonstrating how Generative AI can be integrated with our Chat API and UI Kits. It includes samples built using our [React](https://getstream.io/blog/react-assistant/), [React Native](https://getstream.io/blog/react-native-assistant/), [Jetpack Compose](https://getstream.io/blog/android-assistant/), [Swift UI](https://getstream.io/blog/ios-assistant/) and [Flutter](https://getstream.io/blog/flutter-assistant/) UI SDKs and example servers in [NodeJS](https://getstream.io/blog/nodejs-assistant/) and Python (coming soon).

Developers can clone this repo and run these samples directly using our pre-made OpenAI or Anthropic integrations or integrate with their favourite external LLM provider by extending the Agent class in our backend server.

![Integrating Stream Chat with AI](/assets/arch_diagram.png)

Using this approach, regardless of which LLM provider is used, developers can remain confident our UI components will adapt and take care of the heavy lifting for rendering LLM responses, including full out-of-the-box support for common AI UI patterns such as thinking indicators, code blocks, markdown support, tables, images, etc.


## How to Run 🏃

### **Setup environment variables**

```sh
cp .env.example .env
```

Add following credentials to `.env` file:

1. Stream Chat app api key and secret
2. [User ID and token](https://getstream.io/pr-previews/5538/chat/docs/javascript/tokens_and_authentication/?language=javascript&q=secret#manually-generating-tokens)
2. [OpenAI API key](https://openai.com/product)
3. [Anthropic API key](https://www.anthropic.com/api)

### **Backend**
For detailed instructions on running the backend server for this project, please see the README located in [nodejs-ai-assistant](https://github.com/GetStream/chat-ai-samples/tree/main/nodejs-ai-assistant). Our team also wrote a detailed [backend guide](https://getstream.io/blog/nodejs-assistant/) on our blog explaining the setup and integration with Stream Chat. 


### **Frontend**
Each frontend SDK has an accompanying tutorial on our website aimed at walking you through the different steps to integrate:
* [React](https://getstream.io/blog/react-assistant/)
* [React Native](https://getstream.io/blog/react-native-assistant/)
* [Jetpack Compose](https://getstream.io/blog/android-assistant/)
* [Swift UI](https://getstream.io/blog/ios-assistant/)  
* [Flutter](https://getstream.io/blog/flutter-assistant/) 

## AI Guides 📚
These guides explore more of how AI can be used across our SDKs and products.  

- [Build an AI Chat Android App With Google’s Generative AI](https://getstream.io/blog/android-generative-ai/)
- [Create LLM-powered Chatbot For Your Documentation](https://getstream.io/blog/llm-chatbot-docs/)
- [Conversational AI Using Stream Chat, HuggingFace, and DialogGPT](https://getstream.io/blog/conversational-ai-flutter/)



## Contributing 🤔
- How can I submit a sample app?
    - Apps submissions are always welcomed! 🥳 Open a pr with a proper description and we'll review it as soon as possible
- Spot a bug 🕷 ?
    - We welcome code changes that improve the apps or fix a problem. Please make sure to follow all best practices and add tests if applicable before submitting a Pull Request on Github.
