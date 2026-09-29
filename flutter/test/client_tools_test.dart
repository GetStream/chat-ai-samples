import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/client_tools.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

AIToolInvocation _invocation(Map<String, Object?> args) {
  final event = Event.fromJson({
    'type': kClientToolInvocationEventType,
    'cid': 'messaging:general',
    'message_id': 'msg-1',
    'tool': {'name': 'setThemeMode', 'description': 'Switch theme'},
    'args': args,
  });
  return AIToolInvocation.tryParse(event.toClientToolPayload())!;
}

void main() {
  test('a custom_client_tool_invocation event parses into an invocation', () {
    final invocation = _invocation({'mode': 'dark'});

    expect(invocation.tool.name, 'setThemeMode');
    expect(invocation.channelId, 'messaging:general');
    expect(invocation.messageId, 'msg-1');
    expect(invocation.args['mode'], 'dark');
  });

  group('SetThemeModeTool', () {
    for (final mode in ThemeMode.values) {
      test('switches to ${mode.name}', () async {
        ThemeMode? received;
        final registry = AIToolRegistry()
          ..register(SetThemeModeTool(onChange: (mode) => received = mode));

        expect(await registry.dispatch(_invocation({'mode': mode.name})), isTrue);
        expect(received, mode);
      });
    }

    test('ignores a mode outside the schema', () {
      final tool = SetThemeModeTool(onChange: (_) => fail('should not switch'));

      expect(tool.handleInvocation(_invocation({'mode': 'purple'})), isEmpty);
      expect(tool.handleInvocation(_invocation({})), isEmpty);
    });
  });

  group('ClientToolListener', () {
    late StreamChatClient client;

    setUp(() => client = StreamChatClient('test-key'));
    tearDown(() => client.dispose());

    Event invocationEvent({Map<String, Object?>? tool, Object? args = const {'mode': 'dark'}}) =>
        Event.fromJson({
          'type': kClientToolInvocationEventType,
          'cid': 'messaging:general',
          'message_id': 'msg-1',
          if (tool != null) 'tool': tool,
          'args': args,
        });

    Future<void> pump() => Future<void>.delayed(Duration.zero);

    test('dispatches an invocation to the registered tool', () async {
      ThemeMode? received;
      final registry = AIToolRegistry()
        ..register(SetThemeModeTool(onChange: (mode) => received = mode));
      final listener = ClientToolListener(client: client, registry: registry);

      client.handleEvent(invocationEvent(tool: {'name': 'setThemeMode', 'description': 'x'}));
      await pump();

      expect(received, ThemeMode.dark);
      listener.dispose();
    });

    test('ignores a malformed payload', () async {
      var called = false;
      final registry = AIToolRegistry()..register(SetThemeModeTool(onChange: (_) => called = true));
      final listener = ClientToolListener(client: client, registry: registry);

      // No `tool` at all.
      client.handleEvent(invocationEvent());
      await pump();

      expect(called, isFalse);
      listener.dispose();
    });

    test('dispose cancels the subscription', () async {
      var called = false;
      final registry = AIToolRegistry()..register(SetThemeModeTool(onChange: (_) => called = true));
      ClientToolListener(client: client, registry: registry).dispose();

      client.handleEvent(invocationEvent(tool: {'name': 'setThemeMode', 'description': 'x'}));
      await pump();

      expect(called, isFalse);
    });

    test('a tool that throws is reported and does not escape the listener', () async {
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);

      final failures = <String>[];
      final registry = AIToolRegistry(
        onToolError: (invocation, error, stack) => failures.add(invocation.tool.name),
      )..register(SetThemeModeTool(onChange: (_) => throw StateError('boom')));
      final listener = ClientToolListener(client: client, registry: registry);

      await runZonedGuarded(() async {
        client.handleEvent(invocationEvent(tool: {'name': 'setThemeMode', 'description': 'x'}));
        await pump();
      }, (error, stack) => fail('escaped the listener: $error'));

      expect(failures, ['setThemeMode']);
      expect(reported, isNotEmpty);
      listener.dispose();
    });
  });
}
