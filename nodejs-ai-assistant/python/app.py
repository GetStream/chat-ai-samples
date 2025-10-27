from __future__ import annotations

import asyncio
import logging
import time
from typing import Dict, Optional, Set

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from .agents import AIAgent, AgentPlatform, create_agent
from .server_client import STREAM_API_KEY, run_sync, server_client

load_dotenv()

logger = logging.getLogger(__name__)

app = FastAPI(title="GetStream AI Server (Python)")


class StartAgentRequest(BaseModel):
    channel_id: str
    channel_type: str = "messaging"
    platform: AgentPlatform = AgentPlatform.ANTHROPIC


class StopAgentRequest(BaseModel):
    channel_id: str


ai_agent_cache: Dict[str, AIAgent] = {}
pending_agents: Set[str] = set()
agent_lock = asyncio.Lock()

INACTIVITY_THRESHOLD_SECONDS = 480 * 60
cleanup_stop_event = asyncio.Event()
cleanup_task: Optional[asyncio.Task] = None


@app.on_event("startup")
async def startup_event() -> None:
    global cleanup_task
    cleanup_stop_event.clear()
    cleanup_task = asyncio.create_task(_cleanup_loop())


@app.on_event("shutdown")
async def shutdown_event() -> None:
    cleanup_stop_event.set()
    if cleanup_task:
        cleanup_task.cancel()
        try:
            await cleanup_task
        except asyncio.CancelledError:
            pass


@app.get("/")
async def root() -> dict:
    return {
        "message": "GetStream AI Server is running (Python)",
        "apiKey": STREAM_API_KEY,
        "activeAgents": len(ai_agent_cache),
    }


@app.post("/start-ai-agent")
async def start_ai_agent(request: StartAgentRequest) -> dict:
    channel_id = request.channel_id
    if ":" in channel_id:
        parts = channel_id.split(":")
        if len(parts) > 1:
            channel_id = parts[1]
    channel_type = request.channel_type or "messaging"
    platform = request.platform

    user_id = f"ai-bot-{channel_id.replace('!', '')}"

    async with agent_lock:
        if user_id in ai_agent_cache or user_id in pending_agents:
            return {"message": "AI Agent already active", "data": []}
        pending_agents.add(user_id)

    try:
        await run_sync(
            server_client.upsert_user,
            {"id": user_id, "name": "AI Bot", "role": "admin"},
        )
        channel = server_client.channel(channel_type, channel_id)
        try:
            await run_sync(channel.add_members, [user_id])
        except Exception:  # noqa: BLE001
            logger.debug("Failed to add AI agent to channel", exc_info=True)

        agent = await create_agent(
            user_id=user_id,
            platform=platform,
            channel_type=channel_type,
            channel_id=channel_id,
        )

        await agent.init()

        async with agent_lock:
            existing = ai_agent_cache.get(user_id)
            if existing:
                await existing.dispose()
            ai_agent_cache[user_id] = agent

        return {"message": "AI Agent started", "data": []}
    except Exception as exc:  # noqa: BLE001
        logger.exception("Failed to start AI Agent")
        raise HTTPException(
            status_code=500,
            detail={"error": "Failed to start AI Agent", "reason": str(exc)},
        ) from exc
    finally:
        async with agent_lock:
            pending_agents.discard(user_id)


@app.post("/stop-ai-agent")
async def stop_ai_agent(request: StopAgentRequest) -> dict:
    channel_id = request.channel_id.replace("!", "")
    user_id = f"ai-bot-{channel_id}"
    agent: Optional[AIAgent] = None
    async with agent_lock:
        agent = ai_agent_cache.pop(user_id, None)
    if agent:
        await dispose_agent(agent, user_id)
    return {"message": "AI Agent stopped", "data": []}


async def dispose_agent(agent: AIAgent, user_id: str) -> None:
    await agent.dispose()
    try:
        await run_sync(agent.channel.remove_members, [user_id])
    except Exception:
        logger.debug("Failed to remove AI agent from channel", exc_info=True)


async def _cleanup_loop() -> None:
    while not cleanup_stop_event.is_set():
        await asyncio.sleep(5)
        now = time.time()
        stale: Dict[str, AIAgent] = {}
        async with agent_lock:
            for user_id, agent in list(ai_agent_cache.items()):
                if now - agent.get_last_interaction() > INACTIVITY_THRESHOLD_SECONDS:
                    stale[user_id] = ai_agent_cache.pop(user_id, None)
        for user_id, agent in stale.items():
            if agent:
                logger.info("Disposing AI Agent due to inactivity: %s", user_id)
                await dispose_agent(agent, user_id)
