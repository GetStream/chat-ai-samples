from fastapi import FastAPI, HTTPException, Response
from fastapi.middleware.cors import CORSMiddleware
from stream_chat import StreamChatAsync, StreamChat
from dotenv import load_dotenv
from model import StartAgentRequest, StopAgentRequest, NewMessageRequest
from helpers import clean_channel_id, create_bot_id

from AnthropicAgent import AnthropicAgent
import os
import json

load_dotenv()

api_key = os.getenv("STREAM_API_KEY")
api_secret = os.getenv("STREAM_API_SECRET")


app = FastAPI()

# Add CORS
origins = [
    "*",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


agents = {}


@app.get("/")
async def root():
    return {
        "message": "GetStream AI Server is running",
        "apiKey": api_key,
        "activeAgents": len(agents),
    }


@app.post("/start-ai-agent")
async def start_ai_agent(request: StartAgentRequest, response: Response):
    server_client = StreamChatAsync(api_key, api_secret)

    # Clean up channel id to remove the channel type - if necessary
    channel_id_updated = clean_channel_id(request.channel_id)

    # Create a bot id
    bot_id = create_bot_id(channel_id=channel_id_updated)

    # Upsert the bot user
    await server_client.upsert_user(
        {
            "id": bot_id,
            "name": "AI Bot",
            "role": "admin",
        }
    )

    # Create a channel
    channel = server_client.channel(request.channel_type, channel_id_updated)

    # Add the bot to the channel
    try:
        await channel.add_members([bot_id])
    except Exception as error:
        print("Failed to add members to the channel: ", error)
        response.status_code = 405
        response.body = str.encode(
            json.dumps({"error": "Not possible to add the AI to distinct channels"})
        )
        return response

    # Create an agent
    agent = AnthropicAgent(server_client, channel)
    await agent.init()

    if bot_id in agents:
        await agents[bot_id].dispose()
    else:
        agents[bot_id] = agent

    return {"message": "AI agent started"}


@app.post("/stop-ai-agent")
async def stop_ai_agent(request: StopAgentRequest):
    server_client = StreamChatAsync(api_key, api_secret)

    bot_id = create_bot_id(request.channel_id)

    if bot_id in agents:
        await agents[bot_id].dispose()
        del agents[bot_id]

    channel = server_client.channel("messaging", request.channel_id)
    await channel.remove_members([bot_id])
    return {"message": "AI agent stopped"}


@app.post("/new-message")
async def send_message(request: NewMessageRequest):
    # print(request)
    if not request.cid:
        return {"error": "Missing required fields", "code": 400}

    channel_id = clean_channel_id(request.cid)
    user_id = create_bot_id(channel_id=channel_id)

    if user_id in agents:
        await agents[user_id].handle_message(request)
    else:
        print("AI agent not found for user", user_id)


@app.get("/get-ai-agents")
async def get_ai_agents():
    return {"agents": list(agents.keys())}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8001)
