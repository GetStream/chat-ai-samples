import type { CoreMessage, CoreTool } from 'ai';
import { streamText } from 'ai';
import { createAnthropic } from '@ai-sdk/anthropic';
import { createGoogleGenerativeAI } from '@ai-sdk/google';
import { createOpenAI } from '@ai-sdk/openai';
import { createXai } from '@ai-sdk/xai';
import { z, type ZodTypeAny } from 'zod';
import type {
  Channel,
  Event,
  MessageResponse,
  StreamChat,
} from 'stream-chat';
import type { AIAgent } from './types';
import { AgentPlatform } from './types';

const BASE_SYSTEM_PROMPT =
  'You are an AI assistant. Help users with their questions. Evaluate each user turn independently: restate the user intent, decide whether it matches any available tool instructions, and only invoke the matching tool when the intent clearly applies. If no tool matches, answer normally.';
const CLIENT_TOOL_EVENT = 'custom_client_tool_invocation';

type IndicatorState =
  | 'AI_STATE_THINKING'
  | 'AI_STATE_GENERATING'
  | 'AI_STATE_EXTERNAL_SOURCES'
  | 'AI_STATE_ERROR';

type StreamTextOptions = Parameters<typeof streamText>[0];
type StreamLanguageModel = NonNullable<StreamTextOptions['model']>;

export interface ToolExecutionContext {
  channel: Channel;
  message: MessageResponse;
  sendEvent: (event: Record<string, unknown>) => Promise<void>;
}

export interface AgentTool {
  name: string;
  description: string;
  instructions?: string;
  parameters: ZodTypeAny;
  execute: (args: unknown, context: ToolExecutionContext) => Promise<string> | string;
  showExternalSourcesIndicator?: boolean;
}

export interface JsonSchemaDefinition {
  type?: string;
  description?: string;
  enum?: Array<string | number | boolean>;
  properties?: Record<string, JsonSchemaDefinition>;
  items?: JsonSchemaDefinition | JsonSchemaDefinition[];
  required?: string[];
  additionalProperties?: boolean | JsonSchemaDefinition;
  [key: string]: unknown;
}

export interface ClientToolDefinition {
  name: string;
  description: string;
  instructions?: string;
  parameters?: JsonSchemaDefinition;
  showExternalSourcesIndicator?: boolean;
}

export const createModelForPlatform = (
  platform: AgentPlatform,
  modelOverride?: string,
): StreamLanguageModel => {
  const modelId = typeof modelOverride === 'string' && modelOverride.trim()
    ? modelOverride.trim()
    : undefined;
  switch (platform) {
    case AgentPlatform.OPENAI: {
      const apiKey = process.env.OPENAI_API_KEY;
      if (!apiKey) {
        throw new Error('OpenAI API key is required');
      }
      const openai = createOpenAI({ apiKey });
      return openai(modelId ?? 'gpt-4o-mini') as StreamLanguageModel;
    }
    case AgentPlatform.ANTHROPIC: {
      const apiKey = process.env.ANTHROPIC_API_KEY;
      if (!apiKey) {
        throw new Error('Anthropic API key is required');
      }
      const anthropic = createAnthropic({ apiKey });
      return anthropic(
        modelId ?? 'claude-3-5-sonnet-20241022',
      ) as StreamLanguageModel;
    }
    case AgentPlatform.GEMINI: {
      const apiKey =
        process.env.GOOGLE_GENERATIVE_AI_API_KEY ??
        process.env.GEMINI_API_KEY;
      if (!apiKey) {
        throw new Error('Gemini API key is required');
      }
      const google = createGoogleGenerativeAI({ apiKey });
      return google(modelId ?? 'gemini-1.5-flash') as StreamLanguageModel;
    }
    case AgentPlatform.XAI: {
      const apiKey = process.env.XAI_API_KEY;
      if (!apiKey) {
        throw new Error('xAI API key is required');
      }
      const xai = createXai({ apiKey });
      return xai(modelId ?? 'grok-beta') as StreamLanguageModel;
    }
    default:
      throw new Error(`Unsupported AI platform: ${platform}`);
  }
};

export class VercelAIAgent implements AIAgent {
  private model?: StreamLanguageModel;
  private lastInteractionTs = Date.now();
  private handlers = new Set<VercelResponseHandler>();
  private serverTools: AgentTool[];
  private clientTools: AgentTool[] = [];
  private readonly modelOverride?: string;
  private readonly additionalInstructions: string[];

  constructor(
    readonly chatClient: StreamChat,
    readonly channel: Channel,
    private readonly platform: AgentPlatform,
    tools: AgentTool[] = [],
    modelOverride?: string,
    additionalInstructions?: string[],
  ) {
    this.serverTools = tools ?? [];
    this.modelOverride = modelOverride;
    this.additionalInstructions = Array.isArray(additionalInstructions)
      ? additionalInstructions.filter((line) => line && line.trim().length)
      : additionalInstructions
        ? [additionalInstructions]
        : [];
  }

  init = async () => {
    this.model = createModelForPlatform(this.platform, this.modelOverride);
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

  setServerTools = (tools: AgentTool[]) => {
    this.serverTools = tools ?? [];
  };

  addServerTools = (tools: AgentTool[]) => {
    this.serverTools = [...this.serverTools, ...(tools ?? [])];
  };

  setClientTools = (tools: AgentTool[]) => {
    this.clientTools = tools ?? [];
  };

  setClientToolDefinitions = (definitions: ClientToolDefinition[]) => {
    const tools = (definitions ?? []).map((definition) =>
      this.createClientTool(definition),
    );
    this.setClientTools(tools);
  };

  private getActiveTools(): AgentTool[] {
    return [...this.serverTools, ...this.clientTools];
  }

  private createClientTool(definition: ClientToolDefinition): AgentTool {
    const parameters =
      jsonSchemaToZod(definition.parameters) ?? z.object({}).passthrough();
    return {
      name: definition.name,
      description: definition.description,
      instructions: definition.instructions,
      parameters,
      showExternalSourcesIndicator: definition.showExternalSourcesIndicator,
      execute: async (args, context) => {
        console.log(
          `[ClientTool] Dispatching ${definition.name} with args:`,
          args,
        );
        await context.sendEvent({
          type: CLIENT_TOOL_EVENT,
          cid: context.message.cid,
          message_id: context.message.id,
          channel_id: context.channel.id,
          channel_type: context.channel.type,
          tool: {
            name: definition.name,
            description: definition.description,
            instructions: definition.instructions,
            parameters: definition.parameters ?? null,
          },
          args: args ?? {},
        });
        return `Client tool "${definition.name}" invocation dispatched.`;
      },
    };
  }

  private getSystemPrompt(): string {
    const instructions = [
      ...this.additionalInstructions,
      ...this.getActiveTools()
        .map((tool) => tool.instructions ?? '')
        .filter((value) => typeof value === 'string' && value.trim().length > 0),
    ]
      .map((line) => line.trim())
      .filter((line) => line.length > 0);

    if (!instructions.length) {
      return BASE_SYSTEM_PROMPT;
    }

    const formatted = instructions.map((line) => `- ${line}`).join('\n');
    return `${BASE_SYSTEM_PROMPT}\n\nGuidelines:\n${formatted}`;
  }

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
      { role: 'system', content: this.getSystemPrompt() },
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
      () => this.getActiveTools(),
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
          const label = retryable
            ? 'Failed to send event after retries'
            : 'Failed to send event';
          console.error(label, err);
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
  private readonly toolsResolver: () => AgentTool[];

  constructor(
    private readonly model: StreamLanguageModel,
    private readonly chatClient: StreamChat,
    private readonly channel: Channel,
    private readonly message: MessageResponse,
    private readonly messages: CoreMessage[],
    private readonly sendEvent: (event: Record<string, unknown>) => Promise<void>,
    toolsResolver: () => AgentTool[],
  ) {
    this.chatClient.on('ai_indicator.stop', this.handleStopGenerating);
    this.toolsResolver = toolsResolver;
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
    const tools = this.toolsResolver();
    if (!tools.length) {
      return null;
    }
    return tools.reduce<Record<string, CoreTool<any, any>>>(
      (acc, tool) => {
        acc[tool.name] = {
          description: tool.description,
          parameters: tool.parameters,
          execute: async (args: unknown) => {
            if (tool.showExternalSourcesIndicator !== false) {
              await this.updateIndicator('AI_STATE_EXTERNAL_SOURCES');
            }
            const result = await tool.execute(args, {
              channel: this.channel,
              message: this.message,
              sendEvent: (event) => this.sendEvent(event),
            });
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

const jsonSchemaToZod = (schema?: JsonSchemaDefinition): ZodTypeAny => {
  if (!schema) {
    return z.object({}).passthrough();
  }

  if (
    Array.isArray(schema.enum) &&
    schema.enum.length > 0 &&
    schema.enum.every((value) => typeof value === 'string')
  ) {
    const enumValues = schema.enum as string[];
    const enumSchema =
      enumValues.length === 1
        ? z.literal(enumValues[0])
        : z.enum(enumValues as [string, ...string[]]);
    return applyDescription(enumSchema, schema.description);
  }

  const inferredType = schema.type ?? (schema.properties ? 'object' : undefined);

  switch (inferredType) {
    case 'string':
      return applyDescription(z.string(), schema.description);
    case 'number':
      return applyDescription(z.number(), schema.description);
    case 'integer':
      return applyDescription(z.number().int(), schema.description);
    case 'boolean':
      return applyDescription(z.boolean(), schema.description);
    case 'array': {
      const itemSchemas = Array.isArray(schema.items)
        ? schema.items
        : schema.items
          ? [schema.items]
          : [];
      const firstItemSchema = itemSchemas[0] as JsonSchemaDefinition | undefined;
      const itemZod = firstItemSchema
        ? jsonSchemaToZod(firstItemSchema)
        : z.any();
      return applyDescription(z.array(itemZod), schema.description);
    }
    case 'object':
    default: {
      const properties = schema.properties ?? {};
      const required = new Set(schema.required ?? []);
      const shape: Record<string, ZodTypeAny> = {};
      for (const [key, propertySchema] of Object.entries(properties)) {
        let fieldSchema = jsonSchemaToZod(propertySchema);
        if (!required.has(key)) {
          fieldSchema = fieldSchema.optional();
        }
        shape[key] = fieldSchema;
      }

      let objectSchema: any = z.object(shape);
      const additional = schema.additionalProperties;
      if (typeof additional === 'object') {
        objectSchema = objectSchema.catchall(jsonSchemaToZod(additional));
      } else if (additional === false) {
        objectSchema = objectSchema.strict();
      } else {
        objectSchema = objectSchema.passthrough();
      }

      return applyDescription(objectSchema as ZodTypeAny, schema.description);
    }
  }
};

const applyDescription = <T extends ZodTypeAny>(
  schema: T,
  description?: string,
): T => {
  if (description) {
    return schema.describe(description) as T;
  }
  return schema;
};
