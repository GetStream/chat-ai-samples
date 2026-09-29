import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/typing_state_handler.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

void main() {
  late StreamChatClient client;
  late Channel channel;
  late TypingStateHandler handler;

  Event aiEvent(String type, {String cid = 'messaging:chat-1', String? aiState}) => Event(
    type: type,
    cid: cid,
    aiState: aiState == null ? null : AITypingState.values.firstWhere((s) => s.name == aiState),
  );

  // Events go through the client's own stream, like the websocket would.
  void emit(Event event) => client.handleEvent(event);

  setUp(() {
    client = StreamChatClient('test-key');
    channel = client.channel('messaging', id: 'chat-1');
    handler = TypingStateHandler(channel: channel);
  });

  tearDown(() async {
    handler.dispose();
    await client.dispose();
  });

  test('starts idle', () {
    expect(handler.value, AITypingState.idle);
  });

  test('maps ai_indicator.update to the reported state', () async {
    for (final state in AITypingState.values) {
      emit(aiEvent(EventType.aiIndicatorUpdate, aiState: state.name));
      await Future<void>.delayed(Duration.zero);
      expect(handler.value, state);
    }
  });

  test('maps AI_STATE_ERROR to error', () async {
    emit(aiEvent(EventType.aiIndicatorUpdate, aiState: 'error'));
    await Future<void>.delayed(Duration.zero);

    expect(handler.value, AITypingState.error);
  });

  for (final type in [EventType.aiIndicatorClear, EventType.aiIndicatorStop]) {
    test('$type returns to idle', () async {
      emit(aiEvent(EventType.aiIndicatorUpdate, aiState: 'generating'));
      await Future<void>.delayed(Duration.zero);
      expect(handler.value, AITypingState.generating);

      emit(aiEvent(type));
      await Future<void>.delayed(Duration.zero);
      expect(handler.value, AITypingState.idle);
    });
  }

  test('ignores other event types and other channels', () async {
    emit(aiEvent(EventType.aiIndicatorUpdate, aiState: 'thinking'));
    await Future<void>.delayed(Duration.zero);

    emit(aiEvent(EventType.typingStart));
    emit(aiEvent(EventType.aiIndicatorClear, cid: 'messaging:other'));
    await Future<void>.delayed(Duration.zero);

    expect(handler.value, AITypingState.thinking);
  });

  test('stops listening once disposed', () async {
    handler.dispose();
    emit(aiEvent(EventType.aiIndicatorUpdate, aiState: 'thinking'));
    await Future<void>.delayed(Duration.zero);

    // A disposed ValueNotifier would throw on a further assignment.
    expect(handler.value, AITypingState.idle);
    // Re-create so tearDown's dispose has something valid to dispose.
    handler = TypingStateHandler(channel: channel);
  });
}
