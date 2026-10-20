import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// Tracks what the AI assistant in [channel] is doing, from the
/// `ai_indicator.*` events the backend sends.
class TypingStateHandler extends ValueNotifier<AITypingState> {
  TypingStateHandler({required Channel channel}) : super(AITypingState.idle) {
    _subscription = channel.on().listen(_onEvent);
  }

  late final StreamSubscription<Event> _subscription;

  /// The AI message the latest `ai_indicator.*` event was about. Kept once the
  /// backend goes idle, since that reply may still be typing out.
  ///
  /// The backends send `message_id` with every update and clear; only a stop,
  /// which comes from a client, may lack one.
  String? get messageId => _messageId;
  String? _messageId;

  /// Whether someone pressed stop since the latest reply started. Survives the
  /// `ai_indicator.clear` the backend sends after stopping, and late updates
  /// of the stopped reply are ignored.
  bool get wasStopped => _wasStopped;
  var _wasStopped = false;

  /// Whether the backend is still producing a reply.
  bool get isBusy => switch (value) {
    AITypingState.thinking || AITypingState.checkingSources || AITypingState.generating => true,
    _ => false,
  };

  void _onEvent(Event event) {
    final state = switch (event.type) {
      // On failure the backend sends `ai_indicator.update` with
      // `AI_STATE_ERROR`, not a clear or stop, so `error` also ends a reply.
      EventType.aiIndicatorUpdate => event.aiState,
      EventType.aiIndicatorClear || EventType.aiIndicatorStop => AITypingState.idle,
      _ => null,
    };
    if (state == null) return;
    final messageId = event.messageId ?? _messageId;
    if (messageId != _messageId) {
      _messageId = messageId;
      _wasStopped = false;
    } else if (_wasStopped && event.type == EventType.aiIndicatorUpdate) {
      return;
    }
    if (event.type == EventType.aiIndicatorStop) _wasStopped = true;
    // A repeated state can still carry a new message or stop flag.
    if (value == state) notifyListeners();
    value = state;
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
