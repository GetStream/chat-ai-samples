import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat/stream_chat.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/chat_ai_assistant_client_tools.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

void main() {
  test('a custom_client_tool_invocation event parses into an invocation', () {
    final event = Event.fromJson({
      'type': kClientToolInvocationEventType,
      'cid': 'messaging:general',
      'message_id': 'msg-1',
      'tool': {'name': 'setThemeMode', 'description': 'Switch theme'},
      'args': {'mode': 'dark'},
    });

    final registry = AIToolRegistry()..register(const SetThemeModeTool());
    final invocation = AIToolInvocation.tryParse(event.toClientToolPayload());

    expect(invocation, isNotNull);
    expect(invocation!.tool.name, 'setThemeMode');
    expect(invocation.channelId, 'messaging:general');
    expect(invocation.messageId, 'msg-1');
    expect(invocation.args['mode'], 'dark');
    expect(registry.resolve(invocation), hasLength(1));
  });
}
