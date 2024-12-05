import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/chat_ai_assistant_service.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/chat_ai_assistant_typing_indicator_handler.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

class ChatAIAssistantChannelPage extends StatefulWidget {
  const ChatAIAssistantChannelPage({
    super.key,
    required this.channel,
  });

  final Channel channel;

  @override
  State<ChatAIAssistantChannelPage> createState() =>
      _ChatAIAssistantChannelPageState();
}

class _ChatAIAssistantChannelPageState
    extends State<ChatAIAssistantChannelPage> {
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

  Future<void> _toggleAIAssistant(bool toggleState) async {
    final channelId = widget.channel.id;
    if (channelId == null) return;

    try {
      await switch (toggleState) {
        true => ChatAIAssistantService().startAIAgent(channelId),
        false => ChatAIAssistantService().stopAIAgent(channelId),
      };
    } catch (e) {
      debugPrint('Failed to toggle AI assistant: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamChannel(
      channel: widget.channel,
      child: ValueListenableBuilder(
        valueListenable: _typingStateHandler,
        builder: (context, value, _) => Scaffold(
          appBar: const StreamChannelHeader(),
          body: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: StreamMessageListView(
                      messageBuilder: (_, details, ___, defaultWidget) {
                        // Customize the message widget based on whether it's an
                        // AI generated message or not.
                        if (details.message.isAI) {
                          return defaultWidget.copyWith(
                            textBuilder: (context, message) {
                              // Use the `StreamingMessageView` for AI messages
                              // to animate the typing effect.
                              return StreamingMessageView(
                                text: message.text ?? '',
                                onTypewriterStateChanged: (state) {
                                  if (state == _typewriterState) return;

                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    setState(() => _typewriterState = state);
                                  });
                                },
                              );
                            },
                            bottomRowBuilderWithDefaultWidget: (
                              context,
                              message,
                              defaultWidget,
                            ) {
                              // Hide the edited label for AI messages.
                              return defaultWidget.copyWith(
                                showEditedLabel: false,
                              );
                            },
                          );
                        }

                        return defaultWidget;
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
              // Add a button to toggle the AI assistant.
              Align(
                alignment: const Alignment(0.98, -0.98),
                child: ToggleAIAssistantButton(
                  child: Text(value.isBotPresent ? 'Stop AI' : 'Start AI'),
                  onPressed: () => _toggleAIAssistant(!value.isBotPresent),
                ),
              ),
            ],
          ),
          bottomNavigationBar: StreamMessageInput(
            // Add a button to stop the AI response if it's in progress.
            sendButtonBuilder: value.aiMessageId != null
                ? (_, controller) => IconButton(
                      color: const Color(0XFF006BFE),
                      onPressed: () => widget.channel.stopAIResponse(),
                      icon: const Icon(Icons.stop_circle_rounded),
                    )
                : null,
          ),
        ),
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

class ToggleAIAssistantButton extends StatelessWidget {
  const ToggleAIAssistantButton({
    super.key,
    required this.child,
    this.onPressed,
  });

  final Widget child;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      child: child,
    );
  }
}

extension on Message {
  /// Returns `true` if the message was generated by the AI assistant.
  bool get isAI => extraData['ai_generated'] == true;
}
