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

  void _onEvent(Event event) {
    final state = switch (event.type) {
      // On failure the backend sends `ai_indicator.update` with
      // `AI_STATE_ERROR`, not a clear or stop, so `error` also ends a reply.
      EventType.aiIndicatorUpdate => event.aiState,
      EventType.aiIndicatorClear || EventType.aiIndicatorStop => AITypingState.idle,
      _ => null,
    };
    if (state != null) value = state;
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
