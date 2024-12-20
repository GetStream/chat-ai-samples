from pydantic import BaseModel
from typing import Optional


class StartAgentRequest(BaseModel):
    channel_id: str
    channel_type: str = "messaging"
    platform: str = "anthropic"


class StopAgentRequest(BaseModel):
    channel_id: str


class NewMessageRequest(BaseModel):
    cid: Optional[str]
    type: Optional[str]
    message: Optional[object]
