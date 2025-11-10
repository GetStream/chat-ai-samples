import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { AgentPlatform } from './agents/types';
import { Agent } from './agents/Agent';
import { createDefaultTools } from './agents/defaultTools';
import { ClientToolDefinition } from './agents/VercelAIAgent';
import { apiKey } from './serverClient';

const app = express();
app.use(express.json());
app.use(cors({ origin: '*' }));

// Map to store the AI Agent instances
// [cid: string]: AI Agent
const aiAgentCache = new Map<string, Agent>();
const pendingAiAgents = new Set<string>();
const clientToolRegistry = new Map<string, ClientToolDefinition[]>();

const normalizeChannelId = (rawChannelId: string): string => {
  const trimmed = typeof rawChannelId === 'string' ? rawChannelId.trim() : '';
  if (trimmed.includes(':')) {
    const parts = trimmed.split(':');
    if (parts.length > 1 && parts[1]) {
      return parts[1];
    }
  }
  return trimmed;
};

const buildAgentUserId = (channelId: string): string =>
  `ai-bot-${channelId.replace(/!/g, '')}`;

const isPlainObject = (value: unknown): value is Record<string, unknown> =>
  Boolean(value) && typeof value === 'object' && !Array.isArray(value);

// TODO: temporary set to 8 hours, should be cleaned up at some point
const inactivityThreshold = 480 * 60 * 1000;
setInterval(async () => {
  const now = Date.now();
  for (const [userId, agent] of aiAgentCache) {
    if (now - agent.getLastInteraction() > inactivityThreshold) {
      console.log(`Disposing AI Agent due to inactivity: ${userId}`);
      await agent.stop().catch((error) => {
        console.error(`Failed to stop agent ${userId}`, error);
      });
      aiAgentCache.delete(userId);
    }
  }
}, 5000);

app.get('/', (req, res) => {
  res.json({
    message: 'GetStream AI Server is running',
    apiKey: apiKey,
    activeAgents: aiAgentCache.size,
  });
});

/**
 * Handle the request to start the AI Agent
 */
app.post('/start-ai-agent', async (req, res) => {
  const {
    channel_id,
    channel_type = 'messaging',
    platform = AgentPlatform.ANTHROPIC,
    model,
  } = req.body;

  // Simple validation
  if (!channel_id) {
    res.status(400).json({ error: 'Missing required fields' });
    return;
  }

  const channelIdNormalized = normalizeChannelId(channel_id);
  if (!channelIdNormalized) {
    res.status(400).json({ error: 'Invalid channel_id' });
    return;
  }

  const platformValue =
    typeof platform === 'string'
      ? (platform.toLowerCase() as AgentPlatform)
      : platform;
  const resolvedPlatform = Object.values(AgentPlatform).find(
    (value) => value === platformValue,
  );
  if (!resolvedPlatform) {
    res.status(400).json({ error: 'Unsupported platform' });
    return;
  }
  const modelId =
    typeof model === 'string' && model.trim().length > 0
      ? model.trim()
      : undefined;

  const user_id = buildAgentUserId(channelIdNormalized);
  const channelTypeValue =
    typeof channel_type === 'string' && channel_type.trim().length
      ? channel_type
      : 'messaging';
  let agent = aiAgentCache.get(user_id);
  if (!agent) {
    agent = new Agent({
      userId: user_id,
      channelId: channelIdNormalized,
      channelType: channelTypeValue,
      platform: resolvedPlatform,
      model: modelId,
      serverTools: createDefaultTools(),
    });
    aiAgentCache.set(user_id, agent);
  }
  try {
    if (!pendingAiAgents.has(user_id)) {
      pendingAiAgents.add(user_id);

      await agent.start();
      const registeredClientTools =
        clientToolRegistry.get(channelIdNormalized) ?? [];
      if (registeredClientTools.length) {
        agent.registerClientTools(registeredClientTools, { replace: true });
      }
    } else {
      console.log(`AI Agent ${user_id} already starting`);
    }

    res.json({ message: 'AI Agent started', data: [] });
  } catch (error) {
    const errorMessage = (error as Error).message;
    console.error('Failed to start AI Agent', errorMessage);
    res
      .status(500)
      .json({ error: 'Failed to start AI Agent', reason: errorMessage });
  } finally {
    pendingAiAgents.delete(user_id);
  }
});

/**
 * Handle the request to stop the AI Agent
 */
app.post('/stop-ai-agent', async (req, res) => {
  const { channel_id } = req.body ?? {};
  const channelIdNormalized = typeof channel_id === 'string'
    ? normalizeChannelId(channel_id)
    : '';
  if (!channelIdNormalized) {
    res.status(400).json({ error: 'Invalid channel_id' });
    return;
  }
  try {
    const userId = buildAgentUserId(channelIdNormalized);
    const agent = aiAgentCache.get(userId);
    if (agent) {
      await agent.stop();
      aiAgentCache.delete(userId);
    }
    res.json({ message: 'AI Agent stopped', data: [] });
  } catch (error) {
    const errorMessage = (error as Error).message;
    console.error('Failed to stop AI Agent', errorMessage);
    res
      .status(500)
      .json({ error: 'Failed to stop AI Agent', reason: errorMessage });
  }
});

app.post('/register-tools', (req, res) => {
  const { channel_id, tools } = req.body ?? {};

  if (typeof channel_id !== 'string' || channel_id.trim().length === 0) {
    res.status(400).json({ error: 'Missing or invalid channel_id' });
    return;
  }

  if (!Array.isArray(tools)) {
    res.status(400).json({ error: 'Missing or invalid tools array' });
    return;
  }

  const channelIdNormalized = normalizeChannelId(channel_id);
  if (!channelIdNormalized) {
    res.status(400).json({ error: 'Invalid channel_id' });
    return;
  }

  const sanitizedTools: ClientToolDefinition[] = [];
  const invalidTools: string[] = [];

  tools.forEach((rawTool, index) => {
    const tool = rawTool ?? {};
    const rawName = typeof tool.name === 'string' ? tool.name.trim() : '';
    const rawDescription =
      typeof tool.description === 'string' ? tool.description.trim() : '';

    if (!rawName || !rawDescription) {
      invalidTools.push(
        typeof tool.name === 'string'
          ? tool.name
          : `tool_${index.toString().padStart(2, '0')}`,
      );
      return;
    }

    const instructions =
      typeof tool.instructions === 'string' && tool.instructions.trim().length > 0
        ? tool.instructions.trim()
        : undefined;

    const parameters = isPlainObject(tool.parameters)
      ? (JSON.parse(JSON.stringify(tool.parameters)) as ClientToolDefinition['parameters'])
      : undefined;

    let showExternalSourcesIndicator: boolean | undefined;
    if (typeof tool.showExternalSourcesIndicator === 'boolean') {
      showExternalSourcesIndicator = tool.showExternalSourcesIndicator;
    } else if (typeof tool.show_external_sources_indicator === 'boolean') {
      showExternalSourcesIndicator = tool.show_external_sources_indicator;
    }

    sanitizedTools.push({
      name: rawName,
      description: rawDescription,
      instructions,
      parameters,
      showExternalSourcesIndicator,
    });
  });

  if (!sanitizedTools.length && tools.length > 0) {
    res.status(400).json({
      error: 'No valid tools provided',
      invalid_tools: invalidTools,
    });
    return;
  }

  clientToolRegistry.set(channelIdNormalized, sanitizedTools);

  const userId = buildAgentUserId(channelIdNormalized);
  const agent = aiAgentCache.get(userId);
  agent?.registerClientTools(sanitizedTools, { replace: true });

  const responsePayload: Record<string, unknown> = {
    message: 'Client tools registered',
    channel_id: channelIdNormalized,
    count: sanitizedTools.length,
  };
  if (invalidTools.length) {
    responsePayload.invalid_tools = invalidTools;
  }

  res.json(responsePayload);
});

app.post('/summarize', async (req, res) => {
  const { text, platform = AgentPlatform.ANTHROPIC, model } = req.body ?? {};

  if (typeof text !== 'string' || text.trim().length === 0) {
    res.status(400).json({ error: 'Missing or invalid text to summarize' });
    return;
  }

  const platformValue =
    typeof platform === 'string'
      ? (platform.toLowerCase() as AgentPlatform)
      : platform;

  const resolvedPlatform = Object.values(AgentPlatform).find(
    (value) => value === platformValue,
  );
  if (!resolvedPlatform) {
    res.status(400).json({ error: 'Unsupported platform' });
    return;
  }

  const modelId =
    typeof model === 'string' && model.trim().length > 0 ? model.trim() : undefined;

  try {
    const summary = await Agent.generateSummary(text, resolvedPlatform, modelId);
    res.json({ summary });
  } catch (error) {
    const message = (error as Error).message;
    console.error('Failed to summarize text', message);
    res
      .status(500)
      .json({ error: 'Failed to summarize text', reason: message });
  }
});

// Start the Express server
const port = process.env.PORT || 3000;
app.listen(port, () => {
  console.log(`Server is running on http://localhost:${port}`);
});
