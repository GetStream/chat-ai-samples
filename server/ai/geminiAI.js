const { GoogleGenerativeAI } = require("@google/generative-ai");

require("dotenv").config();

let genAI;
if (process.env.GEMINI_API_KEY) {
  genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
}

async function* startStreaming(prompt) {
  if (!genAI) {
    throw new Error("Please provide GEMINI_API_KEY env variable");
  }

  const model = genAI.getGenerativeModel({ model: "gemini-pro" });

  const result = await model.generateContentStream([prompt]);

  for await (const chunk of result.stream) {
    const chunkText = chunk.text();
    yield chunkText;
  }
}

module.exports = {
  startStreaming,
};
