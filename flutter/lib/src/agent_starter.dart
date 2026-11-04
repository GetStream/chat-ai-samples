import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import 'agent_service.dart';

/// Whether an AI agent is among [watchers]. The backends watch a channel as
/// `ai-bot-<channel id>` while their agent runs in it.
bool hasAgentWatcher(Iterable<User> watchers) => watchers.any((user) => user.id.startsWith('ai-bot'));

/// Asks Stream who is watching [channel], and whether an AI agent is.
Future<bool> isAgentWatching(Channel channel) async {
  final state = await channel.query(watchersPagination: const PaginationParams(limit: 30));
  return hasAgentWatcher(state.watchers ?? const []);
}

/// Starts the AI agent for a channel when none is watching it, and registers
/// the client tools with it.
///
/// Notifies when a channel starts or stops [isStarting], for a progress hint.
class AgentStarter extends ChangeNotifier {
  AgentStarter({
    required this.agentService,
    required this.toolPayloads,
    required this.onError,
    this.platform,
    this.checkAgentWatching = isAgentWatching,
  });

  final AgentService agentService;

  /// The client tools to register, from `AIToolRegistry.registrationPayloads`.
  final List<Map<String, Object?>> Function() toolPayloads;

  /// Shows the user why the assistant won't (fully) work.
  final ValueChanged<String> onError;

  /// The AI platform the backend should use.
  final String? platform;

  /// Checked on every [ensureStarted], so an agent the backend dropped (a
  /// restart, an idle stop) is started again.
  final Future<bool> Function(Channel channel) checkAgentWatching;

  /// The attempt in flight per channel, shared by everything that needs the
  /// agent: the send path waits on the one the draft started.
  final _attempts = <String, _Attempt>{};

  /// Channels this starter started an agent in, trusted when a check fails.
  final _started = <String>{};
  final _toolsRegistered = <String>{};
  final _starting = <String>{};
  var _disposed = false;

  /// Whether the agent of the channel with [channelId] is still starting.
  bool isStarting(String? channelId) => _starting.contains(channelId);

  /// Returns whether the agent is running. Concurrent callers share one
  /// attempt, whose errors the first caller with [reportErrors] reports.
  ///
  /// Pass `checkPresence: false` for a channel that was just created, which
  /// can't have an agent yet.
  Future<bool> ensureStarted(Channel channel, {bool checkPresence = true, bool reportErrors = true}) async {
    final channelId = channel.id;
    if (channelId == null) {
      if (reportErrors) onError("Couldn't start the assistant: the conversation has no id yet.");
      return false;
    }

    final attempt = _attempts[channelId] ??= _Attempt(_ensure(channel, channelId, checkPresence: checkPresence));
    final (:running, :errors) = await attempt.result;
    if (identical(_attempts[channelId], attempt)) _attempts.remove(channelId);
    if (reportErrors && !attempt.reported && !_disposed) {
      attempt.reported = true;
      errors.forEach(onError);
    }
    return running;
  }

  Future<_Result> _ensure(Channel channel, String channelId, {required bool checkPresence}) async {
    if (!checkPresence || !await _isAgentWatching(channel, channelId)) {
      _setStarting(channelId, true);
      try {
        await agentService.startAgent(channelId, platform: platform);
        _started.add(channelId);
        // A new agent may come from a restarted backend that forgot them.
        _toolsRegistered.remove(channelId);
      } catch (e) {
        debugPrint('Failed to start the AI agent: $e');
        _started.remove(channelId);
        _setStarting(channelId, false);
        // Without this, the app looks fine but the assistant never replies.
        return (running: false, errors: ["Couldn't start the assistant. ${describeBackendError(e)}"]);
      }
    }

    final errors = <String>[];
    if (!_toolsRegistered.contains(channelId)) {
      _setStarting(channelId, true);
      try {
        await agentService.registerTools(channelId, toolPayloads());
        _toolsRegistered.add(channelId);
      } catch (e) {
        // Not remembered, so the next send tries again.
        debugPrint('Failed to register client tools: $e');
        errors.add(
          "The assistant is running, but can't use app actions like switching the theme. "
          '${describeBackendError(e)}',
        );
      }
    }
    _setStarting(channelId, false);
    return (running: true, errors: errors);
  }

  /// A failed check trusts an agent this starter started, and otherwise
  /// starts one, as if none were there.
  Future<bool> _isAgentWatching(Channel channel, String channelId) async {
    try {
      return await checkAgentWatching(channel);
    } catch (e) {
      debugPrint('Failed to check for a running AI agent: $e');
      return _started.contains(channelId);
    }
  }

  void _setStarting(String channelId, bool starting) {
    if (_disposed) return;
    final changed = starting ? _starting.add(channelId) : _starting.remove(channelId);
    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

typedef _Result = ({bool running, List<String> errors});

class _Attempt {
  _Attempt(this.result);

  final Future<_Result> result;
  var reported = false;
}
