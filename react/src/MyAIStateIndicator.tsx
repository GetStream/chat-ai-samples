import { AIState } from 'stream-chat';
import { useAIState, useChannelStateContext } from 'stream-chat-react';

export default function MyAIStateIndicator() {
  const { channel } = useChannelStateContext();
  const { aiState } = useAIState(channel);
  const text = textForState(aiState);
  return text && <p className='my-ai-state-indicator'>{text}</p>;

  function textForState(aiState: AIState): string {
    switch (aiState) {
      case 'AI_STATE_ERROR':
        return 'Something went wrong...';
      case 'AI_STATE_CHECKING_SOURCES':
        return 'Checking external resources...';
      case 'AI_STATE_THINKING':
        return "I'm currently thinking...";
      case 'AI_STATE_GENERATING':
        return 'Generating an answer for you...';
      default:
        return '';
    }
  }
}
