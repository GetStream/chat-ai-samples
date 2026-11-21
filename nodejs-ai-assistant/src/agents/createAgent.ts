import { AgentPlatform, AIAgent } from './types';
import { chatLoggerSystem, StreamChat } from 'stream-chat';
import { OpenAIAgent } from './openai/OpenAIAgent';
import { AnthropicAgent } from './anthropic/AnthropicAgent';
import { apiKey, serverClient } from '../serverClient';

// Keep stream-chat's warnings and errors, but not its info-level
// connect/watch/disconnect lines for every bot.
chatLoggerSystem.configureLoggers({ default: { level: 'warn' } });

export const createAgent = async (
  user_id: string,
  platform: AgentPlatform,
  channel_type: string,
  channel_id: string,
): Promise<AIAgent> => {
  const client = new StreamChat(apiKey, {
    client: { allowServerSideConnect: true },
  });
  // The bot connects with a fixed token, so mint one that doesn't expire.
  const token = serverClient.generatePermanentUserToken({ user_id });
  await client.connectUser({ id: user_id }, token);
  console.log(`User ${user_id} [${platform}] connected successfully.`);

  const channel = client.channel(channel_type, channel_id);
  await channel.watch();

  if (platform === AgentPlatform.OPENAI) {
    return new OpenAIAgent(client, channel);
  }
  return new AnthropicAgent(client, channel);
};
