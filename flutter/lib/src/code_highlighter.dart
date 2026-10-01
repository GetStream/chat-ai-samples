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

/// Syntax highlighting for code blocks in AI messages, using `re_highlight`.
///
/// `stream_chat_flutter_ai` renders code blocks but ships no grammars, so the
/// app supplies them. Returning null renders the block as plain text.
TextSpan? highlightCode(String code, String language, TextStyle baseStyle) {
  // `re_highlight` throws for a language it doesn't know, and models label
  // fences with anything, e.g. `pseudocode`.
  if (_highlight.getLanguage(language) == null) return null;

  final result = _highlight.highlight(code: code, language: language);
  // On a parse failure the result holds only part of the code.
  if (result.errorRaised != null) return null;

  final renderer = TextSpanRenderer(baseStyle, vs2015Theme);
  result.render(renderer);
  return renderer.span;
}

/// Compiled on the first code block rather than at startup.
final Highlight _highlight = Highlight()..registerLanguages(_languages);

/// A curated set, not `builtinAllLanguages`: registering all 194 grammars adds
/// megabytes to the app. Aliases such as `js`, `py` or `sh` resolve through
/// these entries. Drop any you don't need; `swift` is by far the largest.
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
