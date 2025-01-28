import os
from stream_chat import StreamChat
from typing import Any, AsyncIterator
import asyncio
from openai.types.chat import ChatCompletionChunk
from openai import AsyncStream
from helpers import create_bot_id

class OpenAIResponseHandler:
    def __init__(
        self, 
        openai_stream: AsyncStream[ChatCompletionChunk], 
        chat_client: StreamChat, 
        channel: Any, 
        message: Any
    ):
        self.openai_stream = openai_stream
        self.chat_client = chat_client
        self.channel = channel
        self.message = message
        self.message_text = ""
        self.chunk_counter = 0

    async def run(self):
        try:
            async for chunk in self.openai_stream:
                await self.handle(chunk)
        except Exception as error:
            print("Error handling message stream event", error)
            bot_id = create_bot_id(channel_id=self.channel.id)
            await self.channel.send_event(
                {
                    "type": "ai_indicator.update",
                    "ai_state": "AI_STATE_ERROR",
                    "message_id": self.message["message"]["id"],
                },
                bot_id,
            )

    async def handle_stop_generating(self):
        print("Stop generating")
        bot_id = create_bot_id(channel_id=self.channel.id)
        if not self.openai_stream:
            print("OpenAI stream not initialized")
            return
            
        # OpenAI's stream doesn't have a direct abort method, but we can close the connection
        await self.openai_stream.response.aclose()
        
        await self.chat_client.update_message_partial(
            self.message["message"]["id"], 
            {"set": {"generating": False}}, 
            bot_id
        )
        await self.channel.send_event(
            {"type": "ai_indicator.clear", "message_id": self.message["message"]["id"]},
            bot_id,
        )

    async def handle(self, chunk: ChatCompletionChunk):
        bot_id = create_bot_id(channel_id=self.channel.id)
        
        # Handle initial chunk (similar to content_block_start)
        if self.chunk_counter == 0:
            await self.channel.send_event(
                {
                    "type": "ai_indicator.update",
                    "ai_state": "AI_STATE_GENERATING",
                    "message_id": self.message["message"]["id"],
                },
                bot_id,
            )

        # Extract text from the chunk
        if chunk.choices and chunk.choices[0].delta.content:
            delta_text = chunk.choices[0].delta.content
            self.message_text += delta_text
            self.chunk_counter += 1

            # Update message periodically
            if self.chunk_counter % 20 == 0 or (
                self.chunk_counter < 8 and self.chunk_counter % 2 != 0
            ):
                try:
                    await self.chat_client.update_message_partial(
                        self.message["message"]["id"],
                        {"set": {"text": self.message_text, "generating": True}},
                        bot_id,
                    )
                except Exception as error:
                    print("Error updating message", error)

        # Handle finish reason (similar to message_stop)
        if chunk.choices and chunk.choices[0].finish_reason:
            await asyncio.sleep(0.5)
            await self.chat_client.update_message_partial(
                self.message["message"]["id"],
                {"set": {"text": self.message_text, "generating": False}},
                bot_id,
            )
            await self.channel.send_event(
                {
                    "type": "ai_indicator.clear",
                    "message_id": self.message["message"]["id"],
                },
                bot_id,
            )

# Example usage:
async def create_openai_handler(client, channel, message):
    """
    Helper function to create and initialize an OpenAI handler
    
    Example:
        stream = await openai.chat.completions.create(
            model="gpt-4",
            messages=[{"role": "user", "content": "Hello!"}],
            stream=True
        )
        handler = await create_openai_handler(client, channel, message, stream)
        await handler.run()
    """
    from openai import AsyncOpenAI
    
    client = AsyncOpenAI(
        base_url="https://api.deepseek.com",
        api_key=os.getenv("OPENAI_API_KEY"),
    )
    stream = await client.chat.completions.create(
        model="deepseek-chat",
        
        messages=[{"role": "user", "content": message["message"]["text"]}],
        stream=True
    )
    
    return OpenAIResponseHandler(stream, client, channel, message)