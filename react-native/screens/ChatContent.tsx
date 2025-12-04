import {
  AIStates,
  Channel,
  isLocalUrl,
  mergeThemes,
  Message,
  MessageList,
  MessageProps,
  ThemeProvider,
  useAIState,
  useChannelContext,
  useMessageComposer,
  useMessageContext,
  useMessageInputContext,
  useStableCallback,
  useTheme,
} from 'stream-chat-react-native';
import { useAppContext } from '../contexts/AppContext.tsx';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { startAI, summarize } from '../http/requests.ts';
import Animated, { FadeIn, FadeOut } from 'react-native-reanimated';
import {
  Dimensions,
  Platform,
  StatusBar,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import {
  AITypingIndicatorView,
  ComposerView,
  StreamingMessageView,
} from '@stream-io/chat-react-native-ai';
import { useCallback, useMemo } from 'react';
import { bottomSheetOptions } from '../bottomSheetOptions.ts';

const CustomMessage = (props: MessageProps) => {
  const { theme } = useTheme();
  const { message } = props;
  const isFromBot = message.ai_generated;
  const hasPendingAttachments = useMemo(
    () =>
      (message.attachments ?? []).some(
        attachment =>
          (attachment.image_url && isLocalUrl(attachment.image_url)) ||
          (attachment.asset_url && isLocalUrl(attachment.asset_url)),
      ),
    [message.attachments],
  );

  const modifiedTheme = useMemo(
    () =>
      mergeThemes({
        theme,
        style: {
          messageSimple: isFromBot
            ? {
                content: {
                  containerInner: {
                    backgroundColor: 'transparent',
                    borderRadius: 0,
                    borderColor: 'transparent',
                  },
                },
              }
            : {
                wrapper: {
                  opacity: hasPendingAttachments ? 0.5 : 1,
                },
              },
        },
      }),
    [theme, isFromBot, hasPendingAttachments],
  );

  return (
    <ThemeProvider mergedStyle={modifiedTheme}>
      <Message {...props} preventPress={true} />
    </ThemeProvider>
  );
};

const CustomStreamingMessageView = () => {
  const { message } = useMessageContext();
  return (
    <View style={styles.streamingMessageViewWrapper}>
      <StreamingMessageView text={message.text ?? ''} />
    </View>
  );
};

const CustomComposerView = () => {
  const messageComposer = useMessageComposer();
  const { sendMessage } = useMessageInputContext();
  const { channel } = useChannelContext();

  const { aiState } = useAIState(channel);

  const stopGenerating = useCallback(
    () => channel?.stopAIResponse(),
    [channel],
  );

  const isGenerating = [AIStates.Thinking, AIStates.Generating].includes(
    aiState,
  );

  const safeAreaInsets = useSafeAreaInsets();
  const insets = useMemo(
    () => ({
      ...safeAreaInsets,
      bottom:
        safeAreaInsets.bottom +
        (Platform.OS === 'android' ? (StatusBar.currentHeight ?? 0) * 2 : 0),
    }),
    [safeAreaInsets],
  );

  const serializeToMessage = useStableCallback(
    async ({ text, attachments }: { text: string; attachments?: any[] }) => {
      messageComposer.textComposer.setText(text);
      if (attachments && attachments.length > 0) {
        const localAttachments = await Promise.all(
          attachments.map(a =>
            messageComposer.attachmentManager.fileToLocalUploadAttachment(a),
          ),
        );
        messageComposer.attachmentManager.upsertAttachments(localAttachments);
      }

      await sendMessage();
    },
  );

  return (
    <ComposerView
      bottomSheetOptions={bottomSheetOptions}
      bottomSheetInsets={insets}
      onSendMessage={serializeToMessage}
      isGenerating={isGenerating}
      stopGenerating={stopGenerating}
    />
  );
};

const EmptyStateIndicator = () => (
  <View style={styles.emptyContainer}>
    <Text style={styles.emptyContainerText}>What can I help with ?</Text>
  </View>
);

const CustomAITypingIndicatorView = () => {
  const { channel } = useChannelContext();
  const { aiState } = useAIState(channel);

  const allowedStates = {
    [AIStates.Thinking]: 'Thinking about the question...',
    [AIStates.Generating]: 'Generating a response...',
    [AIStates.ExternalSources]: 'Checking external sources...',
  };

  if (aiState === AIStates.Idle || aiState === AIStates.Error) {
    return null;
  }

  return (
    <View style={styles.aiTypingIndicatorWrapper}>
      <AITypingIndicatorView text={allowedStates[aiState]} />
    </View>
  );
};

const RenderNull = () => null;

const additionalFlatListProps = {
  maintainVisibleContentPosition: {
    minIndexForVisible: 0,
    autoscrollToTopThreshold: 0,
  },
  ListHeaderComponent: null,
};

export const ChatContent = () => {
  const { channel } = useAppContext();
  const { bottom } = useSafeAreaInsets();

  const preSendMessageRequest = useStableCallback(async ({ localMessage }) => {
    if (!channel) {
      return;
    }

    if (!channel.initialized) {
      await channel.watch({
        created_by_id: localMessage.user_id,
      });
      summarize(localMessage.text).then(response => {
        const { summary } = response as { summary: string };
        channel.update({ name: summary });
      });
    }

    if (
      !Object.keys(channel.state.watchers).some(watcher =>
        watcher.startsWith('ai-bot'),
      ) &&
      channel.id
    ) {
      await startAI(channel.id);
    }
  });

  if (!channel) {
    return null;
  }

  return (
    <Animated.View
      key={channel.id}
      style={[styles.wrapper, { paddingBottom: bottom }]}
      entering={FadeIn.duration(200)}
      exiting={FadeOut.duration(200)}
    >
      <Channel
        channel={channel}
        keyboardVerticalOffset={Platform.OS === 'ios' ? 95 : -300}
        initializeOnMount={false}
        // @ts-expect-error This will be fixed upstream, the type is wrong
        preSendMessageRequest={preSendMessageRequest}
        StreamingMessageView={CustomStreamingMessageView}
        Message={CustomMessage}
        enableSwipeToReply={false}
        EmptyStateIndicator={EmptyStateIndicator}
        allowSendBeforeAttachmentsUpload={true}
        NetworkDownIndicator={RenderNull}
        MessageAvatar={RenderNull}
        MessageFooter={RenderNull}
      >
        <MessageList additionalFlatListProps={additionalFlatListProps} />
        <CustomAITypingIndicatorView />
        <CustomComposerView />
      </Channel>
    </Animated.View>
  );
};

const styles = StyleSheet.create({
  wrapper: { flex: 1, backgroundColor: '#fcfcfc'},
  emptyContainer: {
    flex: 1,
    width: '100%',
    backgroundColor: 'transparent',
    justifyContent: 'center',
    alignItems: 'center',
  },
  emptyContainerText: { fontSize: 24, fontWeight: 'bold' },
  streamingMessageViewWrapper: {
    maxWidth: '100%',
    paddingHorizontal: 16,
  },
  aiTypingIndicatorWrapper: {
    paddingHorizontal: 24,
    paddingVertical: 12,
  },
});
