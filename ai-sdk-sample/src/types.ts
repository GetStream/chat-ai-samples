import {
  AgentPlatform,
  type ClientToolDefinition,
} from '@stream-io/chat-ai-sdk';

export type StartAIAgentRequest = {
  channel_id: string;
  channel_type?: string;
  platform?: AgentPlatform;
  model: string;
};

export type StopAIAgentRequest = {
  channel_id: string;
};

export type RegisterToolsRequest = {
  channel_id: string;
  tools: ClientToolDefinition[];
};

export type SummarizeRequest = {
  text: string;
  platform?: AgentPlatform;
  model?: string;
};
