import { useEffect, useMemo, useState } from "react";
import {
	ChannelPaginator,
	type Channel as StreamChannel,
	type ChannelFilters,
	type SortParamRequest,
} from "stream-chat";
import {
	Channel,
	MessageList,
	ChannelList,
	MessageComposer,
	defaultWorkspaceNavigation,
	useChatContext,
	WithComponents,
	WorkspaceNavigationProvider,
	type WorkspaceNavigation,
} from "stream-chat-react";
import { MessageBubble } from "./MessageBubble";
import { nanoid } from "nanoid";
import { Composer } from "./Composer";
import { ChannelListItem } from "./ChannelListItem";
import { AIStateIndicator } from "./AIStateIndicator";

export type ChatContentProps = {
	filters: ChannelFilters;
	sort: SortParamRequest[];
	pageSize: number;
};

export const ChatContent = ({ filters, sort, pageSize }: ChatContentProps) => {
	const { client } = useChatContext();
	// start with an empty new chat; the composer creates it on the first message
	const [channel, setChannel] = useState<StreamChannel>(() => {
		const newChannel = client.channel("messaging", `ai-${nanoid()}`, {
			members: [{ user_id: client.userId as string }],
		});
		// lets the composer upload files before the channel is created
		newChannel.data = {
			...newChannel.data,
			own_capabilities: ["upload-file"],
		};
		return newChannel;
	});

	const paginator = useMemo(
		() =>
			new ChannelPaginator({
				client,
				filters,
				id: "channels:ai",
				paginatorOptions: { pageSize },
				sort,
			}),
		[client, filters, sort, pageSize],
	);

	useEffect(() => {
		client.channelManager.insertPaginator({ paginator });
		return () => {
			client.channelManager.removePaginator(paginator);
		};
	}, [client, paginator]);

	const navigation = useMemo<WorkspaceNavigation>(
		() => ({
			...defaultWorkspaceNavigation,
			isChannelActive: (cid) => cid !== undefined && cid === channel?.cid,
			openChannel: (nextChannel) => setChannel(nextChannel),
			openChannels: channel ? [channel] : [],
		}),
		[channel],
	);

	return (
		<WorkspaceNavigationProvider value={navigation}>
			<WithComponents
				overrides={{
					MessageUI: MessageBubble,
					MessageComposerUI: Composer,
					ChannelListItemUI: ChannelListItem,
				}}
			>
				<div className="tut__sidebar">
					<ChannelList paginator={paginator} />
				</div>
				{channel && (
					<Channel channel={channel}>
						<MessageList />
						<AIStateIndicator />
						<MessageComposer />
					</Channel>
				)}
			</WithComponents>
		</WorkspaceNavigationProvider>
	);
};
