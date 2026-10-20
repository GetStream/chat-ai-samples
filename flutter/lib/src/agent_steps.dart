/// Agent steps: the reasoning and tool calls an agent writes as `ai_reasoning`
/// and `ai_tool_call` attachments on its reply.
///
/// `AIMessageItem` shows them above the reply. [ConversationAgentSteps] answers
/// the calls that wait for this device: approvals through an [AIToolApprover],
/// client tools through an [AIClientToolRunner].
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import 'agent_service.dart';

/// This install, as tool calls target it (`target_client_id`). Sent as
/// `client_id` with every message, so the agent knows where to send a call.
///
/// New on every launch, so a call waiting from before a restart doesn't run.
/// Persist it if it should.
final clientId = const Uuid().v4();

extension MessageAgentSteps on Message {
  /// The agent steps on this message, in order.
  List<AIMessagePart> get agentSteps => AIMessagePart.parseAll([
    for (final attachment in attachments)
      // `rawType`: `type` can be rewritten, e.g. into a link preview. The
      // spread goes last so the step's own `id` wins over the attachment's.
      if (attachment.rawType case final type?) (type: type, payload: {'id': attachment.id, ...attachment.extraData}),
  ]);
}

/// Answers the tool calls in one conversation that wait for this device.
///
/// Keep one per conversation for the app's lifetime: a new runner doesn't
/// know what an old one ran.
class ConversationAgentSteps {
  ConversationAgentSteps({
    required this.channelId,
    required AIClientIdentity identity,
    required List<AIClientTool> tools,
    required AgentService agentService,
    required this.onError,
  }) {
    approver = AIToolApprover(
      identity: identity,
      // A call whose step never changes after the answer can be answered again.
      sentTimeout: const Duration(seconds: 30),
      decide: (call, decision) async {
        try {
          await agentService.answerToolCall(channelId: channelId, call: call, decision: decision, identity: identity);
        } catch (e) {
          _reportOnce(call, "Couldn't send your answer to the assistant. ${describeBackendError(e)}");
          rethrow;
        }
      },
    );
    runner = AIClientToolRunner(
      identity: identity,
      tools: tools,
      send: (call, result) => agentService.sendToolResult(
        channelId: channelId,
        call: call,
        result: result,
        clientId: identity.clientId!,
      ),
      onToolError: (call, error, stack) => _reportOnce(call, 'The assistant\'s "${call.name}" action failed.'),
      onDeliveryError: (call, result, error, stack) => _reportOnce(
        call,
        "Couldn't send the \"${call.name}\" result to the assistant. ${describeBackendError(error)}",
      ),
    );
  }

  final String channelId;

  /// Shows the user that a tool call went wrong.
  final ValueChanged<String> onError;

  /// Asks under each call waiting for this user's approval.
  late final AIToolApprover approver;

  /// Runs each `awaiting_client` call targeted at this install, once.
  late final AIClientToolRunner runner;

  /// Calls already reported, since the runner retries a delivery on every
  /// update while its call waits.
  final _reported = <String>{};

  void _reportOnce(AIToolCallPart call, String message) {
    if (_reported.add(call.id)) onError(message);
  }

  /// Runs the client tool calls in [messages]. Safe to call on every update.
  void handle(Iterable<Message> messages) {
    for (final message in messages) {
      if (message.attachments.isEmpty) continue;
      unawaited(runner.handle(message.agentSteps));
    }
  }

  /// Calls already running still finish and send their results.
  void dispose() {
    runner.close();
    approver.dispose();
  }
}

/// One [ConversationAgentSteps] per conversation, kept across reopening it so
/// a call that still waits doesn't run twice.
class AgentStepsByChannel {
  AgentStepsByChannel(this._create);

  final ConversationAgentSteps Function(Channel channel) _create;
  final _byCid = <String, ConversationAgentSteps>{};

  /// The steps of [channel], created on first use.
  ConversationAgentSteps of(Channel channel) => _byCid.putIfAbsent(channel.cid!, () => _create(channel));

  void dispose() {
    for (final steps in _byCid.values) {
      steps.dispose();
    }
    _byCid.clear();
  }
}
