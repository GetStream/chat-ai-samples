import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// Creates the next new conversation's channel while its first message is
/// still being typed, so sending doesn't wait for the channel or the agent.
///
/// As in the iOS sample, one draft is created once [minLength] characters are
/// typed, and kept until a message is sent in it: clearing the text, starting
/// another new chat or opening an old one reuses it rather than creating more.
class DraftChannel {
  DraftChannel({required this.create, this.minLength = 5, this.delay = const Duration(milliseconds: 300)});

  /// Creates and watches a new channel, and starts its agent.
  final Future<Channel> Function() create;

  /// How many characters (ignoring surrounding whitespace) make a draft worth
  /// creating.
  final int minLength;

  /// How long the text must stay long enough first, so a few characters typed
  /// and deleted again don't create a channel.
  final Duration delay;

  Timer? _timer;
  Future<Channel>? _draft;

  /// Whether a draft exists or is being created.
  bool get hasDraft => _draft != null;

  /// Call with the new-chat composer's text whenever it changes.
  void onTextChanged(String text) {
    if (_draft != null) return;
    if (text.trim().length < minLength) {
      _cancelTimer();
    } else {
      _timer ??= Timer(delay, _prepare);
    }
  }

  void _prepare() {
    _timer = null;
    final draft = _draft = create();
    draft.then<void>(
      (_) {},
      onError: (Object error) {
        // Forgotten, so the next keystroke or send tries again.
        debugPrint('Failed to prepare the next conversation: $error');
        if (identical(_draft, draft)) _draft = null;
      },
    );
  }

  /// Hands over the draft for a first message, or creates a channel if there
  /// is none. The next new chat gets a draft of its own.
  Future<Channel> take() {
    _cancelTimer();
    final draft = _draft;
    _draft = null;
    if (draft == null) return create();
    // The draft failed in the background: try once more, now that the user
    // is waiting and will see an error.
    return draft.catchError((Object _) => create());
  }

  /// Keeps [channel], whose first message couldn't be sent, as the draft for
  /// the next try, unless there is a draft already.
  void restore(Channel channel) {
    if (_draft != null) return;
    _cancelTimer();
    _draft = Future.value(channel);
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => _cancelTimer();
}
