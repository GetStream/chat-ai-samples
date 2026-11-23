import {
	DefaultChannelData,
	DefaultMessageData,
} from "stream-chat-react";

declare module "stream-chat" {
	interface CustomChannelData extends DefaultChannelData {
		summary?: string;
	}
	interface CustomMessageData extends DefaultMessageData {
		ai_generated?: boolean;
	}
}
