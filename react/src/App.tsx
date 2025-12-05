import {useState} from "react";
import type {ChannelFilters, ChannelOptions, ChannelSort, LocalMessage} from "stream-chat";
import {Chat, useCreateChatClient} from "stream-chat-react";

import {Sidebar} from "./components/Sidebar";
import {ChatContainer} from "./components/ChatContainer";

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

const isMessageAIGenerated = (message: LocalMessage) => !!message?.ai_generated;

function App() {
  const chatClient = useCreateChatClient({
    apiKey: apiKey!,
    tokenOrProvider: userToken,
    userData: { id: userId },
  });

  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  const toggleSidebar = () => setIsSidebarOpen((prev) => !prev);
  const closeSidebar = () => setIsSidebarOpen(false);


  if (!chatClient) return <>Loading...</>;

  return (
    <div className="ai-demo-app">
      <Chat client={chatClient} isMessageAIGenerated={isMessageAIGenerated}>
        <Sidebar
          filters={filters}
          options={options}
          sort={sort}
          isOpen={isSidebarOpen}
          onClose={closeSidebar}
        />
        <ChatContainer onToggleSidebar={toggleSidebar} />
      </Chat>
    </div>
  );
}

export default App;
