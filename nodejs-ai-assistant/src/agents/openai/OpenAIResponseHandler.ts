import axios from 'axios';
import OpenAI from 'openai';
import type { Channel, MessageResponse, StreamChat } from 'stream-chat';

export class OpenAIResponseHandler {
  private message_text = '';
  private chunk_counter = 0;
  private aborted = false;
  private controller: AbortController | null = null;
  private responseId: string | null = null;
  private pendingToolArgs: Record<string, string> = {};
  private functionCalls: Record<string, { name: string; call_id: string }> = {};
  private continuationPending = false;
  private continuationActive = false;
  private currentIndicator?: 'AI_STATE_GENERATING' | 'AI_STATE_EXTERNAL_SOURCES';
  private indicatorCleared = false;
  private finalized = false;
  private pendingUpdateTimer: ReturnType<typeof setTimeout> | null = null;
  private lastUpdatePromise: Promise<void> = Promise.resolve();
  private readonly updateIntervalMs = 200;

  constructor(
    private readonly openai: OpenAI,
    private readonly chatClient: StreamChat,
    private readonly channel: Channel,
    private readonly message: MessageResponse,
    private readonly input: unknown[],
    private readonly tools: unknown[],
    private readonly previousResponseId: string | undefined,
    private readonly onResponseId?: (id: string) => void,
  ) {
    this.chatClient.on('ai_indicator.stop', this.handleStopGenerating);
  }

  run = async () => {
    await this.streamResponse();
  };

  dispose = () => {
    this.chatClient.off('ai_indicator.stop', this.handleStopGenerating);
  };

  private handleStopGenerating = async () => {
    console.log('Stop generating');
    this.aborted = true;
    try {
      this.controller?.abort();
    } catch (e) {
      // no-op
    }
    await this.finalizeMessage();
  };

  // Stream from the Responses API via the official SDK
  private streamResponse = async () => {
    this.controller = new AbortController();
    const params: any = {
      model: 'gpt-4o-mini',
      input: this.input as any,
      tools: this.tools as any,
    };
    if (this.previousResponseId) {
      params.previous_response_id = this.previousResponseId;
    }
    const stream: AsyncIterable<any> = (this.openai as any).responses.stream(
      params,
      { signal: this.controller.signal } as any,
    );

    try {
      for await (const event of stream as any) {
        await this.handleEvent(event as any);
      }
    } catch (err) {
      if (!this.aborted) {
        await this.handleError(err as Error);
      }
    }
  };

  private handleEvent = async (event: any) => {
    const kind = event?.type ?? event?.event;
    const { cid, id } = this.message;
    try {
      switch (kind) {
        case 'response.created': {
          const rid = event?.response?.id ?? event?.id;
          if (rid) this.responseId = rid;
          if (rid && this.onResponseId) this.onResponseId(rid);
          break;
        }
        case 'response.output_item.added': {
          const item = event?.item;
          if (item?.type === 'function_call') {
            const itemId: string = item.id;
            const name: string = item.name;
            const call_id: string = item.call_id;
            if (itemId && call_id) {
              this.functionCalls[itemId] = { name, call_id };
            }
          }
          break;
        }
        case 'response.output_text.delta': {
          const delta: string = event?.delta ?? '';
          if (!delta) break;
          await this.updateIndicator('AI_STATE_GENERATING');
          this.message_text += delta;
          this.chunk_counter += 1;
          this.schedulePartialUpdate();
          break;
        }
        case 'response.completed': {
          if (!this.continuationPending && !this.continuationActive) {
            await this.finalizeMessage();
          }
          break;
        }
        case 'response.function_call_arguments.delta': {
          const toolItemId: string = event?.item_id ?? event?.id;
          const delta: string = event?.delta ?? '';
          if (!toolItemId || !delta) break;
          this.pendingToolArgs[toolItemId] =
            (this.pendingToolArgs[toolItemId] ?? '') + delta;
          // Optional: show external sources indicator
          await this.updateIndicator('AI_STATE_EXTERNAL_SOURCES');
          break;
        }
        case 'response.function_call_arguments.done': {
          const toolItemId: string = event?.item_id ?? event?.id;
          if (!toolItemId) break;
          const fnMeta = this.functionCalls[toolItemId];
          const functionName: string | undefined = fnMeta?.name;
          const call_id: string | undefined = fnMeta?.call_id;
          const argsStr = this.pendingToolArgs[toolItemId] ?? '{}';
          delete this.pendingToolArgs[toolItemId];
          let output = '';
          if (functionName === 'getCurrentTemperature') {
            try {
              const args = JSON.parse(argsStr);
              const location = args.location as string;
              const temperature = await this.getCurrentTemperature(location);
              output = String(temperature);
            } catch (e) {
              output = 'NaN';
            }
          } else {
            output = '';
          }

          // Continue the response by creating a new stream with previous_response_id
          if (this.responseId && call_id) {
            this.continuationPending = true;
            const continuation: AsyncIterable<any> = (this.openai as any).responses.stream(
              {
                model: 'gpt-4o-mini',
                previous_response_id: this.responseId,
                tools: this.tools as any,
                input: [
                  {
                    type: 'function_call_output',
                    call_id,
                    output,
                  },
                ],
              },
              { signal: this.controller?.signal } as any,
            );
            // Iterate continuation and mark active so we don't finalize early
            this.continuationActive = true;
            this.continuationPending = false;
            for await (const tevent of continuation as any) {
              await this.handleEvent(tevent as any);
            }
            this.continuationActive = false;
            // Ensure we finalize with the full accumulated text after continuation
            if (!this.aborted) {
              await this.finalizeMessage();
            }
          }
          break;
        }
        case 'response.error': {
          const msg = event?.error?.message ?? event?.data?.error?.message ?? 'OpenAI response error';
          await this.handleError(new Error(msg));
          break;
        }
        default:
          break;
      }
    } catch (error) {
      if (!this.aborted) {
        await this.handleError(error as Error);
      }
    }
  };

  // getCurrentTemperature is used by the tool-calling flow

  private getCurrentTemperature = async (location: string) => {
    const apiKey = process.env.OPENWEATHER_API_KEY;
    if (!apiKey) {
      throw new Error(
        'OpenWeatherMap API key is missing. Set it in the .env file.',
      );
    }
    const encodedLocation = encodeURIComponent(location);
    const url = `https://api.openweathermap.org/data/2.5/weather?q=${encodedLocation}&units=metric&appid=${apiKey}`;

    const response = await axios.get(url);
    const { data } = response;
    if (!data || !data.main || typeof data.main.temp !== 'number') {
      throw new Error('Temperature data not found in the API response.');
    }
    return data.main.temp;
  };

  private handleError = async (error: Error) => {
    this.finalized = true;
    if (this.pendingUpdateTimer) {
      clearTimeout(this.pendingUpdateTimer);
      this.pendingUpdateTimer = null;
    }
    await this.safeSendEvent({
      type: 'ai_indicator.update',
      ai_state: 'AI_STATE_ERROR',
      cid: this.message.cid,
      message_id: this.message.id,
    });
    await this.chatClient.partialUpdateMessage(this.message.id, {
      set: {
        text: error.message ?? 'Error generating the message',
        message: error.toString(),
        generating: false,
      },
    });
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
    const text = this.message_text;
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

  private async updateIndicator(state: 'AI_STATE_GENERATING' | 'AI_STATE_EXTERNAL_SOURCES') {
    if (this.currentIndicator === state) return;
    this.currentIndicator = state;
    this.indicatorCleared = false;
    await this.safeSendEvent({
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
    await this.safeSendEvent({
      type: 'ai_indicator.clear',
      cid: this.message.cid,
      message_id: this.message.id,
    });
  }

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
          return; // Swallow to avoid breaking generation flow on indicator errors
        }
        await new Promise((r) => setTimeout(r, delay + Math.floor(Math.random() * 50)));
        delay *= 2;
      }
    }
  }

  private async finalizeMessage() {
    if (this.finalized) return;
    this.finalized = true;
    if (this.pendingUpdateTimer) {
      clearTimeout(this.pendingUpdateTimer);
      this.pendingUpdateTimer = null;
    }
    // Wait for any in-flight partial updates to settle, then apply final
    await this.lastUpdatePromise.catch(() => Promise.resolve());
    const text = this.message_text;
    await this.chatClient.partialUpdateMessage(this.message.id, {
      set: { text, generating: false },
    });
    await this.clearIndicator();
  }
}
