import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/agent_service.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/agent_steps.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/client_tools.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

/// Answers every request with `{}` and keeps it for the test to inspect.
class _RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  /// The status every response has; 500 makes each request fail.
  var statusCode = 200;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '{}',
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _identity = AIClientIdentity(userId: 'luke', clientId: 'install-1');

/// An AI reply carrying one `ai_tool_call` step, as the agent would write it.
Message _replyWithToolCall(Map<String, Object?> step) => Message(
  id: 'reply-1',
  attachments: [
    Attachment.fromJson({'type': 'ai_tool_call', 'id': 'attachment-1', ...step}),
  ],
);

void main() {
  late _RecordingAdapter adapter;
  late List<String> errors;
  late ConversationAgentSteps steps;

  ConversationAgentSteps createSteps() => ConversationAgentSteps(
    channelId: 'chat-1',
    identity: _identity,
    tools: [LocalTimeTool(clock: () => DateTime(2026, 10, 20, 9, 30))],
    agentService: AgentService(dio: Dio()..httpClientAdapter = adapter),
    onError: errors.add,
  );

  setUp(() {
    adapter = _RecordingAdapter();
    errors = [];
    steps = createSteps();
  });

  tearDown(() => steps.dispose());

  final awaitingApproval = {
    'id': 'call_1',
    'name': 'getLocalTime',
    'status': 'awaiting_approval',
    'target_user_id': 'luke',
    'approval': {'title': 'Share your local time?'},
  };

  final awaitingClient = {
    'id': 'call_2',
    'name': 'getLocalTime',
    'executor': 'client',
    'status': 'awaiting_client',
    'target_user_id': 'luke',
    'target_client_id': 'install-1',
  };

  test("a message's attachments parse into steps, keeping the step's own id", () {
    final parts = _replyWithToolCall({'id': 'call_1', 'name': 'getLocalTime', 'status': 'running'}).agentSteps;

    expect(parts, hasLength(1));
    expect(parts.single.toolCall?.id, 'call_1');
    expect(parts.single.toolCall?.name, 'getLocalTime');
  });

  test('an approval is posted to /tool-approval', () async {
    final call = _replyWithToolCall({
      'id': 'call_1',
      'name': 'getLocalTime',
      'status': 'awaiting_approval',
      'target_user_id': 'luke',
      'approval': {'title': 'Share your local time?'},
    }).agentSteps.single.toolCall!;

    steps.approver.answer(call, AIToolApprovalDecision.allowed);
    await pumpEventQueue();

    expect(adapter.requests.single.path, '/tool-approval');
    expect(adapter.requests.single.data, {
      'channel_id': 'chat-1',
      'tool_call_id': 'call_1',
      'user_id': 'luke',
      'client_id': 'install-1',
      'decision': 'allowed',
    });
    expect(steps.approver.stateOf(call), const AIToolApprovalSent(AIToolApprovalDecision.allowed));
  });

  test('a client tool call for this install runs once and posts its result', () async {
    final reply = _replyWithToolCall({
      'id': 'call_2',
      'name': 'getLocalTime',
      'executor': 'client',
      'status': 'awaiting_client',
      'target_user_id': 'luke',
      'target_client_id': 'install-1',
    });

    // Every update of the reply is handed over; the call still runs once.
    steps
      ..handle([reply])
      ..handle([reply]);
    await steps.runner.whenIdle();

    expect(adapter.requests.single.path, '/tool-results');
    expect(adapter.requests.single.data, {
      'channel_id': 'chat-1',
      'tool_call_id': 'call_2',
      'client_id': 'install-1',
      'output': {
        'local_time': DateTime(2026, 10, 20, 9, 30).toIso8601String(),
        'time_zone': DateTime(2026, 10, 20, 9, 30).timeZoneName,
        'utc_offset_minutes': DateTime(2026, 10, 20, 9, 30).timeZoneOffset.inMinutes,
      },
      'summary': 'Shared the local time',
    });
  });

  test('a client tool call for another install is left alone', () async {
    steps.handle([
      _replyWithToolCall({
        'id': 'call_3',
        'name': 'getLocalTime',
        'executor': 'client',
        'status': 'awaiting_client',
        'target_user_id': 'luke',
        'target_client_id': 'install-2',
      }),
    ]);
    await steps.runner.whenIdle();

    expect(adapter.requests, isEmpty);
  });

  test('a failed approval turns Failed and is reported', () async {
    adapter.statusCode = 500;
    final call = _replyWithToolCall(awaitingApproval).agentSteps.single.toolCall!;

    steps.approver.answer(call, AIToolApprovalDecision.allowed);
    await pumpEventQueue();

    expect(steps.approver.stateOf(call), isA<AIToolApprovalFailed>());
    expect(errors, hasLength(1));
  });

  testWidgets('an approval whose step never changes can be answered again', (tester) async {
    final call = _replyWithToolCall(awaitingApproval).agentSteps.single.toolCall!;

    steps.approver.answer(call, AIToolApprovalDecision.allowed);
    await tester.pump(const Duration(seconds: 1));
    expect(steps.approver.stateOf(call), isA<AIToolApprovalSent>());

    await tester.pump(const Duration(seconds: 30));
    expect(steps.approver.stateOf(call), isA<AIToolApprovalFailed>());
  });

  testWidgets('a result that cannot be sent is reported once, without running the tool again', (tester) async {
    adapter.statusCode = 500;
    // The runner also reports each give-up to FlutterError, which would fail
    // the test.
    final onError = FlutterError.onError;
    FlutterError.onError = (_) {};

    final reply = _replyWithToolCall(awaitingClient);

    steps.handle([reply]);
    await tester.pump(const Duration(seconds: 10));
    expect(errors, hasLength(1));
    final attempts = adapter.requests.length;
    expect(attempts, 3);

    // The next update of the reply sends the kept result again, once.
    steps.handle([reply]);
    await tester.pump(const Duration(seconds: 10));
    expect(adapter.requests, hasLength(attempts * 2));
    expect(errors, hasLength(1));

    // Nothing more without an update.
    await tester.pump(const Duration(minutes: 1));
    expect(adapter.requests, hasLength(attempts * 2));
    FlutterError.onError = onError;
  });

  test('a reopened conversation keeps its steps, so a waiting call runs once', () async {
    final client = StreamChatClient('test-key');
    addTearDown(client.dispose);
    final channel = client.channel('messaging', id: 'chat-1');
    var created = 0;
    final byChannel = AgentStepsByChannel((_) {
      created++;
      return createSteps();
    });
    addTearDown(byChannel.dispose);
    final reply = _replyWithToolCall(awaitingClient);

    final first = byChannel.of(channel)..handle([reply]);
    await first.runner.whenIdle();
    // Opened again, with the call's step not updated yet.
    final second = byChannel.of(channel)..handle([reply]);
    await second.runner.whenIdle();

    expect(second, same(first));
    expect(created, 1);
    expect(adapter.requests, hasLength(1));
  });
}
