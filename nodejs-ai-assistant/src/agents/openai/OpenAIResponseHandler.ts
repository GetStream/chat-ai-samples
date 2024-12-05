import axios from 'axios';
import OpenAI from 'openai';
import type { AssistantStream } from 'openai/lib/AssistantStream';
import type { Channel, MessageResponse, StreamChat } from 'stream-chat';

export class OpenAIResponseHandler {
  private message_text = '';
  private chunk_counter = 0;
  private run_id = '';

  constructor(
    private readonly openai: OpenAI,
    private readonly openAiThread: OpenAI.Beta.Threads.Thread,
    private readonly assistantStream: AssistantStream,
    private readonly chatClient: StreamChat,
    private readonly channel: Channel,
    private readonly message: MessageResponse,
  ) {
    this.chatClient.on('ai_indicator.stop', this.handleStopGenerating);
  }

  run = async () => {
    for await (const event of this.assistantStream) {
      await this.handle(event);
    }
  };

  dispose = () => {
    this.chatClient.off('ai_indicator.stop', this.handleStopGenerating);
  };

  private handleStopGenerating = async () => {
    console.log('Stop generating');
    if (!this.openai || !this.openAiThread) {
      console.log('OpenAI not initialized');
      return;
    }

    this.openai.beta.threads.runs.cancel(this.openAiThread.id, this.run_id);
    await this.chatClient.partialUpdateMessage(this.message.id, {
      set: { generating: false },
    });
    await this.channel.sendEvent({
      type: 'ai_indicator.clear',
      cid: this.message.cid,
      message_id: this.message.id,
    });
  };

  private handle = async (
    event: OpenAI.Beta.Assistants.AssistantStreamEvent,
  ) => {
    try {
      // Retrieve events that are denoted with 'requires_action'
      // since these will have our tool_calls
      const { cid, id } = this.message;
      switch (event.event) {
        case 'thread.run.requires_action':
          console.log('Requires action');
          await this.channel.sendEvent({
            type: 'ai_indicator.update',
            state: 'AI_STATE_EXTERNAL_SOURCES',
            cid: cid,
            message_id: id,
          });
          await this.handleRequiresAction(
            event.data,
            event.data.id,
            event.data.thread_id,
          );
          break;
        case 'thread.message.created':
          await this.channel.sendEvent({
            type: 'ai_indicator.update',
            state: 'AI_STATE_GENERATING',
            cid: cid,
            message_id: id,
          });
          break;
        case 'thread.message.delta':
          const content = event.data.delta.content;
          if (!content || content[0]?.type !== 'text') return;
          this.message_text += content[0].text?.value ?? '';
          if (
            this.chunk_counter % 15 === 0 ||
            (this.chunk_counter < 8 && this.chunk_counter % 2 === 0)
          ) {
            const text = this.message_text;
            await this.chatClient.partialUpdateMessage(id, {
              set: { text, generating: true },
            });
          }
          this.chunk_counter += 1;
          break;
        case 'thread.message.completed':
          const text = this.message_text;
          await this.chatClient.partialUpdateMessage(id, {
            set: { text, generating: false },
          });
          await this.channel.sendEvent({
            type: 'ai_indicator.clear',
            cid: cid,
            message_id: id,
          });
          break;
        case 'thread.run.step.created':
          this.run_id = event.data.id;
          break;
      }
    } catch (error) {
      console.error('Error handling event:', error);
    }
  };

  private handleRequiresAction = async (
    data: OpenAI.Beta.Threads.Runs.Run,
    runId: string,
    threadId: string,
  ) => {
    if (!data.required_action || !data.required_action.submit_tool_outputs) {
      console.log('No tool outputs to submit');
      return;
    }
    try {
      const toolOutputs = await Promise.all(
        data.required_action.submit_tool_outputs.tool_calls.map(
          async (toolCall) => {
            if (toolCall.function.name !== 'getCurrentTemperature') return;

            const argumentsString = toolCall.function.arguments;
            console.log('Arguments: ', argumentsString);
            const args = JSON.parse(argumentsString);
            const location = args.location as string;
            const temperature = await this.getCurrentTemperature(location);
            const temperatureString = temperature.toString();
            return {
              tool_call_id: toolCall.id,
              output: temperatureString,
            };
          },
        ),
      );
      // Submit all the tool outputs at the same time
      await this.submitToolOutputs(
        toolOutputs.filter((t) => !!t),
        runId,
        threadId,
      );
    } catch (error) {
      console.error('Error processing required action:', error);
      this.openai.beta.threads.runs.cancel(threadId, runId);
      await this.handleError(error as Error);
    }
  };

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

  private submitToolOutputs = async (
    toolOutputs: { output: string; tool_call_id: string }[],
    runId: string,
    threadId: string,
  ) => {
    try {
      // Use the submitToolOutputsStream helper
      const stream = this.openai.beta.threads.runs.submitToolOutputsStream(
        threadId,
        runId,
        { tool_outputs: toolOutputs },
      );
      for await (const event of stream) {
        await this.handle(event);
      }
    } catch (error) {
      console.error('Error submitting tool outputs:', error);
      await this.handleError(error as Error);
    }
  };

  private handleError = async (error: Error) => {
    await this.channel.sendEvent({
      type: 'ai_indicator.update',
      state: 'AI_STATE_ERROR',
      cid: this.message.cid,
      message_id: this.message.id,
    });
    await this.chatClient.partialUpdateMessage(this.message.id, {
      set: {
        text: 'Error generating the message',
        message: error.toString(),
        generating: false,
      },
    });
  };
}
