from __future__ import annotations

import asyncio
import logging
from typing import Any, Awaitable, Callable, Dict, List, Optional

from anthropic import AsyncAnthropic
from stream_chat import StreamChat
from stream_chat.channel import Channel

from ...server_client import run_sync

OnFinalizeCallback = Callable[[str, str], Awaitable[None]]
OnErrorCallback = Callable[[str, Exception], Awaitable[None]]


class AnthropicResponseHandler:
    """Streams Anthropic responses and mirrors them to Stream Chat."""

    def __init__(
        self,
        *,
        anthropic: AsyncAnthropic,
        channel: Channel,
        server_client: StreamChat,
        ai_message_id: str,
        prompts: List[Dict[str, str]],
        model: str,
        max_tokens: int,
        on_finalize: OnFinalizeCallback,
        on_error: OnErrorCallback,
    ) -> None:
        self._anthropic = anthropic
        self._channel = channel
        self._server_client = server_client
        self._message_id = ai_message_id
        self._prompts = prompts
        self._model = model
        self._max_tokens = max_tokens
        self._on_finalize = on_finalize
        self._on_error = on_error
        self._buffer = ""
        self._stop_event = asyncio.Event()
        self._task: Optional[asyncio.Task] = None
        self._finished = False

    def start(self) -> None:
        if self._task:
            return
        self._task = asyncio.create_task(self._run())

    async def stop(self) -> None:
        self._stop_event.set()
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
            finally:
                self._task = None
        await self._finalize(generating=False)

    async def _run(self) -> None:
        try:
            async with self._anthropic.messages.stream(
                max_tokens=self._max_tokens,
                messages=self._prompts,
                model=self._model,
            ) as stream:
                async for event in stream:
                    if self._stop_event.is_set():
                        close = getattr(stream, "close", None)
                        if callable(close):
                            maybe_await = close()
                            if asyncio.iscoroutine(maybe_await):
                                await maybe_await
                        break
                    await self._handle_event(event)
        except asyncio.CancelledError:
            pass
        except Exception as err:
            logging.exception("Anthropic streaming failed")
            await self._on_error(self._message_id, err)
            self._buffer = str(err)
        finally:
            await self._finalize()

    async def _handle_event(self, event: Any) -> None:
        event_type = getattr(event, "type", None)
        if event_type == "content_block_start":
            await self._send_indicator("AI_STATE_GENERATING")
        elif event_type == "content_block_delta":
            delta = getattr(event, "delta", None)
            if not delta or getattr(delta, "type", None) != "text_delta":
                return
            text_piece = getattr(delta, "text", "")
            if not text_piece:
                return
            self._buffer += text_piece
            await self._update_message(generating=True)
        elif event_type in {"message_delta", "message_stop"}:
            await self._finalize()

    async def _finalize(self, generating: bool = False) -> None:
        try:
            await self._update_message(generating=generating)
            await self._send_indicator("AI_STATE_CLEAR")
        finally:
            if not self._finished:
                self._finished = True
                await self._on_finalize(self._message_id, self._buffer)

    async def _update_message(self, generating: bool) -> None:
        await run_sync(
            self._server_client.partial_update_message,
            self._message_id,
            {"text": self._buffer, "generating": generating},
            {},
        )

    async def _send_indicator(self, state: str) -> None:
        if not getattr(self._channel, "cid", None):
            return
        if state == "AI_STATE_CLEAR":
            payload = {
                "type": "ai_indicator.clear",
                "cid": self._channel.cid,
                "message_id": self._message_id,
            }
        else:
            payload = {
                "type": "ai_indicator.update",
                "ai_state": state,
                "cid": self._channel.cid,
                "message_id": self._message_id,
            }
        try:
            await run_sync(self._channel.send_event, payload)
        except Exception:
            logging.debug("Failed to send AI indicator update", exc_info=True)
