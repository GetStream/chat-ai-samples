import axios from 'axios';
import OpenAI from 'openai';
import type {
  Channel,
  MessageResponse,
  PartialMessageUpdate,
  StreamChat,
} from 'stream-chat';
import { ResponseInput, Tool } from 'openai/resources/responses/responses';

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
  private currentIndicator?:
    | 'AI_STATE_GENERATING'
    | 'AI_STATE_EXTERNAL_SOURCES';
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
    private readonly input: ResponseInput,
    private readonly tools: Tool[],
    private readonly previousResponseId: string | undefined,
    private readonly onResponseId: (id: string) => void,
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

    await this.finalizeMessage({ forceStop: true });
  };

  // Stream from the Responses API via the official SDK
  private streamResponse = async () => {
    this.controller = new AbortController();

    const stream = this.openai.responses.stream(
      {
        model: 'gpt-4o-mini',
        input: this.input,
        tools: this.tools,
        previous_response_id: this.previousResponseId,
      },
      { signal: this.controller.signal },
    );

    try {
      for await (const event of stream) {
        await this.handleEvent(event);
      }
    } catch (err) {
      if (!this.aborted) {
        await this.handleError(err as Error);
      }
    }
  };

  private handleEvent = async (event: OpenAI.Responses.ResponseStreamEvent) => {
    switch (event.type) {
      case 'response.created':
        const rid = event.response.id;
        if (rid) {
          this.responseId = rid;
          this.onResponseId(rid);
        }
        break;

      case 'response.output_item.added':
        const item = event.item;
        if (item.type === 'function_call' && item.id) {
          this.functionCalls[item.id] = {
            name: item.name,
            call_id: item.call_id,
          };
        }
        break;

      case 'response.output_text.delta':
        if (!event.delta) break;
        await this.updateIndicator('AI_STATE_GENERATING');
        this.message_text += event.delta;
        this.chunk_counter += 1;
        this.schedulePartialUpdate();
        break;

      case 'response.completed':
        if (!this.continuationPending && !this.continuationActive) {
          await this.finalizeMessage();
        }
        break;

      case 'response.function_call_arguments.delta': {
        const { delta, item_id: toolItemId } = event;
        if (!toolItemId || !delta) break;
        this.pendingToolArgs[toolItemId] =
          (this.pendingToolArgs[toolItemId] ?? '') + delta;
        // Optional: show external sources indicator
        await this.updateIndicator('AI_STATE_EXTERNAL_SOURCES');
        break;
      }

      case 'response.function_call_arguments.done': {
        const toolItemId = event.item_id;
        if (!toolItemId) break;
        const { name: functionName, call_id } =
          this.functionCalls[toolItemId] || {};

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
        }

        // Continue the response by creating a new stream with previous_response_id
        if (this.responseId && call_id) {
          this.continuationPending = true;
          const continuation = this.openai.responses.stream(
            {
              model: 'gpt-4o-mini',
              previous_response_id: this.responseId,
              tools: this.tools,
              input: [{ type: 'function_call_output', call_id, output }],
            },
            { signal: this.controller?.signal },
          );
          // Iterate continuation and mark active so we don't finalize early
          this.continuationActive = true;
          this.continuationPending = false;
          for await (const e of continuation) {
            await this.handleEvent(e);
          }
          this.continuationActive = false;
          // Ensure we finalize with the full accumulated text after continuation
          if (!this.aborted) {
            await this.finalizeMessage();
          }
        }
        break;
      }

      case 'error':
        const msg = event.message ?? 'OpenAI response error';
        await this.handleError(new Error(msg));
        break;
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

  private async updateIndicator(
    state: 'AI_STATE_GENERATING' | 'AI_STATE_EXTERNAL_SOURCES',
  ) {
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
        await new Promise((r) =>
          setTimeout(r, delay + Math.floor(Math.random() * 50)),
        );
        delay *= 2;
      }
    }
  }

  private async finalizeMessage({
    forceStop = false,
  }: { forceStop?: boolean } = {}) {
    if (this.finalized) return;
    this.finalized = true;
    if (this.pendingUpdateTimer) {
      clearTimeout(this.pendingUpdateTimer);
      this.pendingUpdateTimer = null;
    }
    // Wait for any in-flight partial updates to settle, then apply final
    await this.lastUpdatePromise.catch(() => Promise.resolve());
    const text = this.message_text;

    const partialMessage: PartialMessageUpdate = {
      set: { generating: false },
    };

    // if forceStop is true, it means generation was stopped by the user, so we avoid overwriting the message text with extra content that may have been generated after the stop signal was sent
    if (!forceStop) {
      partialMessage.set!.text = text;
    }

    await this.chatClient.partialUpdateMessage(this.message.id, partialMessage);
    await this.clearIndicator();
  }
}
