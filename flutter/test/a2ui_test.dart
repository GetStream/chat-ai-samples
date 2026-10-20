import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' show DataPath;
import 'package:stream_chat_ai_assistant_flutter_example/src/a2ui.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// A v0.9 payload as `ai-sdk-sample` sends it, copied from the Android sample.
Map<String, Object?> _fixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync()) as Map<String, Object?>;

Message _reply(Object? payload, {String id = 'reply-1'}) =>
    Message(id: id, text: '', extraData: {'ai_generated': true, a2uiPayloadKey: ?payload});

void main() {
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
      expect(store.surfaceOf(_reply(null)), isNull);
      expect(store.surfaceOf(_reply({'version': 'v0.8', 'surfaceId': 'x', 'messages': <Object>[]})), isNull);
      expect(store.surfaceOf(_reply('not json', id: 'reply-2')), isNull);
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
  });

  group('A2uiSurfaceView', () {
    late A2uiSurfaceStore store;
    late List<A2uiAction> actions;

    setUp(() {
      store = A2uiSurfaceStore();
      actions = [];
    });
    tearDown(() => store.dispose());

    Future<void> pumpFixture(WidgetTester tester, String name) async {
      final surface = store.surfaceOf(_reply(_fixture(name)))!;
      // genui reports invalid components here, rather than throwing.
      final errors = [];
      final subscription = surface.controller.onSubmit.listen(errors.add);
      addTearDown(subscription.cancel);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
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
      expect(actions.single.context, containsPair('partySize', 4)); // A "number" field stores a number.;
      expect(actions.single.context, containsPair('restaurantName', "Xi'an Famous Foods"));
    });
  });
}
