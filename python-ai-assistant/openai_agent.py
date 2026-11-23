"""Agent for using OpenAI API style agents"""

import os
import asyncio
from typing import Any
from openai import AsyncOpenAI
from getstream.models import MessageRequest
from model import NewMessageRequest
from helpers import (
    clear_ai_indicator,
    create_bot_id,
    get_last_messages_from_channel,
    is_ai_generated,
    update_ai_state,
)


class OpenAIAgent:
    """Agent for using OpenAI API style agents"""

    def __init__(self, chat_client, channel):
        api_key = os.environ.get("OPENAI_API_KEY")
        if not api_key:
            raise ValueError("OpenAI API key is required")
        self.openai = AsyncOpenAI(api_key=api_key)
        # By changing the base_url parameter, we can use e.g. the DeepSeek API, or even local models
        # Example:
        # self.openai = AsyncOpenAI(api_key=api_key, base_url="https://api.deepseek.com")
        self.chat_client = chat_client
        self.channel = channel

        self.processing = False
        self.message_text = ""
        self.chunk_counter = 0

    async def dispose(self):
        """Dispose of the agent"""
        self.channel = None
        await self.chat_client.aclose()
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

            if not event.message or is_ai_generated(event.message):
                print("Skip handling ai generated message")
                return

            message = event.message.get("text")
            if not message:
                print("Skip handling empty message")
                return

            messages = await get_last_messages_from_channel(
                self.chat_client, event.cid, 5
            )

            try:
                if messages[0]["content"] != message:
                    messages.insert(0, {"role": "user", "content": message})
            except IndexError as error:
                print("No messages found in channel: ", error)

            # If the message has a parent_id it is part of a threaded message and
            # we need to append the message to the messages list
            if "parent_id" in event.message:
                message_to_append = {"role": "user", "content": message}
                print("Message to append: ", message_to_append)
                messages.append(message_to_append)

            bot_id = create_bot_id(channel_id=self.channel.channel_id)

            channel_message = await self.channel.send_message(
                MessageRequest(text="", user_id=bot_id, custom={"ai_generated": True})
            )
            message_id = channel_message.data.message.id

            try:
                if message_id:
                    await update_ai_state(
                        self.channel, bot_id, message_id, "AI_STATE_THINKING"
                    )

                openai_stream = await self.openai.chat.completions.create(
                    max_tokens=1024,
                    messages=list(reversed(messages)),
                    model="gpt-4o-mini",
                    stream=True,
                )

                async for chunk in openai_stream:
                    await self.handle(chunk, message_id, bot_id)

                await clear_ai_indicator(self.channel, bot_id)

            except Exception as error:
                print("Error in message handling:", error)
                await update_ai_state(
                    self.channel, bot_id, message_id, "AI_STATE_ERROR"
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
                await update_ai_state(
                    self.channel, bot_id, message_id, "AI_STATE_GENERATING"
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
                        await self.chat_client.chat.update_message_partial(
                            message_id,
                            set={"text": self.message_text, "generating": True},
                            user_id=bot_id,
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
                await self.chat_client.chat.update_message_partial(
                    message_id,
                    set={"text": self.message_text, "generating": False},
                    user_id=bot_id,
                )
                # Clear the AI indicator
                await clear_ai_indicator(self.channel, bot_id)

        except Exception as e:
            print(f"Error handling chunk: {str(e)}")
            await update_ai_state(self.channel, bot_id, message_id, "AI_STATE_ERROR")
            raise
