import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/draft_channel.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

void main() {
  late StreamChatClient client;
  late List<Channel> created;
  late DraftChannel draft;
  var failNext = false;

  /// When set, the next create waits for it, and fails if it does.
  Completer<void>? gate;

  setUp(() {
    client = StreamChatClient('test-key');
    created = [];
    failNext = false;
    gate = null;
    draft = DraftChannel(
      create: () async {
        if (gate case final pending?) {
          gate = null;
          await pending.future;
        }
        if (failNext) {
          failNext = false;
          throw StateError('offline');
        }
        final channel = client.channel('messaging', id: 'chat-${created.length}');
        created.add(channel);
        return channel;
      },
    );
  });

  tearDown(() async {
    draft.dispose();
    await client.dispose();
  });

  testWidgets('creates one draft once enough is typed, however much more follows', (tester) async {
    draft.onTextChanged('Hi');
    await tester.pump(const Duration(seconds: 1));
    expect(created, isEmpty);

    for (final text in ['Hello', 'Hello there', 'Hello there, how are you?']) {
      draft.onTextChanged(text);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));

    expect(created, hasLength(1));
  });

  testWidgets('waits for the text to settle, so a quick delete creates nothing', (tester) async {
    draft.onTextChanged('Hello');
    await tester.pump(const Duration(milliseconds: 100));
    draft.onTextChanged('He');
    await tester.pump(const Duration(seconds: 1));

    expect(created, isEmpty);
    expect(draft.hasDraft, isFalse);
  });

  testWidgets('a cleared composer keeps the draft for the next send', (tester) async {
    draft.onTextChanged('Hello');
    await tester.pump(const Duration(seconds: 1));
    draft.onTextChanged('');
    draft.onTextChanged('Something else entirely');
    await tester.pump(const Duration(seconds: 1));

    expect(await draft.take(), same(created.single));
  });

  testWidgets('the next new chat gets a channel of its own', (tester) async {
    draft.onTextChanged('Hello');
    await tester.pump(const Duration(seconds: 1));
    final first = await draft.take();

    draft.onTextChanged('Second chat');
    await tester.pump(const Duration(seconds: 1));
    final second = await draft.take();

    expect(created, hasLength(2));
    expect(second, isNot(same(first)));
  });

  testWidgets('sending before a draft exists creates the channel then', (tester) async {
    final channel = await draft.take();

    expect(created, [channel]);
  });

  testWidgets('sending while the draft is being created waits for that one', (tester) async {
    final pending = gate = Completer();
    draft.onTextChanged('Hello');
    await tester.pump(const Duration(seconds: 1));

    final taken = draft.take();
    pending.complete();

    expect(await taken, same(created.single));
  });

  testWidgets('a draft that fails after send was pressed is retried', (tester) async {
    final pending = gate = Completer();
    failNext = true;
    draft.onTextChanged('Hello');
    await tester.pump(const Duration(seconds: 1));

    final taken = draft.take();
    pending.complete();

    expect(await taken, same(created.single));
  });

  testWidgets('a restored channel is the next draft', (tester) async {
    final channel = await draft.take();
    draft.restore(channel);
    draft.onTextChanged('Hello again');
    await tester.pump(const Duration(seconds: 1));

    expect(await draft.take(), same(channel));
    expect(created, [channel]);
  });

  testWidgets('dispose cancels a pending draft', (tester) async {
    draft.onTextChanged('Hello');
    draft.dispose();
    await tester.pump(const Duration(seconds: 1));

    expect(created, isEmpty);
  });
}
