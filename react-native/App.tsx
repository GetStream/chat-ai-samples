import React, {useEffect, useState} from 'react';
import { NavigationContainer } from '@react-navigation/native';
import {
    createNativeStackNavigator,
    type NativeStackNavigationProp,
} from '@react-navigation/native-stack';
import {Pressable, Text } from 'react-native';
import { useChatClient } from './hooks/useChatClient.ts';
import { AppProvider, useAppContext } from './contexts/AppContext.tsx';
import {
    Chat,
    OverlayProvider,
    ChannelList,
    Channel,
    MessageList,
    MessageInput, AITypingIndicatorView,
} from 'stream-chat-react-native';
import { StreamChat, ChannelSort, LocalMessage, Channel as ChannelType } from 'stream-chat';
import { chatUserId, chatApiKey } from './chatConfig';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaView } from 'react-native-safe-area-context';
import {startAI, stopAI} from "./http/requests.ts";
import {useWatchers} from "./hooks/useWatchers.ts";

const chatInstance = StreamChat.getInstance(chatApiKey);

const filters = {
    members: {
        $in: [chatUserId],
    },
};

const sort: ChannelSort = { last_updated: -1 };

const chatTheme = {};

type ChannelRoute = { ChannelScreen: undefined };
type ChannelListRoute = { ChannelListScreen: undefined };
type NavigationParamsList = ChannelRoute & ChannelListRoute;

const Stack = createNativeStackNavigator<NavigationParamsList>();

const ChannelListScreen: React.FC<{
    navigation: NativeStackNavigationProp<
        NavigationParamsList,
        'ChannelListScreen'
    >;
}> = props => {
    const { setChannel } = useAppContext();

    return (
        <ChannelList
            filters={filters}
            sort={sort}
            onSelect={channel => {
                const { navigation } = props;
                setChannel(channel);
                navigation.navigate('ChannelScreen');
            }}
        />
    );
};

const ControlAIButton = ({ channel }: { channel: ChannelType }) => {
    const channelId = channel.id;
    const { watchers, loading } = useWatchers({ channel });
    const [isAIOn, setIsAIOn] = useState(false);

    useEffect(() => {
        if (watchers) {
            setIsAIOn(watchers.some((watcher) => watcher.startsWith('ai-bot')));
        }
    }, [watchers]);

    const onPress = async () => {
        if (!channelId) {
            return;
        }

        const handler = () => (isAIOn ? stopAI(channelId) : startAI(channelId));

        await handler();
    };

    return watchers && !loading ? (
        <Pressable
            style={{
                padding: 8,
                position: 'absolute',
                top: 18,
                right: 18,
                backgroundColor: '#D8BFD8',
                borderRadius: 8,
                shadowColor: '#000',
                shadowOffset: { width: 0, height: 4 },
                shadowOpacity: 0.3,
                shadowRadius: 5,
                elevation: 5,
            }}
            onPress={onPress}
        >
            <Text style={{ fontSize: 16, fontWeight: '500' }}>
                {isAIOn ? 'Stop AI 🪄' : 'Start AI 🪄'}
            </Text>
        </Pressable>
    ) : null;
};

const ChannelScreen: React.FC<{
    navigation: NativeStackNavigationProp<NavigationParamsList, 'ChannelScreen'>;
}> = () => {
    const { channel } = useAppContext();

    if (!channel) {
        return null;
    }

    return (
        <Channel channel={channel}>
            <MessageList />
            <ControlAIButton channel={channel} />
            <AITypingIndicatorView />
            <MessageInput />
        </Channel>
    );
};

const NavigationStack = () => {
    const { clientIsReady } = useChatClient();

    if (!clientIsReady) {
        return <Text>Loading the chats ...</Text>;
    }
    return (
        <Stack.Navigator>
            <Stack.Screen name="ChannelListScreen" component={ChannelListScreen} />
            <Stack.Screen name="ChannelScreen" component={ChannelScreen} />
        </Stack.Navigator>
    );
};

const isMessageAIGenerated = (message: LocalMessage) => !!message.ai_generated;

export default () => {
    return (
        <SafeAreaView style={{ flex: 1, backgroundColor: 'white' }}>
            <AppProvider>
                <GestureHandlerRootView style={{ flex: 1 }}>
                    <OverlayProvider value={{ style: chatTheme }}>
                        <Chat client={chatInstance} isMessageAIGenerated={isMessageAIGenerated}>
                            <NavigationContainer>
                                <NavigationStack />
                            </NavigationContainer>
                        </Chat>
                    </OverlayProvider>
                </GestureHandlerRootView>
            </AppProvider>
        </SafeAreaView>
    );
};
