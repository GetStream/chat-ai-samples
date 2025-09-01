import React, { ReactNode, useState } from 'react';
import type { Channel } from 'stream-chat';

export type AppContextValue = {
    channel: Channel | undefined;
    setChannel: (channel: Channel) => void;
};

export const AppContext = React.createContext<AppContextValue>({
    setChannel: () => {},
    channel: undefined,
});

export const AppProvider = ({ children }: { children: ReactNode }) => {
    const [channel, setChannel] = useState<Channel>();

    const contextValue = { channel, setChannel };

    return <AppContext.Provider value={contextValue}>{children}</AppContext.Provider>;
};

export const useAppContext = () => React.useContext(AppContext);
