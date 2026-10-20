import 'dart:async';

import 'package:flutter/material.dart';
// stream_chat_flutter ships older versions of these AI widgets; use the ones
// from stream_chat_flutter_ai.
import 'package:stream_chat_flutter/stream_chat_flutter.dart'
    hide StreamingMessageView, AITypingIndicatorView, TypewriterState, TypewriterController, StreamTypewriterBuilder;
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import 'a2ui.dart';
import 'agent_steps.dart';
import 'ai_message_item.dart';
import 'generating_tracker.dart';
import 'typing_state_handler.dart';

/// The message list and AI typing indicator for [channel].
///
/// Give it a key derived from the channel (e.g. `ValueKey(channel.cid)`), so
/// switching channels creates a fresh [TypingStateHandler].
class ConversationView extends StatefulWidget {
  const ConversationView({
    super.key,
    required this.channel,
    this.agentSteps,
    this.onGeneratingChanged,
    required this.onSendMessage,
  });

  final Channel channel;

  /// Answers this conversation's tool calls. Owned by the caller, so it
  /// outlives this view and a reopened conversation doesn't rerun a call.
  final ConversationAgentSteps? agentSteps;

  /// Called when the assistant starts replying, and again once its reply is
  /// fully on screen, so the composer can show a stop button in between.
  final ValueChanged<bool>? onGeneratingChanged;

  /// Sends a message the view built itself, such as an A2UI action. Throws if
  /// the message couldn't be sent; the view shows the error.
  final Future<void> Function(Channel channel, Message message) onSendMessage;

  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  late final _typingStateHandler = TypingStateHandler(channel: widget.channel);
  late final GeneratingTracker _generating;
  var _typewriterState = TypewriterState.idle;
  StreamSubscription<List<Message>>? _messagesSubscription;

  /// Outlives the message items, so form input survives scrolling.
  final _surfaces = A2uiSurfaceStore();

  late final _actions = A2uiActionSender(
    send: (message) => widget.onSendMessage(widget.channel, message),
    onError: (error) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(error)));
    },
  );

  @override
  void initState() {
    super.initState();
    _generating = GeneratingTracker(
      typingState: _typingStateHandler,
      replyText: _replyText,
      onChanged: (isGenerating) => widget.onGeneratingChanged?.call(isGenerating),
      typingSpeed: replyTypingSpeed,
    );
    final agentSteps = widget.agentSteps;
    if (agentSteps != null) {
      // Every update, so a call that starts waiting mid-reply runs too.
      _messagesSubscription = widget.channel.state?.messagesStream.listen(agentSteps.handle);
    }
  }

  @override
  void dispose() {
    unawaited(_messagesSubscription?.cancel());
    _generating.dispose();
    _surfaces.dispose();
    _typingStateHandler.dispose();
    super.dispose();
  }

  String? _replyText(String messageId) {
    final messages = widget.channel.state?.messages ?? const <Message>[];
    return messages.where((message) => message.id == messageId).firstOrNull?.text;
  }

  /// Items leave the tree while it is locked, so report after the frame.
  void _onReplyDisposed(String messageId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _generating.replyDisposed(messageId);
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
              // Not a spinner: a first message that fails leaves it empty.
              builders: StreamMessageListViewBuilders(empty: (context) => const SizedBox.shrink()),
              messageBuilder: (context, message, defaultProps) {
                if (message.isAI) {
                  // Rebuilt on every state change, so `expectMoreText` drops
                  // as soon as the backend is done.
                  return _OnDispose(
                    onDispose: () => _onReplyDisposed(message.id),
                    child: ValueListenableBuilder(
                      valueListenable: _typingStateHandler,
                      builder: (context, _, _) => AIMessageItem(
                        message: message,
                        expectMoreText: _typingStateHandler.isBusy && message.id == _typingStateHandler.messageId,
                        onFinished: () => _generating.replyFinished(message.id),
                        onTypewriterStateChanged: _onTypewriterStateChanged,
                        approver: widget.agentSteps?.approver,
                        surface: _surfaces.surfaceOf(message),
                        onSurfaceAction: (action) => unawaited(_actions.handle(action, sourceMessageId: message.id)),
                      ),
                    ),
                  );
                }
                // An A2UI action shows what the user did, not what the model reads.
                final displayed = displayedA2uiMessage(message);
                return DefaultStreamMessageItem(
                  props: identical(displayed, message) ? defaultProps : defaultProps.copyWith(message: displayed),
                );
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

/// Calls [onDispose] when [child] leaves the tree.
class _OnDispose extends StatefulWidget {
  const _OnDispose({required this.onDispose, required this.child});

  final VoidCallback onDispose;
  final Widget child;

  @override
  State<_OnDispose> createState() => _OnDisposeState();
}

class _OnDisposeState extends State<_OnDispose> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
