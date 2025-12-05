import { AIMessageComposer } from '@stream-io/chat-react-ai';
import { useState, useEffect } from 'react';
import {
  isImageFile,
  type Channel,
  type LocalUploadAttachment,
  type UploadRequestFn,
} from 'stream-chat';
import {
  useAttachmentsForPreview,
  useChannelActionContext,
  useChannelStateContext,
  useChatContext,
  useMessageComposer,
} from 'stream-chat-react';
import { startAiAgent, summarizeConversation } from '../api';
import './MessageInputBar.scss';

const isWatchedByAI = (channel: Channel) => {
  return Object.keys(channel.state.watchers).some((watcher) =>
    watcher.startsWith('ai-bot'),
  );
};

export const MessageInputBar = () => {
  const { client } = useChatContext();
  const { updateMessage, sendMessage } = useChannelActionContext();
  const { channel } = useChannelStateContext();
  const composer = useMessageComposer();

  const { attachments } = useAttachmentsForPreview();
  const [selectedPlatformModel, setSelectedPlatformModel] = useState<string>();

  useEffect(() => {
    if (!composer) return;

    const upload: UploadRequestFn = (file) => {
      const f = isImageFile(file) ? client.uploadImage : client.uploadFile;

      return f.call(client, file as File);
    };

    const previousDefault = composer.attachmentManager.doDefaultUploadRequest;

    composer.attachmentManager.setCustomUploadFn(upload);

    return () => composer.attachmentManager.setCustomUploadFn(previousDefault);
  }, [client, composer]);

  return (
    <div className="ai-demo-message-input-bar">
      <AIMessageComposer
        onChange={(e) => {
          const input = e.currentTarget.elements.namedItem(
            'attachments',
          ) as HTMLInputElement | null;

          const files = input?.files ?? null;

          if (files) {
            composer.attachmentManager.uploadFiles(files);
          }
        }}
        onSubmit={async (e) => {
          const event = e;
          event.preventDefault();

          const target = event.currentTarget;

          const formData = new FormData(target);

          const message = formData.get('message');
          const platformModel = formData.get('platform-model');
          setSelectedPlatformModel(platformModel as string);

          composer.textComposer.setText(message as string);

          const composedData = await composer.compose();

          if (!composedData) return;

          target.reset();
          composer.clear();

          updateMessage(composedData?.localMessage);

          if (!channel.initialized) {
            await channel.watch();
          }

          const [platform, model] = (platformModel as string).split('|');

          if (!isWatchedByAI(channel)) {
            await startAiAgent(channel, model, platform);
          }

          await sendMessage(composedData);

          if (
            typeof channel.data?.summary !== 'string' ||
            !channel.data.summary.length
          ) {
            const summary = await summarizeConversation(
              message as string,
            ).catch(() => {
              console.warn('Failed to summarize conversation');
              return null;
            });

            if (typeof summary === 'string' && summary.length > 0) {
              await channel.update({ summary });
            }
          }
        }}
      >
        <AIMessageComposer.AttachmentPreview>
          {attachments.map((attachment) => (
            <AIMessageComposer.AttachmentPreview.Item
              key={attachment.localMetadata.id}
              file={attachment.localMetadata.file as File}
              state={attachment.localMetadata.uploadState}
              imagePreviewSource={
                attachment.thumb_url ||
                (attachment.localMetadata.previewUri as string)
              }
              onDelete={() => {
                composer.attachmentManager.removeAttachments([
                  attachment.localMetadata.id,
                ]);
              }}
              onRetry={() => {
                composer.attachmentManager.uploadAttachment(
                  attachment as LocalUploadAttachment,
                );
              }}
            />
          ))}
        </AIMessageComposer.AttachmentPreview>
        <AIMessageComposer.TextInput name="message" />
        <div
          style={{
            display: 'flex',
            gap: '1rem',
            justifyContent: 'space-between',
            alignItems: 'center',
          }}
        >
          <div style={{ display: 'flex', gap: '.25rem', alignItems: 'center' }}>
            <AIMessageComposer.FileInput name="attachments" />
            <AIMessageComposer.SpeechToTextButton />
            <AIMessageComposer.ModelSelect
              name="platform-model"
              value={selectedPlatformModel}
            />
          </div>

          <AIMessageComposer.SubmitButton active={attachments.length > 0} />
        </div>
      </AIMessageComposer>
    </div>
  );
};
