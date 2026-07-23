/// Editor-Zustand abseits des Widgets: das global persistierte
/// Spaltenverhältnis (`uiEdPct`, Prozent 25–70, Default 50 — editor.js:203)
/// und die reine Snippet-Einfüge-Logik der Toolbar (editor.js:233-242),
/// getrennt vom Widget, damit sie direkt testbar ist.
library;

import 'package:flutter/widgets.dart' show TextSelection;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/db/kv.dart';

part 'editor_state.g.dart';

/// Globaler Store-Key des Editor-Splits (NICHT projekt-gescoped).
const String kUiEdPctKey = 'uiEdPct';

/// Prozent-Klemme des Splits (editor.js:203/209).
int clampEdPct(num? v) {
  final n = (v ?? 50).toInt();
  if (n < 25) return 25;
  if (n > 70) return 70;
  return n;
}

/// `uiEdPct` — Spaltenverhältnis der linken Editor-Spalte in Prozent.
@Riverpod(keepAlive: true)
class EditorSplitPct extends _$EditorSplitPct {
  @override
  Future<int> build() async {
    final v = await ref.watch(kvStoreProvider).getJson(kUiEdPctKey, 50);
    return clampEdPct(v is num ? v : num.tryParse('$v'));
  }

  void set(int pct) {
    final clamped = clampEdPct(pct);
    state = AsyncData(clamped);
    ref.read(kvStoreProvider).setJson(kUiEdPctKey, clamped);
  }

  /// Doppelklick-Reset: zurück auf 50 % (editor.js:208).
  void reset() => set(50);
}

/// Ergebnis einer Snippet-Einfügung: neuer Text + neue Cursor-Position.
class SnippetResult {
  final String text;
  final int cursor;

  const SnippetResult(this.text, this.cursor);
}

/// Toolbar-Snippet einsetzen (editor.js:233-242): enthält das Snippet `$`,
/// ersetzt `$` die aktuelle Selektion und der Cursor landet HINTER der
/// eingesetzten Selektion; sonst Cursor ans Snippet-Ende.
SnippetResult applySnippet(String value, TextSelection sel, String ins) {
  final a = sel.isValid ? sel.start : value.length;
  final e = sel.isValid ? sel.end : value.length;
  final selected = value.substring(a, e);
  final text = ins.contains(r'$') ? ins.replaceFirst(r'$', selected) : ins;
  final out = value.substring(0, a) + text + value.substring(e);
  final pos = a +
      (ins.contains(r'$') ? ins.indexOf(r'$') + selected.length : text.length);
  return SnippetResult(out, pos);
}

/// Die 8 Toolbar-Snippets — Label → Einfügetext, `$` = Selektions-Platzhalter
/// (editor.js:182-184, wörtlich).
const List<(String, String)> kEditorSnippets = [
  (r'\textbf{…}', r'\textbf{$}'),
  (r'\textit{…}', r'\textit{$}'),
  (r'\enquote{…}', r'\enquote{$}'),
  (r'\footnote{…}', r'\footnote{$}'),
  (r'\S', r'\S $'),
  ('itemize', '\\begin{itemize}\n  \\item \$\n\\end{itemize}'),
  (r'\item', r'\item $'),
  ('–', '--'),
];
