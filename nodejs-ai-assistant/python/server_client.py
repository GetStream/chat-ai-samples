import asyncio
import os
from typing import Callable, TypeVar

from dotenv import load_dotenv
from stream_chat import StreamChat
from stream_chat.channel import Channel

T = TypeVar("T")

load_dotenv()

STREAM_API_KEY = os.getenv("STREAM_API_KEY")
STREAM_API_SECRET = os.getenv("STREAM_API_SECRET")

if not STREAM_API_KEY or not STREAM_API_SECRET:
    raise RuntimeError(
        "Missing required environment variables STREAM_API_KEY or STREAM_API_SECRET"
    )

server_client = StreamChat(api_key=STREAM_API_KEY, api_secret=STREAM_API_SECRET)


async def run_sync(func: Callable[..., T], *args, **kwargs) -> T:
    """Helper to execute blocking SDK calls without blocking the event loop."""
    return await asyncio.to_thread(func, *args, **kwargs)


def server_channel(channel_type: str, channel_id: str) -> Channel:
    """Shortcut to get a Channel instance from the server client."""
    return server_client.channel(channel_type, channel_id)
