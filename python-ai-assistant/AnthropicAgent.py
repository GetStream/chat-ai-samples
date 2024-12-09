from anthropic import AsyncAnthropic
from AntrophicResponseHandler import AnthropicResponseHandler
from typing import List, Optional
from datetime import datetime
import os
import asyncio
from model import NewMessageRequest
from helpers import create_bot_id

# from .anthropic_response_handler import AnthropicResponseHandler


class AnthropicAgent:
    def __init__(self, chat_client, channel):
        self.anthropic: Optional[AsyncAnthropic] = None
        # self.handlers: List[AnthropicResponseHandler] = []
        self.last_interaction_ts: float = datetime.now().timestamp()
        self.chat_client = chat_client
        self.channel = channel

    async def dispose(self):
        # self.chat_client.off("message.new", self.handle_message)
        await self.chat_client.disconnect_user()

        for handler in self.handlers:
            await handler.dispose()
        self.handlers = []

    def get_last_interaction(self) -> float:
        return self.last_interaction_ts

    async def init(self):
        api_key = os.environ.get("ANTHROPIC_API_KEY")
        if not api_key:
            raise ValueError("Anthropic API key is required")
        self.anthropic = AsyncAnthropic(api_key=api_key)

    async def handle_message(self, event: NewMessageRequest):
        if not self.anthropic:
            print("Anthropic SDK is not initialized")
            return

        if not event.message or event.message.get("ai_generated"):
            print("Skip handling ai generated message")
            return

        # print("Message: ", event.message)

        message = event.message.get("text")
        if not message:
            return

        self.last_interaction_ts = datetime.now().timestamp()

        channel_filters = {"cid": event.cid}
        message_filters = {"type": {"$eq": "regular"}}
        sort = {"updated_at": -1}
        message_search = await self.chat_client.search(
            channel_filters, message_filters, sort, limit=5
        )

        # print("Message search: ", message_search)

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
        ]

        # print("Messages: ", messages)

        # messages = [
        #     {
        #         "role": (
        #             "assistant"
        #             if msg.get("user", {}).get("id", "").startswith("ai-bot")
        #             else "user"
        #         ),
        #         "content": msg.get("text", ""),
        #     }
        #     for msg in messages
        # ]

        if "parent_id" in event.message:
            message_to_append = {"role": "user", "content": message["text"]}
            print("Message to append: ", message_to_append)
            messages.append({"role": "user", "content": message["text"]})

        anthropic_stream = await self.anthropic.messages.create(
            max_tokens=1024,
            messages=messages,
            model="claude-3-5-sonnet-20241022",
            stream=True,
        )

        bot_id = create_bot_id(channel_id=self.channel.id)

        channel_message = await self.channel.send_message(
            {"text": "", "ai_generated": True}, bot_id
        )

        try:
            await self.channel.send_event(
                {
                    "type": "ai_indicator.update",
                    "ai_state": "AI_STATE_THINKING",
                    "message_id": channel_message["id"],
                }
            )
        except Exception as error:
            print("Failed to send ai indicator update", error)

        await asyncio.sleep(0.75)

        handler = AnthropicResponseHandler(
            anthropic_stream, self.chat_client, self.channel, channel_message
        )
        asyncio.create_task(handler.run())
        self.handlers.append(handler)
