const OpenAI = require("openai");
require("dotenv").config();

let openAI;
if (process.env.OPENAI_API_KEY) {
  openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
}

async function* startStreaming(prompt) {
  if (!openai) {
    throw new Error("Please provide OPENAI_API_KEY env variable");
  }

  const runner = await openai.beta.chat.completions.stream({
    model: "gpt-3.5-turbo",
    messages: [{ role: "user", content: prompt }],
  });

  for await (const chunk of runner) {
    yield chunk.choices[0].delta.content || "";
  }
}

module.exports = {
  startStreaming,
};
