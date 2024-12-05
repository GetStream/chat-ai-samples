import { useMessageContext, useMessageTextStreaming } from 'stream-chat-react';

export default function MyMessage() {
  const { message } = useMessageContext();
  const { streamedMessageText } = useMessageTextStreaming({
    renderingLetterCount: 10,
    streamingLetterIntervalMs: 50,
    text: message.text ?? '',
  });
  return <p className='my-message'>{streamedMessageText}</p>;
}
