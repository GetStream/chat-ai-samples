import type { CoreMessage, CoreTool } from 'ai';
import { streamText } from 'ai';
import { createAnthropic } from '@ai-sdk/anthropic';
import { createGoogleGenerativeAI } from '@ai-sdk/google';
import { createOpenAI } from '@ai-sdk/openai';
import { createXai } from '@ai-sdk/xai';
import type { ZodTypeAny } from 'zod';
import type {
  Channel,
  Event,
  MessageResponse,
  StreamChat,
} from 'stream-chat';
import type { AIAgent } from './types';
import { AgentPlatform } from './types';

const SYSTEM_PROMPT =
  'You are an AI assistant. Help users with their questions. Only call the getCurrentTemperature tool if the user explicitly asks for the current temperature for a specific location.';

type IndicatorState =
  | 'AI_STATE_THINKING'
  | 'AI_STATE_GENERATING'
  | 'AI_STATE_EXTERNAL_SOURCES'
  | 'AI_STATE_ERROR';

type StreamTextOptions = Parameters<typeof streamText>[0];
type StreamLanguageModel = NonNullable<StreamTextOptions['model']>;

export interface AgentTool {
  name: string;
  description: string;
  parameters: ZodTypeAny;
  execute: (args: any) => Promise<string> | string;
  showExternalSourcesIndicator?: boolean;
}

export const createModelForPlatform = (
  platform: AgentPlatform,
): StreamLanguageModel => {
  switch (platform) {
    case AgentPlatform.OPENAI: {
      const apiKey = process.env.OPENAI_API_KEY;
      if (!apiKey) {
        throw new Error('OpenAI API key is required');
      }
      const openai = createOpenAI({ apiKey });
      return openai('gpt-4o-mini') as StreamLanguageModel;
    }
    case AgentPlatform.ANTHROPIC: {
      const apiKey = process.env.ANTHROPIC_API_KEY;
      if (!apiKey) {
        throw new Error('Anthropic API key is required');
      }
      const anthropic = createAnthropic({ apiKey });
      return anthropic('claude-3-5-sonnet-20241022') as StreamLanguageModel;
    }
    case AgentPlatform.GEMINI: {
      const apiKey =
        process.env.GOOGLE_GENERATIVE_AI_API_KEY ??
        process.env.GEMINI_API_KEY;
      if (!apiKey) {
        throw new Error('Gemini API key is required');
      }
      const google = createGoogleGenerativeAI({ apiKey });
      return google('gemini-1.5-flash') as StreamLanguageModel;
    }
    case AgentPlatform.XAI: {
      const apiKey = process.env.XAI_API_KEY;
      if (!apiKey) {
        throw new Error('xAI API key is required');
      }
      const xai = createXai({ apiKey });
      return xai('grok-beta') as StreamLanguageModel;
    }
    default:
      throw new Error(`Unsupported AI platform: ${platform}`);
  }
};

export class VercelAIAgent implements AIAgent {
  private model?: StreamLanguageModel;
  private lastInteractionTs = Date.now();
  private handlers = new Set<VercelResponseHandler>();

  constructor(
    readonly chatClient: StreamChat,
    readonly channel: Channel,
    private readonly platform: AgentPlatform,
    private readonly tools: AgentTool[] = [],
  ) {}

  init = async () => {
    this.model = createModelForPlatform(this.platform);
    this.chatClient.on('message.new', this.handleMessage);
  };

  dispose = async () => {
    this.chatClient.off('message.new', this.handleMessage);
    await this.chatClient.disconnectUser();

    const handlers = Array.from(this.handlers);
    this.handlers.clear();
    await Promise.allSettled(handlers.map((handler) => handler.dispose()));
  };

  getLastInteraction = (): number => this.lastInteractionTs;

  private handleMessage = async (event: Event) => {
    if (!this.model) {
      console.warn('AI model not initialized');
      return;
    }

    if (!event.message || event.message.ai_generated) {
      return;
    }

    const incomingText = event.message.text?.trim();
    if (!incomingText) {
      return;
    }

    const userId = event.message.user?.id;
    if (!userId || userId.startsWith('ai-bot')) return;

    this.lastInteractionTs = Date.now();

    const history = this.channel.state.messages
      .slice(-10)
      .filter((msg) => msg.text && msg.text.trim() !== '')
      .map<CoreMessage>((msg) => ({
        role: msg.user?.id.startsWith('ai-bot') ? 'assistant' : 'user',
        content: msg.text ?? '',
      }));

    const lastHistoryEntry = history[history.length - 1];
    if (
      lastHistoryEntry?.content !== incomingText ||
      lastHistoryEntry.role !== 'user'
    ) {
      history.push({ role: 'user', content: incomingText });
    }

    const messages: CoreMessage[] = [
      { role: 'system', content: SYSTEM_PROMPT },
      ...history,
    ];

    const { message: channelMessage } = await this.channel.sendMessage({
      text: '',
      ai_generated: true,
    });

    await this.safeSendEvent({
      type: 'ai_indicator.update',
      ai_state: 'AI_STATE_THINKING',
      cid: channelMessage.cid,
      message_id: channelMessage.id,
    });

    const handler = new VercelResponseHandler(
      this.model,
      this.chatClient,
      this.channel,
      channelMessage,
      messages,
      (event) => this.safeSendEvent(event),
      this.tools,
    );

    this.handlers.add(handler);
    void handler
      .run()
      .catch((error) => {
        console.error('AI handler error', error);
      })
      .finally(() => {
        this.handlers.delete(handler);
      });
  };

  private async safeSendEvent(event: Record<string, unknown>) {
    const maxAttempts = 5;
    let delay = 100;
    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await this.channel.sendEvent(event as any);
        return;
      } catch (err) {
        const status = (err as any)?.status || (err as any)?.response?.status;
        const retryable = status === 429 || (status >= 500 && status < 600);
        if (!retryable || attempt === maxAttempts) {
          if (retryable) {
            console.warn('Failed to send event after retries', err);
          }
          return;
        }
        await new Promise((resolve) =>
          setTimeout(resolve, delay + Math.floor(Math.random() * 50)),
        );
        delay *= 2;
      }
    }
  }

}

class VercelResponseHandler {
  private controller: AbortController | null = null;
  private messageText = '';
  private finalized = false;
  private aborted = false;
  private currentIndicator?: IndicatorState;
  private indicatorCleared = false;
  private pendingUpdateTimer: ReturnType<typeof setTimeout> | null = null;
  private lastUpdatePromise: Promise<void> = Promise.resolve();
  private readonly updateIntervalMs = 200;
  private disposed = false;
  private readonly tools: AgentTool[];

  constructor(
    private readonly model: StreamLanguageModel,
    private readonly chatClient: StreamChat,
    private readonly channel: Channel,
    private readonly message: MessageResponse,
    private readonly messages: CoreMessage[],
    private readonly sendEvent: (event: Record<string, unknown>) => Promise<void>,
    tools: AgentTool[],
  ) {
    this.chatClient.on('ai_indicator.stop', this.handleStopGenerating);
    this.tools = tools;
  }

  run = async () => {
    this.controller = new AbortController();

    try {
      const toolDefinitions = this.buildToolDefinitions();
      const streamOptions = {
        model: this.model,
        messages: this.messages,
        abortSignal: this.controller.signal,
      } as Parameters<typeof streamText>[0];
      if (toolDefinitions) {
        (streamOptions as any).toolChoice = 'auto';
        (streamOptions as any).tools = toolDefinitions;
      }

      const result = await streamText(streamOptions);

      await this.consumeStream(result);
      if (!this.aborted) {
        await this.finalizeMessage();
      }
    } catch (error) {
      if (this.aborted) {
        await this.finalizeMessage();
      } else {
        await this.handleError(error as Error);
      }
    } finally {
      await this.dispose();
    }
  };

  private buildToolDefinitions(): Record<string, CoreTool<any, any>> | null {
    if (!this.tools.length) {
      return null;
    }
    return this.tools.reduce<Record<string, CoreTool<any, any>>>(
      (acc, tool) => {
        acc[tool.name] = {
          description: tool.description,
          parameters: tool.parameters,
          execute: async (args: unknown) => {
            if (tool.showExternalSourcesIndicator !== false) {
              await this.updateIndicator('AI_STATE_EXTERNAL_SOURCES');
            }
            const result = await tool.execute(args);
            if (typeof result === 'string') {
              return result;
            }
            return JSON.stringify(result);
          },
        };
        return acc;
      },
      {},
    );
  }

  dispose = async () => {
    if (this.disposed) return;
    this.disposed = true;
    this.chatClient.off('ai_indicator.stop', this.handleStopGenerating);
    if (this.pendingUpdateTimer) {
      clearTimeout(this.pendingUpdateTimer);
      this.pendingUpdateTimer = null;
    }
  };

  private async consumeStream(result: any) {
    const fullStream = result?.fullStream;
    if (fullStream) {
      for await (const part of fullStream) {
        if (!part) continue;
        if (part.type === 'text-delta') {
          const delta = part.textDelta;
          if (!delta) continue;
          await this.updateIndicator('AI_STATE_GENERATING');
          this.messageText += delta;
          this.schedulePartialUpdate();
        } else if (part.type === 'error') {
          throw part.error instanceof Error
            ? part.error
            : new Error('Error streaming response');
        } else if (part.type === 'finish') {
          break;
        }
      }
      return;
    }

    const textStream = result?.textStream;
    if (!textStream) return;
    for await (const delta of textStream) {
      if (!delta) continue;
      await this.updateIndicator('AI_STATE_GENERATING');
      this.messageText += delta;
      this.schedulePartialUpdate();
    }
  }

  private handleStopGenerating = async (event: Event) => {
    const messageId = (event as unknown as { message_id?: string })?.message_id;
    if (messageId && messageId !== this.message.id) {
      return;
    }

    this.aborted = true;
    try {
      this.controller?.abort();
    } catch (e) {
      // no-op
    }
  };

  private schedulePartialUpdate() {
    if (this.finalized) return;
    if (this.pendingUpdateTimer) return;
    this.pendingUpdateTimer = setTimeout(() => {
      this.pendingUpdateTimer = null;
      void this.flushPartialUpdate();
    }, this.updateIntervalMs);
  }

  private async flushPartialUpdate() {
    if (this.finalized) return;
    const text = this.messageText;
    const id = this.message.id;
    this.lastUpdatePromise = this.lastUpdatePromise.then(() =>
      this.chatClient
        .partialUpdateMessage(id, {
          set: { text, generating: true },
        })
        .then(() => undefined),
    );
    await this.lastUpdatePromise;
  }

  private async updateIndicator(state: IndicatorState) {
    if (this.currentIndicator === state) return;
    this.currentIndicator = state;
    this.indicatorCleared = false;
    await this.sendEvent({
      type: 'ai_indicator.update',
      ai_state: state,
      cid: this.message.cid,
      message_id: this.message.id,
    });
  }

  private async clearIndicator() {
    if (this.indicatorCleared) return;
    this.currentIndicator = undefined;
    this.indicatorCleared = true;
    await this.sendEvent({
      type: 'ai_indicator.clear',
      cid: this.message.cid,
      message_id: this.message.id,
    });
  }

  private async finalizeMessage() {
    if (this.finalized) return;
    this.finalized = true;
    if (this.pendingUpdateTimer) {
      clearTimeout(this.pendingUpdateTimer);
      this.pendingUpdateTimer = null;
    }
    await this.lastUpdatePromise.catch(() => Promise.resolve());
    await this.chatClient.partialUpdateMessage(this.message.id, {
      set: { text: this.messageText, generating: false },
    });
    await this.clearIndicator();
  }

  private async handleError(error: Error) {
    this.finalized = true;
    await this.sendEvent({
      type: 'ai_indicator.update',
      ai_state: 'AI_STATE_ERROR',
      cid: this.message.cid,
      message_id: this.message.id,
    });
    await this.chatClient.partialUpdateMessage(this.message.id, {
      set: {
        text: error.message ?? 'Error generating the message',
        generating: false,
      },
    });
  }
}
