import Anthropic from '@anthropic-ai/sdk';
import { AnthropicResponseHandler } from './AnthropicResponseHandler';
import type { MessageParam } from '@anthropic-ai/sdk/resources/messages';
import type { Channel, EventPayload, StreamChat } from 'stream-chat';
import type { AIAgent } from '../types';

export class AnthropicAgent implements AIAgent {
  private anthropic?: Anthropic;
  private handlers: AnthropicResponseHandler[] = [];
  private lastInteractionTs = Date.now();

  constructor(
    readonly chatClient: StreamChat,
    readonly channel: Channel,
  ) {}

  dispose = async () => {
    this.chatClient.off('message.new', this.handleMessage);
    // Node's WebSocket never reports the close frame, so cap the wait for it.
    await this.chatClient.disconnectUser(100);

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

    this.chatClient.on('message.new', this.handleMessage);
  };

  private handleMessage = async (e: EventPayload<'message.new'>) => {
    if (!this.anthropic) {
      console.error('Anthropic SDK is not initialized');
      return;
    }

    if (!e.message || e.message.custom?.ai_generated) {
      console.log('Skip handling ai generated message');
      return;
    }

    const message = e.message.text;
    if (!message) return;

    this.lastInteractionTs = Date.now();

    const messages = this.channel.messagePaginator.anchoredHeadItems
      .slice(-5)
      .filter((msg) => msg.text && msg.text.trim() !== '')
      .map<MessageParam>((message) => ({
        role: message.user?.id.startsWith('ai-bot') ? 'assistant' : 'user',
        content: message.text || '',
      }));

    if (e.message.parent_id !== undefined) {
      messages.push({
        role: 'user',
        content: message,
      });
    }

    const anthropicStream = await this.anthropic.messages.create({
      max_tokens: 16000,
      messages,
      model: 'claude-opus-5-5',
      stream: true,
    });

    const { message: channelMessage } = await this.channel.sendMessage({
      message: { text: '', custom: { ai_generated: true } },
    });

    try {
      await this.channel.updateAIState(channelMessage.id, 'AI_STATE_THINKING');
    } catch (error) {
      console.error('Failed to send ai indicator update', error);
    }

    await new Promise((resolve) => setTimeout(resolve, 750));

    const handler = new AnthropicResponseHandler(
      anthropicStream,
      this.chatClient,
      this.channel,
      channelMessage,
    );
    void handler.run();
    this.handlers.push(handler);
  };
}
