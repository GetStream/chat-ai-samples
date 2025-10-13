import OpenAI from 'openai';
import { OpenAIResponseHandler } from './OpenAIResponseHandler';
import type { AIAgent } from '../types';
import type { Channel, Event, StreamChat } from 'stream-chat';
import {
  ResponseInput,
  ResponseInputImage,
  ResponseInputText,
  Tool,
} from 'openai/resources/responses/responses';

export class OpenAIAgent implements AIAgent {
  private openai?: OpenAI;
  private lastInteractionTs = Date.now();
  private lastResponseId?: string;

  private handlers: OpenAIResponseHandler[] = [];

  constructor(
    readonly chatClient: StreamChat,
    readonly channel: Channel,
  ) {}

  dispose = async () => {
    this.chatClient.off('message.new', this.handleMessage);
    await this.chatClient.disconnectUser();

    this.handlers.forEach((handler) => handler.dispose());
    this.handlers = [];
  };

  getLastInteraction = (): number => this.lastInteractionTs;

  init = async () => {
    const apiKey = process.env.OPENAI_API_KEY as string | undefined;
    if (!apiKey) {
      throw new Error('OpenAI API key is required');
    }

    this.openai = new OpenAI({ apiKey });

    this.chatClient.on('message.new', this.handleMessage);
  };

  private handleMessage = async (e: Event) => {
    if (!this.openai) {
      console.log('OpenAI not initialized');
      return;
    }

    if (!e.message || e.message.ai_generated) {
      console.log('Skip handling ai generated message');
      return;
    }

    const text = e.message.text ?? '';
    const attachments = e.message.attachments ?? [];
    const imageAttachments = attachments.filter((attachment) => {
      if (!attachment) return false;
      const hasImageType =
        attachment.type === 'image' ||
        (!!attachment.mime_type && attachment.mime_type.startsWith('image/'));
      const hasUrl =
        attachment.image_url || attachment.asset_url || attachment.thumb_url;
      return Boolean(hasImageType && hasUrl);
    });

    if (!text.trim() && imageAttachments.length === 0) return;

    this.lastInteractionTs = Date.now();

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

    // Provide a system prompt and the latest user message.
    // Conversation state is maintained via previous_response_id.
    const systemPrompt =
      'You are an AI assistant. Help users with their questions. Only call the getCurrentTemperature tool if the user explicitly asks for the current temperature for a specific location.';
    const userContent: (ResponseInputText | ResponseInputImage)[] = [];
    if (text.trim().length > 0) {
      userContent.push({ type: 'input_text', text });
    }
    for (const attachment of imageAttachments) {
      const imageUrl =
        attachment.image_url ?? attachment.asset_url ?? attachment.thumb_url;
      if (!imageUrl) continue;
      userContent.push({
        type: 'input_image',
        image_url: imageUrl,
        detail: 'high',
      });
    }

    if (userContent.length === 0) {
      userContent.push({
        type: 'input_text',
        text:
          'The user sent an image with no description. Provide helpful observations.',
      });
    }

    const input: ResponseInput = [
      { role: 'system', content: [{ type: 'input_text', text: systemPrompt }] },
      { role: 'user', content: userContent },
    ];

    const tools: Tool[] = [
      {
        type: 'function',
        name: 'getCurrentTemperature',
        description: 'Get the current temperature for a specific location',
        strict: true,
        parameters: {
          type: 'object',
          additionalProperties: false,
          properties: {
            location: {
              type: 'string',
              description: 'The city and state, e.g., San Francisco, CA',
            },
            unit: {
              type: 'string',
              enum: ['Celsius', 'Fahrenheit'],
              description:
                "The temperature unit to use. Infer this from the user's location.",
            },
          },
          required: ['location', 'unit'],
        },
      },
    ];

    const handler = new OpenAIResponseHandler(
      this.openai,
      this.chatClient,
      this.channel,
      channelMessage,
      input,
      tools,
      this.lastResponseId,
      (rid) => {
        this.lastResponseId = rid;
      },
    );
    void handler.run();
    this.handlers.push(handler);
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
          throw err; // propagate initial failure if non-retryable
        }
        await new Promise((r) =>
          setTimeout(r, delay + Math.floor(Math.random() * 50)),
        );
        delay *= 2;
      }
    }
  }
}
