/// Agent steps: the reasoning and tool calls an agent writes as `ai_reasoning`
/// and `ai_tool_call` attachments on its reply.
///
/// `AIMessageItem` shows them above the reply. [ConversationAgentSteps] answers
/// the calls that wait for this device: approvals through an [AIToolApprover],
/// client tools through an [AIClientToolRunner].
library;

import 'dart:async';

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
/// Keep one per conversation: a new runner doesn't know what an old one ran.
class ConversationAgentSteps {
  ConversationAgentSteps({
    required this.channelId,
    required AIClientIdentity identity,
    required List<AIClientTool> tools,
    required AgentService agentService,
  }) : approver = AIToolApprover(
         identity: identity,
         decide: (call, decision) => agentService.answerToolCall(
           channelId: channelId,
           call: call,
           decision: decision,
           identity: identity,
         ),
       ),
       runner = AIClientToolRunner(
         identity: identity,
         tools: tools,
         send: (call, result) => agentService.sendToolResult(
           channelId: channelId,
           call: call,
           result: result,
           clientId: identity.clientId ?? '',
         ),
       );

  final String channelId;

  /// Asks under each call waiting for this user's approval.
  final AIToolApprover approver;

  /// Runs each `awaiting_client` call targeted at this install, once.
  final AIClientToolRunner runner;

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
