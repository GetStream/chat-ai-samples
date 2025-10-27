import asyncio
import json
import logging
import os
from typing import Awaitable, Callable, Optional
from urllib.parse import urlencode

import aiohttp

EventHandler = Callable[[dict], Awaitable[None]]


class StreamEventListener:
    """Lightweight Stream Chat websocket listener used to receive real-time events."""

    def __init__(
        self,
        *,
        api_key: str,
        user_id: str,
        user_token: str,
        event_handler: EventHandler,
        base_url: Optional[str] = None,
    ) -> None:
        self.api_key = api_key
        self.user_id = user_id
        self.user_token = user_token
        self.event_handler = event_handler
        self.ws_url = base_url or os.getenv(
            "STREAM_WS_URL", "wss://chat.stream-io-api.com/connect"
        )

        self._session: Optional[aiohttp.ClientSession] = None
        self._ws: Optional[aiohttp.ClientWebSocketResponse] = None
        self._listener_task: Optional[asyncio.Task] = None
        self._stop_event = asyncio.Event()
        self._reconnect_delay = 1.0
        self._lock = asyncio.Lock()

    async def start(self) -> None:
        async with self._lock:
            if self._listener_task:
                return
            self._stop_event.clear()
            self._listener_task = asyncio.create_task(self._listen_loop())

    async def stop(self) -> None:
        async with self._lock:
            if not self._listener_task:
                return
            self._stop_event.set()
            self._listener_task.cancel()
            try:
                await self._listener_task
            except asyncio.CancelledError:
                pass
            finally:
                self._listener_task = None
            await self._disconnect()

    async def _listen_loop(self) -> None:
        while not self._stop_event.is_set():
            try:
                await self._connect()
                self._reconnect_delay = 1.0

                assert self._ws
                async for msg in self._ws:
                    if self._stop_event.is_set():
                        break
                    if msg.type == aiohttp.WSMsgType.TEXT:
                        try:
                            payload = json.loads(msg.data)
                        except json.JSONDecodeError:
                            logging.warning("Received non-JSON payload from Stream Chat.")
                            continue
                        event_type = payload.get("type")
                        if event_type in {"health.check", "pong"}:
                            continue
                        try:
                            await self.event_handler(payload)
                        except Exception:
                            logging.exception("Unexpected error while handling websocket event")
                    elif msg.type == aiohttp.WSMsgType.ERROR:
                        raise msg.data or RuntimeError("Websocket error encountered")
                    elif msg.type in (aiohttp.WSMsgType.CLOSED, aiohttp.WSMsgType.CLOSING):
                        break
            except asyncio.CancelledError:
                break
            except Exception:
                logging.exception("Stream Chat websocket listener encountered an error")
                await asyncio.sleep(min(self._reconnect_delay, 30.0))
                self._reconnect_delay *= 2
            finally:
                await self._disconnect()

    async def _connect(self) -> None:
        if not self._session or self._session.closed:
            self._session = aiohttp.ClientSession()
        params = urlencode(
            {
                "json": "1",
                "api_key": self.api_key,
                "user_id": self.user_id,
                "authorization": self.user_token,
            }
        )
        url = f"{self.ws_url}?{params}"
        self._ws = await self._session.ws_connect(url, heartbeat=55, timeout=15)

    async def _disconnect(self) -> None:
        if self._ws:
            await self._ws.close()
            self._ws = None
        if self._session and not self._session.closed:
            await self._session.close()
        self._session = None
