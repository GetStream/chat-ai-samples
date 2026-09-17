import 'package:flutter/painting.dart';
import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/c.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/csharp.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/diff.dart';
import 'package:re_highlight/languages/dockerfile.dart';
import 'package:re_highlight/languages/go.dart';
import 'package:re_highlight/languages/graphql.dart';
import 'package:re_highlight/languages/ini.dart';
import 'package:re_highlight/languages/java.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/kotlin.dart';
import 'package:re_highlight/languages/lua.dart';
import 'package:re_highlight/languages/markdown.dart';
import 'package:re_highlight/languages/objectivec.dart';
import 'package:re_highlight/languages/php.dart';
import 'package:re_highlight/languages/plaintext.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/r.dart';
import 'package:re_highlight/languages/ruby.dart';
import 'package:re_highlight/languages/rust.dart';
import 'package:re_highlight/languages/scala.dart';
import 'package:re_highlight/languages/shell.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/languages/swift.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/styles/vs2015.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

/// A [CodeHighlighter] over `re_highlight`, wired to [_languages] and
/// [_theme].
///
/// `stream_chat_flutter_ai` recognises code fences and renders their chrome,
/// but ships no grammars — they dwarf the package itself — so this is the seam
/// where a host supplies them, exactly as `mathBuilder` supplies a math engine.
/// Copy this file to get highlighting in your own app.
///
/// Returning null is how a fence declines to be highlighted; [CodeBlockView]
/// then renders it as plain monospace text.
TextSpan? highlightCode(String code, String language, TextStyle baseStyle) {
  // `re_highlight` throws on a language it has no grammar for rather than
  // degrading, and an LLM will happily label a fence `pseudocode`.
  if (_highlight.getLanguage(language) == null) return null;

  final result = _highlight.highlight(code: code, language: language);
  // `Highlight` runs in safe mode, so a grammar or engine failure part-way
  // through the parse is reported here rather than thrown — and the emitter it
  // hands back holds only the tokens produced before the failure. Rendering
  // that would drop the tail of the code, or all of it.
  if (result.errorRaised != null) return null;

  final renderer = TextSpanRenderer(baseStyle, _theme);
  result.render(renderer);
  return renderer.span;
}

/// Token colors, keyed by highlight.js scope name.
///
/// Visual Studio 2015's dark palette, whose `root` is `#DCDCDC` on `#1E1E1E` —
/// the same colors `CodeBlockView` defaults to, so the tokens land on the
/// background the block already draws. Any of `re_highlight`'s `styles/*.dart`
/// maps works here.
const _theme = vs2015Theme;

/// The process-wide highlighter, with [_languages] registered.
///
/// A lazy top-level `final`, so the grammars are compiled on the first code
/// block a process renders rather than at startup, and only once.
final Highlight _highlight = Highlight()..registerLanguages(_languages);

/// The grammars to register, keyed by fence language.
///
/// Curated rather than `re_highlight`'s own `builtinAllLanguages`, and
/// deliberately so. That map references all 194 bundled grammars, and each is a
/// top-level `final` holding a tree of `Mode` constructor calls — so naming it
/// makes 2.7 MB of Dart source reachable, and nothing tree-shakes it back out.
/// This set is ~870 KB of source, which compiles to ~636 KB of JS (~56 KB
/// gzipped) in a release web build, and covers what LLMs actually emit.
///
/// `swift` alone is 388 KB of that source total. Drop it, or any other entry
/// you don't need — a language that isn't registered simply renders plain.
///
/// Aliases don't need listing: [Highlight.registerLanguage] reads each
/// grammar's own `aliases`, so `js`/`jsx`/`mjs`, `ts`/`tsx`, `py`, `sh`, `yml`,
/// `c++`/`hpp`/`cxx`, `cs`/`c#`, `rb`, `kt`, `rs`, `md`, `objc`, `gql`,
/// `docker`, `html`/`svg`/`xhtml`, `text`/`txt` and `console` all resolve
/// through the entries below.
final Map<String, Mode> _languages = {
  'bash': langBash,
  'c': langC,
  'cpp': langCpp,
  'csharp': langCsharp,
  'css': langCss,
  'dart': langDart,
  'diff': langDiff,
  'dockerfile': langDockerfile,
  'go': langGo,
  'graphql': langGraphql,
  'ini': langIni,
  'java': langJava,
  'javascript': langJavascript,
  'json': langJson,
  'kotlin': langKotlin,
  'lua': langLua,
  'markdown': langMarkdown,
  'objectivec': langObjectivec,
  'php': langPhp,
  'plaintext': langPlaintext,
  'python': langPython,
  'r': langR,
  'ruby': langRuby,
  'rust': langRust,
  'scala': langScala,
  'shell': langShell,
  'sql': langSql,
  'swift': langSwift,
  'typescript': langTypescript,
  'xml': langXml,
  'yaml': langYaml,
};
