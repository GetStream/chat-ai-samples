import "stream-chat";

declare module "stream-chat" {
  interface CustomMessageData {
    generating?: boolean;
    ai_generated?: boolean;
  }
}
