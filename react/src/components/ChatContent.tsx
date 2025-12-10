import {
	Channel,
	MessageList,
	ChannelList,
	Window,
	MessageInput,
	useChatContext,
	type ChannelListProps,
} from "stream-chat-react";
import { Composer } from "./Composer";
import { MessageBubble } from "./MessageBubble";
import { AIStateIndicator } from "./AIStateIndicator";
import { useEffect } from "react";
import { nanoid } from "nanoid";
import { ChannelListItem } from "./ChannelListItem";

export const ChatContent = ({
	filters,
	options,
	sort,
}: Pick<ChannelListProps, "options" | "sort" | "filters">) => {
	const { setActiveChannel, client, channel } = useChatContext();

	useEffect(() => {
		if (!channel) {
			setActiveChannel(
				client.channel("messaging", `ai-${nanoid()}`, {
					members: [client.userID as string],
					// @ts-expect-error fix - this is a hack that allows a custom upload function to run
					own_capabilities: ["upload-file"],
				})
			);
		}
	}, [channel]);

	return (
		<>
			<ChannelList
				Preview={ChannelListItem}
				setActiveChannelOnMount={false}
				filters={filters}
				sort={sort}
				options={options}
			/>
			<Channel initializeOnMount={false} Message={MessageBubble}>
				<Window>
					<MessageList />
					<AIStateIndicator />
					<MessageInput Input={Composer} />
				</Window>
			</Channel>
		</>
	);
};
