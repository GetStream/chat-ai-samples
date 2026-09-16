import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stream_chat/stream_chat.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

/// Client-side tools: the AI agent reaching back into this app.
///
/// The round trip, all of which is wired up in `ChatAIAssistantHomePage`:
///
/// 1. Each tool below declares itself as an [AIClientTool] and is put in an
///    [AIToolRegistry].
/// 2. `registrationPayloads()` is POSTed to the sample backend's
///    `/register-tools`, which hands them to the agent SDK.
/// 3. When the model decides to call one, the agent sends a
///    `custom_client_tool_invocation` event down the normal chat connection.
/// 4. [ChatAIAssistantClientToolListener] parses it and asks the registry to
///    run the matching tool.
///
/// **Nothing is returned to the model.** A client tool is a side effect, not a
/// function call with a result — the protocol carries no answer back, which is
/// why none of the tools here return a value.
///
/// Mirrors the iOS sample's `StreamChatClientTools.swift` +
/// `ClientToolActionHandler.swift`.

/// An alert a client tool asked the app to show.
@immutable
class ChatAIAssistantToolAlert {
  const ChatAIAssistantToolAlert({required this.title, required this.message});

  final String title;
  final String message;
}

/// The app-side effects the tools in this file can trigger.
///
/// Mirrors the iOS sample's `ClientToolActionHandler.shared`: one object the
/// tools push into and the widget tree listens to.
///
/// That indirection is the point of the package's deferred-action design. A
/// tool is a plain object with no `BuildContext` and no idea whether the app is
/// even in the foreground, so [AIClientTool.handleInvocation] returns actions
/// instead of performing them. They land here, and the widget tree renders the
/// result on its own terms.
class ChatAIAssistantToolActionHandler {
  factory ChatAIAssistantToolActionHandler() => _instance;

  static final _instance = ChatAIAssistantToolActionHandler._();

  ChatAIAssistantToolActionHandler._();

  /// The alert waiting to be shown, or `null` when there is none.
  final pendingAlert = ValueNotifier<ChatAIAssistantToolAlert?>(null);

  /// The theme the app renders in — driven by [SetThemeModeTool].
  final themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

  void presentAlert(ChatAIAssistantToolAlert alert) => pendingAlert.value = alert;

  void dismissAlert() => pendingAlert.value = null;

  void setThemeMode(ThemeMode mode) => themeMode.value = mode;
}

/// Shows a native alert. Takes no arguments.
///
/// The direct counterpart of the iOS sample's `GreetClientTool`, down to the
/// tool name and wording, so the same backend prompt drives both apps.
class GreetUserTool implements AIClientTool {
  const GreetUserTool();

  @override
  AIToolDefinition get definition => const AIToolDefinition(
        name: 'greetUser',
        description: 'Display a native greeting to the user',
        instructions: 'Use the greetUser tool when the user asks to be '
            'greeted. The tool shows a greeting alert in the Flutter app.',
        // A tool that takes no arguments can omit `parameters` entirely —
        // `AIToolDefinition` defaults to an empty object schema. Spelled out
        // here to match what iOS sends, including `additionalProperties`.
        parameters: {
          'type': 'object',
          'properties': <String, Object?>{},
          'required': <Object?>[],
          'additionalProperties': false,
        },
      );

  @override
  List<AIToolAction> handleInvocation(AIToolInvocation invocation) => [
        () => ChatAIAssistantToolActionHandler().presentAlert(
              const ChatAIAssistantToolAlert(
                title: 'Greetings!',
                message: '👋 Hello there! The assistant asked me to greet you.',
              ),
            ),
      ];
}

/// Switches the app between its light and dark theme.
///
/// No iOS counterpart — it is here because `greetUser` takes no arguments, so
/// on its own it never demonstrates the half of the protocol that carries
/// them. Ask the assistant to "switch to dark mode" to see the whole path,
/// schema included, end to end.
class SetThemeModeTool implements AIClientTool {
  const SetThemeModeTool();

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
    // `tryParse` has already decoded the arguments — including the
    // `arguments`-as-a-JSON-string form the OpenAI and Anthropic tool APIs
    // emit — so reading them is a plain map lookup.
    final mode = switch (invocation.args['mode']) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      // The model sent something outside the schema's enum. Returning no
      // actions is the honest answer: there is nothing sensible to switch to,
      // and guessing would change the app's appearance against the user's
      // actual request.
      _ => null,
    };

    if (mode == null) return const [];

    return [() => ChatAIAssistantToolActionHandler().setThemeMode(mode)];
  }
}

/// Feeds `custom_client_tool_invocation` events to an [AIToolRegistry].
///
/// Subscribes on the *client*, not a channel, mirroring the iOS sample's
/// single `chatClient.eventsController()`: invocations then keep arriving
/// while the user switches conversations, with no resubscribing.
class ChatAIAssistantClientToolListener {
  ChatAIAssistantClientToolListener({
    required StreamChatClient client,
    required AIToolRegistry registry,
  }) : _registry = registry {
    _subscription = client.on(kClientToolInvocationEventType).listen(_onEvent);
  }

  final AIToolRegistry _registry;
  late final StreamSubscription<Event> _subscription;

  Future<void> _onEvent(Event event) async {
    final invocation = AIToolInvocation.tryParse(event.toClientToolPayload());
    if (invocation == null) {
      debugPrint('Ignoring unreadable client tool invocation: ${event.type}');
      return;
    }

    // `false` means no tool is registered under that name. That is normal
    // rather than an error: registrations are persisted server-side and
    // re-applied when the channel's agent restarts, so a channel an older
    // build registered can still invoke a tool this build no longer has.
    // Failures *inside* a tool go to `FlutterError.onError` instead.
    final handled = await _registry.dispatch(invocation);
    if (!handled) {
      debugPrint('No client tool registered as "${invocation.tool.name}"');
    }
  }

  void dispose() => unawaited(_subscription.cancel());
}

/// Exposed (rather than a private extension) so a test can pin the one
/// assumption this file makes about the chat SDK's own parsing.
extension EventClientToolPayload on Event {
  /// Flattens the event back into the JSON [AIToolInvocation.tryParse] reads.
  ///
  /// `tool` and `args` aren't fields `Event` knows about, so the SDK parks them
  /// in [extraData] — while `cid` and `message_id` *are* known fields and so
  /// are not there. Rejoining the two halves is all the bridging this needs.
  Map<String, Object?> toClientToolPayload() => {
        'type': type,
        'cid': cid,
        'message_id': messageId,
        ...extraData,
      };
}
