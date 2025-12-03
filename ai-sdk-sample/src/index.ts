import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import {
  Agent,
  AgentManager,
  AgentPlatform,
  type ClientToolDefinition,
  createDefaultTools,
} from '@stream-io/chat-ai-sdk';
import { buildAgentUserId, normalizeChannelId } from './utils.ts';
import type {
  RegisterToolsRequest,
  StartAIAgentRequest,
  StopAIAgentRequest,
  SummarizeRequest,
} from './types';

const apiKey = process.env.STREAM_API_KEY as string | undefined;
const apiSecret = process.env.STREAM_API_SECRET as string | undefined;
if (!apiKey || !apiSecret) {
  throw new Error(
      'Missing required environment variables STREAM_API_KEY or STREAM_API_SECRET',
  );
}

const app = express();
app.use(express.json());
app.use(cors({ origin: '*' }));

const agentManager = new AgentManager({
  serverToolsFactory: () => createDefaultTools(),
  agentIdResolver: buildAgentUserId,
});

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
  } = req.body as StartAIAgentRequest;

  console.log('Received request to start AI Agent', req.body)

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

  const modelId = model.trim().length > 0 ? model.trim() : undefined;
  const user_id = buildAgentUserId(channelIdNormalized);
  const channelTypeValue = channel_type.trim().length
      ? channel_type.trim()
      : 'messaging';
  try {
    await agentManager.startAgent({
      userId: user_id,
      channelId: channelIdNormalized,
      channelType: channelTypeValue,
      platform: resolvedPlatform,
      model: modelId,
    });
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
  const { channel_id } = (req.body ?? {}) as StopAIAgentRequest;
  const channelIdNormalized = normalizeChannelId(channel_id);
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
  const { channel_id, tools } = (req.body ?? {}) as RegisterToolsRequest;

  if (channel_id?.trim().length === 0) {
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
    const rawName = tool.name.trim();
    const rawDescription = tool.description.trim();

    if (!rawName || !rawDescription) {
      invalidTools.push(
          tool.name ? tool.name : `tool_${index.toString().padStart(2, '0')}`,
      );
      return;
    }

    const instructions = tool.instructions?.trim();
    const parameters = tool.parameters;

    let showExternalSourcesIndicator: boolean | undefined;
    if (typeof tool.showExternalSourcesIndicator === 'boolean') {
      showExternalSourcesIndicator = tool.showExternalSourcesIndicator;
      // @ts-expect-error: show_external_sources_indicator is deprecated, but still supported for backwards compatibility
    } else if (typeof tool.show_external_sources_indicator === 'boolean') {
      // @ts-expect-error: show_external_sources_indicator is deprecated, but still supported for backwards compatibility
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
  const {
    text,
    platform = AgentPlatform.ANTHROPIC,
    model,
  } = (req.body ?? {}) as SummarizeRequest;

  if (text.trim().length === 0) {
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

  const modelId = model?.trim();
  try {
    const summary = await Agent.generateSummary(
        text,
        resolvedPlatform,
        modelId,
    );
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
