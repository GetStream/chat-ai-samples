from anthropic import AsyncAnthropic
from AntrophicResponseHandler import AnthropicResponseHandler
from typing import List, Optional, Any
from datetime import datetime
import os
import asyncio
from model import NewMessageRequest
from helpers import create_bot_id


class AnthropicAgent:
    def __init__(self, chat_client, channel):
        self.anthropic: Optional[AsyncAnthropic] = None
        self.handlers: List[AnthropicResponseHandler] = []
        self.last_interaction_ts: float = datetime.now().timestamp()
        self.chat_client = chat_client
        self.channel = channel
        api_key = os.environ.get("ANTHROPIC_API_KEY")
        if not api_key:
            raise ValueError("Anthropic API key is required")
        self.anthropic = AsyncAnthropic(api_key=api_key)

        self.processing = False
        self.message_text = ""
        self.chunk_counter = 0

    async def dispose(self):
        await self.chat_client.close()
        self.handlers = []

    def get_last_interaction(self) -> float:
        return self.last_interaction_ts

    async def handle_message(self, event: NewMessageRequest):
        self.processing = True
        if not self.anthropic:
            print("Anthropic SDK is not initialized")
            self.processing = False
            return

        if not event.message or event.message.get("ai_generated"):
            print("Skip handling ai generated message")
            self.processing = False
            return

        message = event.message.get("text")
        if not message:
            print("Skip handling empty message")
            self.processing = False
            return

        self.last_interaction_ts = datetime.now().timestamp()

        channel_filters = {"cid": event.cid}
        message_filters = {"type": {"$eq": "regular"}}
        sort = {"updated_at": -1}
        message_search = await self.chat_client.search(
            channel_filters, message_filters, sort, limit=5
        )

        messages = [
            {
                "content": message["message"]["text"].strip(),
                "role": (
                    "assistant"
                    if message["message"]["user"]["id"].startswith("ai-bot")
                    else "user"
                ),
            }
            for message in message_search["results"]
            if message["message"]["text"] != ""
        ]
        if messages[0]["content"] != message:
            messages.insert(0, {"role": "user", "content": message})

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
        except Exception as error:
            print("Failed to send ai indicator update", error)

        anthropic_stream = await self.anthropic.messages.create(
            max_tokens=1024,
            messages=list(reversed(messages)),
            model="claude-3-5-sonnet-20241022",
            stream=True,
        )

        try:
            async for message_stream_event in anthropic_stream:
                await self.handle(message_stream_event, message_id, bot_id)
        except Exception as error:
            print("Error handling message stream event", error)
            await self.channel.send_event(
                {
                    "type": "ai_indicator.update",
                    "ai_state": "AI_STATE_ERROR",
                    "message_id": message_id,
                },
                bot_id,
            )
        self.processing = False

    async def handle(self, message_stream_event: Any, message_id: str, bot_id: str):
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
