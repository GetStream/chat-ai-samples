import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/code_highlighter.dart';
// stream_chat_flutter ships older versions of these AI widgets; use the ones
// from stream_chat_flutter_ai.
import 'package:stream_chat_flutter/stream_chat_flutter.dart'
    hide StreamingMessageView, TypewriterState;
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders an AI message as streaming markdown, without a bubble or avatar.
///
/// The user's own messages keep the SDK's regular bubble.
class AIMessageItem extends StatelessWidget {
  const AIMessageItem({
    super.key,
    required this.message,
    this.onTypewriterStateChanged,
  });

  final Message message;
  final ValueChanged<TypewriterState>? onTypewriterStateChanged;

  @override
  Widget build(BuildContext context) {
    // Use the same text style as the regular message bubbles.
    final bodyStyle = context.streamTextTheme.bodyDefault.copyWith(
      color: context.streamColorScheme.textPrimary,
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: StreamingMessageView(
        text: message.text ?? '',
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
