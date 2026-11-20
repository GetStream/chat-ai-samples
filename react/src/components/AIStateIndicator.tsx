import { AIStates, type MessagePaginatorAggregateState } from "stream-chat";
import { useAIState, useChannel, useStateStore } from "stream-chat-react";
import { AIStateIndicator as StateIndicator } from "stream-chat-react/ai-components";

const latestMessageIdSelector = ({
	latestMessage,
}: MessagePaginatorAggregateState) => ({
	latestMessageId: latestMessage?.id,
});

export const AIStateIndicator = () => {
	const channel = useChannel();
	const { aiState } = useAIState(channel);
	const { latestMessageId } = useStateStore(
		channel.messagePaginator.aggregateState,
		latestMessageIdSelector,
	);

	if (aiState !== AIStates.Generating && aiState !== AIStates.Thinking) return null;

	// a new message restarts the indicator's animation
	return <StateIndicator key={latestMessageId} />;
};
