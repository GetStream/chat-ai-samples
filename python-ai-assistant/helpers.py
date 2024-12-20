def clean_channel_id(channel_id: str) -> str:
    channel_id_updated = channel_id
    if ":" in channel_id:
        parts = channel_id.split(":")
        if len(parts) > 1:
            channel_id_updated = parts[1]
    return channel_id_updated


def create_bot_id(channel_id: str) -> str:
    return f"ai-bot-{channel_id.replace('!', '')}"
