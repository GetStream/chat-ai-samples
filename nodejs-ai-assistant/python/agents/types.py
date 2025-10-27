from __future__ import annotations
from enum import Enum
from typing import Protocol

from stream_chat.channel import Channel


class AIAgent(Protocol):
    user_id: str
    channel: Channel

    async def init(self) -> None:
        ...

    async def dispose(self) -> None:
        ...

    def get_last_interaction(self) -> float:
        ...


class AgentPlatform(str, Enum):
    ANTHROPIC = "anthropic"
    OPENAI = "openai"
