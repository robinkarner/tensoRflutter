/// Zustands-Tests des Erklärbuchs (K-1): KV-Store, Quellen-Kaskade
/// (eigenes > eingebautes > Starter), Datenpaket und 🤖-Prompt.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thesor/data/bundles/indexes.dart';
import 'package:thesor/data/db/database.dart';
import 'package:thesor/data/db/kv.dart';
import 'package:thesor/features/studio/layout/studio_state.dart';
import 'package:thesor/features/wissen/notebook/notebook_prompt.dart';
import 'package:thesor/features/wissen/notebook/notebook_state.dart';
import 'package:thesor/features/wissen/tabs/wissen_state.dart';

import 'wissen_fixtures.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  Future<void> boot({String? erklaerbuch}) async {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
    container
        .read(activeRuntimeProvider.notifier)
        .activate(wissenTestRuntime(erklaerbuch: erklaerbuch));
    await container.read(studioPrefsCtlProvider.future);
    await container.read(studioKvProvider.future);
    await container.read(notebookStoreProvider.future);
  }

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('NotebookStore: set/get + Leerstring löscht', () async {
    await boot();
    final store = container.read(notebookStoreProvider.notifier);
    store.set('# Mein Buch');
    expect(container.read(notebookStoreProvider).value, '# Mein Buch');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await container.read(kvStoreProvider).getJson(KvKeys.notebook),
        '# Mein Buch');

    // Leer/blank → Original speichert null → hier: Eintrag weg.
    store.set('   ');
    expect(container.read(notebookStoreProvider).value, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
        await container.read(kvStoreProvider).getJson(KvKeys.notebook), isNull);
  });

  test('Kaskade: eigenes Buch > eingebautes > Starter', () async {
    await boot(erklaerbuch: '# Eingebautes Buch');
    var src = container.read(erklaerbuchSourceProvider);
    expect(src.own, isFalse);
    expect(src.hasBuiltin, isTrue);
    expect(src.src, '# Eingebautes Buch');

    container.read(notebookStoreProvider.notifier).set('# Eigenes Buch');
    src = container.read(erklaerbuchSourceProvider);
    expect(src.own, isTrue);
    expect(src.src, '# Eigenes Buch');

    container.read(notebookStoreProvider.notifier).set(null);
    src = container.read(erklaerbuchSourceProvider);
    expect(src.own, isFalse);
    expect(src.src, '# Eingebautes Buch');
  });

  test('ohne eingebautes Buch rendert der Starter', () async {
    await boot();
    final src = container.read(erklaerbuchSourceProvider);
    expect(src.hasBuiltin, isFalse);
    expect(src.src, contains('# Erklärbuch — Testarbeit'));
  });

  test('Datenpaket: echte Zahlen der Arbeit', () async {
    await boot();
    final d = await container.read(notebookDatasetProvider.future);
    expect((d['arbeit'] as Map)['titel'], 'Testarbeit');
    final kapitel = d['kapitel'] as List;
    expect(kapitel.length, 2);
    expect((kapitel.first as Map)['fussnoten'], 1);
    final quellen = d['quellen'] as List;
    expect((quellen.single as Map)['kurz'], 'Kim 2023');
    expect((quellen.single as Map)['zitierstellen'], 1);
    final status = d['belegStatus'] as Map;
    // KI-Beleg vorhanden → Fußnote 1 auf Stufe 1 (vermutet).
    expect(status['gesamt'], 1);
    expect(status['vermutet'], 1);
    final abb = d['abbildungen'] as List;
    expect((abb.single as Map)['id'], 'abb-1');
  });

  test('🤖 Prompt enthält Referenz, Abschnitte und Datenpaket', () async {
    await boot();
    final prompt = await container.read(notebookPromptProvider.future);
    expect(prompt, contains('Du erzeugst das ERKLÄRBUCH'));
    expect(prompt, contains('== BAUSTEINE'));
    expect(prompt, contains('1.1 Motivation'));
    expect(prompt, contains('abb-1'));
    expect(prompt, contains('"titel": "Testarbeit"'));
    expect(prompt, contains('Antworte NUR mit dem fertigen Markdown-Dokument.'));
  });

  test('wissenStats: Bundle-Stats gewinnen, sonst wird berechnet', () async {
    await boot();
    // Fixture liefert stats mit → Bundle-Werte.
    expect(container.read(wissenStatsProvider)!.fussnoten, 397);
  });

  test('wissenLens: Default + Persistenz', () async {
    await boot();
    expect(await container.read(wissenLensProvider.future), 'erklaerung');
    container.read(wissenLensProvider.notifier).set('analyse');
    expect(container.read(wissenLensProvider).value, 'analyse');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await container.read(kvStoreProvider).getJson(wissenLensKey),
        'analyse');
  });
}
