"""Agent for using OpenAI API style agents"""

import os
import asyncio
from typing import Any
from openai import AsyncOpenAI
from model import NewMessageRequest
from helpers import create_bot_id, get_last_messages_from_channel


class OpenAIAgent:
    """Agent for using OpenAI API style agents"""

    def __init__(self, chat_client, channel):
        api_key = os.environ.get("OPENAI_API_KEY")
        if not api_key:
            raise ValueError("OpenAI API key is required")
        # self.openai = AsyncOpenAI(api_key=api_key, base_url="https://api.deepseek.com")
        self.openai = AsyncOpenAI(api_key=api_key)
        self.chat_client = chat_client
        self.channel = channel

        self.processing = False
        self.message_text = ""
        self.chunk_counter = 0

    async def dispose(self):
        """Dispose of the agent"""
        self.channel = None
        await self.chat_client.close()
        await self.openai.close()

    async def handle_message(self, event: NewMessageRequest):
        """Handle a new message"""
        self.processing = True
        self.message_text = ""  # Reset message text
        self.chunk_counter = 0  # Reset chunk counter

        try:
            if not self.openai:
                print("OpenAI SDK is not initialized")
                return

            if not event.message or event.message.get("ai_generated"):
                print("Skip handling ai generated message")
                return

            message = event.message.get("text")
            if not message:
                print("Skip handling empty message")
                return

            messages = await get_last_messages_from_channel(
                self.chat_client, event.cid, 5
            )

            if messages[0]["content"] != message:
                messages.insert(0, {"role": "user", "content": message})

            bot_id = create_bot_id(channel_id=self.channel.id)

            channel_message = await self.channel.send_message(
                {"text": "", "ai_generated": True}, bot_id
            )
            message_id = channel_message["message"]["id"]

            try:
                if message_id:
                    await self.channel.send_event(
                        {
                            "type": "ai_indicator.update",
                            "ai_state": "AI_STATE_THINKING",
                            "message_id": message_id,
                        },
                        bot_id,
                    )

                openai_stream = await self.openai.chat.completions.create(
                    model="gpt-4o-mini",
                    # model="deepseek-chat",
                    messages=messages,
                    stream=True,
                )

                async for chunk in openai_stream:
                    print("Chunk", chunk)
                    await self.handle(chunk, message_id, bot_id)

            except Exception as error:
                print("Error in message handling:", error)
                await self.channel.send_event(
                    {
                        "type": "ai_indicator.update",
                        "ai_state": "AI_STATE_ERROR",
                        "message_id": message_id,
                    },
                    bot_id,
                )
        finally:
            self.processing = False

    async def handle(self, chunk: Any, message_id: str, bot_id: str):
        """
        Handle chunks from OpenAI Chat Completions API streaming response.
        Each chunk contains a choices array with a single choice containing a delta.
        """
        try:
            # First chunk - start generating indicator
            if self.chunk_counter == 0:
                # Add await here to ensure the event is processed before continuing
                await self.channel.send_event(
                    {
                        "type": "ai_indicator.update",
                        "ai_state": "AI_STATE_GENERATING",
                        "message_id": message_id,
                    },
                    bot_id,
                )
                # Add a small delay to ensure the UI has time to process the event
                await asyncio.sleep(0.1)

            # Get content from the delta if present
            if (
                hasattr(chunk, "choices")
                and len(chunk.choices) > 0
                and hasattr(chunk.choices[0], "delta")
                and hasattr(chunk.choices[0].delta, "content")
                and chunk.choices[0].delta.content is not None
            ):

                delta_text = chunk.choices[0].delta.content
                self.message_text += delta_text
                self.chunk_counter += 1

                # Update message less frequently to avoid overwhelming the connection
                if self.chunk_counter % 15 == 0 or (
                    self.chunk_counter < 8 and self.chunk_counter % 2 == 0
                ):
                    try:
                        # Add await here to ensure the update completes
                        await self.chat_client.update_message_partial(
                            message_id,
                            {"set": {"text": self.message_text, "generating": True}},
                            bot_id,
                        )
                        # Small delay after updates
                        await asyncio.sleep(0.05)
                    except Exception as error:
                        print("Error updating message:", error)

            # Check for completion (final chunk)
            if (
                hasattr(chunk, "choices")
                and len(chunk.choices) > 0
                and chunk.choices[0].finish_reason is not None
            ):

                # Increased delay before final updates
                await asyncio.sleep(0.5)
                # Final message update
                await self.chat_client.update_message_partial(
                    message_id,
                    {"set": {"text": self.message_text, "generating": False}},
                    bot_id,
                )
                # Clear the AI indicator
                await self.channel.send_event(
                    {
                        "type": "ai_indicator.clear",
                        "message_id": message_id,
                    },
                    bot_id,
                )

        except Exception as e:
            print(f"Error handling chunk: {str(e)}")
            raise
