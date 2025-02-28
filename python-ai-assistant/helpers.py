"""Helper functions"""

from typing import Any, List


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


async def get_last_messages_from_channel(
    chat_client: Any, channel_id: str, limit: int = 5
) -> List[Any]:
    """Get the last messages from the channel"""
    channel_filters = {"cid": channel_id}
    message_filters = {"type": {"$eq": "regular"}}
    sort = {"updated_at": -1}
    message_search = await chat_client.search(
        channel_filters, message_filters, sort, limit=limit
    )

    messages = [
        {
            "content": message["message"]["text"].strip(),
            "role": (
                "assistant"
                if message["message"]["user"]["id"].startswith("ai-bot")
                else "user"
            ),
        }
        for message in message_search["results"]
        if message["message"]["text"] != ""
    ]
    return messages
