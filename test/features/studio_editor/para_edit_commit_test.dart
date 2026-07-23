/// Tests der Absatz-Doppelklick-Übernahme (S-3, `commitParaEdit`):
/// Whitespace-Normalisierung, `paraEdits`-Override (== Original ⇒ löschen),
/// §0-Sync des [textOverridesProvider] und der LaTeX-Sync nach `texEdits`.
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/data/bundles/indexes.dart';
import 'package:thesor/data/db/database.dart';
import 'package:thesor/data/db/kv.dart';
import 'package:thesor/features/studio/layout/studio_state.dart';
import 'package:thesor/features/studio/views/para_edit.dart';

import '../studio/studio_state_test.dart' show testRuntime;

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
    container.read(activeRuntimeProvider.notifier).activate(testRuntime());
    await container.read(studioPrefsCtlProvider.future);
    await container.read(studioKvProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Map<String, Object?> kvMap(String key) =>
      container.read(studioKvProvider.notifier).readMap(key);

  test('normalisiert, schreibt paraEdits + Overrides + LaTeX-Sync', () {
    final out = commitParaEdit(
      container,
      sectionId: '1.1',
      paraId: '1.1-p1',
      // nbsp + Zeilenumbrüche + Doppel-Spaces → EIN Space.
      rawInput: 'Neuer Text.\n\nMit  Beleg.[^1]',
    );
    expect(out, 'Neuer Text. Mit Beleg.[^1]');

    // paraEdits-Override gespeichert:
    expect(kvMap(KvKeys.paraEdits)['1.1-p1'], 'Neuer Text. Mit Beleg.[^1]');

    // §0: textOverridesProvider zieht nach; effektive Struktur übernimmt.
    expect(container.read(textOverridesProvider).paraEdits['1.1-p1'],
        'Neuer Text. Mit Beleg.[^1]');
    expect(
      container
          .read(effectiveThesisProvider)!
          .chapters
          .first
          .sections
          .first
          .paragraphs
          .first
          .text,
      'Neuer Text. Mit Beleg.[^1]',
    );

    // LaTeX-Sync: texEdits['1.1'] enthält den rekonstruierten Abschnitt mit
    // dem NEUEN Text und dem ORIGINAL-Fußnotentext als \footnote{…}.
    final tex = kvMap(KvKeys.texEdits)['1.1'];
    expect(tex, isA<String>());
    expect('$tex', contains('Neuer Text. Mit Beleg.'));
    expect('$tex', contains(r'\footnote{Vgl. Kim 2023, S. 4.}'));
  });

  test('Rückkehr zum Original entfernt den Override', () {
    commitParaEdit(container,
        sectionId: '1.1', paraId: '1.1-p1', rawInput: 'Anders.');
    expect(kvMap(KvKeys.paraEdits).containsKey('1.1-p1'), isTrue);

    // Exakt der Originaltext (nach Normalisierung) ⇒ Eintrag gelöscht.
    commitParaEdit(container,
        sectionId: '1.1',
        paraId: '1.1-p1',
        rawInput: 'Erster Satz. Zweiter Satz mit Beleg.[^1]');
    expect(kvMap(KvKeys.paraEdits).containsKey('1.1-p1'), isFalse);
    expect(container.read(textOverridesProvider).paraEdits, isEmpty);
  });

  test('leere Eingabe wird verworfen (kein Override, kein Sync)', () {
    final out = commitParaEdit(container,
        sectionId: '1.1', paraId: '1.1-p1', rawInput: '   \n ');
    expect(out, '');
    expect(kvMap(KvKeys.paraEdits), isEmpty);
    expect(kvMap(KvKeys.texEdits), isEmpty);
  });

  test('unveränderte Eingabe schreibt nichts (kein texEdits-Rauschen)', () {
    commitParaEdit(container,
        sectionId: '1.1',
        paraId: '1.1-p1',
        rawInput: 'Erster Satz. Zweiter Satz mit Beleg.[^1]');
    expect(kvMap(KvKeys.paraEdits), isEmpty);
    expect(kvMap(KvKeys.texEdits), isEmpty);
  });
}
