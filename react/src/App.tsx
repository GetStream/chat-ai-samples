import type { ChannelFilters, SortParamRequest } from "stream-chat";
import { Chat, useCreateChatClient } from "stream-chat-react";

import { ChatContent } from "./components/ChatContent";

const userToken = import.meta.env.VITE_STREAM_USER_TOKEN;
const apiKey = import.meta.env.VITE_STREAM_API_KEY;

if (typeof apiKey !== "string" || !apiKey.length) {
	throw new Error("Missing VITE_STREAM_API_KEY");
}

if (typeof userToken !== "string" || !userToken.length) {
	throw new Error("Missing VITE_STREAM_USER_TOKEN");
}

const userIdFromToken = (token: string) => {
	const [, payload] = token.split(".");
	const parsedPayload = JSON.parse(atob(payload));
	return parsedPayload.user_id as string;
};

const userId = userIdFromToken(userToken!);

const filters: ChannelFilters = {
	members: { $in: [userId] },
	type: "messaging",
	archived: false,
};
const pageSize = 5;
const sort: SortParamRequest[] = [
	{ direction: 1, field: "pinned_at" },
	{ direction: -1, field: "last_message_at" },
	{ direction: -1, field: "updated_at" },
];

function App() {
	const chatClient = useCreateChatClient({
		apiKey: apiKey!,
		tokenOrProvider: userToken!,
		userData: {
			id: userId,
		},
	});

	if (!chatClient) {
		return <div>Loading chat...</div>;
	}

	return (
		<Chat client={chatClient}>
			<ChatContent filters={filters} sort={sort} pageSize={pageSize} />
		</Chat>
	);
}

export default App;
