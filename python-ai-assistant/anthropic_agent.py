"""Agent for using Anthropic API style agents"""

import os
import asyncio
from typing import Any
from anthropic import AsyncAnthropic
from model import NewMessageRequest
from helpers import create_bot_id, get_last_messages_from_channel


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
        await self.chat_client.close()
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

            try:
                if messages[0]["content"] != message:
                    messages.insert(0, {"role": "user", "content": message})
            except IndexError as error:
                print("No messages found in channel: ", error)

            # If the message has a parent_id it is part of a threaded message and
            # we need to append the message to the messages list
            if "parent_id" in event.message:
                message_to_append = {"role": "user", "content": message["text"]}
                print("Message to append: ", message_to_append)
                messages.append({"role": "user", "content": message["text"]})

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

                anthropic_stream = await self.anthropic.messages.create(
                    max_tokens=1024,
                    messages=list(reversed(messages)),
                    model="claude-3-5-sonnet-20241022",
                    stream=True,
                )

                async for message_stream_event in anthropic_stream:
                    await self.handle(message_stream_event, message_id, bot_id)

                await self.channel.send_event(
                    {
                        "type": "ai_indicator.clear",
                        "message_id": message_id,
                    },
                    bot_id,
                )
            except Exception as error:
                print("Failed to send ai indicator update", error)
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

    async def handle(self, message_stream_event: Any, message_id: str, bot_id: str):
        """Handle a message stream event"""
        event_type = message_stream_event.type

        if event_type == "content_block_start":
            await self.channel.send_event(
                {
                    "type": "ai_indicator.update",
                    "ai_state": "AI_STATE_GENERATING",
                    "message_id": message_id,
                },
                bot_id,
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
                    await self.chat_client.update_message_partial(
                        message_id,
                        {"set": {"text": self.message_text, "generating": True}},
                        bot_id,
                    )
                except Exception as error:
                    print("Error updating message", error)

        elif event_type in ["message_delta"]:
            await self.chat_client.update_message_partial(
                message_id,
                {"set": {"text": self.message_text, "generating": False}},
                bot_id,
            )
        elif event_type == "message_stop":
            await asyncio.sleep(0.5)
            await self.chat_client.update_message_partial(
                message_id,
                {"set": {"text": self.message_text, "generating": False}},
                bot_id,
            )
            await self.channel.send_event(
                {
                    "type": "ai_indicator.clear",
                    "message_id": message_id,
                },
                bot_id,
            )
