from __future__ import annotations

import asyncio
import logging
import os
import time
from collections import deque
from typing import Any, Deque, Dict, Optional

from anthropic import AsyncAnthropic
from stream_chat import StreamChat
from stream_chat.channel import Channel

from ...server_client import run_sync
from ..stream_listener import StreamEventListener
from ..types import AIAgent
from .response_handler import AnthropicResponseHandler


class AnthropicAgent(AIAgent):
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
        self._token = user_token
        self._api_key = api_key
        self._server_client = server_client
        self._cid = getattr(
            channel, "cid", f"{getattr(channel, 'type', 'messaging')}:{getattr(channel, 'id', '')}"
        )
        self._last_interaction = time.time()
        self._anthropic: Optional[AsyncAnthropic] = None
        self._listener = StreamEventListener(
            api_key=self._api_key,
            user_id=self.user_id,
            user_token=self._token,
            event_handler=self._handle_event,
        )
        self._history: Deque[Dict[str, Any]] = deque(maxlen=25)
        self._handlers: Dict[str, AnthropicResponseHandler] = {}
        self._lock = asyncio.Lock()

    async def init(self) -> None:
        api_key = os.getenv("ANTHROPIC_API_KEY")
        if not api_key:
            raise RuntimeError("Anthropic API key is required")
        self._anthropic = AsyncAnthropic(api_key=api_key)

        await self._bootstrap_history()
        await self._listener.start()

    async def dispose(self) -> None:
        await self._listener.stop()
        async with self._lock:
            handlers = list(self._handlers.values())
            self._handlers.clear()
        for handler in handlers:
            await handler.stop()
        if self._anthropic and hasattr(self._anthropic, "close"):
            close_result = self._anthropic.close()
            if asyncio.iscoroutine(close_result):
                await close_result
            self._anthropic = None

    def get_last_interaction(self) -> float:
        return self._last_interaction

    async def _handle_event(self, event: Dict[str, Any]) -> None:
        event_type = event.get("type")
        if event_type == "message.new":
            await self._handle_new_message(event)
        elif event_type == "ai_indicator.stop":
            await self._handle_stop(event)

    async def _handle_new_message(self, event: Dict[str, Any]) -> None:
        if not self._anthropic:
            logging.warning("Received message before Anthropic client initialised")
            return

        message = event.get("message") or {}
        if not message or message.get("ai_generated"):
            return

        text = message.get("text", "").strip()
        if not text:
            return

        self._last_interaction = time.time()
        self._history.append(message)

        prompts = self._build_prompt_history(message)

        # create placeholder AI message
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
            logging.error("Failed to create AI placeholder message")
            return

        await self._send_indicator(
            state="AI_STATE_THINKING",
            message_id=ai_message_id,
        )

        await asyncio.sleep(0.75)

        handler = AnthropicResponseHandler(
            anthropic=self._anthropic,
            channel=self.channel,
            server_client=self._server_client,
            ai_message_id=ai_message_id,
            prompts=prompts,
            model="claude-3-5-sonnet-20241022",
            max_tokens=1024,
            on_finalize=self._on_finalize,
            on_error=self._on_error,
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

    async def _bootstrap_history(self) -> None:
        try:
            state = await run_sync(
                self.channel.query,
                filters={},
                messages={"limit": 25},
            )
        except TypeError:
            # Older versions of the SDK expect positional args
            state = await run_sync(self.channel.query, {})
        except Exception:
            logging.exception("Failed to bootstrap channel history")
            return

        messages = state.get("messages", []) if isinstance(state, dict) else []
        for msg in messages[-25:]:
            if isinstance(msg, dict):
                self._history.append(msg)

    def _build_prompt_history(self, latest_message: Dict[str, Any]) -> Any:
        context = []
        for msg in list(self._history)[-5:]:
            text = msg.get("text")
            if not text:
                continue
            user = (msg.get("user") or {}).get("id", "")
            role = "assistant" if msg.get("ai_generated") or user.startswith("ai-bot") else "user"
            context.append({"role": role, "content": text})

        if latest_message.get("parent_id") is not None:
            context.append({"role": "user", "content": latest_message.get("text", "")})

        return context

    async def _on_finalize(self, message_id: str, text: str) -> None:
        async with self._lock:
            self._handlers.pop(message_id, None)
        if text:
            self._history.append(
                {
                    "id": message_id,
                    "text": text,
                    "ai_generated": True,
                    "user": {"id": self.user_id},
                }
            )

    async def _on_error(self, message_id: str, error: Exception) -> None:
        logging.exception("Anthropic handler error", exc_info=error)
        await run_sync(
            self._server_client.partial_update_message,
            message_id,
            {
                "text": str(error),
                "generating": False,
            },
            {},
        )

    async def _send_indicator(self, *, state: str, message_id: str) -> None:
        cid = getattr(self.channel, "cid", self._cid)
        if not cid:
            return
        payload = {
            "cid": cid,
            "message_id": message_id,
        }
        if state == "AI_STATE_THINKING":
            payload.update({"type": "ai_indicator.update", "ai_state": state})
        else:
            payload.update({"type": "ai_indicator.clear"})
        try:
            await run_sync(self.channel.send_event, payload)
        except Exception:
            logging.debug("Failed to send ai indicator event", exc_info=True)
