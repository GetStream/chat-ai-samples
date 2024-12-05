from fastapi import FastAPI
from pydantic import BaseModel
from stream_chat import StreamChat
from dotenv import load_dotenv
import os
load_dotenv()

api_key = os.getenv("STREAM_API_KEY")
api_secret = os.getenv("STREAM_API_SECRET")

server_client = StreamChat(api_key, api_secret)

class StartAgentRequest(BaseModel):
    channel_id: str
    channel_type: str = "messaging"
    platform: str = "anthropic"

class StopAgentRequest(BaseModel):
    channel_id: str

app = FastAPI()


@app.get("/")
async def root():
    return {"message": "Hello World"}

@app.post("/start-ai-agent")
async def start_ai_agent(request: StartAgentRequest):
    print(request)
    channel_id_updated = request.channel_id
    if ':' in request.channel_id:
        parts = request.channel_id.split(':')
        if len(parts) > 1:
            channel_id_updated = parts[1]

    user_id = f"ai-bot-{channel_id_updated.replace('!', '')}"
    await server_client.upsertUser({
        "id": user_id,
        "name": "AI Bot",
        "role": "admin",
      });
    channel = server_client.channel(request.channel_type, channel_id_updated)
    await channel.addMembers([user_id])
    await channel.watch()
    return {"message": "AI agent started"}

@app.post("/stop-ai-agent")
async def stop_ai_agent(request: StopAgentRequest):
    print(request)
    user_id = f"ai-bot-{request.channel_id.replace('!', '')}"
    channel = server_client.channel('messaging', request.channel_id)
    await channel.removeMembers([user_id])
    return {"message": "AI agent stopped"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
