import Anthropic from '@anthropic-ai/sdk';
import { AnthropicResponseHandler } from './AnthropicResponseHandler';
import type { MessageParam } from '@anthropic-ai/sdk/resources/messages';
import type { Channel, Event, StreamChat } from 'stream-chat';
import type { AIAgent } from '../types';
import { buildMessageContent } from './buildMessageContent';
import { detectEnumOptions } from './detectEnumOptions';
import { transformCollectedData } from '../../transformCollectedData';
import { createPmgListing } from '../../pmg/pmgClient';
import { reverseGeocode } from '../../geocode';
import * as fs from 'fs';
import * as path from 'path';

const PET_SCHEMA: Record<string, unknown> = JSON.parse(
  fs.readFileSync(path.resolve(__dirname, '../../../../schema/petSchema.json'), 'utf-8'),
);

export class AnthropicAgent implements AIAgent {
  private anthropic?: Anthropic;
  private handlers: AnthropicResponseHandler[] = [];
  private lastInteractionTs = Date.now();
  private lastImageUrl: string | null = null;
  private userLocation: { latitude: number; longitude: number } | null = null;

  constructor(
    readonly chatClient: StreamChat,
    readonly channel: Channel,
    private readonly schema?: Record<string, unknown>,
  ) {}

  dispose = async () => {
    this.chatClient.off('message.new', this.handleMessage);
    this.channel.off('user_location' as any, this.handleUserLocation);
    await this.chatClient.disconnectUser();

    this.handlers.forEach((handler) => handler.dispose());
    this.handlers = [];
  };

  getLastInteraction = (): number => this.lastInteractionTs;

  init = async () => {
    const apiKey = process.env.ANTHROPIC_API_KEY as string | undefined;
    if (!apiKey) {
      throw new Error('Anthropic API key is required');
    }
    this.anthropic = new Anthropic({ apiKey });

    await this.channel.sendMessage({
      text: "Hello! 👋 I'm here to help you create a listing. To start, please upload a photo of your pet!",
      ai_generated: true,
    });

    this.chatClient.on('message.new', this.handleMessage);
    this.channel.on('user_location' as any, this.handleUserLocation);
  };

  private buildSystemPrompt(schema: any): string | undefined {
    return `
    You are a pet listing assistant. Your job is to help the user create a complete pet advert.

Schema of required fields: ${JSON.stringify(schema, null, 2)}

## Step 1 — Image
If no image has been uploaded yet, ask the user to upload a photo of their pet. Do not proceed without one.

## Step 2 — Analyse the image
Once an image is provided, extract all possible information based on the image and use them to fulfill the schema.

Present these to the user so they can confirm or correct them.

## Step 3 — Collect all fields from the schema which are not already filled in.
If the schema collects title and description, pre-populate them.
Find the most fitting breed based on the photo.
If schema is collecting mother breed and father breed, pre-populate them with the same breed as the pet breed.
User should be presented only one question at a time.

## Step 4 — Submit
Once you have all fields confirmed, call submit_collected_data with the complete data.

You are a friendly data collection assistant. Your job is to conversationally collect the following information from the user.`;
  }

  private buildTool(): Anthropic.Messages.Tool {
    const effectiveSchema = this.schema ?? PET_SCHEMA;
    const requiredFields = this.schema
      ? Object.keys(this.schema)
      : ['title', 'description', 'advert_type', 'breed', 'number_of_males', 'number_of_females', 'date_of_birth'];

    return {
      name: 'submit_collected_data',
      description:
        'Submit the fully collected structured data when all required fields have been gathered from the user.',
      input_schema: {
        type: 'object' as const,
        properties: effectiveSchema,
        required: requiredFields,
      },
    };
  }

  private handleUserLocation = (e: Event) => {
    const { latitude, longitude } = e as any;
    if (typeof latitude === 'number' && typeof longitude === 'number') {
      this.userLocation = { latitude, longitude };
      console.log(`User location received: ${latitude}, ${longitude}`);
    }
  };

  private handleMessage = async (e: Event) => {
    if (!this.anthropic) {
      console.error('Anthropic SDK is not initialized');
      return;
    }

    if (!e.message || e.message.ai_generated) {
      console.log('Skip handling ai generated message');
      return;
    }

    const message = e.message.text ?? '';
    const hasImages = e.message.attachments?.some((a) => a.type === 'image' && a.image_url);
    if (!message && !hasImages) return;

    const imageUrl = e.message.attachments?.find(
      (a): a is typeof a & { image_url: string } => a.type === 'image' && typeof a.image_url === 'string',
    )?.image_url ?? null;
    if (imageUrl) this.lastImageUrl = imageUrl;

    this.lastInteractionTs = Date.now();

    const isThreadReply = e.message.parent_id !== undefined;
    const historySize = this.schema ? 20 : 20;

    // For non-thread messages, the current message is already the last entry
    // in channel.state.messages — exclude it so we can re-add it with vision content.
    // Thread replies are NOT in channel.state.messages (Stream stores them separately),
    // so for thread replies we use historySlice as-is and just append the current message.
    const historySlice = this.channel.state.messages
      .slice(-historySize)
      .filter((msg) => msg.text && msg.text.trim() !== '');

    const historyBase = isThreadReply ? historySlice : historySlice.slice(0, -1);

    const messages: MessageParam[] = [
      ...historyBase.map((msg) => ({
        role: (msg.user?.id.startsWith('ai-bot') ? 'assistant' : 'user') as
          | 'user'
          | 'assistant',
        content: msg.text || '',
      })),
      {
        role: 'user',
        content: buildMessageContent(message, e.message.attachments),
      },
    ];

    const systemPrompt = this.buildSystemPrompt(PET_SCHEMA);
    const tool = this.buildTool();

    const anthropicStream = await this.anthropic.messages.create({
      max_tokens: 1024,
      system: systemPrompt,
      messages,
      model: 'claude-sonnet-4-5',
      tools: [tool],
      stream: true,
    });

    const { message: channelMessage } = await this.channel.sendMessage({
      text: '',
      ai_generated: true,
    });

    try {
      await this.channel.sendEvent({
        type: 'ai_indicator.update',
        ai_state: 'AI_STATE_THINKING',
        message_id: channelMessage.id,
      });
    } catch (error) {
      console.error('Failed to send ai indicator update', error);
    }

    await new Promise((resolve) => setTimeout(resolve, 750));

    const handler = new AnthropicResponseHandler(
      anthropicStream,
      this.chatClient,
      this.channel,
      channelMessage,
      async (toolName, input) => {
        if (toolName === 'submit_collected_data') {
          console.log('Data collection complete (raw):', JSON.stringify(input));

          let resolvedLocation: Record<string, unknown> | undefined;
          if (this.userLocation) {
            try {
              resolvedLocation = await reverseGeocode(this.userLocation.latitude, this.userLocation.longitude) as unknown as Record<string, unknown>;
              console.log('Resolved location:', JSON.stringify(resolvedLocation));
            } catch (error) {
              console.error('Failed to reverse geocode, using default location:', error);
            }
          }

          const payload = transformCollectedData(input as any, resolvedLocation);

          console.log('Transformed listing payload:', JSON.stringify(payload));

          try {
            await this.channel.sendEvent({
              type: 'data_collection_complete',
              collected_data: { title: payload.title },
            } as any);
          } catch (error) {
            console.error('Failed to send data_collection_complete event', error);
          }

          try {
            const { slug } = await createPmgListing(payload, this.lastImageUrl);

            const clientUrl = process.env.PMG_CLIENT_URL;
            if (!clientUrl) {
              console.warn('PMG_CLIENT_URL is not set — preview URL will be incomplete');
            }
            const previewUrl = `${clientUrl ?? ''}/classifieds/${slug}`;
            await this.channel.sendMessage({
              text: `Your listing has been created! Preview it here: ${previewUrl}`,
              ai_generated: true,
            });
          } catch (error) {
            console.error('Failed to create listing on remote server', error);
          }
        }
      },
      async (text: string) => {
        const options = detectEnumOptions(
          text,
          PET_SCHEMA as Record<string, { enum?: string[]; [key: string]: unknown }>,
        );
        if (options) {
          await this.chatClient.partialUpdateMessage(channelMessage.id, {
            set: { options },
          });
        }
      },
    );
    void handler.run();
    this.handlers.push(handler);
  };
}
