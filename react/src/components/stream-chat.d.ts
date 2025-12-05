import type {DefaultAttachmentData, DefaultChannelData, DefaultMessageData,} from 'stream-chat-react';

declare module 'stream-chat' {
  interface CustomAttachmentData extends DefaultAttachmentData {
    id?: string;
  }

  interface CustomChannelData extends DefaultChannelData {
    summary?: string;
  }

  interface CustomMessageData extends DefaultMessageData {
    ai_generated?: boolean;
  }
}
