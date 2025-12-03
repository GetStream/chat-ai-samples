import { chatUserId } from '../chatConfig.ts';
import { ChannelSort } from 'stream-chat';
import {
  ChannelList,
  ChannelPreviewMessengerProps,
  useChannelsContext,
  useStableCallback,
  Copy,
  useChatContext,
} from 'stream-chat-react-native';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { DrawerContentComponentProps } from '@react-navigation/drawer';
import { createChannel, useAppContext } from '../contexts/AppContext.tsx';
import { Channel as ChannelClass } from 'stream-chat';
import { SafeAreaView } from 'react-native-safe-area-context';
import React from 'react';

const filters = {
  members: {
    $in: [chatUserId],
  },
};

const sort: ChannelSort = { last_updated: -1 };

const ChannelPreview = (props: ChannelPreviewMessengerProps) => {
  const channel = props.channel;
  const { onSelect } = useChannelsContext();
  const onPress = useStableCallback(() => {
    onSelect?.(channel);
  });
  return (
    <Pressable
      style={({ pressed }) => ({
        paddingVertical: 8,
        paddingHorizontal: 12,
        opacity: pressed ? 0.6 : 1,
      })}
      onPress={onPress}
    >
      <Text style={styles.previewText} numberOfLines={1}>
        {channel.data?.name ?? channel.cid}
      </Text>
    </Pressable>
  );
};

export const MenuDrawer = ({ navigation }: DrawerContentComponentProps) => {
  const { client } = useChatContext();
  const { setChannel } = useAppContext();

  const onSelect = useStableCallback((channel: ChannelClass) => {
    setChannel(channel);
    navigation.closeDrawer();
  });

  const onCreateNewChat = useStableCallback(() => {
    setChannel(createChannel(client));
    navigation.closeDrawer();
  });

  return (
    <SafeAreaView style={styles.wrapper}>
      <View style={styles.container}>
        <Text style={styles.title}>Conversations</Text>
        <Pressable onPress={onCreateNewChat}>
          <Copy />
        </Pressable>
      </View>
      <ChannelList
        filters={filters}
        sort={sort}
        onSelect={onSelect}
        Preview={ChannelPreview}
      />
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  wrapper: { flex: 1 },
  container: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginHorizontal: 12,
    paddingVertical: 16,
    borderBottomWidth: 1,
    borderBottomColor: 'grey',
  },
  title: { fontSize: 15, fontWeight: 'bold' },
  previewText: { fontSize: 15, fontWeight: 'bold' },
});
