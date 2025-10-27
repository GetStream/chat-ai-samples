from __future__ import annotations

import asyncio
import logging
import os
import time
from typing import Any, Dict, List, Optional

from openai import AsyncOpenAI
from stream_chat import StreamChat
from stream_chat.channel import Channel

from ...server_client import run_sync
from ..stream_listener import StreamEventListener
from ..types import AIAgent
from .response_handler import OpenAIResponseHandler


class OpenAIAgent(AIAgent):
    def __init__(
        self,
        *,
        user_id: str,
        user_token: str,
        channel: Channel,
        api_key: str,
        server_client: StreamChat,
    ) -> None:
        self.user_id = user_id
        self.channel = channel
        self._cid = getattr(
            channel, "cid", f"{getattr(channel, 'type', 'messaging')}:{getattr(channel, 'id', '')}"
        )
        self._token = user_token
        self._api_key = api_key
        self._server_client = server_client
        self._last_interaction = time.time()
        self._openai: Optional[AsyncOpenAI] = None
        self._listener = StreamEventListener(
            api_key=self._api_key,
            user_id=self.user_id,
            user_token=self._token,
            event_handler=self._handle_event,
        )
        self._handlers: Dict[str, OpenAIResponseHandler] = {}
        self._lock = asyncio.Lock()
        self._last_response_id: Optional[str] = None
        self._openweather_api_key = os.getenv("OPENWEATHER_API_KEY")

    async def init(self) -> None:
        api_key = os.getenv("OPENAI_API_KEY")
        if not api_key:
            raise RuntimeError("OpenAI API key is required")
        self._openai = AsyncOpenAI(api_key=api_key)
        await self._listener.start()

    async def dispose(self) -> None:
        await self._listener.stop()
        async with self._lock:
            handlers = list(self._handlers.values())
            self._handlers.clear()
        for handler in handlers:
            await handler.stop()
        if self._openai and hasattr(self._openai, "close"):
            close_result = self._openai.close()
            if asyncio.iscoroutine(close_result):
                await close_result
            self._openai = None

    def get_last_interaction(self) -> float:
        return self._last_interaction

    async def _handle_event(self, event: Dict[str, Any]) -> None:
        event_type = event.get("type")
        if event_type == "message.new":
            await self._handle_new_message(event)
        elif event_type == "ai_indicator.stop":
            await self._handle_stop(event)

    async def _handle_new_message(self, event: Dict[str, Any]) -> None:
        if not self._openai:
            logging.warning("Received message before OpenAI client initialised")
            return

        message = event.get("message") or {}
        if not message or message.get("ai_generated"):
            return

        text = (message.get("text") or "").strip()
        attachments = message.get("attachments") or []
        image_attachments = [
            attachment
            for attachment in attachments
            if self._is_image_attachment(attachment)
        ]
        if not text and not image_attachments:
            return

        self._last_interaction = time.time()

        response = await run_sync(
            self.channel.send_message,
            {
                "text": "",
                "ai_generated": True,
                "user_id": self.user_id,
                "parent_id": message.get("id"),
            },
        )
        ai_message = response.get("message", {})
        ai_message_id = ai_message.get("id")
        if not ai_message_id:
            logging.error("Failed to create AI message shell")
            return

        await self._send_indicator(
            {
                "type": "ai_indicator.update",
                "ai_state": "AI_STATE_THINKING",
                "message_id": ai_message_id,
            }
        )

        user_content = []
        if text:
            user_content.append({"type": "input_text", "text": text})
        for attachment in image_attachments:
            image_url = (
                attachment.get("image_url")
                or attachment.get("asset_url")
                or attachment.get("thumb_url")
            )
            if image_url:
                user_content.append(
                    {"type": "input_image", "image_url": image_url, "detail": "high"}
                )
        if not user_content:
            user_content.append(
                {
                    "type": "input_text",
                    "text": "The user sent an image with no description. Provide helpful observations.",
                }
            )

        system_prompt = (
            "You are an AI assistant. Help users with their questions. Only call the "
            "getCurrentTemperature tool if the user explicitly asks for the current temperature "
            "for a specific location."
        )
        request_input = [
            {
                "role": "system",
                "content": [{"type": "input_text", "text": system_prompt}],
            },
            {"role": "user", "content": user_content},
        ]

        tools = [
            {
                "type": "function",
                "name": "getCurrentTemperature",
                "description": "Get the current temperature for a specific location",
                "strict": True,
                "parameters": {
                    "type": "object",
                    "additionalProperties": False,
                    "properties": {
                        "location": {
                            "type": "string",
                            "description": "The city and state, e.g., San Francisco, CA",
                        },
                        "unit": {
                            "type": "string",
                            "enum": ["Celsius", "Fahrenheit"],
                            "description": "The temperature unit to use. Infer this from the user's location.",
                        },
                    },
                    "required": ["location", "unit"],
                },
            }
        ]

        handler = OpenAIResponseHandler(
            openai=self._openai,
            server_client=self._server_client,
            channel=self.channel,
            ai_message_id=ai_message_id,
            cid=self._cid,
            input_payload=request_input,
            tools=tools,
            previous_response_id=self._last_response_id,
            on_response_id=self._set_last_response_id,
            on_finalize=self._on_finalize,
            openweather_api_key=self._openweather_api_key,
        )

        async with self._lock:
            self._handlers[ai_message_id] = handler
        handler.start()

    async def _handle_stop(self, event: Dict[str, Any]) -> None:
        message_id = event.get("message_id")
        if not message_id:
            return
        async with self._lock:
            handler = self._handlers.get(message_id)
        if handler:
            await handler.stop()

    async def _on_finalize(self, message_id: str, _: str) -> None:
        async with self._lock:
            self._handlers.pop(message_id, None)

    async def _send_indicator(self, payload: Dict[str, Any]) -> None:
        cid = getattr(self.channel, "cid", self._cid)
        if not cid:
            return
        payload.setdefault("cid", cid)
        try:
            await run_sync(self.channel.send_event, payload)
        except Exception:
            logging.debug("Failed to send indicator event", exc_info=True)

    async def _set_last_response_id(self, response_id: str) -> None:
        self._last_response_id = response_id

    def _is_image_attachment(self, attachment: Dict[str, Any]) -> bool:
        if not attachment:
            return False
        attachment_type = attachment.get("type")
        mime = attachment.get("mime_type", "")
        has_image_type = attachment_type == "image" or (isinstance(mime, str) and mime.startswith("image/"))
        has_url = any(
            attachment.get(key)
            for key in ("image_url", "asset_url", "thumb_url")
        )
        return bool(has_image_type and has_url)
