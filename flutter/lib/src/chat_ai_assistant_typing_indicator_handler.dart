import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:stream_chat/stream_chat.dart';

class _NullConst {
  const _NullConst();
}

const _nullConst = _NullConst();

class AITypingStateValue {
  const AITypingStateValue({
    this.isBotPresent = false,
    this.aiMessageId,
    this.aiTypingState = AITypingState.idle,
  });

  final bool isBotPresent;
  final String? aiMessageId;
  final AITypingState aiTypingState;

  /// Creates a copy of this [AITypingStateValue] with the given fields replaced
  /// by the new values.
  AITypingStateValue copyWith({
    bool? isBotPresent,
    Object? aiMessageId = _nullConst,
    AITypingState? aiTypingState,
  }) {
    return AITypingStateValue(
      isBotPresent: isBotPresent ?? this.isBotPresent,
      // This was done to support nullability of aiMessageId in copyWith.
      aiMessageId: switch (aiMessageId == _nullConst) {
        true => this.aiMessageId,
        false => aiMessageId as String?,
      },
      aiTypingState: aiTypingState ?? this.aiTypingState,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AITypingStateValue &&
        other.isBotPresent == isBotPresent &&
        other.aiMessageId == aiMessageId &&
        other.aiTypingState == aiTypingState;
  }

  @override
  int get hashCode =>
      isBotPresent.hashCode ^ aiMessageId.hashCode ^ aiTypingState.hashCode;
}

class ChatAIAssistantTypingStateHandler
    extends ValueNotifier<AITypingStateValue> {
  ChatAIAssistantTypingStateHandler({
    required this.channel,
  }) : super(const AITypingStateValue()) {
    _startListeningWatchersStream();
    _startListeningAiTypingStateStream();
  }

  final Channel channel;
  static const _botUserId = 'ai-bot';

  StreamSubscription<List<User>>? _channelWatchersSubscription;
  void _startListeningWatchersStream() async {
    // Fetch the watchers list to get the initial state.
    //
    // Note: This is a workaround to get the initial state of the watchers.
    // This is needed because the watchersStream doesn't emit the initial state.
    final channelState = await channel.query(
      watchersPagination: const PaginationParams(limit: 5, offset: 0),
    );

    _updateBotPresenceFromWatchers(channelState.watchers);

    // Start listening to the channel's watchers stream.
    _channelWatchersSubscription = channel.state?.watchersStream.listen(
      _updateBotPresenceFromWatchers,
    );
  }

  StreamSubscription<Event>? _aiTypingStateSubscription;
  void _startListeningAiTypingStateStream() {
    _aiTypingStateSubscription = channel.on().listen(
      (event) {
        final state = switch (event.type) {
          EventType.aiIndicatorUpdate => (event.aiState, event.messageId),
          EventType.aiIndicatorClear => (AITypingState.idle, null),
          EventType.aiIndicatorStop => (AITypingState.idle, null),
          _ => null,
        };

        if (state == null) return;

        value = value.copyWith(
          aiTypingState: state.$1,
          aiMessageId: state.$2,
        );
      },
    );
  }

  void _updateBotPresenceFromWatchers(List<User>? watchers) {
    if (watchers == null) return;

    value = value.copyWith(
      isBotPresent: watchers
          .where((it) => it.id.startsWith(_botUserId))
          .any((it) => it.online),
    );
  }

  @override
  void dispose() {
    _aiTypingStateSubscription?.cancel();
    _channelWatchersSubscription?.cancel();
    super.dispose();
  }
}
