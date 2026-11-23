"""Helper functions"""

from typing import Any, Dict, List

from getstream import AsyncStream
from getstream.chat.async_channel import Channel
from getstream.models import EventRequest, SearchPayload, SortParamRequest


def clean_channel_id(channel_id: str) -> str:
    """Clean the channel id"""
    channel_id_updated = channel_id
    if ":" in channel_id:
        parts = channel_id.split(":")
        if len(parts) > 1:
            channel_id_updated = parts[1]
    return channel_id_updated


def create_bot_id(channel_id: str) -> str:
    """Create a bot id"""
    return f"ai-bot-{channel_id.replace('!', '')}"


def is_ai_generated(message: Dict[str, Any]) -> bool:
    """Check whether a webhook message was sent by the AI bot"""
    custom = message.get("custom") or {}
    return bool(message.get("ai_generated") or custom.get("ai_generated"))


async def update_ai_state(
    channel: Channel, bot_id: str, message_id: str, ai_state: str
) -> None:
    """Send an `ai_indicator.update` event; the API reads its fields from `custom`"""
    await channel.send_event(
        EventRequest(
            type="ai_indicator.update",
            user_id=bot_id,
            custom={"ai_state": ai_state, "message_id": message_id},
        )
    )


async def clear_ai_indicator(channel: Channel, bot_id: str) -> None:
    """Send an `ai_indicator.clear` event"""
    await channel.send_event(EventRequest(type="ai_indicator.clear", user_id=bot_id))


async def get_last_messages_from_channel(
    chat_client: AsyncStream, channel_id: str, limit: int = 5
) -> List[Dict[str, str]]:
    """Get the last messages from the channel"""
    message_search = await chat_client.chat.search(
        payload=SearchPayload(
            filter_conditions={"cid": channel_id},
            message_filter_conditions={"type": {"$eq": "regular"}},
            sort=[SortParamRequest(field="updated_at", direction=-1)],
            limit=limit,
        )
    )

    messages = [
        {
            "content": result.message.text.strip(),
            "role": (
                "assistant"
                if result.message.user and result.message.user.id.startswith("ai-bot")
                else "user"
            ),
        }
        for result in message_search.data.results
        if result.message and result.message.text != ""
    ]
    return messages
