import type { ChannelPreviewProps } from "stream-chat-react";
import { useChatContext } from "stream-chat-react";
import clsx from "clsx";

export const ChannelListItem = (props: ChannelPreviewProps) => {
	const { id, data } = props.channel;
	const { setActiveChannel, channel: activeChannel } = useChatContext();
	const isActive = activeChannel?.id === id;

	return (
		<div
			className={clsx("tut__channel-preview", {
				"tut__channel-preview--active": isActive,
			})}
			onClick={() => setActiveChannel(props.channel)}
		>
			<div className="tut__channel-preview__text">
				{data?.summary ?? "New Chat"}
			</div>
		</div>
	);
};
