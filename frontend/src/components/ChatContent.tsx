import {
	Channel,
	MessageList,
	Window,
	MessageInput,
	useChatContext,
} from "stream-chat-react";
import { Composer } from "./Composer";
import { MessageBubble } from "./MessageBubble";
import { AIStateIndicator } from "./AIStateIndicator";
import { useEffect } from "react";
import { nanoid } from "nanoid";
import { startAiAgent } from "../api";

function getUserLocation(): Promise<{ latitude: number; longitude: number } | undefined> {
	return new Promise((resolve) => {
		if (!navigator.geolocation) return resolve(undefined);
		navigator.geolocation.getCurrentPosition(
			(pos) => resolve({ latitude: pos.coords.latitude, longitude: pos.coords.longitude }),
			() => resolve(undefined),
			{ timeout: 5000 },
		);
	});
}

export const ChatContent = () => {
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

	useEffect(() => {
		if (!channel) return;
		const autoStart = async () => {
			if (!channel.initialized) {
				await channel.watch();
			}
			await startAiAgent(channel, "claude-sonnet-4-5", "anthropic");

			const location = await getUserLocation();
			if (location) {
				await channel.sendEvent({
					type: 'user_location' as any,
					latitude: location.latitude,
					longitude: location.longitude,
				} as any);
			}
		};
		autoStart().catch(console.error);
	}, [channel?.id]);

	return (
		<Channel initializeOnMount={false} Message={MessageBubble}>
			<Window>
				<MessageList />
				<AIStateIndicator />
				<MessageInput Input={Composer} />
			</Window>
		</Channel>
	);
};
