import { useEffect, useMemo, useState } from "react";

import type { Channel as StreamChannel, User } from "stream-chat";
import {
  Channel,
  ChannelHeader,
  Chat,
  MessageInput,
  MessageList,
  Thread,
  Window,
} from "stream-chat-react";
import { useCreateChatClient } from "./hooks/useCreateChatClient";
import { StreamedMessage } from "./components/StreamedMessage";
import "stream-chat-react/dist/css/v2/index.css";
import env from "react-dotenv";

const apiKey = env.STREAM_API_KEY!;
const userId = env.USER_ID!;
const userName = env.USER_NAME!;
const token = env.USER_TOKEN!;

const App = () => {
  const [channel, setChannel] = useState<StreamChannel>();

  const user: User = useMemo(
    () => ({
      id: userId,
      name: userName,
      image: `https://getstream.io/random_png/?name=${userName}`,
    }),
    [],
  );

  const client = useCreateChatClient({
    apiKey,
    tokenOrProvider: token,
    userData: user,
  });

  useEffect(() => {
    if (!client) return;

    const newChannel = client.channel("messaging", {
      members: [user.id, "chat-ai-assistant"],
    });
    setChannel(newChannel);
  }, [client, user.id]);

  if (!client || !channel) return <div>Setting up client & connection...</div>;

  return (
    <div id="root" className="str-chat">
      <Chat client={client}>
        <Channel channel={channel}>
          <Window>
            <ChannelHeader />
            <MessageList Message={StreamedMessage} />
            <MessageInput />
          </Window>
          <Thread />
        </Channel>
      </Chat>
    </div>
  );
};

export default App;
