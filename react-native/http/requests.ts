import { post } from './api.ts';

export const startAI = async (channelId: string) =>
  post('http://192.168.1.80:3000/start-ai-agent', { channel_id: channelId });
export const stopAI = async (channelId: string) =>
  post('http://192.168.1.80:3000/stop-ai-agent', { channel_id: channelId });
export const summarize = async (text: string) =>
  post('http://192.168.1.80:3000/summarize', { text });
