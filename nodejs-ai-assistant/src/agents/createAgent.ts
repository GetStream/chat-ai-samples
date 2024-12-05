import { AgentPlatform, AIAgent } from './types';
import { StreamChat } from 'stream-chat';
import { OpenAIAgent } from './openai/OpenAIAgent';
import { AnthropicAgent } from './anthropic/AnthropicAgent';
import { apiKey, serverClient } from '../serverClient';

export const createAgent = async (
  user_id: string,
  platform: AgentPlatform,
  channel_type: string,
  channel_id: string,
): Promise<AIAgent> => {
  const client = new StreamChat(apiKey, { allowServerSideConnect: true });
  const token = serverClient.createToken(user_id);
  await client.connectUser({ id: user_id }, token);
  console.log(`User ${user_id} connected successfully.`);

  const channel = client.channel(channel_type, channel_id);
  await channel.watch();

  if (platform === AgentPlatform.OPENAI) {
    return new OpenAIAgent(client, channel);
  }
  return new AnthropicAgent(client, channel);
};
