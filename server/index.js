require("dotenv").config();

const express = require("express");
const StreamChat = require("stream-chat").StreamChat;
const { startAiBotStreaming } = require("./ai");

const app = express();
const port = 3000;
app.use(express.raw({ type: "application/json" })); // <-- parses all bodies as a Buffer

const apiKey = process.env.STREAM_API_KEY;
const apiSecret = process.env.STREAM_API_SECRET;
const aiuserid = process.env.AI_USER_ID;

const reqHandler = async (req, res) => {
  const client = StreamChat.getInstance(apiKey, apiSecret);

  // parse the request body
  const rawBody = req.body;
  const isValid = client.verifyWebhook(rawBody, req.headers["x-signature"]);

  if (!isValid) {
    return res.status(400).send("Invalid signature");
  }

  const body = JSON.parse(rawBody);
  if (!body) {
    return res.status(400).send("Invalid JSON");
  }

  const event = body;
  if (
    event.type !== "message.new" ||
    !event.message ||
    event.message.user.id === aiUserId ||
    !event.channel_type ||
    !event.channel_id
  ) {
    // we are interested only in new messages, from regular users
    return res.status(200).send("Not a new message");
  }

  // Think about what to do about it
  if (req.headers["x-webhook-attempt"] > 1) {
    return res.status(200).send("Not a new message");
  }

  const channel = client.channel(event.channel_type, event.channel_id);
  const prompt = event.message?.text;
  if (channel && prompt) {
    const provider = process.argv[2];
    // start streaming in async mode
    await startAiBotStreaming(client, channel, prompt, provider).catch(
      (error) => {
        console.error("An error occurred", error);
      },
    );
  }

  return res.status(200).send("OK");
};

const startServer = async () => {
  if (process.argv.length < 3) {
    console.error(
      "Please provide a name of generative API provider <'openai' | 'gemini'>. E.g., `yarn start gemini`",
    );
    process.exit(1);
  }

  const provider = process.argv[2];
  if (provider !== "openai" && provider !== "gemini") {
    console.error(
      "Please provide a valid generative API provider <'openai' | 'gemini'>. E.g., `yarn start gemini`",
    );
    process.exit(1);
  }

  if (provider === "openai" && !process.env.OPENAI_API_KEY) {
    console.error("Please provide OPENAI_API_KEY env variable");
    process.exit(1);
  }

  if (provider === "gemini" && !process.env.GEMINI_API_KEY) {
    console.error("Please provide GEMINI_API_KEY env variable");
    process.exit(1);
  }

  app.post("/", reqHandler);

  app.listen(port, () => {
    console.log(`Example app listening on port ${port}. Provider: ${provider}`);
  });
};

startServer();
