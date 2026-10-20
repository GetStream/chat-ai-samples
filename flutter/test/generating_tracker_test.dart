import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/generating_tracker.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/typing_state_handler.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

void main() {
  late StreamChatClient client;
  late TypingStateHandler handler;
  late GeneratingTracker tracker;
  late Map<String, String> replies;

  /// What the composer was told, latest last.
  late List<bool> reported;

  void emit(String type, {String? aiState, String? messageId}) => client.handleEvent(
    Event(
      type: type,
      cid: 'messaging:chat-1',
      messageId: messageId,
      aiState: aiState == null ? null : AITypingState.values.byName(aiState),
    ),
  );

  setUp(() => client = StreamChatClient('test-key'));
  tearDown(() => client.dispose());

  // Listens from inside each test, so the fallback timer runs on its fake
  // clock.
  void init() {
    handler = TypingStateHandler(channel: client.channel('messaging', id: 'chat-1'));
    replies = {'reply-1': 'Hello there'};
    reported = [];
    tracker = GeneratingTracker(
      typingState: handler,
      replyText: (id) => replies[id],
      onChanged: reported.add,
      typingSpeed: const Duration(milliseconds: 10),
    );
    addTearDown(() {
      tracker.dispose();
      handler.dispose();
    });
  }

  /// A reply that the backend has finished, but that is still typing out.
  Future<void> replyDone(WidgetTester tester) async {
    emit(EventType.aiIndicatorUpdate, aiState: 'generating', messageId: 'reply-1');
    emit(EventType.aiIndicatorClear, messageId: 'reply-1');
    await tester.pump();
  }

  testWidgets('stays after the clear until the reply is on screen', (tester) async {
    init();
    await replyDone(tester);
    expect(reported.last, isTrue);

    tracker.replyFinished('reply-1');
    expect(reported.last, isFalse);
  });

  testWidgets('a stop drops it at once', (tester) async {
    init();
    emit(EventType.aiIndicatorUpdate, aiState: 'generating', messageId: 'reply-1');
    emit(EventType.aiIndicatorStop);
    await tester.pump();

    expect(reported.last, isFalse);
  });

  testWidgets('an error drops it at once', (tester) async {
    init();
    emit(EventType.aiIndicatorUpdate, aiState: 'generating', messageId: 'reply-1');
    emit(EventType.aiIndicatorUpdate, aiState: 'error', messageId: 'reply-1');
    await tester.pump();

    expect(reported.last, isFalse);
  });

  testWidgets('an empty reply drops it with the clear', (tester) async {
    init();
    replies['reply-1'] = '';
    await replyDone(tester);

    expect(reported.last, isFalse);
  });

  testWidgets("ignores another reply's onFinished, and one while still generating", (tester) async {
    init();
    emit(EventType.aiIndicatorUpdate, aiState: 'generating', messageId: 'reply-1');
    await tester.pump();
    tracker.replyFinished('reply-1');
    expect(tracker.isGenerating, isTrue);

    emit(EventType.aiIndicatorClear, messageId: 'reply-1');
    await tester.pump();
    tracker.replyFinished('reply-0');
    expect(tracker.isGenerating, isTrue);
    tracker.replyFinished('reply-1');
  });

  testWidgets('a disposed reply item drops it', (tester) async {
    init();
    await replyDone(tester);

    tracker.replyDisposed('reply-1');
    expect(reported.last, isFalse);
  });

  testWidgets('drops it once the reply would surely be typed out, if it never finishes', (tester) async {
    init();
    await replyDone(tester);

    await tester.pump(const Duration(seconds: 2));
    expect(tracker.isGenerating, isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(reported.last, isFalse);
  });
}
