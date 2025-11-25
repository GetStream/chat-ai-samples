import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import {
  Agent,
  AgentManager,
  AgentPlatform,
  ClientToolDefinition,
  createDefaultTools,
} from '@stream-io/chat-ai-sdk';
import { apiKey } from './serverClient';

const app = express();
app.use(express.json());
app.use(cors({ origin: '*' }));

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

const agentManager = new AgentManager({
  serverToolsFactory: () => createDefaultTools(),
  agentIdResolver: buildAgentUserId,
});

const isPlainObject = (value: unknown): value is Record<string, unknown> =>
  Boolean(value) && typeof value === 'object' && !Array.isArray(value);

app.get('/', (req, res) => {
  res.json({
    message: 'GetStream AI Server is running',
    apiKey,
    activeAgents: agentManager.activeAgentCount,
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
  try {
    console.log(`Starting AI agent for channel ${channelIdNormalized}:`);
    console.log(`  - User ID: ${user_id}`);
    console.log(`  - Channel Type: ${channelTypeValue}`);
    console.log(`  - Platform: ${resolvedPlatform}`);
    console.log(`  - Model: ${modelId || 'default'}`);
    
    await agentManager.startAgent({
      userId: user_id,
      channelId: channelIdNormalized,
      channelType: channelTypeValue,
      platform: resolvedPlatform,
      model: modelId,
    });
    
    console.log(`AI Agent ${user_id} started successfully`);
    console.log(`Active agents: ${agentManager.activeAgentCount}`);
    res.json({ message: 'AI Agent started', data: [] });
  } catch (error) {
    const errorMessage = (error as Error).message;
    console.error('Failed to start AI Agent', errorMessage);
    res
      .status(500)
      .json({ error: 'Failed to start AI Agent', reason: errorMessage });
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
    await agentManager.stopAgent(userId);
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

  agentManager.registerClientTools(channelIdNormalized, sanitizedTools);

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
