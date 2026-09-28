import {
  AgentPlatform,
  type ClientToolDefinition,
  type ReasoningEffort,
} from '@stream-io/chat-ai-sdk';

export type StartAIAgentRequest = {
  channel_id: string;
  channel_type?: string;
  platform?: AgentPlatform;
  model: string;
  /** Streams the model's reasoning into the in-progress message. */
  reasoning?: boolean;
  reasoning_effort?: ReasoningEffort;
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
