/// Abgleich der Command-Palette-Einträge gegen `cmdkItems` (app.js:150-168)
/// — Teil des K-4-Finish (BAUPLAN Welle 2): 8 feste Ansichten mit
/// ⚒/📚/◈/⚙/▤/？-Präfixen (Studio-Einträge mit `studioLast`-Fallback),
/// dann alle Abschnitte („id Titel", bei isIntro der Kapiteltitel), dann
/// alle Quellen („srcShort — title"), Kategorien in der rechten Spalte.
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/core/shell/cmdk.dart';
import 'package:thesor/data/bundles/indexes.dart';
import 'package:thesor/data/db/database.dart';
import 'package:thesor/data/db/kv.dart';

import '../studio/studio_state_test.dart' show testRuntime;

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
    container.read(activeRuntimeProvider.notifier).activate(testRuntime());
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('Reihenfolge + Texte: 8 Ansichten, dann Abschnitte, dann Quellen',
      () async {
    final items = await buildCmdkItems(container);

    // Test-Arbeit: 1 Abschnitt (1.1) + 1 Quelle (kim2023).
    expect(items.length, 8 + 1 + 1);

    // Die 8 Ansichten wortwörtlich, in Original-Reihenfolge; die drei
    // Studio-Einträge zielen ohne studioLast auf den ersten Abschnitt.
    expect(items[0].t, '⚒ Studio — Lesen');
    expect(items[0].go, '/studio/1.1/lesen');
    expect(items[1].t, '⚒ Studio — Prüfen');
    expect(items[1].go, '/studio/1.1/pruefen');
    expect(items[2].t, '⚒ Studio — Editor');
    expect(items[2].go, '/studio/1.1/editor');
    expect(items[3].t, '📚 Quellen-Bibliothek');
    expect(items[3].go, '/quellen');
    expect(items[4].t, '◈ Wissen — Informationsspeicher');
    expect(items[4].go, '/analyse');
    expect(items[5].t, '⚙ Status & Setup');
    expect(items[5].go, '/projekt');
    expect(items[6].t, '▤ PDF Dokument (ganze Arbeit)');
    expect(items[6].go, '/doc');
    expect(items[7].t, '？ Hilfe & Anleitung');
    expect(items[7].go, '/hilfe');
    for (var i = 0; i < 8; i++) {
      expect(items[i].k, 'Ansicht');
    }

    // Abschnitt: „{id} {Titel}", Ziel ohne Modus-Segment.
    expect(items[8].t, '1.1 Motivation');
    expect(items[8].k, 'Abschnitt');
    expect(items[8].go, '/studio/1.1');

    // Quelle: „{srcShort} — {title}" (kim2023 → „Kim 2023").
    expect(items[9].t, 'Kim 2023 — Health Data Paper');
    expect(items[9].k, 'Quelle');
    expect(items[9].go, '/quellen/kim2023');
  });

  test('studioLast steuert die Ziel-Route der Studio-Einträge', () async {
    // Wie das Original ungeprüft übernommen (U.storeGet('studioLast','')
    // || orderedUnits()[0], app.js:152) — daher ein abweichender Wert.
    await container
        .read(kvStoreProvider)
        .setJson(KvKeys.studioLast, '9.9');
    final items = await buildCmdkItems(container);
    expect(items[0].go, '/studio/9.9/lesen');
    expect(items[1].go, '/studio/9.9/pruefen');
    expect(items[2].go, '/studio/9.9/editor');
  });
}
