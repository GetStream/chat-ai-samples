"""Agent for using Anthropic API style agents"""

import os
import asyncio
from typing import Any
from anthropic import AsyncAnthropic
from getstream.models import MessageRequest
from model import NewMessageRequest
from helpers import (
    clear_ai_indicator,
    create_bot_id,
    get_last_messages_from_channel,
    is_ai_generated,
    update_ai_state,
)


class AnthropicAgent:
    """Agent for using Anthropic API style agents"""

    def __init__(self, chat_client, channel):
        api_key = os.environ.get("ANTHROPIC_API_KEY")
        if not api_key:
            raise ValueError("Anthropic API key is required")
        self.anthropic = AsyncAnthropic(api_key=api_key)
        self.chat_client = chat_client
        self.channel = channel

        self.processing = False
        self.message_text = ""
        self.chunk_counter = 0

    async def dispose(self):
        """Dispose of the agent"""
        self.channel = None
        await self.chat_client.aclose()
        await self.anthropic.close()

    async def handle_message(self, event: NewMessageRequest):
        """Handle a new message"""
        self.processing = True
        self.message_text = ""
        self.chunk_counter = 0

        try:
            if not self.anthropic:
                print("Anthropic SDK is not initialized")
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

                anthropic_stream = await self.anthropic.messages.create(
                    max_tokens=16000,
                    messages=list(reversed(messages)),
                    model="claude-opus-5-5",
                    stream=True,
                )

                async for message_stream_event in anthropic_stream:
                    await self.handle(message_stream_event, message_id, bot_id)

                await clear_ai_indicator(self.channel, bot_id)
            except Exception as error:
                print("Failed to send ai indicator update", error)
                await update_ai_state(
                    self.channel, bot_id, message_id, "AI_STATE_ERROR"
                )
        finally:
            self.processing = False

    async def handle(self, message_stream_event: Any, message_id: str, bot_id: str):
        """Handle a message stream event"""
        event_type = message_stream_event.type

        if event_type == "content_block_start":
            await update_ai_state(
                self.channel, bot_id, message_id, "AI_STATE_GENERATING"
            )

        elif event_type == "content_block_delta":
            if message_stream_event.delta.type != "text_delta":
                return

            self.message_text += message_stream_event.delta.text
            self.chunk_counter += 1

            if self.chunk_counter % 20 == 0 or (
                self.chunk_counter < 8 and self.chunk_counter % 2 != 0
            ):
                try:
                    await self.chat_client.chat.update_message_partial(
                        message_id,
                        set={"text": self.message_text, "generating": True},
                        user_id=bot_id,
                    )
                except Exception as error:
                    print("Error updating message", error)

        elif event_type in ["message_delta"]:
            await self.chat_client.chat.update_message_partial(
                message_id,
                set={"text": self.message_text, "generating": False},
                user_id=bot_id,
            )
        elif event_type == "message_stop":
            await asyncio.sleep(0.5)
            await self.chat_client.chat.update_message_partial(
                message_id,
                set={"text": self.message_text, "generating": False},
                user_id=bot_id,
            )
            await clear_ai_indicator(self.channel, bot_id)
