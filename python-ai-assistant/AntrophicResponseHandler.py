from stream_chat import StreamChat
from typing import Any
import asyncio
from helpers import create_bot_id


class AnthropicResponseHandler:
    def __init__(
        self, anthropic_stream: Any, chat_client: StreamChat, channel: Any, message: Any
    ):
        self.anthropic_stream = anthropic_stream
        self.chat_client = chat_client
        self.channel = channel
        self.message = message
        self.message_text = ""
        self.chunk_counter = 0

        # Register stop handler
        # self.chat_client.on("ai_indicator.stop", self.handle_stop_generating)

    async def run(self):
        try:
            async for message_stream_event in self.anthropic_stream:
                await self.handle(message_stream_event)
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

    def dispose(self):
        pass
        # self.chat_client.off("ai_indicator.stop", self.handle_stop_generating)

    async def handle_stop_generating(self):
        print("Stop generating")
        bot_id = create_bot_id(channel_id=self.channel.id)

        if not self.anthropic_stream:
            print("Anthropic not initialized")
            return

        self.anthropic_stream.controller.abort()
        await self.chat_client.update_message_partial(
            self.message["message"]["id"], {"set": {"generating": False}}, bot_id
        )
        await self.channel.send_event(
            {"type": "ai_indicator.clear", "message_id": self.message["message"]["id"]},
            bot_id,
        )

    async def handle(self, message_stream_event: Any):
        event_type = message_stream_event.type
        bot_id = create_bot_id(channel_id=self.channel.id)

        if event_type == "content_block_start":
            await self.channel.send_event(
                {
                    "type": "ai_indicator.update",
                    "ai_state": "AI_STATE_GENERATING",
                    "message_id": self.message["message"]["id"],
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
                        self.message["message"]["id"],
                        {"set": {"text": self.message_text, "generating": True}},
                        bot_id,
                    )
                except Exception as error:
                    print("Error updating message", error)

        elif event_type in ["message_delta"]:
            await self.chat_client.update_message_partial(
                self.message["message"]["id"],
                {"set": {"text": self.message_text, "generating": False}},
                bot_id,
            )
        elif event_type == "message_stop":
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
