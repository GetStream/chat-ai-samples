export const normalizeChannelId = (rawChannelId: string): string => {
  const trimmed = rawChannelId.trim();
  if (trimmed.includes(':')) {
    const parts = trimmed.split(':');
    if (parts.length > 1 && parts[1]) {
      return parts[1];
    }
  }
  return trimmed;
};

export const buildAgentUserId = (channelId: string): string =>
  `ai-bot-${channelId.replace(/!/g, '')}`;
