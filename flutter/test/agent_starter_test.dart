import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/agent_service.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/agent_starter.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

class _FakeAgentService extends AgentService {
  final started = <String>[];
  final registered = <String>[];

  @override
  Future<void> startAgent(String channelId, {String? platform}) async => started.add(channelId);

  @override
  Future<void> registerTools(String channelId, List<Map<String, Object?>> tools) async => registered.add(channelId);
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
  });
}
