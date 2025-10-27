from __future__ import annotations

import asyncio
import base64
import io
import json
import logging
from typing import Any, Awaitable, Callable, Dict, List, Optional

import httpx
from openai import AsyncOpenAI
from stream_chat import StreamChat
from stream_chat.channel import Channel

from ...server_client import run_sync


class OpenAIResponseHandler:
    def __init__(
        self,
        *,
        openai: AsyncOpenAI,
        server_client: StreamChat,
        channel: Channel,
        ai_message_id: str,
        cid: str,
        input_payload: List[Any],
        tools: List[Any],
        previous_response_id: Optional[str],
        on_response_id: Callable[[str], Awaitable[None]],
        on_finalize: Callable[[str, str], Awaitable[None]],
        openweather_api_key: Optional[str],
    ) -> None:
        self._openai = openai
        self._server_client = server_client
        self._channel = channel
        self._message_id = ai_message_id
        self._cid = cid
        self._input = input_payload
        self._tools = tools
        self._previous_response_id = previous_response_id
        self._on_response_id = on_response_id
        self._on_finalize = on_finalize
        self._openweather_api_key = openweather_api_key
        self._last_response_id: Optional[str] = previous_response_id

        self._stop_event = asyncio.Event()
        self._task: Optional[asyncio.Task] = None
        self._mode: str = "text"
        self._message_text = ""
        self._pending_tool_args: Dict[str, str] = {}
        self._function_calls: Dict[str, Dict[str, str]] = {}
        self._continuation_pending = False
        self._continuation_active = False
        self._current_indicator: Optional[str] = None
        self._indicator_cleared = False
        self._finalized = False
        self._last_update_lock = asyncio.Lock()

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
        if self._mode == "image" and not self._finalized:
            await self._update_message(
                text="Image generation stopped.",
                generating=False,
                attachments=[],
            )
            await self._clear_indicator()
            self._finalized = True
            await self._on_finalize(self._message_id, "")

    async def _run(self) -> None:
        self._mode = "image" if self._should_generate_image_request() else "text"
        if self._mode == "image":
            await self._generate_image()
        else:
            await self._stream_text()

    async def _stream_text(self) -> None:
        try:
            async with self._openai.responses.stream(
                model="gpt-4o",
                input=self._input,
                tools=self._tools,
                previous_response_id=self._previous_response_id,
            ) as stream:
                async for event in stream:
                    if self._stop_event.is_set():
                        await stream.close()
                        break
                    await self._handle_event(event)
        except asyncio.CancelledError:
            pass
        except Exception as err:
            logging.exception("OpenAI streaming failed")
            await self._handle_error(err)
        finally:
            await self._finalize_message()

    async def _handle_event(self, event: Any) -> None:
        event_type = getattr(event, "type", None)
        if event_type == "response.created":
            response = getattr(event, "response", None)
            response_id = getattr(response, "id", None)
            if response_id:
                self._last_response_id = response_id
                await self._on_response_id(response_id)
        elif event_type == "response.output_item.added":
            item = getattr(event, "item", None)
            if getattr(item, "type", None) == "function_call" and getattr(item, "id", None):
                self._function_calls[item.id] = {
                    "name": getattr(item, "name", ""),
                    "call_id": getattr(item, "call_id", ""),
                }
        elif event_type == "response.output_text.delta":
            delta = getattr(event, "delta", None)
            if delta:
                await self._update_indicator("AI_STATE_GENERATING")
                self._message_text += str(delta)
                await self._flush_partial_update()
        elif event_type == "response.completed":
            if not self._continuation_pending and not self._continuation_active:
                await self._finalize_message()
        elif event_type == "response.function_call_arguments.delta":
            delta = getattr(event, "delta", None)
            item_id = getattr(event, "item_id", None)
            if not item_id or delta is None:
                return
            self._pending_tool_args[item_id] = (
                self._pending_tool_args.get(item_id, "") + str(delta)
            )
            await self._update_indicator("AI_STATE_EXTERNAL_SOURCES")
        elif event_type == "response.function_call_arguments.done":
            item_id = getattr(event, "item_id", None)
            if not item_id:
                return
            call_meta = self._function_calls.get(item_id) or {}
            function_name = call_meta.get("name")
            call_id = call_meta.get("call_id")
            args_str = self._pending_tool_args.pop(item_id, "{}")
            output = await self._invoke_tool(function_name, args_str)
            response_id = self._last_response_id
            if response_id and call_id:
                await self._run_continuation(call_id, output, response_id)
        elif event_type == "error":
            message = getattr(event, "message", "OpenAI response error")
            await self._handle_error(RuntimeError(message))

    async def _run_continuation(self, call_id: str, output: str, response_id: str) -> None:
        self._continuation_pending = True
        try:
            async with self._openai.responses.stream(
                model="gpt-4o",
                previous_response_id=response_id,
                tools=self._tools,
                input=[{"type": "function_call_output", "call_id": call_id, "output": output}],
            ) as continuation:
                self._continuation_active = True
                self._continuation_pending = False
                async for event in continuation:
                    if self._stop_event.is_set():
                        await continuation.close()
                        break
                    await self._handle_event(event)
        finally:
            self._continuation_active = False

    async def _invoke_tool(self, name: Optional[str], args_json: str) -> str:
        if name != "getCurrentTemperature":
            return ""
        if not self._openweather_api_key:
            return "NaN"
        try:
            args = json.loads(args_json)
            location = str(args.get("location", ""))
            unit = str(args.get("unit", "Celsius"))
        except Exception:
            return "NaN"

        params = {"q": location, "appid": self._openweather_api_key}
        if unit.lower().startswith("f"):
            params["units"] = "imperial"
        else:
            params["units"] = "metric"

        try:
            async with httpx.AsyncClient(timeout=10) as client:
                response = await client.get(
                    "https://api.openweathermap.org/data/2.5/weather", params=params
                )
                response.raise_for_status()
                data = response.json()
            temperature = data.get("main", {}).get("temp")
            return str(temperature) if temperature is not None else "NaN"
        except Exception:
            return "NaN"

    async def _generate_image(self) -> None:
        try:
            await self._update_indicator("AI_STATE_GENERATING")
            prompt = self._build_image_prompt()
            if not prompt:
                raise RuntimeError("No prompt provided for image generation.")
            response = await self._openai.images.generate(
                model="gpt-image-1",
                prompt=prompt,
                size="1024x1024",
            )
            data = response.data[0]
            image_b64 = getattr(data, "b64_json", None) or data.get("b64_json")
            if not image_b64:
                raise RuntimeError("Image generation failed: missing image data.")
            image_bytes = base64.b64decode(image_b64)
            buffer = io.BytesIO(image_bytes)
            upload = await run_sync(
                self._channel.send_image,
                buffer,
                "generated-image.png",
                "image/png",
            )
            attachment = {
                "type": "image",
                "image_url": upload.get("file"),
                "thumb_url": upload.get("thumb_url") or upload.get("file"),
                "fallback": prompt,
            }
            message_text = f'Generated image for prompt: "{prompt}"'
            await self._update_message(
                text=message_text,
                generating=False,
                attachments=[attachment],
            )
            self._message_text = message_text
            self._finalized = True
            await self._on_finalize(self._message_id, self._message_text)
        except Exception as err:
            await self._handle_error(err)
        finally:
            await self._clear_indicator()

    async def _update_message(
        self,
        *,
        text: str,
        generating: bool,
        attachments: Optional[List[Dict[str, Any]]] = None,
    ) -> None:
        await run_sync(
            self._server_client.partial_update_message,
            self._message_id,
            {
                "text": text,
                "generating": generating,
                **({"attachments": attachments} if attachments is not None else {}),
            },
            {},
        )

    async def _flush_partial_update(self) -> None:
        if self._finalized:
            return
        async with self._last_update_lock:
            await self._update_message(
                text=self._message_text,
                generating=True,
            )

    async def _finalize_message(self) -> None:
        if self._finalized:
            return
        self._finalized = True
        await self._update_message(text=self._message_text, generating=False)
        await self._clear_indicator()
        await self._on_finalize(self._message_id, self._message_text)

    async def _handle_error(self, error: Exception) -> None:
        self._finalized = True
        await self._update_indicator("AI_STATE_ERROR")
        await self._update_message(
            text=str(error),
            generating=False,
        )
        await self._on_finalize(self._message_id, "")

    async def _update_indicator(self, state: str) -> None:
        if self._current_indicator == state:
            return
        self._current_indicator = state
        self._indicator_cleared = False
        payload = {
            "type": "ai_indicator.update",
            "cid": self._cid,
            "message_id": self._message_id,
            "ai_state": state,
        }
        try:
            await run_sync(self._channel.send_event, payload)
        except Exception:
            logging.debug("Failed to send indicator update", exc_info=True)

    async def _clear_indicator(self) -> None:
        if self._indicator_cleared:
            return
        self._current_indicator = None
        self._indicator_cleared = True
        payload = {
            "type": "ai_indicator.clear",
            "cid": self._cid,
            "message_id": self._message_id,
        }
        try:
            await run_sync(self._channel.send_event, payload)
        except Exception:
            logging.debug("Failed to clear indicator", exc_info=True)

    def _should_generate_image_request(self) -> bool:
        if self._has_user_image_input():
            return False
        for text in self._user_input_texts():
            normalized = text.lower()
            has_image_keyword = any(
                term in normalized
                for term in [
                    "image",
                    "picture",
                    "art",
                    "artwork",
                    "illustration",
                    "logo",
                    "icon",
                    "graphic",
                    "photo",
                    "photograph",
                    "painting",
                ]
            )
            has_action_keyword = any(
                term in normalized
                for term in [
                    "generate",
                    "create",
                    "draw",
                    "design",
                    "make",
                    "produce",
                    "render",
                    "sketch",
                    "imagine",
                ]
            )
            has_command_prefix = normalized.strip().startswith(("!image", "image:"))
            if (has_image_keyword and has_action_keyword) or has_command_prefix:
                return True
        return False

    def _user_input_texts(self) -> List[str]:
        results: List[str] = []
        for item in self._input:
            if isinstance(item, dict) and item.get("role") == "user":
                for content in item.get("content", []):
                    if isinstance(content, dict) and content.get("type") == "input_text":
                        results.append(content.get("text", ""))
        return results

    def _has_user_image_input(self) -> bool:
        for item in self._input:
            if isinstance(item, dict) and item.get("role") == "user":
                for content in item.get("content", []):
                    if isinstance(content, dict) and content.get("type") == "input_image":
                        return True
        return False

    def _build_image_prompt(self) -> str:
        texts = self._user_input_texts()
        if not texts:
            return ""
        latest = texts[-1]
        lowered = latest.lower().strip()
        if lowered.startswith("!image"):
            return latest[len("!image") :].strip()
        if lowered.startswith("image:"):
            return latest[len("image:") :].strip()
        return latest
