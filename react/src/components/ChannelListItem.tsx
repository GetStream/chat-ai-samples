import type { ChannelListItemUIProps } from "stream-chat-react";
import { useWorkspaceNavigation } from "stream-chat-react";
import clsx from "clsx";

export const ChannelListItem = (props: ChannelListItemUIProps) => {
	const { data } = props.channel;
	const { openChannel } = useWorkspaceNavigation();
	const isActive = props.active;

	return (
		<div
			className={clsx("tut__channel-preview", {
				"tut__channel-preview--active": isActive,
			})}
			onClick={(event) => openChannel(props.channel, { event })}
		>
			<div className="tut__channel-preview__text">
				{data?.custom?.summary ?? "New Chat"}
			</div>
		</div>
	);
};
