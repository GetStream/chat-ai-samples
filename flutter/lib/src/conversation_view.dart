import 'dart:async';

import 'package:flutter/material.dart';
// stream_chat_flutter ships older versions of these AI widgets; use the ones
// from stream_chat_flutter_ai.
import 'package:stream_chat_flutter/stream_chat_flutter.dart'
    hide StreamingMessageView, AITypingIndicatorView, TypewriterState, TypewriterController, StreamTypewriterBuilder;
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import 'agent_steps.dart';
import 'ai_message_item.dart';
import 'typing_state_handler.dart';

/// The message list and AI typing indicator for [channel].
///
/// Give it a key derived from the channel (e.g. `ValueKey(channel.cid)`), so
/// switching channels creates a fresh [TypingStateHandler] and
/// [ConversationAgentSteps].
class ConversationView extends StatefulWidget {
  const ConversationView({super.key, required this.channel, this.createAgentSteps, this.onGeneratingChanged});

  final Channel channel;

  /// Creates what answers this conversation's tool calls, once per view.
  final ConversationAgentSteps Function(Channel channel)? createAgentSteps;

  /// Called when the assistant starts replying, and again once its reply is
  /// fully on screen, so the composer can show a stop button in between.
  final ValueChanged<bool>? onGeneratingChanged;

  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  late final _typingStateHandler = TypingStateHandler(channel: widget.channel)..addListener(_onTypingStateChanged);
  var _typewriterState = TypewriterState.idle;

  /// The reply that keeps the stop button up until it is fully on screen. The
  /// typewriter usually trails the backend, so this outlives the
  /// `ai_indicator.clear`.
  String? _revealingReplyId;

  late final _agentSteps = widget.createAgentSteps?.call(widget.channel);
  StreamSubscription<List<Message>>? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    final agentSteps = _agentSteps;
    if (agentSteps != null) {
      // Every update, so a call that starts waiting mid-reply runs too.
      _messagesSubscription = widget.channel.state?.messagesStream.listen(agentSteps.handle);
    }
  }

  @override
  void dispose() {
    unawaited(_messagesSubscription?.cancel());
    _agentSteps?.dispose();
    _typingStateHandler.dispose();
    super.dispose();
  }

  void _onTypingStateChanged() {
    final handler = _typingStateHandler;
    if (handler.isBusy) {
      _revealingReplyId = handler.messageId;
    } else if (handler.value == AITypingState.error || handler.wasStopped || !_hasTextToReveal(_revealingReplyId)) {
      // Nothing left to wait for: `onFinished` never fires for an empty reply.
      _revealingReplyId = null;
    }
    _reportGenerating();
  }

  bool _hasTextToReveal(String? messageId) {
    if (messageId == null) return false;
    final messages = widget.channel.state?.messages ?? const <Message>[];
    final reply = messages.where((message) => message.id == messageId).firstOrNull;
    return reply?.text?.isNotEmpty ?? false;
  }

  void _onReplyFinished(String messageId) {
    if (messageId != _revealingReplyId || _typingStateHandler.isBusy) return;
    _revealingReplyId = null;
    _reportGenerating();
  }

  void _reportGenerating() {
    widget.onGeneratingChanged?.call(_typingStateHandler.isBusy || _revealingReplyId != null);
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
                  // Rebuilt on every state change, so `expectMoreText` drops
                  // as soon as the backend is done.
                  return ValueListenableBuilder(
                    valueListenable: _typingStateHandler,
                    builder: (context, _, _) => AIMessageItem(
                      message: message,
                      expectMoreText: _typingStateHandler.isBusy && message.id == _typingStateHandler.messageId,
                      onFinished: () => _onReplyFinished(message.id),
                      onTypewriterStateChanged: _onTypewriterStateChanged,
                      approver: _agentSteps?.approver,
                    ),
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
    final colors = Theme.of(context).colorScheme;
    // `error` wins over a still-running typewriter: the reply won't finish.
    final indicatorText = switch ((typewriterState, aiTypingState)) {
      (_, AITypingState.error) => 'Something went wrong. Please try again.',
      (TypewriterState.typing, _) || (_, AITypingState.generating) => 'Generating',
      (_, AITypingState.thinking) => 'Thinking',
      (_, AITypingState.checkingSources) => 'Checking sources',
      _ => null,
    };
    final isError = aiTypingState == AITypingState.error;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: switch (indicatorText) {
        final text? => Container(
          key: ValueKey(text),
          width: double.infinity,
          color: isError ? colors.errorContainer : colors.surfaceContainerHighest,
          padding: const EdgeInsets.all(8),
          child: isError
              ? Text(text, style: TextStyle(color: colors.onErrorContainer, fontSize: 16))
              : AITypingIndicatorView(
                  text: text,
                  textStyle: TextStyle(color: colors.onSurface, fontSize: 16),
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
