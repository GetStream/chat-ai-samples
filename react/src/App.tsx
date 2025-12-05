import type { ChannelFilters, ChannelOptions, ChannelSort } from "stream-chat";
import { useCreateChatClient } from "stream-chat-react";
import { AIChatApp } from "./components/AIChatApp";

import './components/index.scss';

const userToken = import.meta.env.VITE_STREAM_USER_TOKEN;
const apiKey = import.meta.env.VITE_STREAM_API_KEY;

console.log(import.meta, userToken, apiKey);

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
  members: {$in: [userId]},
  type: 'messaging',
  archived: false,
};
const options: ChannelOptions = {limit: 15, presence: true, state: true};

const sort: ChannelSort = {
  pinned_at: 1,
  last_message_at: -1,
  updated_at: -1,
};

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
    <AIChatApp
      apiKey={apiKey!}
      userToken={userToken!}
      userId={userId}
      filters={filters}
      options={options}
      sort={sort}
    />
  );
}

export default App;
