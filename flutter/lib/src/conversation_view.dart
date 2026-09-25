import 'package:flutter/material.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/ai_message_item.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/typing_state_handler.dart';
// stream_chat_flutter ships older versions of these AI widgets; use the ones
// from stream_chat_flutter_ai.
import 'package:stream_chat_flutter/stream_chat_flutter.dart'
    hide
        StreamingMessageView,
        AITypingIndicatorView,
        TypewriterState,
        TypewriterController,
        StreamTypewriterBuilder;
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

/// The message list and AI typing indicator for [channel].
///
/// Give it a key derived from the channel (e.g. `ValueKey(channel.cid)`), so
/// switching channels creates a fresh [TypingStateHandler].
class ConversationView extends StatefulWidget {
  const ConversationView({
    super.key,
    required this.channel,
    this.onGeneratingChanged,
  });

  final Channel channel;

  /// Called when the assistant starts or stops replying, so the composer can
  /// swap its send button for a stop button.
  final ValueChanged<bool>? onGeneratingChanged;

  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  late final _typingStateHandler = TypingStateHandler(channel: widget.channel)
    ..addListener(_reportGenerating);
  var _typewriterState = TypewriterState.idle;

  @override
  void dispose() {
    _typingStateHandler.dispose();
    super.dispose();
  }

  /// Follows the backend only: stopping can't cancel text that has already
  /// arrived and is still being revealed by the typewriter.
  void _reportGenerating() {
    widget.onGeneratingChanged?.call(switch (_typingStateHandler.value) {
      AITypingState.thinking || AITypingState.checkingSources || AITypingState.generating => true,
      _ => false,
    });
  }

  void _onTypewriterStateChanged(TypewriterState state) {
    if (state == _typewriterState) return;
    // Reported while the message list builds, so wait for the frame to end.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _typewriterState = state);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamChannel(
      channel: widget.channel,
      child: Column(
        children: [
          Expanded(
            child: StreamMessageListView(
              // A new channel is created together with its first message, so
              // the default "no messages yet" text would only flash briefly.
              builders: StreamMessageListViewBuilders(
                empty: (context) => const Center(
                  child: SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              messageBuilder: (context, message, defaultProps) {
                if (message.isAI) {
                  return AIMessageItem(
                    message: message,
                    onTypewriterStateChanged: _onTypewriterStateChanged,
                  );
                }
                return DefaultStreamMessageItem(props: defaultProps);
              },
            ),
          ),
          ValueListenableBuilder(
            valueListenable: _typingStateHandler,
            builder: (context, aiTypingState, _) => AITypingIndicatorStateView(
              typewriterState: _typewriterState,
              aiTypingState: aiTypingState,
            ),
          ),
        ],
      ),
    );
  }
}

class AITypingIndicatorStateView extends StatelessWidget {
  const AITypingIndicatorStateView({
    super.key,
    required this.aiTypingState,
    required this.typewriterState,
  });

  final AITypingState aiTypingState;
  final TypewriterState typewriterState;

  @override
  Widget build(BuildContext context) {
    final indicatorText = switch ((typewriterState, aiTypingState)) {
      (TypewriterState.typing, _) || (_, AITypingState.generating) => 'Generating',
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
              textStyle: const TextStyle(color: Colors.black, fontSize: 16),
            ),
          ),
        null => const SizedBox.shrink(),
      },
    );
  }
}

extension on Message {
  /// Whether the AI assistant wrote this message.
  bool get isAI => extraData['ai_generated'] == true;
}
