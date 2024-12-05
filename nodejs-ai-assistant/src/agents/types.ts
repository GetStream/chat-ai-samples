import type { Channel, StreamChat } from 'stream-chat';

export interface AIAgent {
  init(): Promise<void>;
  dispose(): Promise<void>;
  getLastInteraction(): number;

  chatClient: StreamChat;
  channel: Channel;
}

export enum AgentPlatform {
  ANTHROPIC = 'anthropic',
  OPENAI = 'openai',
}
