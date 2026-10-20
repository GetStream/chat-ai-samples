import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
// stream_chat_flutter ships older versions of these AI widgets; use the ones
// from stream_chat_flutter_ai.
import 'package:stream_chat_flutter/stream_chat_flutter.dart' hide StreamingMessageView, TypewriterState;
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:url_launcher/url_launcher.dart';

import 'agent_steps.dart';
import 'code_highlighter.dart';

/// Renders an AI message as streaming markdown, without a bubble or avatar,
/// under the agent's steps (reasoning and tool calls), if it wrote any.
///
/// The user's own messages keep the SDK's regular bubble.
class AIMessageItem extends StatelessWidget {
  const AIMessageItem({
    super.key,
    required this.message,
    this.expectMoreText = false,
    this.onFinished,
    this.onTypewriterStateChanged,
    this.approver,
  });

  final Message message;

  /// Whether the backend may still add text to [message].
  final bool expectMoreText;

  /// Called once [message] is completely on screen.
  final VoidCallback? onFinished;

  final ValueChanged<TypewriterState>? onTypewriterStateChanged;

  /// Asks under each tool call waiting for this user's approval.
  final AIToolApprover? approver;

  @override
  Widget build(BuildContext context) {
    // Use the same text style as the regular message bubbles.
    final bodyStyle = context.streamTextTheme.bodyDefault.copyWith(
      color: context.streamColorScheme.textPrimary,
    );

    final steps = message.agentSteps;
    final reply = StreamingMessageView(
      text: message.text ?? '',
      expectMoreText: expectMoreText,
      onFinished: onFinished,
      onTypewriterStateChanged: onTypewriterStateChanged,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(p: bodyStyle),

      // Optional extras. The package renders code blocks, formulas and
      // links, but the app supplies the grammars, math engine and link
      // handling.
      codeHighlighter: highlightCode,
      mathBuilder: _buildMath,
      // Models write `$…$` more often than the default `\(…\)` / `\[…\]`.
      useDollarDelimitersForMath: true,
      onTapLink: (text, href, title) => _openLink(href),
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      // Always a column, so the reply keeps its typewriter state when the
      // first step arrives.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (steps.isNotEmpty) ...[
            AIMessagePartsView(parts: steps, approver: approver),
            const SizedBox(height: 12),
          ],
          reply,
        ],
      ),
    );
  }

  static Widget _buildMath(
    BuildContext context,
    String tex,
    TextStyle? style, {
    required bool inline,
  }) {
    return Math.tex(
      tex,
      textStyle: style,
      mathStyle: inline ? MathStyle.text : MathStyle.display,
      // Models emit malformed TeX often enough; show the source instead.
      onErrorFallback: (error) => Text(tex, style: style),
    );
  }

  static Future<void> _openLink(String? href) async {
    final uri = href == null ? null : Uri.tryParse(href);
    if (uri == null) return;
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (e) {
      debugPrint('Failed to open link $href: $e');
      return;
    }
    debugPrint('Could not open link: $href');
  }
}
