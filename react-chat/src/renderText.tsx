import type {MessageListProps, RenderTextPluginConfigurator} from 'stream-chat-react';
import {defaultAllowedTagNames, renderText as defaultRenderText,} from "stream-chat-react";
import rehypeHighlight from "rehype-highlight";

const getRehypePlugins: RenderTextPluginConfigurator = (plugins) => {
  return [rehypeHighlight, ...plugins];
};

// fixme: do we plan to add some custom plugins or can be removed?
const getRemarkPlugins: RenderTextPluginConfigurator = (plugins) => {
  return [...plugins];
};

export const renderText: MessageListProps['renderText'] = (text, mentionedUsers) =>
  defaultRenderText(text, mentionedUsers, {
  getRehypePlugins,
  getRemarkPlugins,
  allowedTagNames: [...defaultAllowedTagNames, "span"],
})
