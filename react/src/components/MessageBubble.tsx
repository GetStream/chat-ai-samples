import { StreamingMessage } from "@stream-io/chat-react-ai";
import {
	Attachment,
	MessageErrorIcon,
	useMessageContext,
} from "stream-chat-react";
import clsx from "clsx";

export const MessageBubble = () => {
	const { message, isMyMessage, highlighted, handleAction } =
		useMessageContext();

	const attachments = message?.attachments || [];
	const hasAttachments = attachments.length > 0;

	const rootClassName = clsx(
		"str-chat__message str-chat__message-simple",
		`str-chat__message--${message.type}`,
		`str-chat__message--${message.status}`,
		{
			"str-chat__message--me": isMyMessage(),
			"str-chat__message--other": !isMyMessage(),
			"str-chat__message--has-attachment": hasAttachments,
			"str-chat__message--highlighted": highlighted,
			"str-chat__message-send-can-be-retried":
				message?.status === "failed" && message?.error?.status !== 403,
		}
	);

	return (
		<div className={rootClassName}>
			<div className="str-chat__message-inner" data-testid="message-inner">
				<div className="str-chat__message-bubble">
					{hasAttachments && (
						<Attachment
							actionHandler={handleAction}
							attachments={attachments}
						/>
					)}
					{message?.text && <StreamingMessage text={message.text} />}
					<MessageErrorIcon />
				</div>
			</div>
		</div>
	);
};
