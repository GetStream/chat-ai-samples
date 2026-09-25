/// Client-side tools let the AI agent trigger behaviour in this app.
///
/// 1. Each tool is an [AIClientTool], registered in an [AIToolRegistry].
/// 2. `registrationPayloads()` is sent to the backend's `/register-tools`.
/// 3. When the model calls a tool, the agent sends a
///    `custom_client_tool_invocation` event over the chat connection.
/// 4. [ClientToolListener] parses it and dispatches it to the registry.
///
/// Nothing is sent back to the model: a client tool is a side effect.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

/// Shows a greeting. Takes no arguments.
class GreetUserTool implements AIClientTool {
  const GreetUserTool({required this.onGreet});

  final VoidCallback onGreet;

  @override
  AIToolDefinition get definition => const AIToolDefinition(
        name: 'greetUser',
        description: 'Display a native greeting to the user',
        instructions: 'Use the greetUser tool when the user asks to be '
            'greeted. The tool shows a greeting alert in the Flutter app.',
      );

  // Tools return actions instead of running them, so the registry decides
  // when they run.
  @override
  List<AIToolAction> handleInvocation(AIToolInvocation invocation) => [onGreet];
}

/// Switches the app between light and dark theme — a tool with arguments.
class SetThemeModeTool implements AIClientTool {
  const SetThemeModeTool({required this.onChange});

  final ValueChanged<ThemeMode> onChange;

  @override
  AIToolDefinition get definition => const AIToolDefinition(
        name: 'setThemeMode',
        description: 'Switch the app between its light and dark theme',
        instructions: 'Use setThemeMode when the user asks for dark mode, '
            'light mode, or to change how the app looks.',
        parameters: {
          'type': 'object',
          'properties': {
            'mode': {
              'type': 'string',
              'enum': ['light', 'dark', 'system'],
              'description': 'The theme the app should switch to.',
            },
          },
          'required': ['mode'],
          'additionalProperties': false,
        },
      );

  @override
  List<AIToolAction> handleInvocation(AIToolInvocation invocation) {
    final mode = ThemeMode.values.asNameMap()[invocation.args['mode']];
    // Outside the schema's enum: better to do nothing than to guess.
    if (mode == null) {
      debugPrint('setThemeMode: unsupported mode ${invocation.args['mode']}');
      return const [];
    }
    return [() => onChange(mode)];
  }
}

/// Feeds `custom_client_tool_invocation` events to an [AIToolRegistry].
///
/// Listens on the client rather than a channel, so invocations keep arriving
/// while the user switches conversations.
class ClientToolListener {
  ClientToolListener({required StreamChatClient client, required AIToolRegistry registry})
      : _registry = registry {
    _subscription = client.on(kClientToolInvocationEventType).listen(_onEvent);
  }

  final AIToolRegistry _registry;
  late final StreamSubscription<Event> _subscription;

  Future<void> _onEvent(Event event) async {
    final invocation = AIToolInvocation.tryParse(event.toClientToolPayload());
    if (invocation == null) return;

    // `false` means no tool has that name, e.g. one an older build of the app
    // registered. Errors thrown inside a tool go to `FlutterError.onError`.
    final handled = await _registry.dispatch(invocation);
    if (!handled) debugPrint('No client tool registered as "${invocation.tool.name}"');
  }

  void dispose() => unawaited(_subscription.cancel());
}

extension EventClientToolPayload on Event {
  /// Rebuilds the JSON [AIToolInvocation.tryParse] reads.
  ///
  /// `Event` has no `tool` or `args` fields, so the SDK puts them in
  /// [extraData], while `cid` and `message_id` are regular fields.
  Map<String, Object?> toClientToolPayload() => {
        'type': type,
        'cid': cid,
        'message_id': messageId,
        ...extraData,
      };
}
