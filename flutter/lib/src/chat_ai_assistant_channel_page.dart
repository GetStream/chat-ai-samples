import 'package:flutter/material.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/chat_ai_assistant_typing_indicator_handler.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart'
    hide
        StreamingMessageView,
        AITypingIndicatorView,
        TypewriterState,
        TypewriterController,
        StreamTypewriterBuilder;
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

/// Renders the message list and AI typing indicator for [channel].
///
/// The composer lives in the parent `ChatAIAssistantHomePage` instead of here
/// — it's now a single, persistent widget shown across both the landing
/// (no active channel) and active-conversation states, matching the iOS
/// sample's always-docked `ComposerView`.
///
/// Callers must pass a `key` derived from the channel's identity (e.g.
/// `ValueKey(channel.cid)`) so a new [State] — and a fresh
/// [ChatAIAssistantTypingStateHandler] — is created whenever the active
/// channel changes.
class ChatAIAssistantConversationView extends StatefulWidget {
  const ChatAIAssistantConversationView({
    super.key,
    required this.channel,
  });

  final Channel channel;

  @override
  State<ChatAIAssistantConversationView> createState() =>
      _ChatAIAssistantConversationViewState();
}

class _ChatAIAssistantConversationViewState
    extends State<ChatAIAssistantConversationView> {
  var _typewriterState = TypewriterState.idle;
  late final ChatAIAssistantTypingStateHandler _typingStateHandler;

  @override
  void initState() {
    super.initState();
    _typingStateHandler = ChatAIAssistantTypingStateHandler(
      channel: widget.channel,
    );
  }

  @override
  void dispose() {
    _typingStateHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamChannel(
      channel: widget.channel,
      child: ValueListenableBuilder(
        valueListenable: _typingStateHandler,
        builder: (context, value, _) => Column(
          children: [
            Expanded(
              child: StreamMessageListView(
                messageBuilder: (context, message, defaultProps) {
                  // Customize the message widget based on whether it's an
                  // AI generated message or not.
                  if (message.isAI) {
                    // Use the `StreamingMessageView` for AI messages to
                    // animate the typing effect.
                    return AIMessageItem(
                      message: message,
                      onTypewriterStateChanged: (state) {
                        if (state == _typewriterState) return;

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          setState(() => _typewriterState = state);
                        });
                      },
                    );
                  }

                  return DefaultStreamMessageItem(props: defaultProps);
                },
              ),
            ),
            // Show the AI typing indicator when the AI assistant is
            // generating a response.
            AITypingIndicatorStateView(
              typewriterState: _typewriterState,
              aiTypingState: value.aiTypingState,
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders an AI-generated message as plain, padded markdown text — no
/// avatar, no bubble background.
///
/// Mirrors the iOS sample's `AIComponentsFactory.makeCustomAttachmentViewType`
/// (`StreamingMessageView(content:isGenerating:).padding()`), which applies
/// only to AI-generated messages; the user's own messages keep the SDK's
/// normal (bubble) rendering via [DefaultStreamMessageItem].
class AIMessageItem extends StatelessWidget {
  const AIMessageItem({
    super.key,
    required this.message,
    this.onTypewriterStateChanged,
  });

  final Message message;
  final ValueChanged<TypewriterState>? onTypewriterStateChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: StreamingMessageView(
        text: message.text ?? '',
        onTypewriterStateChanged: onTypewriterStateChanged,
      ),
    );
  }
}

class AITypingIndicatorStateView extends StatelessWidget {
  const AITypingIndicatorStateView({
    super.key,
    required this.aiTypingState,
    required this.typewriterState,
    this.child,
  });

  final AITypingState aiTypingState;
  final TypewriterState typewriterState;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final indicatorText = switch ((typewriterState, aiTypingState)) {
      (TypewriterState.typing, _) => 'Generating',
      (_, AITypingState.generating) => 'Generating',
      (_, AITypingState.thinking) => 'Thinking',
      (_, AITypingState.checkingSources) => 'Checking sources',
      _ => null,
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: switch (indicatorText) {
        final text? => Container(
            key: ValueKey(text),
            width: double.infinity,
            color: Colors.grey[200],
            padding: const EdgeInsets.all(8),
            child: AITypingIndicatorView(
              text: text,
              textStyle: const TextStyle(
                color: Colors.black,
                fontSize: 16,
              ),
            ),
          ),
        _ => KeyedSubtree(
            key: const ValueKey('empty'),
            child: child ?? const SizedBox.shrink(),
          ),
      },
    );
  }
}

extension on Message {
  /// Returns `true` if the message was generated by the AI assistant.
  bool get isAI => extraData['ai_generated'] == true;
}
