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
}
