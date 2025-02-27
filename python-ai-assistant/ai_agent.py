"""The protocol for AI agents"""

from abc import abstractmethod
from enum import Enum
from typing import Protocol
from stream_chat import StreamChat, Channel


class AIAgent(Protocol):
    """Protocol defining the interface for AI Agents."""

    chatClient: StreamChat
    channel: Channel

    @abstractmethod
    async def dispose(self) -> None:
        """Clean up the agent resources."""

    @abstractmethod
    def handle_message(self, event) -> None:
        """Handle a new message."""


class AgentPlatform(str, Enum):
    """Enum defining supported AI platforms."""

    ANTHROPIC = "anthropic"
    OPENAI = "openai"
