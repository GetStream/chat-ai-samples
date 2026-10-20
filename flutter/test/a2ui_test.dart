import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:a2ui_core/a2ui_core.dart' show A2uiMessage;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' show DataPath;
import 'package:stream_chat_ai_assistant_flutter_example/src/a2ui.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/ai_message_item.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// A v0.9 payload as `ai-sdk-sample` sends it, copied from the Android sample.
Map<String, Object?> _fixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync()) as Map<String, Object?>;

Message _reply(Object? payload, {String id = 'reply-1'}) =>
    Message(id: id, text: '', extraData: {'ai_generated': true, a2uiPayloadKey: ?payload});

/// Collects what is logged with `debugPrint` until the test ends.
List<String> _captureLogs() {
  final logs = <String>[];
  final original = debugPrint;
  debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
  addTearDown(() => debugPrint = original);
  return logs;
}

/// Completes once [surface]'s controller is disposed.
Future<void> _disposed(A2uiSurface surface) {
  final done = Completer<void>();
  surface.controller.onSubmit.listen(null, onDone: done.complete);
  return done.future;
}

void main() {
  // The store disposes replaced surfaces after the frame.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A2uiSurfaceStore', () {
    late A2uiSurfaceStore store;

    setUp(() => store = A2uiSurfaceStore());
    tearDown(() => store.dispose());

    test('builds the surface of each fixture', () {
      for (final (name, surfaceId) in [
        ('restaurant-list', 'restaurant-finder'),
        ('booking-form', 'restaurant-booking-form'),
        ('booking-confirmation', 'restaurant-booking-confirmation'),
      ]) {
        final surface = store.surfaceOf(_reply(_fixture(name), id: name));
        expect(surface?.surfaceId, surfaceId);
        expect(surface?.controller.activeSurfaceIds, [surfaceId]);
      }
    });

    test('reads a payload sent as a JSON string', () {
      final surface = store.surfaceOf(_reply(jsonEncode(_fixture('booking-form'))));
      expect(surface?.surfaceId, 'restaurant-booking-form');
    });

    test('has no surface without a valid payload', () {
      _captureLogs();
      expect(store.surfaceOf(_reply(null)), isNull);
      final v08 = {
        'version': 'v0.8',
        'surfaceId': 'x',
        'messages': [
          {
            'beginRendering': {'surfaceId': 'x', 'root': 'root'},
          },
        ],
      };
      expect(store.surfaceOf(_reply(v08)), isNull);
      expect(store.surfaceOf(_reply('not json', id: 'reply-2')), isNull);
    });

    test('logs a payload whose surface id matches no created surface, and has no surface', () {
      final logs = _captureLogs();
      final payload = {..._fixture('booking-form'), 'surfaceId': 'other-surface'};

      expect(store.surfaceOf(_reply(payload)), isNull);
      expect(logs, contains(contains('other-surface')));
    });

    test('logs a payload without a root component, and has no surface', () async {
      final logs = _captureLogs();
      final payload = {
        'version': 'v0.9',
        'surfaceId': 's',
        'messages': [
          {
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 's',
              'catalogId': 'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json',
            },
          },
          {
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 's',
              'components': [
                {'id': 'not-root', 'component': 'NoSuchComponent'},
              ],
            },
          },
        ],
      };

      expect(store.surfaceOf(_reply(payload)), isNull);
      await pumpEventQueue();
      expect(logs, contains(contains('no renderable surface "s"')));
    });

    test('keeps the surface, and its input, while the payload is the same', () {
      final surface = store.surfaceOf(_reply(_fixture('booking-form')))!;
      final dataModel = surface.controller.contextFor(surface.surfaceId).dataModel;
      dataModel.update(DataPath('/partySize'), '4');

      // A message update parses the payload into new maps.
      final again = store.surfaceOf(_reply(_fixture('booking-form')));
      expect(again, same(surface));
      expect(dataModel.getValue<String>(DataPath('/partySize')), '4');
    });

    test('rebuilds the surface when the payload changes', () {
      final first = store.surfaceOf(_reply(_fixture('booking-form')));
      final second = store.surfaceOf(_reply(_fixture('booking-confirmation')));
      expect(second, isNot(same(first)));
      expect(second?.surfaceId, 'restaurant-booking-confirmation');
    });

    testWidgets('disposes a replaced surface after the frame, and shows the new one', (tester) async {
      var message = _reply(_fixture('booking-form'));
      late StateSetter setMessage;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setMessage = setState;
                return ListView(
                  children: [A2uiSurfaceView(surface: store.surfaceOf(message)!, onAction: (_) {})],
                );
              },
            ),
          ),
        ),
      );
      final first = store.surfaceOf(message)!;
      var firstDisposed = false;
      unawaited(_disposed(first).then((_) => firstDisposed = true));

      setMessage(() => message = _reply(_fixture('booking-confirmation')));
      await tester.pump();
      await tester.pump();

      expect(firstDisposed, isTrue);
      expect(find.text("Reserve a table at Xi'an Famous Foods"), findsNothing);
      expect(find.text("Reservation confirmed for Xi'an Famous Foods"), findsOneWidget);
    });
  });

  group('buildA2uiActionMessage', () {
    test('reports a booking request', () {
      final message = buildA2uiActionMessage(
        (
          surfaceId: 'restaurant-finder',
          name: 'book_restaurant',
          context: {'restaurantName': 'Carbone', 'address': '181 Thompson St', 'imageUrl': 'https://x/y.jpg'},
        ),
        sourceMessageId: 'reply-1',
      );

      expect(message.text, 'Book a table at Carbone');
      expect(jsonDecode(message.extraData[a2uiInteractionKey]! as String), {
        'userAction': {
          'name': 'book_restaurant',
          'context': {'restaurantName': 'Carbone', 'address': '181 Thompson St', 'imageUrl': 'https://x/y.jpg'},
        },
      });
      expect(message.extraData, containsPair(a2uiSurfaceIdKey, 'restaurant-finder'));
      expect(message.extraData, containsPair(a2uiDisplayTextKey, 'Book a table at Carbone'));
      expect(message.extraData, containsPair('a2ui_action_name', 'book_restaurant'));
      expect(message.extraData, containsPair('a2ui_source_message_id', 'reply-1'));
      expect(
        message.extraData,
        containsPair(
          'a2ui_query_text',
          'USER_WANTS_TO_BOOK: Carbone, Address: 181 Thompson St, ImageURL: https://x/y.jpg',
        ),
      );
      expect(message.extraData.containsKey('a2ui_action_label'), isFalse);
    });

    test('reports a submitted booking', () {
      final message = buildA2uiActionMessage(
        (
          surfaceId: 'restaurant-booking-form',
          name: 'submit_booking',
          context: {'restaurantName': 'Carbone', 'partySize': 4, 'reservationTime': '2026-10-20T19:00:00'},
        ),
        sourceMessageId: 'reply-2',
      );

      expect(message.text, 'Confirm the reservation at Carbone');
      expect(
        message.extraData['a2ui_query_text'],
        'User submitted a booking for Carbone for 4 people at 2026-10-20T19:00:00 with dietary requirements: None',
      );
    });

    test('describes other actions by their label or name', () {
      String textOf(Map<String, Object?> context) => readableActionText(
        (surfaceId: 's', name: 'submit_contact_form', context: context),
      );

      expect(textOf({}), 'Submit contact form');
      expect(textOf({'label': 'Send'}), 'Send');
    });

    test('leaves empty fields out of the query, like the backend', () {
      final message = buildA2uiActionMessage(
        (
          surfaceId: 's',
          name: 'book_restaurant',
          context: {'restaurantName': 'Carbone', 'address': '', 'imageUrl': ''},
        ),
        sourceMessageId: 'reply-1',
      );
      expect(message.extraData['a2ui_query_text'], 'USER_WANTS_TO_BOOK: Carbone');
    });
  });

  group('displayedA2uiMessage', () {
    test("shows another client's display text instead of its query", () {
      final message = Message(
        text: 'USER_WANTS_TO_BOOK: Carbone',
        extraData: const {a2uiDisplayTextKey: 'Book a table at Carbone'},
      );
      expect(displayedA2uiMessage(message).text, 'Book a table at Carbone');
    });

    test('leaves other messages as they are', () {
      final plain = Message(text: 'Hi');
      final own = Message(text: 'Book a table', extraData: const {a2uiDisplayTextKey: 'Book a table'});
      expect(displayedA2uiMessage(plain), same(plain));
      expect(displayedA2uiMessage(own), same(own));
    });
  });

  group('A2uiActionSender', () {
    const action = (surfaceId: 'restaurant-finder', name: 'book_restaurant', context: <String, Object?>{});

    test('sends the action with its source message, ignoring taps while it is in flight', () async {
      final sent = <Message>[];
      final pending = Completer<void>();
      final sender = A2uiActionSender(
        send: (message) {
          sent.add(message);
          return pending.future;
        },
        onError: (_) => fail('no error expected'),
      );

      final first = sender.handle(action, sourceMessageId: 'reply-1');
      await sender.handle(action, sourceMessageId: 'reply-1');
      expect(sent, hasLength(1));
      expect(sent.single.extraData['a2ui_source_message_id'], 'reply-1');
      expect(sender.isSending('reply-1'), isTrue);

      // Another message's surface isn't blocked.
      unawaited(sender.handle(action, sourceMessageId: 'reply-2'));
      expect(sent, hasLength(2));

      pending.complete();
      await first;
      expect(sender.isSending('reply-1'), isFalse);
    });

    test('a failed send shows the error and lets the surface send again', () async {
      _captureLogs();
      final errors = <String>[];
      var attempts = 0;
      final sender = A2uiActionSender(
        send: (message) async {
          if (attempts++ == 0) throw Exception('offline');
        },
        onError: errors.add,
      );

      await sender.handle(action, sourceMessageId: 'reply-1');
      expect(errors, ["Couldn't send your message. Please try again."]);
      expect(sender.isSending('reply-1'), isFalse);

      await sender.handle(action, sourceMessageId: 'reply-1');
      expect(attempts, 2);
      expect(errors, hasLength(1));
    });
  });

  group('A2uiSurfaceView', () {
    late A2uiSurfaceStore store;
    late List<A2uiAction> actions;

    setUp(() {
      store = A2uiSurfaceStore();
      actions = [];
    });
    tearDown(() => store.dispose());

    Future<void> pumpFixture(WidgetTester tester, String name, {ThemeData? theme}) async {
      final surface = store.surfaceOf(_reply(_fixture(name)))!;
      // genui reports invalid components here, rather than throwing.
      final errors = [];
      final subscription = surface.controller.onSubmit.listen(errors.add);
      addTearDown(subscription.cancel);

      await tester.pumpWidget(
        MaterialApp(
          theme: theme ?? ThemeData.dark(),
          // Unbounded height, as in the message list.
          home: Scaffold(
            body: ListView(
              children: [A2uiSurfaceView(surface: surface, onAction: actions.add)],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(errors, isEmpty);
    }

    testWidgets('renders the restaurant list and reports "Book Now"', (tester) async {
      await pumpFixture(tester, 'restaurant-list');

      expect(find.text('Top 3 restaurants in New York'), findsOneWidget);
      expect(find.text("Xi'an Famous Foods"), findsOneWidget);
      expect(find.text('Book Now'), findsNWidgets(3));

      await tester.tap(find.text('Book Now').first);
      await tester.pump();

      expect(actions, hasLength(1));
      expect(actions.single.surfaceId, 'restaurant-finder');
      expect(actions.single.name, 'book_restaurant');
      expect(actions.single.context['restaurantName'], "Xi'an Famous Foods");
      expect(actions.single.context['address'], '81 St Marks Pl, New York, NY 10003');
    });

    testWidgets('sends the booking form with what the user typed', (tester) async {
      await pumpFixture(tester, 'booking-form');

      expect(find.text("Reserve a table at Xi'an Famous Foods"), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Party size'), '4');
      await tester.tap(find.text('Confirm reservation'));
      await tester.pump();

      expect(actions.single.name, 'submit_booking');
      expect(actions.single.context, containsPair('partySize', 4)); // A "number" field stores a number.
      expect(actions.single.context, containsPair('restaurantName', "Xi'an Famous Foods"));
    });
    testWidgets('sends the picked reservation time', (tester) async {
      await pumpFixture(tester, 'booking-form');

      await tester.tap(find.byKey(const Key('booking-time_text')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm reservation'));
      await tester.pump();

      expect(actions.single.context, containsPair('reservationTime', '2026-10-15T19:00:00.000'));
    });

    testWidgets('renders in the light theme', (tester) async {
      await pumpFixture(tester, 'booking-confirmation', theme: ThemeData.light());

      expect(find.byType(A2uiSurfaceView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows a fallback line for a surface that is gone', (tester) async {
      final surface = store.surfaceOf(_reply(_fixture('booking-confirmation')))!;
      surface.controller.handleMessage(
        A2uiMessage.fromJson({
          'version': 'v0.9',
          'deleteSurface': {'surfaceId': surface.surfaceId},
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A2uiSurfaceView(surface: surface, onAction: actions.add),
          ),
        ),
      );

      expect(find.text("Couldn't show this content."), findsOneWidget);
    });

    testWidgets("an AI message's surface reports its taps", (tester) async {
      final message = _reply(_fixture('restaurant-list'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                AIMessageItem(message: message, surface: store.surfaceOf(message), onSurfaceAction: actions.add),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Book Now').first);
      expect(actions.single.name, 'book_restaurant');
    });
  });
}
