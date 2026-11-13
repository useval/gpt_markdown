// Generates the API reference on each component page of the docs, from the
// source: the style class's fields, and the `GptMarkdown` builders and
// callbacks for that component, with their doc comments and exact types.
//
//   dart run tool/docs/api_reference.dart          # write docs/components/api/
//   dart run tool/docs/api_reference.dart --check  # exit 1 if out of date
//
// test/docs/api_reference_test.dart runs the check, so a change to a style
// field, a builder typedef or a doc comment that is not regenerated fails CI.
//
// The source is read with regular expressions, not the analyzer: the files
// follow one shape (`/// docs` then `final Type? name;`), and a shape this
// script cannot read throws rather than writing a partial table.
import 'dart:io';

/// What each component page documents, by docs slug: its style objects, the
/// `GptMarkdown` options that belong to it (builders, callbacks and settings),
/// and the types those options hand you (builder details, enums).
const components =
    <String, ({List<String> styles, List<String> options, List<String> types})>{
      'heading': (
        styles: ['HeadingStyle'],
        options: ['headingBuilder'],
        types: [],
      ),
      'text-formatting': (
        styles: ['HighlightStyle', 'ScriptStyle'],
        options: [],
        types: [],
      ),
      'link': (
        styles: ['LinkStyle'],
        options: [
          'inlineLinkBuilder',
          'onLinkTap',
          'autolink',
          'autolinkSchemes',
          'followLinkColor',
          'linkBuilder',
        ],
        types: ['LinkBuildDetails'],
      ),
      'inline-code': (
        styles: ['InlineCodeStyle'],
        options: ['inlineCodeBuilder', 'inlineCodeStyle', 'highlightBuilder'],
        types: [],
      ),
      'code-block': (
        styles: ['CodeBlockStyle'],
        options: ['codeBuilder', 'onCodeCopy'],
        types: [],
      ),
      'lists': (
        styles: ['ListStyle'],
        options: ['orderedListBuilder', 'unOrderedListBuilder'],
        types: [],
      ),
      'task-list': (
        styles: ['CheckboxStyle'],
        options: ['checkboxBuilder', 'radioOptionBuilder', 'onCheckboxChanged'],
        types: [],
      ),
      'blockquote': (
        styles: ['BlockQuoteStyle'],
        options: ['blockQuoteBuilder'],
        types: [],
      ),
      'alert': (
        styles: ['AlertStyle'],
        options: ['alertBuilder'],
        types: ['AlertBuildDetails', 'MarkdownAlertType'],
      ),
      'table': (
        styles: ['TableStyle'],
        options: ['tableBuilder'],
        types: ['CustomTableRow', 'CustomTableField', 'TableOverflow'],
      ),
      'image': (
        styles: ['ImageStyle'],
        options: ['imageBuilder', 'onImageTap'],
        types: [],
      ),
      'horizontal-rule': (
        styles: ['HrStyle'],
        options: ['hrBuilder'],
        types: [],
      ),
      'math': (
        styles: ['LatexStyle'],
        options: [
          'inlineLatexBuilder',
          'blockLatexBuilder',
          'onLatexTap',
          'useDollarSignsForLatex',
          'latexWorkaround',
          'latexBuilder',
        ],
        types: [
          'InlineLatexBuildDetails',
          'BlockLatexBuildDetails',
          'LatexTapDetails',
        ],
      ),
      'citation': (
        styles: ['SourceTagStyle'],
        options: [
          'inlineSourceTagBuilder',
          'onSourceTagTap',
          'sourceTagBuilder',
        ],
        types: ['SourceTagBuildDetails'],
      ),
    };

const outDir = 'docs/components/api';

void main(List<String> args) {
  final check = args.contains('--check');
  final files = generateApiReference(Directory.current);
  final stale = <String>[];
  for (final MapEntry(key: path, value: content) in files.entries) {
    final file = File(path);
    if (file.existsSync() && file.readAsStringSync() == content) continue;
    stale.add(path);
    if (!check) {
      file
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(content);
    }
  }
  final extra = Directory(outDir).existsSync()
      ? Directory(outDir)
            .listSync()
            .whereType<File>()
            .map((f) => f.path)
            .where((p) => !files.containsKey(p))
            .toList()
      : <String>[];
  if (check) {
    if (stale.isEmpty && extra.isEmpty) return;
    stderr.writeln(
      'API reference out of date: ${[...stale, ...extra].join(', ')}\n'
      'Run `dart run tool/docs/api_reference.dart`.',
    );
    exitCode = 1;
    return;
  }
  for (final p in extra) {
    File(p).deleteSync();
  }
  stdout.writeln(
    stale.isEmpty && extra.isEmpty
        ? 'API reference up to date.'
        : 'Wrote ${stale.length} file(s), removed ${extra.length}.',
  );
}

/// Path → content of every generated file, for the package at [root].
Map<String, String> generateApiReference(Directory root) {
  final sources = {
    for (final f in Directory('${root.path}/lib').listSync(recursive: true))
      if (f is File && f.path.endsWith('.dart')) f.path: f.readAsStringSync(),
  };
  final widget = File('${root.path}/lib/gpt_markdown.dart').readAsStringSync();
  final sheet = File(
    '${root.path}/lib/styles/gpt_markdown_style_sheet.dart',
  ).readAsStringSync();

  return {
    for (final MapEntry(key: slug, value: spec) in components.entries)
      '$outDir/_$slug.mdx': _page(spec, sources, widget, sheet),
  };
}

String _page(
  ({List<String> styles, List<String> options, List<String> types}) spec,
  Map<String, String> sources,
  String widget,
  String sheet,
) {
  final out = StringBuffer()
    ..writeln(
      '{/* Generated by `dart run tool/docs/api_reference.dart` from lib/. '
      'Do not edit. */}',
    );
  for (final name in spec.styles) {
    final source = sources.values.firstWhere(
      (s) => RegExp('^class $name\\b', multiLine: true).hasMatch(s),
      orElse: () => throw StateError('class $name not found in lib/'),
    );
    final key = RegExp(
      '^\\s*final $name\\? (\\w+);',
      multiLine: true,
    ).firstMatch(sheet)?.group(1);
    final body = _classBody(source, name);
    final fields = _fields(body);
    if (fields.isEmpty) throw StateError('$name: no fields read');

    out
      ..writeln()
      ..writeln('### `$name`')
      ..writeln()
      ..writeln(_mdx(_firstParagraph(_docBefore(source, 'class $name'))));
    if (key != null) {
      out
        ..writeln()
        ..writeln(
          'Set it as `GptMarkdownStyleSheet($key: $name(…))` on the widget, '
          'or in `GptMarkdownThemeData` for the whole app. Every field is '
          'optional; an unset one falls back to the theme, then to the default.',
        );
    }
    out
      ..writeln()
      ..writeln('| Field | Type | Description |')
      ..writeln('|---|---|---|');
    for (final f in fields) {
      out.writeln(
        '| `${f.name}` | `${f.type}` | '
        '${f.deprecated ? '*Deprecated.* ' : ''}${_cell(f.doc)} |',
      );
    }
    _more(out, [for (final f in fields) (f.name, f.doc)]);

    final methods = [
      for (final m in _members(body, name))
        if (m.member.contains('(') || m.member.startsWith('static ')) m,
    ];
    if (methods.isNotEmpty) {
      out
        ..writeln()
        ..writeln('| Member | Type | Description |')
        ..writeln('|---|---|---|');
      for (final m in methods) {
        out.writeln('| `${m.member}` | `${m.type}` | ${_cell(m.doc)} |');
      }
      _more(out, [for (final m in methods) (m.member.split('(').first, m.doc)]);
    }
  }

  for (final name in spec.options) {
    final field = _fields(widget).where((f) => f.name == name).firstOrNull;
    if (field == null) throw StateError('GptMarkdown.$name not found');
    final typeName = field.type.replaceAll('?', '');
    final typedef = sources.values
        .map(
          (s) => RegExp(
            '^typedef $typeName\\b[^;]*;',
            multiLine: true,
          ).firstMatch(s)?.group(0),
        )
        .nonNulls
        .firstOrNull;

    out
      ..writeln()
      ..writeln('### `$name`')
      ..writeln();
    if (field.deprecated) {
      out.writeln(
        ':::caution[Deprecated]\n${_deprecation(widget, name)}\n:::\n',
      );
    }
    out.writeln(_mdx(field.doc));
    out
      ..writeln()
      ..writeln('```dart')
      ..writeln(typedef != null ? _oneLine(typedef) : '${field.type} $name')
      ..writeln('```');
  }
  for (final name in spec.types) {
    final source = sources.values.firstWhere(
      (s) => RegExp(
        '^(?:final |base |sealed )?(?:class|enum) $name\\b',
        multiLine: true,
      ).hasMatch(s),
      orElse: () => throw StateError('type $name not found in lib/'),
    );
    final isEnum = RegExp('^enum $name\\b', multiLine: true).hasMatch(source);
    out
      ..writeln()
      ..writeln('### `$name`')
      ..writeln()
      ..writeln(
        _mdx(
          _firstParagraph(
            _docBefore(
              source,
              RegExp('^(?:final |base |sealed )?(?:class|enum) $name\\b'),
            ),
          ),
        ),
      )
      ..writeln();
    if (isEnum) {
      out
        ..writeln('| Value | Description |')
        ..writeln('|---|---|');
      for (final v in _enumValues(_classBody(source, name, 'enum'))) {
        out.writeln('| `${v.name}` | ${_cell(v.doc)} |');
      }
      _more(out, [
        for (final v in _enumValues(_classBody(source, name, 'enum')))
          (v.name, v.doc),
      ]);
      // Members declared after the values.
      final enumBody = _classBody(source, name, 'enum');
      final members = _members(
        enumBody.substring(
          enumBody.indexOf(RegExp(r';\s*$', multiLine: true)) + 1,
        ),
        name,
      );
      if (members.isNotEmpty) {
        out
          ..writeln()
          ..writeln('| Member | Type | Description |')
          ..writeln('|---|---|---|');
        for (final m in members) {
          out.writeln('| `${m.member}` | `${m.type}` | ${_cell(m.doc)} |');
        }
        _more(out, [
          for (final m in members) (m.member.split('(').first, m.doc),
        ]);
      }
      continue;
    }
    final members = [
      // Members a details class inherits from a base class in lib/ come first.
      for (final base in _bases(source, name))
        ..._members(
          _classBody(
            sources.values.firstWhere(
              (s) => RegExp(
                '^(?:abstract |final |base |sealed )*class $base\\b',
                multiLine: true,
              ).hasMatch(s),
            ),
            base,
          ),
          base,
        ),
      ..._members(_classBody(source, name), name),
    ];
    if (members.isEmpty) throw StateError('$name: no members read');
    out
      ..writeln('| Member | Type | Description |')
      ..writeln('|---|---|---|');
    for (final m in members) {
      out.writeln(
        '| `${m.member}` | ${m.type.isEmpty ? '' : '`${m.type}`'} | ${_cell(m.doc)} |',
      );
    }
    _more(out, [for (final m in members) (m.member.split('(').first, m.doc)]);
  }
  return out.toString();
}

/// After a table: the rest of each doc comment the table's one-line cell left
/// out — later paragraphs and code examples — in a collapsed block, so the
/// table stays scannable and nothing in the source is dropped.
void _more(StringBuffer out, List<(String, String)> entries) {
  for (final (name, doc) in entries) {
    final paragraphs = doc.split(RegExp(r'\n\s*\n'));
    if (paragraphs.length < 2) continue;
    out
      ..writeln()
      ..writeln('<details>')
      ..writeln('<summary><code>$name</code>: more</summary>')
      ..writeln()
      ..writeln(_mdx(paragraphs.skip(1).join('\n\n')))
      ..writeln()
      ..writeln('</details>');
  }
}

/// The classes [name] extends that are declared in the same source, nearest
/// last — so inherited members can be listed with its own.
Iterable<String> _bases(String source, String name) sync* {
  final m = RegExp(
    '^(?:final |base |sealed )?class $name\\b[^{]*?extends (\\w+)',
    multiLine: true,
  ).firstMatch(source);
  if (m == null) return;
  final base = m.group(1)!;
  if (!RegExp('class $base\\b').hasMatch(source)) return;
  yield* _bases(source, base);
  yield base;
}

typedef _Member = ({String member, String type, String doc});

/// The documented public fields, getters and methods in a class body.
/// Constructors, statics, overrides and private members are left out.
List<_Member> _members(String body, String cls) {
  final out = <_Member>[];
  final doc = RegExp(
    r'((?:^  ///[^\n]*\n)+)((?:^  @[^\n]*\n(?:^   +[^\n]*\n)*?)*)^  (?=\S)',
    multiLine: true,
  );
  for (final m in doc.allMatches(body)) {
    if (m.group(2)!.contains('@override')) continue;
    // The declaration runs to the first `;`, `{` or `=>` outside parentheses.
    var depth = 0, i = m.end;
    for (; i < body.length; i++) {
      final c = body[i];
      if (c == '(' || c == '[') depth++;
      if (c == ')' || c == ']') depth--;
      if (depth == 0 && (c == ';' || c == '{' || body.startsWith('=>', i))) {
        break;
      }
    }
    final decl = body
        .substring(m.end, i)
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('( ', '(')
        .replaceAll('{ ', '{')
        .replaceAll(RegExp(r',?\s*\)'), ')')
        .replaceAll(RegExp(r',?\s*\}'), '}')
        .trim();
    // Constructors: `const Cls(`, `Cls(`, `Cls.named(`, `factory …`.
    if (RegExp('^(const |factory |$cls[.(])').hasMatch(decl)) continue;
    final constant = RegExp(
      r'^static const (.+) (\w+) = (.+)$',
    ).firstMatch(decl);
    if (constant != null) {
      out.add((
        member: 'static ${constant.group(2)} = ${constant.group(3)}',
        type: constant.group(1)!,
        doc: _docText(m.group(1)!),
      ));
      continue;
    }
    if (decl.startsWith('static ') && !decl.contains('(')) continue;
    final text = _docText(m.group(1)!);
    final field = RegExp(r'^final (.+) (\w+)$').firstMatch(decl);
    final getter = RegExp(r'^(.+) get (\w+)$').firstMatch(decl);
    final method = RegExp(r'^(.+?) (\w+)(\(.*\))$').firstMatch(decl);
    if (field != null) {
      if (field.group(2)!.startsWith('_')) continue;
      out.add((member: field.group(2)!, type: field.group(1)!, doc: text));
    } else if (getter != null) {
      if (getter.group(2)!.startsWith('_')) continue;
      out.add((member: getter.group(2)!, type: getter.group(1)!, doc: text));
    } else if (method != null) {
      if (method.group(2)!.startsWith('_')) continue;
      final isStatic = method.group(1)!.startsWith('static ');
      // A long parameter list (`copyWith`'s repeats every field) is elided.
      final params = method.group(3)!.length > 60
          ? (method.group(3)!.startsWith('({') ? '({…})' : '(…)')
          : method.group(3)!;
      out.add((
        member: '${isStatic ? 'static ' : ''}${method.group(2)}$params',
        type: method.group(1)!.replaceFirst('static ', ''),
        doc: text,
      ));
    }
  }
  return out;
}

/// An enum's values with their doc comments.
List<({String name, String doc})> _enumValues(String body) {
  final out = <({String name, String doc})>[];
  final doc = <String>[];
  // Values end at the first `;` on a code line (a doc comment may hold one).
  for (final line in body.split('\n')) {
    final t = line.trim();
    if (t.startsWith('///')) {
      doc.add(t);
    } else if (t.startsWith('//') || t.startsWith('@') || t.isEmpty) {
      continue;
    } else {
      // `a,` or `a` — or several on one line: `none, left, center, right`.
      final end = t.contains(';');
      final names = t
          .split(';')
          .first
          .split(',')
          .map((n) => n.trim())
          .where((n) => n.isNotEmpty);
      for (final n in names) {
        out.add((name: n, doc: _docText(doc.join('\n'))));
        doc.clear();
      }
      if (end) break;
    }
  }
  return out;
}

typedef _Field = ({String name, String type, String doc, bool deprecated});

/// `/// docs` + optional annotations + `final Type? name;`, in order.
List<_Field> _fields(String body) {
  final re = RegExp(
    r'((?:^[ \t]*///[^\n]*\n)+)((?:^[ \t]*@[^\n]*\n(?:^[ \t]+[^\n]*\n)*?)*)^[ \t]*final ([^=;]+?) (\w+);',
    multiLine: true,
  );
  return [
    for (final m in re.allMatches(body))
      (
        name: m.group(4)!,
        type: m.group(3)!.trim(),
        doc: _docText(m.group(1)!),
        deprecated: m.group(2)!.contains('@Deprecated'),
      ),
  ];
}

/// The text inside `class Name { … }`, to the matching closing brace.
String _classBody(String source, String name, [String keyword = 'class']) {
  final start = RegExp(
    '^(?:abstract |final |base |sealed )*$keyword $name\\b[^{]*\\{',
    multiLine: true,
  ).firstMatch(source)!;
  var depth = 1;
  for (var i = start.end; i < source.length; i++) {
    final c = source[i];
    if (c == '{') depth++;
    if (c == '}' && --depth == 0) return source.substring(start.end, i);
  }
  throw StateError('$name: unbalanced braces');
}

/// The doc comment directly above [declaration] (annotations allowed between).
String _docBefore(String source, Pattern declaration) {
  final lines = source.split('\n');
  final at = lines.indexWhere(
    (l) => declaration is RegExp
        ? declaration.hasMatch(l)
        : l.startsWith(declaration as String),
  );
  var i = at - 1;
  while (i >= 0 && lines[i].trimLeft().startsWith('@')) {
    i--;
  }
  final doc = <String>[];
  while (i >= 0 && lines[i].trimLeft().startsWith('///')) {
    doc.insert(0, lines[i--]);
  }
  return _docText(doc.join('\n'));
}

String _deprecation(String widget, String name) {
  final m = RegExp(
    "@Deprecated\\(\\s*((?:'[^']*'\\s*)+)\\)\\s*final [^;]* $name;",
  ).firstMatch(widget);
  if (m == null) return 'Deprecated.';
  return _mdx(
    RegExp(r"'([^']*)'").allMatches(m.group(1)!).map((x) => x.group(1)).join(),
  );
}

/// A doc comment's text: `///` stripped, code fences kept, `[Ref]` → `` `Ref` ``.
String _docText(String comment) {
  final text = comment
      .split('\n')
      .map((l) => l.trimLeft())
      .where((l) => l.startsWith('///'))
      .map((l) => l.length > 3 && l[3] == ' ' ? l.substring(4) : l.substring(3))
      .join('\n')
      .trim();
  // `[Ref]` → `` `Ref` ``, outside code spans and fences only.
  var inFence = false;
  return text
      .split('\n')
      .map((line) {
        if (line.trimLeft().startsWith('```')) inFence = !inFence;
        if (inFence || line.trimLeft().startsWith('```')) return line;
        final parts = line.split('`');
        for (var i = 0; i < parts.length; i += 2) {
          parts[i] = parts[i].replaceAllMapped(
            RegExp(r'(?<!\[)\[([A-Za-z_][\w.]*)\](?![(\[])'),
            (m) => '`${m[1]}`',
          );
        }
        return parts.join('`');
      })
      .join('\n');
}

String _firstParagraph(String doc) => doc.split(RegExp(r'\n\s*\n')).first;

/// A table cell: the first paragraph, on one line, pipes escaped.
String _cell(String doc) =>
    _mdx(_firstParagraph(doc).replaceAll('\n', ' ')).replaceAll('|', r'\|');

/// Prose made safe for MDX: `{`, `}` and `<` escaped outside code spans and
/// fences, so a doc comment cannot open a JSX expression or tag.
String _mdx(String text) {
  final out = StringBuffer();
  var inFence = false;
  for (final line in text.split('\n')) {
    if (line.trimLeft().startsWith('```')) {
      inFence = !inFence;
      out.writeln(line);
      continue;
    }
    if (inFence) {
      out.writeln(line);
      continue;
    }
    final parts = line.split('`');
    for (var i = 0; i < parts.length; i += 2) {
      parts[i] = parts[i]
          .replaceAll('{', r'\{')
          .replaceAll('}', r'\}')
          .replaceAll('<', '&lt;');
    }
    out.writeln(parts.join('`'));
  }
  return out.toString().trimRight();
}

/// A typedef on one line, or with one parameter per line when that would be
/// longer than 80 columns — the shape `dart format` gives it.
String _oneLine(String code) {
  final flat = code
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('( ', '(')
      .replaceAll(RegExp(r',?\s*\)'), ')');
  if (flat.length <= 80) return flat;
  final open = flat.indexOf('Function(') + 'Function('.length;
  final close = flat.lastIndexOf(')');
  final params = <String>[];
  var depth = 0, start = open;
  for (var i = open; i < close; i++) {
    final c = flat[i];
    if ('<([{'.contains(c)) depth++;
    if ('>)]}'.contains(c)) depth--;
    if (c == ',' && depth == 0) {
      params.add(flat.substring(start, i).trim());
      start = i + 1;
    }
  }
  params.add(flat.substring(start, close).trim());
  return '${flat.substring(0, open)}\n'
      '${params.map((p) => '  $p,').join('\n')}\n'
      '${flat.substring(close)}';
}
