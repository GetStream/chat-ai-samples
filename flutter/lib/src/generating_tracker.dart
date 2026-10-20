import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import 'typing_state_handler.dart';

/// Whether the composer should offer stop: from when the backend starts a
/// reply until that reply is fully on screen. The typewriter usually trails
/// the backend, so this outlives the `ai_indicator.clear`.
class GeneratingTracker {
  GeneratingTracker({
    required this.typingState,
    required this.replyText,
    required this.onChanged,
    required this.typingSpeed,
  }) {
    typingState.addListener(_onTypingStateChanged);
  }

  final TypingStateHandler typingState;

  /// The current text of the message with the given id, if it is loaded.
  final String? Function(String messageId) replyText;

  final ValueChanged<bool> onChanged;

  /// The reply's per-character typing speed, to size the fallback.
  final Duration typingSpeed;

  String? _revealingReplyId;
  Timer? _fallback;

  /// Whether stop should show.
  bool get isGenerating => typingState.isBusy || _revealingReplyId != null;

  void _onTypingStateChanged() {
    _cancelFallback();
    if (typingState.isBusy) {
      _revealingReplyId = typingState.messageId;
    } else if (typingState.value == AITypingState.error || typingState.wasStopped) {
      _revealingReplyId = null;
    } else if (_revealingReplyId case final id?) {
      final text = replyText(id) ?? '';
      if (text.isEmpty) {
        // `onFinished` never fires for an empty reply.
        _revealingReplyId = null;
      } else {
        // `onFinished` never fires if the reply isn't built (a lazy list
        // scrolled away), so give up once typing out all of it, from the
        // start, would surely be done.
        _fallback = Timer(typingSpeed * text.length + const Duration(seconds: 2), () => _finish(id));
      }
    }
    _report();
  }

  /// Called by the reply's `onFinished`. Ignored for an older reply, or while
  /// the backend may add more.
  void replyFinished(String messageId) {
    if (!typingState.isBusy) _finish(messageId);
  }

  /// Called when the reply's item leaves the tree, after which its
  /// `onFinished` can't come.
  void replyDisposed(String messageId) => replyFinished(messageId);

  void _finish(String messageId) {
    if (messageId != _revealingReplyId) return;
    _revealingReplyId = null;
    _cancelFallback();
    _report();
  }

  void _report() => onChanged(isGenerating);

  void _cancelFallback() {
    _fallback?.cancel();
    _fallback = null;
  }

  void dispose() {
    _cancelFallback();
    typingState.removeListener(_onTypingStateChanged);
  }
}
