/// Kernlogik-Tests des LaTeX-Editors (S-3): Snippet-Einfügung
/// (`$`-Selektions-Semantik, editor.js:233-242), Split-Klemme 25–70
/// (`uiEdPct`) und die wörtlichen Toolbar-Snippets.
library;

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show TextSelection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/data/db/database.dart';
import 'package:thesor/data/db/kv.dart';
import 'package:thesor/features/studio/editor/editor_state.dart';

void main() {
  group('applySnippet', () {
    test(r'$ ersetzt die Selektion, Cursor hinter der eingesetzten Selektion',
        () {
      // "Hallo Welt" — "Welt" markiert, \textbf{$} einfügen.
      const value = 'Hallo Welt';
      const sel = TextSelection(baseOffset: 6, extentOffset: 10);
      final r = applySnippet(value, sel, r'\textbf{$}');
      expect(r.text, r'Hallo \textbf{Welt}');
      // Cursor = a + ins.indexOf('$') + sel.length = 6 + 8 + 4.
      expect(r.cursor, 18);
    });

    test(r'ohne $ landet der Cursor am Snippet-Ende', () {
      const value = 'a–b';
      const sel = TextSelection.collapsed(offset: 1);
      final r = applySnippet(value, sel, '--');
      expect(r.text, 'a--–b');
      expect(r.cursor, 3);
    });

    test('leere Selektion: Platzhalter wird leer ersetzt', () {
      const value = 'xy';
      const sel = TextSelection.collapsed(offset: 1);
      final r = applySnippet(value, sel, r'\enquote{$}');
      expect(r.text, r'x\enquote{}y');
      expect(r.cursor, 1 + r'\enquote{'.length);
    });

    test('itemize-Snippet (mehrzeilig) mit Selektion', () {
      const value = 'Punkt eins';
      const sel = TextSelection(baseOffset: 0, extentOffset: 10);
      final r = applySnippet(
          value, sel, '\\begin{itemize}\n  \\item \$\n\\end{itemize}');
      expect(r.text, '\\begin{itemize}\n  \\item Punkt eins\n\\end{itemize}');
      expect(r.cursor, '\\begin{itemize}\n  \\item '.length + 10);
    });

    test('ungültige Selektion fügt am Ende ein', () {
      final r = applySnippet('abc', const TextSelection.collapsed(offset: -1),
          r'\item $');
      expect(r.text, r'abc\item ');
      expect(r.cursor, r'abc\item '.length);
    });
  });

  group('clampEdPct', () {
    test('klemmt auf 25–70, Default 50', () {
      expect(clampEdPct(null), 50);
      expect(clampEdPct(24), 25);
      expect(clampEdPct(25), 25);
      expect(clampEdPct(50), 50);
      expect(clampEdPct(70), 70);
      expect(clampEdPct(71), 70);
    });
  });

  group('kEditorSnippets', () {
    test('die 8 Toolbar-Snippets wörtlich (editor.js:182-184)', () {
      expect(kEditorSnippets, const [
        (r'\textbf{…}', r'\textbf{$}'),
        (r'\textit{…}', r'\textit{$}'),
        (r'\enquote{…}', r'\enquote{$}'),
        (r'\footnote{…}', r'\footnote{$}'),
        (r'\S', r'\S $'),
        ('itemize', '\\begin{itemize}\n  \\item \$\n\\end{itemize}'),
        (r'\item', r'\item $'),
        ('–', '--'),
      ]);
    });
  });

  group('EditorSplitPct (uiEdPct)', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ]);
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('set persistiert geklemmt; Reboot liest den Wert zurück', () async {
      expect(await container.read(editorSplitPctProvider.future), 50);

      container.read(editorSplitPctProvider.notifier).set(64);
      expect(container.read(editorSplitPctProvider).value, 64);
      // Roh im KV (global, NICHT projekt-gescoped — uiEdPct fehlt in
      // PROJECT_KEYS):
      expect(await container.read(kvStoreProvider).getJson(kUiEdPctKey), 64);

      // Über-Grenze wird geklemmt gespeichert.
      container.read(editorSplitPctProvider.notifier).set(95);
      expect(await container.read(kvStoreProvider).getJson(kUiEdPctKey), 70);

      // Neuaufbau des Providers liest aus dem Store.
      container.invalidate(editorSplitPctProvider);
      expect(await container.read(editorSplitPctProvider.future), 70);

      container.read(editorSplitPctProvider.notifier).reset();
      expect(container.read(editorSplitPctProvider).value, 50);
    });
  });
}
