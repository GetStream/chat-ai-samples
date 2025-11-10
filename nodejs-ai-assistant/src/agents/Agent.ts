import { StreamChat } from 'stream-chat';
import { AgentPlatform } from './types';
import {
  AgentTool,
  ClientToolDefinition,
  VercelAIAgent,
  createModelForPlatform,
} from './VercelAIAgent';
import { apiKey, serverClient } from '../serverClient';
import { generateText } from 'ai';

export interface AgentOptions {
  userId: string;
  channelId: string;
  channelType?: string;
  platform: AgentPlatform;
  model?: string;
  instructions?: string | string[];
  serverTools?: AgentTool[];
  clientTools?: ClientToolDefinition[];
}

export interface RegisterToolOptions {
  replace?: boolean;
}

export class Agent {
  private chatClient?: StreamChat;
  private channelType: string;
  private streamChannelId: string;
  private platform: AgentPlatform;
  private model?: string;
  private instructions: string[];
  private serverTools: AgentTool[];
  private clientTools: ClientToolDefinition[];
  private aiAgent?: VercelAIAgent;
  private started = false;
  private lastInteraction = Date.now();

  constructor(private readonly options: AgentOptions) {
    this.channelType = options.channelType ?? 'messaging';
    this.streamChannelId = options.channelId;
    this.platform = options.platform;
    this.model = options.model;
    this.instructions = Array.isArray(options.instructions)
      ? options.instructions
      : options.instructions
        ? [options.instructions]
        : [];
    this.serverTools = options.serverTools ?? [];
    this.clientTools = options.clientTools ?? [];
  }

  get userId(): string {
    return this.options.userId;
  }

  get channelId(): string {
    return this.streamChannelId;
  }

  getLastInteraction(): number {
    return this.aiAgent?.getLastInteraction() ?? this.lastInteraction;
  }

  isStarted(): boolean {
    return this.started;
  }

  async start(): Promise<void> {
    if (this.started) {
      return;
    }

    try {
      await serverClient.upsertUser({
        id: this.options.userId,
        name: 'AI Bot',
        role: 'admin',
      });

      const adminChannel = serverClient.channel(
        this.channelType,
        this.streamChannelId,
      );
      try {
        await adminChannel.addMembers([this.options.userId]);
      } catch (error) {
        console.warn(
          `Agent ${this.options.userId}: failed to add member to channel`,
          error,
        );
      }

      this.chatClient = new StreamChat(apiKey, { allowServerSideConnect: true });
      const token = serverClient.createToken(this.options.userId);
      await this.chatClient.connectUser({ id: this.options.userId }, token);
      const channel = this.chatClient.channel(
        this.channelType,
        this.streamChannelId,
      );
      await channel.watch();

      this.aiAgent = new VercelAIAgent(
        this.chatClient,
        channel,
        this.platform,
        this.serverTools,
        this.model,
        this.instructions,
      );
      if (this.clientTools.length) {
        this.aiAgent.setClientToolDefinitions(this.clientTools);
      }
      await this.aiAgent.init();
      this.started = true;
    } catch (error) {
      await this.stop();
      throw error;
    }
  }

  async stop(): Promise<void> {
    this.started = false;
    this.lastInteraction = Date.now();

    if (this.aiAgent) {
      await this.aiAgent.dispose();
    }
    this.aiAgent = undefined;

    if (this.chatClient) {
      try {
        await this.chatClient.disconnectUser();
      } catch (error) {
        console.warn('Failed to disconnect chat client', error);
      }
    }
    this.chatClient = undefined;

    const adminChannel = serverClient.channel(
      this.channelType,
      this.streamChannelId,
    );
    try {
      await adminChannel.removeMembers([this.options.userId]);
    } catch (error) {
      console.warn(
        `Agent ${this.options.userId}: failed to remove member from channel`,
        error,
      );
    }
  }

  addServerTools(tools: AgentTool[]) {
    if (!tools?.length) return;
    this.serverTools = [...this.serverTools, ...tools];
    this.aiAgent?.setServerTools(this.serverTools);
  }

  registerServerTools(
    tools: AgentTool[],
    options: RegisterToolOptions = { replace: true },
  ) {
    if (!tools?.length) return;
    if (options.replace) {
      this.serverTools = [...tools];
    } else {
      this.serverTools = [...this.serverTools, ...tools];
    }
    this.aiAgent?.setServerTools(this.serverTools);
  }

  registerClientTools(
    tools: ClientToolDefinition[],
    options: RegisterToolOptions = { replace: true },
  ) {
    if (!tools?.length) return;
    if (options.replace) {
      this.clientTools = [...tools];
    } else {
      this.clientTools = [...this.clientTools, ...tools];
    }
    this.aiAgent?.setClientToolDefinitions(this.clientTools);
  }

  async summarize(text: string): Promise<string> {
    return Agent.generateSummary(text, this.platform, this.model);
  }

  static async generateSummary(
    text: string,
    platform: AgentPlatform,
    model?: string,
  ): Promise<string> {
    const languageModel = createModelForPlatform(platform, model);
    const { text: rawSummary } = await generateText({
      model: languageModel,
      prompt:
        'Write a short, catchy title of at most six words that captures the main idea of the following text. Respond with the title only.\n\nText:\n' +
        text,
    });

    return rawSummary
      .trim()
      .replace(/^[“”"']+/, '')
      .replace(/[“”"']+$/, '');
  }
}
