import { useEffect, useState } from 'react';
import { StreamChat } from 'stream-chat';
import { chatApiKey, chatUserId, chatUserName, chatUserToken } from '../chatConfig';

const user = {
    id: chatUserId,
    name: chatUserName,
};

const chatClient = StreamChat.getInstance(chatApiKey);

export const useChatClient = () => {
    const [clientIsReady, setClientIsReady] = useState(false);

    useEffect(() => {
        const setupClient = async () => {
            try {
                if (!chatClient.userID) {
                    chatClient.connectUser(user, chatUserToken);
                }
                setClientIsReady(true);
            } catch (error) {
                if (error instanceof Error) {
                    console.error(`An error occurred while connecting the user: ${error.message}`);
                }
            }
        };
        setupClient();
    }, []);

    return {
        clientIsReady,
    };
};
