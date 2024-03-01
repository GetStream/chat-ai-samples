const { startStreaming: startGeminiAIStreaming } = require("./geminiAI");
const { startStreaming: startOpenAIStreaming } = require("./openAI");
const { startStreaming: startMockStreaming } = require("./mockAI");

async function startAiBotStreaming(client, channel, prompt, provider) {
  // 1. create an empty message and mark it with 'isGptStreamed' custom property
  const message = await channel.sendMessage({
    user_id: "chat-ai-assistant",
    type: "regular",
    // 1.1 flag to indicate the ui to render a streamed message
    isGptStreamed: true,
  });

  // give some time for the ui to render the streamed message
  // and attaches the event listeners
  await sleep(300);

  // 2. Listen for new response chunks from GPT. Send them as custom events
  // to the UI once they become available.
  let text = "";

  let contentStreamGenerator =
    provider === "openai"
      ? startOpenAIStreaming
      : provider === "gemini"
        ? startGeminiAIStreaming
        : startMockStreaming;

  const chunks = contentStreamGenerator(prompt);

  for await (const chunk of chunks) {
    await channel.sendEvent({
      // @ts-expect-error - non-standard event, StreamedMessage subscribes to it
      type: "gpt_chunk",
      user_id: "chat-ai-assistant",
      message_id: message.message.id,
      chunk,
    });
    text += chunk;
  }

  // 3. Once chunks are sent and full response (text) is aggregated,
  // update the message created in step 1 to include the full response.
  // This way, the response will be stored in the Stream API, and we can
  // use it later without having to go to ChatGPT again.
  await client.updateMessage(
    {
      id: message.message.id,
      // 3.1 flag to indicate the ui to stop rendering the streamed message
      isGptStreamed: false,
      // 3.2 store the full text in the message
      text,
    },
    "chat-ai-assistant",
  );
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

module.exports = {
  startAiBotStreaming,
};
