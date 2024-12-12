from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from stream_chat import StreamChatAsync
from dotenv import load_dotenv
from model import StartAgentRequest, StopAgentRequest, NewMessageRequest
from helpers import clean_channel_id, create_bot_id

from AnthropicAgent import AnthropicAgent
import os

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
    return {"message": "GetStream AI Server is running"}


@app.post("/start-ai-agent")
async def start_ai_agent(request: StartAgentRequest):
    print(request)
    # Validation that if no channel_id is provided, return an error
    if not request.channel_id:
        return {"error": "Missing required fields", "code": 400}

    server_client = StreamChatAsync(api_key, api_secret)

    client_object_methods = [
        method_name
        for method_name in dir(server_client)
        if callable(getattr(server_client, method_name))
    ]

    # print("Client methods: ", "\n".join(client_object_methods))

    # Clean up channel id to remove the channel type - if necessary
    channel_id_updated = clean_channel_id(request.channel_id)

    user_id = create_bot_id(channel_id=channel_id_updated)
    await server_client.upsert_user(
        {
            "id": user_id,
            "name": "AI Bot",
            "role": "admin",
        }
    )
    channel = server_client.channel(request.channel_type, channel_id_updated)
    try:
        await channel.add_members([user_id])
    except Exception as error:
        print("Failed to add members to channel", error)

    # channel_object_methods = [
    #     method_name
    #     for method_name in dir(channel)
    #     if callable(getattr(channel, method_name))
    # ]

    # print("Channel methods: ", "\n".join(channel_object_methods))

    # await channel.watch()

    agent = AnthropicAgent(server_client, channel)
    await agent.init()

    if user_id in agents:
        await agents[user_id].dispose()
    else:
        agents[user_id] = agent

    return {"message": "AI agent started"}


@app.post("/stop-ai-agent")
async def stop_ai_agent(request: StopAgentRequest):
    print(request)
    server_client = StreamChatAsync(api_key, api_secret)

    ai_id = f"ai-bot-{request.channel_id.replace('!', '')}"

    if ai_id in agents:
        await agents[ai_id].dispose()
        del agents[ai_id]

    channel = server_client.channel("messaging", request.channel_id)
    await channel.remove_members([ai_id])
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
