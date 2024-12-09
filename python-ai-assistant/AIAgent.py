from abc import abstractmethod
from enum import Enum
from stream_chat import StreamChat, Channel
from typing import Protocol


class AIAgent(Protocol):
    """Protocol defining the interface for AI Agents."""

    chatClient: StreamChat
    channel: Channel

    @abstractmethod
    async def init(self) -> None:
        """Initialize the agent."""
        pass

    @abstractmethod
    async def dispose(self) -> None:
        """Clean up the agent resources."""
        pass

    @abstractmethod
    def get_last_interaction(self) -> float:
        """Get the timestamp of the last interaction."""
        pass

    @abstractmethod
    def handle_message(self, event) -> None:
        """Handle a new message."""
        pass


class AgentPlatform(str, Enum):
    """Enum defining supported AI platforms."""

    ANTHROPIC = "anthropic"
    OPENAI = "openai"
