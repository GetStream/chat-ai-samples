/// Generative UI: the A2UI v0.9 surfaces `ai-sdk-sample` attaches to AI
/// messages (with `A2UI_PROTOCOL=v0.9`), rendered with the `genui` package.
///
/// [A2uiSurfaceStore] keeps one surface per message, [A2uiSurfaceView] shows
/// it, and [buildA2uiActionMessage] turns a button press into the user message
/// the backend answers.
library;

import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart' show A2uiMessage;
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// Message field with the A2UI v0.9 payload.
const a2uiPayloadKey = 'a2ui_v09';

/// Message field with the user action, as a JSON string.
const a2uiInteractionKey = 'a2ui_interaction';

/// Message field with the id of the surface an action comes from.
const a2uiSurfaceIdKey = 'a2ui_surface_id';

/// Message field with the text to show for an action message.
const a2uiDisplayTextKey = 'a2ui_display_text';

/// A user action on a surface, such as a button press.
typedef A2uiAction = ({String surfaceId, String name, Map<String, Object?> context});

/// The surface of one message: a `genui` controller fed with its payload.
class A2uiSurface {
  A2uiSurface._(this.surfaceId, this.controller);

  /// Parses [payload] (`{version, surfaceId, messages}`) and builds its surface,
  /// or returns null if it isn't a v0.9 payload.
  static A2uiSurface? tryParse(Object? payload) {
    try {
      final json = payload is String ? jsonDecode(payload) : jsonDecode(jsonEncode(payload));
      if (json is! Map<String, dynamic> || json['messages'] is! List) return null;
      final messages = [for (final message in json['messages'] as List) A2uiMessage.fromJson(message)];
      final surfaceId = json['surfaceId'] as String?;
      if (surfaceId == null || messages.isEmpty) return null;

      final controller = SurfaceController(catalogs: [BasicCatalogItems.asCatalog()]);
      messages.forEach(controller.handleMessage);
      return A2uiSurface._(surfaceId, controller);
    } catch (e) {
      debugPrint('Invalid A2UI payload: $e');
      return null;
    }
  }

  /// The id the backend gave the surface, e.g. `restaurant-finder`.
  final String surfaceId;

  /// Holds the surface's components and data model, including user input.
  final SurfaceController controller;

  /// Releases [controller].
  void dispose() => controller.dispose();
}

/// Keeps the A2UI surface of each message, by message id.
///
/// A surface is built once from the payload, and user input lives in it, so
/// input survives rebuilds, list recycling and message updates. It is rebuilt
/// only when the payload itself changes.
class A2uiSurfaceStore {
  final _entries = <String, ({String payload, A2uiSurface? surface})>{};

  /// The surface of [message], or null if it has none.
  A2uiSurface? surfaceOf(Message message) {
    final raw = message.extraData[a2uiPayloadKey];
    if (raw == null) return null;
    // Message updates parse the payload anew, so compare by content.
    final payload = raw is String ? raw : jsonEncode(raw);
    final entry = _entries[message.id];
    if (entry != null && entry.payload == payload) return entry.surface;

    entry?.surface?.dispose();
    final surface = A2uiSurface.tryParse(raw);
    _entries[message.id] = (payload: payload, surface: surface);
    return surface;
  }

  /// Releases every surface.
  void dispose() {
    for (final entry in _entries.values) {
      entry.surface?.dispose();
    }
    _entries.clear();
  }
}

/// Shows [surface], following the app's theme, and reports button actions to
/// [onAction].
class A2uiSurfaceView extends StatelessWidget {
  const A2uiSurfaceView({super.key, required this.surface, required this.onAction});

  final A2uiSurface surface;

  final ValueChanged<A2uiAction> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // The catalog styles itself from the Material theme. Cards use `surface`,
    // the color of the list behind them, so lift them a little.
    return Theme(
      data: theme.copyWith(colorScheme: colors.copyWith(surface: colors.surfaceContainerLow)),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: colors.onSurface),
        child: Surface(
          surfaceContext: surface.controller.contextFor(surface.surfaceId),
          actionDelegate: _ActionDelegate(surface.surfaceId, onAction),
        ),
      ),
    );
  }
}

class _ActionDelegate implements ActionDelegate {
  const _ActionDelegate(this.surfaceId, this.onAction);

  final String surfaceId;
  final ValueChanged<A2uiAction> onAction;

  @override
  bool handleEvent(
    BuildContext context,
    UiEvent event,
    SurfaceContext genUiContext,
    Widget Function(SurfaceDefinition, Catalog, String, DataContext) buildWidget,
  ) {
    if (!event.isUserAction) return false;
    final action = UserActionEvent.fromMap(event.toMap());
    onAction((surfaceId: surfaceId, name: action.name, context: action.context));
    return true;
  }
}

/// The user message that reports [action] to the backend.
///
/// `a2ui_interaction` is `{"userAction":{"name":…,"context":{…}}}` as a JSON
/// string; the backend answers `book_restaurant` and `submit_booking` itself.
/// The other `a2ui_*` fields match what the iOS sample sends.
Message buildA2uiActionMessage(A2uiAction action, {required String sourceMessageId}) {
  final label = _labelOf(action.context);
  final displayText = readableActionText(action);
  return Message(
    text: displayText,
    extraData: {
      a2uiInteractionKey: jsonEncode({
        'userAction': {'name': action.name, 'context': action.context},
      }),
      a2uiSurfaceIdKey: action.surfaceId,
      a2uiDisplayTextKey: displayText,
      'a2ui_action_name': action.name,
      'a2ui_action_label': ?label,
      'a2ui_query_text': _queryText(action),
      'a2ui_action_context': action.context,
      'a2ui_source_message_id': sourceMessageId,
    },
  );
}

/// A short description of [action] for the user's own bubble, e.g. "Book a
/// table at Carbone".
String readableActionText(A2uiAction action) {
  final restaurant = _stringOf(action.context['restaurantName']);
  return switch (action.name) {
    'book_restaurant' => restaurant == null ? 'Book a table' : 'Book a table at $restaurant',
    'submit_booking' => restaurant == null ? 'Confirm the reservation' : 'Confirm the reservation at $restaurant',
    // e.g. "submit_contact_form" becomes "Submit contact form"
    final name => _labelOf(action.context) ?? _humanize(name),
  };
}

/// What the action means, for a model to read, like `ai-sdk-sample`'s
/// `restaurantActionProvider`.
String _queryText(A2uiAction action) {
  String? value(String key) => _stringOf(action.context[key]);
  final restaurant = value('restaurantName') ?? 'Unknown Restaurant';
  final imageUrl = value('imageUrl');
  switch (action.name) {
    case 'book_restaurant':
      return [
        'USER_WANTS_TO_BOOK: $restaurant',
        if (value('address') case final address?) 'Address: $address',
        if (imageUrl != null) 'ImageURL: $imageUrl',
      ].join(', ');
    case 'submit_booking':
      return 'User submitted a booking for $restaurant for ${value('partySize') ?? 'Unknown Size'} people at '
          '${value('reservationTime') ?? 'Unknown Time'} with dietary requirements: ${value('dietary') ?? 'None'}'
          '${imageUrl == null ? '' : '. Image URL: $imageUrl'}';
    default:
      return 'User submitted an event: ${action.name} with data: ${jsonEncode(action.context)}';
  }
}

String? _labelOf(Map<String, Object?> context) =>
    [context['label'], context['title'], context['text']].whereType<String>().where((s) => s.isNotEmpty).firstOrNull;

String? _stringOf(Object? value) => switch (value) {
  null => null,
  String() => value,
  num() || bool() => '$value',
  _ => jsonEncode(value),
};

String _humanize(String name) {
  final words = name.replaceAll('_', ' ').trim();
  return words.isEmpty ? 'Submitted action' : '${words[0].toUpperCase()}${words.substring(1)}';
}
