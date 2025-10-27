from __future__ import annotations

from ..server_client import STREAM_API_KEY, run_sync, server_channel, server_client
from .anthropic.agent import AnthropicAgent
from .openai.agent import OpenAIAgent
from .types import AIAgent, AgentPlatform

async def create_agent(
    user_id: str,
    platform: AgentPlatform,
    channel_type: str,
    channel_id: str,
) -> AIAgent:
    token = server_client.create_token(user_id)
    channel = server_channel(channel_type, channel_id)
    await _watch_channel(channel)

    if platform == AgentPlatform.OPENAI:
        return OpenAIAgent(
            user_id=user_id,
            user_token=token,
            channel=channel,
            api_key=STREAM_API_KEY,
            server_client=server_client,
        )

    return AnthropicAgent(
        user_id=user_id,
        user_token=token,
        channel=channel,
        api_key=STREAM_API_KEY,
        server_client=server_client,
    )


async def _watch_channel(channel) -> None:
    watch_callable = getattr(channel, "watch", None)
    if callable(watch_callable):
        try:
            await run_sync(watch_callable)
            return
        except TypeError:
            await run_sync(watch_callable, {})
            return
    await run_sync(channel.query, watch=True, state=True)
