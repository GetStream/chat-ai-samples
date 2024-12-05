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
const apiKey = 'zcgvnykxsfm8';
const userId = 'anakin_skywalker';
const userName = 'Anakin Skywalker';
const userToken =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiYW5ha2luX3NreXdhbGtlciJ9.ZwCV1qPrSAsie7-0n61JQrSEDbp6fcMgVh4V2CB0kM8';

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