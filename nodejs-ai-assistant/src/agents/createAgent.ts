import { AgentPlatform, AIAgent } from './types';
import { StreamChat } from 'stream-chat';
import { apiKey, serverClient } from '../serverClient';
import { VercelAIAgent } from './VercelAIAgent';

export const createAgent = async (
  user_id: string,
  platform: AgentPlatform,
  channel_type: string,
  channel_id: string,
): Promise<AIAgent> => {
  const client = new StreamChat(apiKey, { allowServerSideConnect: true });
  const token = serverClient.createToken(user_id);
  await client.connectUser({ id: user_id }, token);
  console.log(`User ${user_id} [${platform}] connected successfully.`);

  const channel = client.channel(channel_type, channel_id);
  await channel.watch();

  return new VercelAIAgent(client, channel, platform);
};
