import type {
  User,
  ChannelSort,
  ChannelFilters,
  ChannelOptions,
} from 'stream-chat';
import {
  useCreateChatClient,
  Chat,
  Channel,
  ChannelList,
  MessageInput,
  MessageList,
  Thread,
  Window,
} from 'stream-chat-react';

import 'stream-chat-react/dist/css/v2/index.css';
import MyChannelHeader from './MyChannelHeader';
import MyAIStateIndicator from './MyAIStateIndicator';

// your Stream app information
const apiKey = import.meta.env.VITE_STREAM_API_KEY as string | undefined;
const userToken = import.meta.env.VITE_STREAM_TOKEN as string | undefined;
const userId = 'anakin_skywalker';
const userName = 'Anakin Skywalker';

if (!apiKey || !userToken) {
  throw new Error('Missing API key or user token');
}

const user: User = {
  id: userId,
  name: userName,
  image:
    'https://vignette.wikia.nocookie.net/starwars/images/6/6f/Anakin_Skywalker_RotS.png',
};

const sort: ChannelSort = { last_message_at: -1 };
const filters: ChannelFilters = {
  type: 'messaging',
  members: { $in: [userId] },
};
const options: ChannelOptions = {
  limit: 10,
};

const App = () => {
  const client = useCreateChatClient({
    apiKey,
    tokenOrProvider: userToken,
    userData: user,
  });

  if (!client) return <div>Setting up client & connection...</div>;

  return (
    <Chat client={client}>
      <ChannelList filters={filters} sort={sort} options={options} />
      <Channel>
        <Window>
          <MyChannelHeader />
          <MessageList />
          <MyAIStateIndicator />
          <MessageInput />
        </Window>
        <Thread />
      </Channel>
    </Chat>
  );
};

export default App;
