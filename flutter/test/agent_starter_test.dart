import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/agent_service.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/agent_starter.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

class _FakeAgentService extends AgentService {
  final started = <String>[];
  final registered = <String>[];

  /// Thrown by the next start or registration, then cleared.
  Object? startError;
  Object? registerError;

  /// Completed by the test to let a start finish.
  Completer<void>? startGate;

  @override
  Future<void> startAgent(String channelId, {String? platform}) async {
    await startGate?.future;
    if (startError case final error?) {
      startError = null;
      throw error;
    }
    started.add(channelId);
  }

  @override
  Future<void> registerTools(String channelId, List<Map<String, Object?>> tools) async {
    if (registerError case final error?) {
      registerError = null;
      throw error;
    }
    registered.add(channelId);
  }
}

void main() {
  group('hasAgentWatcher', () {
    test('finds the agent among the watchers', () {
      expect(hasAgentWatcher([User(id: 'luke'), User(id: 'ai-bot-chat-1')]), isTrue);
    });

    test('is false without one', () {
      expect(hasAgentWatcher([User(id: 'luke')]), isFalse);
      expect(hasAgentWatcher(const []), isFalse);
    });
  });

  group('AgentStarter', () {
    late StreamChatClient client;
    late Channel channel;
    late _FakeAgentService service;
    late List<String> errors;

    AgentStarter starter({required Future<bool> Function(Channel) watching}) => AgentStarter(
      agentService: service,
      toolPayloads: () => const [],
      onError: errors.add,
      checkAgentWatching: watching,
    );

    setUp(() {
      client = StreamChatClient('test-key');
      channel = client.channel('messaging', id: 'chat-1');
      service = _FakeAgentService();
      errors = [];
    });

    tearDown(() => client.dispose());

    test('skips /start-ai-agent when an agent is already watching', () async {
      final agents = starter(watching: (_) async => true);

      expect(await agents.ensureStarted(channel), isTrue);
      expect(service.started, isEmpty);
      // The tools are still registered, in case this build has new ones.
      expect(service.registered, ['chat-1']);
    });

    test('starts the agent when none is watching', () async {
      final agents = starter(watching: (_) async => false);

      expect(await agents.ensureStarted(channel), isTrue);
      expect(service.started, ['chat-1']);
    });

    test('starts the agent when the check fails', () async {
      final agents = starter(watching: (_) async => throw StateError('offline'));

      expect(await agents.ensureStarted(channel), isTrue);
      expect(service.started, ['chat-1']);
      expect(errors, isEmpty);
    });

    test("doesn't check a channel that was just created", () async {
      final agents = starter(watching: (_) async => fail('should not check'));

      await agents.ensureStarted(channel, checkPresence: false);
      expect(service.started, ['chat-1']);
    });

    test('concurrent callers share one start', () async {
      var checks = 0;
      final agents = starter(
        watching: (_) async {
          checks++;
          return false;
        },
      );

      await Future.wait([agents.ensureStarted(channel), agents.ensureStarted(channel)]);
      expect(checks, 1);
      expect(service.started, ['chat-1']);
    });

    test('a failed start reports once and is retried on the next call', () async {
      final agents = starter(watching: (_) async => false);
      service.startError = StateError('offline');

      expect(await agents.ensureStarted(channel), isFalse);
      expect(errors, hasLength(1));
      expect(service.registered, isEmpty);

      expect(await agents.ensureStarted(channel), isTrue);
      expect(service.started, ['chat-1']);
      expect(errors, hasLength(1));
    });

    test('a failed registration still runs the agent and is retried on the next call', () async {
      var watching = false;
      final agents = starter(watching: (_) async => watching);
      service.registerError = StateError('offline');

      expect(await agents.ensureStarted(channel), isTrue);
      expect(errors, hasLength(1));
      expect(service.registered, isEmpty);

      watching = true;
      expect(await agents.ensureStarted(channel), isTrue);
      expect(service.registered, ['chat-1']);
      // Registered now, so not again.
      await agents.ensureStarted(channel);
      expect(service.registered, ['chat-1']);
    });

    test('starts again once the agent the backend had is gone', () async {
      var watching = false;
      final agents = starter(watching: (_) async => watching);

      await agents.ensureStarted(channel);
      watching = true;
      await agents.ensureStarted(channel);
      expect(service.started, ['chat-1']);

      // The backend restarted, or stopped an idle agent.
      watching = false;
      expect(await agents.ensureStarted(channel), isTrue);
      expect(service.started, ['chat-1', 'chat-1']);
      // A new agent may have forgotten the tools.
      expect(service.registered, ['chat-1', 'chat-1']);
    });

    test('a background start leaves its errors to the next caller', () async {
      final agents = starter(watching: (_) async => false);
      service
        ..startGate = Completer()
        ..startError = StateError('offline');

      final background = agents.ensureStarted(channel, checkPresence: false, reportErrors: false);
      final send = agents.ensureStarted(channel);
      service.startGate!.complete();

      expect(await background, isFalse);
      expect(await send, isFalse);
      expect(errors, hasLength(1));
    });

    test('notifies while a channel is starting', () async {
      final agents = starter(watching: (_) async => false);
      final starting = <bool>[];
      agents.addListener(() => starting.add(agents.isStarting('chat-1')));
      service.startGate = Completer();

      final start = agents.ensureStarted(channel);
      await pumpEventQueue();
      expect(agents.isStarting('chat-1'), isTrue);
      service.startGate!.complete();
      await start;

      expect(agents.isStarting('chat-1'), isFalse);
      expect(starting, [true, false]);
    });

    test("doesn't notify for an agent that is already there", () async {
      final agents = starter(watching: (_) async => true);
      await agents.ensureStarted(channel);

      var notified = false;
      agents.addListener(() => notified = true);
      await agents.ensureStarted(channel);

      expect(notified, isFalse);
    });

    test('disposing during a start is safe', () async {
      final agents = starter(watching: (_) async => false);
      service.startGate = Completer();

      final start = agents.ensureStarted(channel);
      await pumpEventQueue();
      agents.dispose();
      service.startGate!.complete();

      expect(await start, isTrue);
    });

    test('a channel without an id is reported', () async {
      final agents = starter(watching: (_) async => false);

      expect(await agents.ensureStarted(client.channel('messaging')), isFalse);
      expect(errors, hasLength(1));
    });
  });
}
