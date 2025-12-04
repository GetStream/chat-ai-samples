import { NavigationContainer } from '@react-navigation/native';
import { createDrawerNavigator } from '@react-navigation/drawer';

import { StyleSheet } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import React from 'react';
import {
  Chat,
  OverlayProvider,
  useCreateChatClient,
} from 'stream-chat-react-native';
import { AppProvider } from './contexts/AppContext.tsx';
import {
  chatApiKey,
  chatUserId,
  chatUserName,
  chatUserToken,
} from './chatConfig.ts';
import { StreamTheme } from '@stream-io/chat-react-native-ai';
import { MenuDrawer } from './screens/MenuDrawer.tsx';
import { LocalMessage } from 'stream-chat';
import { ChatContent } from './screens/ChatContent.tsx';

const Drawer = createDrawerNavigator();

const DrawerNavigator = () => (
  <Drawer.Navigator
    drawerContent={MenuDrawer}
    screenOptions={{
      drawerStyle: {
        width: 300,
      },
    }}
  >
    <Drawer.Screen name="Chat" component={ChatContent} />
  </Drawer.Navigator>
);

const isMessageAIGenerated = (message: LocalMessage) => !!message.ai_generated;

const App = () => {
  const chatClient = useCreateChatClient({
    apiKey: chatApiKey,
    tokenOrProvider: chatUserToken,
    userData: { id: chatUserId, name: chatUserName },
  });

  if (!chatClient) {
    return null;
  }

  return (
    <SafeAreaProvider>
      <AppProvider client={chatClient}>
        <StreamTheme>
          <GestureHandlerRootView style={styles.container}>
            <OverlayProvider>
              <Chat
                client={chatClient}
                isMessageAIGenerated={isMessageAIGenerated}
              >
                <NavigationContainer>
                  <DrawerNavigator />
                </NavigationContainer>
              </Chat>
            </OverlayProvider>
          </GestureHandlerRootView>
        </StreamTheme>
      </AppProvider>
    </SafeAreaProvider>
  );
};

const styles = StyleSheet.create({
  container: { flex: 1 },
});

export default App;
