from pydantic import BaseModel


class StartAgentRequest(BaseModel):
    channel_id: str
    channel_type: str = "messaging"
    platform: str = "anthropic"


class StopAgentRequest(BaseModel):
    channel_id: str


class NewMessageRequest(BaseModel):
    cid: str
    type: str
    message: object
