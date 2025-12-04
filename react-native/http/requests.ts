import { post } from './api.ts';

export const startAI = async (channelId: string) =>
    post('https://ai-sdk-server-0f347d455e2e.herokuapp.com/start-ai-agent', { channel_id: channelId });
export const stopAI = async (channelId: string) =>
    post('https://ai-sdk-server-0f347d455e2e.herokuapp.com/stop-ai-agent', { channel_id: channelId });
export const summarize = async (text: string) =>
    post('https://ai-sdk-server-0f347d455e2e.herokuapp.com/summarize', { text });

// export const startAI = async (channelId: string) =>
//     post('http://localhost:3000/start-ai-agent', { channel_id: channelId });
// export const stopAI = async (channelId: string) =>
//     post('http://localhost:3000/stop-ai-agent', { channel_id: channelId });
// export const summarize = async (text: string) =>
//     post('http://localhost:3000/summarize', { text });
