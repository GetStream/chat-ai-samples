import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/agent_service.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/agent_steps.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/client_tools.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

/// Answers every request with `{}` and keeps it for the test to inspect.
class _RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '{}',
      200,
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
  late ConversationAgentSteps steps;

  setUp(() {
    adapter = _RecordingAdapter();
    steps = ConversationAgentSteps(
      channelId: 'chat-1',
      identity: _identity,
      tools: [LocalTimeTool(clock: () => DateTime(2026, 10, 20, 9, 30))],
      agentService: AgentService(dio: Dio()..httpClientAdapter = adapter),
    );
  });

  tearDown(() => steps.dispose());

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
}
