/// Generative UI: the A2UI v0.9 surfaces `ai-sdk-sample` attaches to AI
/// messages (with `A2UI_PROTOCOL=v0.9`), rendered with the `genui` package.
///
/// [A2uiSurfaceStore] keeps one surface per message, [A2uiSurfaceView] shows
/// it, and [A2uiActionSender] sends a button press as the user message the
/// backend answers.
library;

import 'dart:async';
import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart' show A2uiMessage;
import 'package:collection/collection.dart';
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
  A2uiSurface._(this.surfaceId, this.controller, this._errors);

  /// Parses [payload] (`{version, surfaceId, messages}`) and builds its surface,
  /// or returns null if it isn't a v0.9 payload with a renderable surface.
  static A2uiSurface? tryParse(Object? payload) {
    try {
      final json = payload is String ? jsonDecode(payload) : jsonDecode(jsonEncode(payload));
      if (json is! Map<String, dynamic> || json['version'] != 'v0.9' || json['messages'] is! List) return null;
      final messages = [for (final message in json['messages'] as List) A2uiMessage.fromJson(message)];
      final surfaceId = json['surfaceId'] as String?;
      if (surfaceId == null || messages.isEmpty) return null;

      final controller = SurfaceController(catalogs: [BasicCatalogItems.asCatalog()]);
      // genui reports invalid messages and components here instead of throwing.
      final errors = controller.onSubmit.listen((message) {
        for (final part in message.parts.uiInteractionParts) {
          debugPrint('A2UI error in surface $surfaceId: ${part.interaction}');
        }
      });
      messages.forEach(controller.handleMessage);
      final definition = controller.contextFor(surfaceId).definition.value;
      if (!controller.activeSurfaceIds.contains(surfaceId) || !(definition?.components.containsKey('root') ?? false)) {
        debugPrint('A2UI payload has no renderable surface "$surfaceId".');
        // Errors already reported are still logged before the stream closes.
        controller.dispose();
        return null;
      }
      return A2uiSurface._(surfaceId, controller, errors);
    } catch (e, s) {
      debugPrint('Invalid A2UI payload: $e\n$s');
      return null;
    }
  }

  /// The id the backend gave the surface, e.g. `restaurant-finder`.
  final String surfaceId;

  /// Holds the surface's components and data model, including user input.
  final SurfaceController controller;

  final StreamSubscription<Object?> _errors;

  /// Releases [controller].
  void dispose() {
    unawaited(_errors.cancel());
    controller.dispose();
  }
}

/// Keeps the A2UI surface of each message, by message id.
///
/// A surface is built once from the payload, and user input lives in it, so
/// input survives rebuilds, list recycling and message updates. It is rebuilt
/// only when the payload itself changes.
class A2uiSurfaceStore {
  final _entries = <String, ({Object payload, A2uiSurface? surface})>{};

  /// Replaced surfaces, still shown until the frame ends.
  final _retired = <A2uiSurface>{};

  static const _equality = DeepCollectionEquality();

  /// The surface of [message], or null if it has none.
  ///
  /// Called while the message list builds.
  A2uiSurface? surfaceOf(Message message) {
    final payload = message.extraData[a2uiPayloadKey];
    if (payload == null) return null;
    final entry = _entries[message.id];
    // Message updates parse the payload into new maps, so compare by content.
    if (entry != null && (identical(entry.payload, payload) || _equality.equals(entry.payload, payload))) {
      return entry.surface;
    }

    if (entry?.surface case final old?) _retire(old);
    final surface = A2uiSurface.tryParse(payload);
    _entries[message.id] = (payload: payload, surface: surface);
    return surface;
  }

  /// Disposes [surface] once the frame that replaces it is done with it.
  void _retire(A2uiSurface surface) {
    _retired.add(surface);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_retired.remove(surface)) surface.dispose();
    });
  }

  /// Releases every surface.
  void dispose() {
    for (final surface in [..._entries.values.map((entry) => entry.surface).nonNulls, ..._retired]) {
      surface.dispose();
    }
    _entries.clear();
    _retired.clear();
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
          // A rebuilt surface gets fresh widget state, not the old one's.
          key: ObjectKey(surface),
          surfaceContext: surface.controller.contextFor(surface.surfaceId),
          actionDelegate: _ActionDelegate(surface.surfaceId, onAction),
          defaultBuilder: (context) => Text(
            "Couldn't show this content.",
            style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
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

/// Sends surface actions with [send], one at a time per message: a tap while
/// that message's last action is still being sent is ignored.
class A2uiActionSender {
  A2uiActionSender({required this.send, required this.onError});

  /// Sends the action message. Throws if it couldn't be sent.
  final Future<void> Function(Message message) send;

  /// Shows a failed send to the user.
  final ValueChanged<String> onError;

  final _sending = <String>{};

  /// Whether an action of the surface of [sourceMessageId] is being sent.
  bool isSending(String sourceMessageId) => _sending.contains(sourceMessageId);

  /// Sends [action], which came from the surface of [sourceMessageId].
  Future<void> handle(A2uiAction action, {required String sourceMessageId}) async {
    if (!_sending.add(sourceMessageId)) return;
    try {
      await send(buildA2uiActionMessage(action, sourceMessageId: sourceMessageId));
    } catch (e, s) {
      debugPrint('Failed to send the A2UI action: $e\n$s');
      onError("Couldn't send your message. Please try again.");
    } finally {
      _sending.remove(sourceMessageId);
    }
  }
}

/// [message] as the user's bubble shows it: an action message shows its
/// `a2ui_display_text`.
///
/// Our own action messages already have it as their text; this is for those
/// other clients send, like iOS, which puts the model's query in the text.
Message displayedA2uiMessage(Message message) => switch (message.extraData[a2uiDisplayTextKey]) {
  final String displayText when displayText != message.text => message.copyWith(text: displayText),
  _ => message,
};

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

/// What the action means, for a model to read, worded like `ai-sdk-sample`'s
/// `restaurantActionProvider`. Kept for parity with iOS: the backend rebuilds
/// the query from `a2ui_interaction` itself.
String _queryText(A2uiAction action) {
  String? value(String key) => _stringOf(action.context[key]);
  final restaurant = value('restaurantName') ?? 'Unknown Restaurant';
  // Skipped when empty, like the backend's `if (imageUrl)`.
  final imageUrl = value('imageUrl')?.nonEmpty;
  switch (action.name) {
    case 'book_restaurant':
      return [
        'USER_WANTS_TO_BOOK: $restaurant',
        if (value('address')?.nonEmpty case final address?) 'Address: $address',
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

extension on String {
  String? get nonEmpty => isEmpty ? null : this;
}
