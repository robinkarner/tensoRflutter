/// Widget-Tests der Projekt-Welt (K-2): Statkacheln, Kapitel-Fortschritt,
/// Quellen-Setup (inkl. „✓ alle übernehmen“-Randfall) und die
/// Referenzierungsdurchläufe — auf der kleinen Test-Arbeit der
/// Quellen-Tests (2 Fußnoten, 2 Quellen).
///
/// Async-Disziplin: ALLE asynchronen Provider (FileStore, FigStore,
/// PDF-Zählung, KV-Schnappschuss) werden im setUp (echte Async-Zone)
/// vorab aufgelöst; die Testkörper pumpen nur noch begrenzt (`pump()`),
/// denn unter der FakeAsync-Zone von testWidgets kommen Drift-/Asset-
/// Futures nicht zuverlässig zum Abschluss (pumpAndSettle würde hängen).
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/core/theme/theme.dart';
import 'package:thesor/data/bundles/indexes.dart';
import 'package:thesor/data/db/database.dart';
import 'package:thesor/data/db/kv.dart';
import 'package:thesor/data/repos/fig_store.dart';
import 'package:thesor/data/repos/file_store.dart';
import 'package:thesor/features/projekt/dashboard/chapter_progress_card.dart';
import 'package:thesor/features/projekt/dashboard/projekt_state.dart';
import 'package:thesor/features/projekt/dashboard/stat_grid.dart';
import 'package:thesor/features/projekt/setup/quellen_setup_card.dart';
import 'package:thesor/features/projekt/setup/referenz_runs_card.dart';
import 'package:thesor/features/quellen/state/quellen_kv.dart';

import '../quellen/quellen_kv_test.dart' show quellenTestRuntime;

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
    container.read(activeRuntimeProvider.notifier).activate(quellenTestRuntime());
    await container.read(quellenKvProvider.future);
    await container.read(fileStoreProvider.future);
    await container.read(figStoreProvider.future);
    // PDF-Zählung vorab auflösen (keepAlive) — die Widgets finden dann
    // fertige Daten vor und starten unter FakeAsync keine neue Async-Kette.
    await container.read(projektDetectedPdfsProvider.future);
  });

  tearDown(() async {
    // Offene Drift-Writes/Stream-Events aus den Testkörpern ablaufen lassen,
    // bevor Container und DB schließen (tearDown läuft in echter Async-Zone).
    await Future<void>.delayed(const Duration(milliseconds: 30));
    container.dispose();
    await db.close();
  });

  /// Breiter Test-Viewport (Standard 800×600 ist schmäler als das
  /// Dashboard-Layout) — Reset über addTearDown.
  void wideView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget host(Widget child) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: Scaffold(
            body: SingleChildScrollView(child: child),
          ),
        ),
      );

  /// Begrenztes Pumpen statt pumpAndSettle (siehe Bibliotheks-Doku oben).
  Future<void> pumpFrames(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
  }

  testWidgets('Statkacheln: alle 6 Labels + Zähler', (tester) async {
    wideView(tester);
    final domain = container.read(quellenDomainProvider)!;
    await tester.pumpWidget(host(ProjektStatGrid(domain: domain)));
    await pumpFrames(tester);

    expect(find.text('Abschnitte GPT-analysiert ✦'), findsOneWidget);
    expect(find.text('PDFs vorhanden (Artikel/Reports)'), findsOneWidget);
    expect(find.text('Links geprüft/übernommen'), findsOneWidget);
    expect(find.text('Belege gesichert ✓'), findsOneWidget);
    expect(find.text('Quellen-Durchläufe importiert 🤖'), findsOneWidget);
    expect(find.text('Abbildungen hinterlegt'), findsOneWidget);
    // 1 analysierter Abschnitt von 1 (Fixture: 1_1 vorhanden).
    expect(find.textContaining('/1', findRichText: true), findsWidgets);
  });

  testWidgets('Kapitel-Fortschritt: Legende, Zeile, ⌖-Sprung', (tester) async {
    wideView(tester);
    final domain = container.read(quellenDomainProvider)!;
    await tester.pumpWidget(host(ChapterProgressCard(domain: domain)));
    await pumpFrames(tester);

    expect(find.text('BELEG-FORTSCHRITT JE KAPITEL'), findsOneWidget);
    expect(find.textContaining('vermutet → ', findRichText: true), findsOneWidget);
    expect(find.text('Einleitung'), findsOneWidget);
    expect(find.text('⌖'), findsOneWidget);
    // 0 von 2 Fußnoten belegt.
    expect(find.text('0/2 ✓'), findsOneWidget);
  });

  testWidgets('Quellen-Setup: Zeilen, Zähler, „✓ alle übernehmen“-Randfall',
      (tester) async {
    wideView(tester);
    final domain = container.read(quellenDomainProvider)!;
    await tester.pumpWidget(host(QuellenSetupCard(domain: domain)));
    await pumpFrames(tester);

    expect(find.text('QUELLEN-SETUP — DATEIEN BESORGEN'), findsOneWidget);
    expect(find.text('⭳ Alle laden'), findsOneWidget);
    expect(find.text('⭱ Import (PDF/ZIP)'), findsOneWidget);
    expect(find.text('2 von 2 Links offen'), findsOneWidget);
    // Zeileninhalt: Titel fett + id-Code + Zitierstellen-Zähler.
    expect(find.textContaining('Health Data Paper', findRichText: true),
        findsOneWidget);
    expect(find.textContaining('· 1 Zitierstellen', findRichText: true),
        findsNWidgets(2));
    // Beide Quellen offen: Status „·“.
    expect(find.text('·'), findsNWidgets(2));

    // ✓ alle übernehmen: kim2023/dsgvo haben KEINE Links → Platzhalter
    // official='https://' zählt als geprüft (views_projekt.js:98). Die
    // Prüfung läuft über den synchronen KV-Schnappschuss (Write-Through).
    await tester.tap(find.text('✓ alle übernehmen'));
    await pumpFrames(tester);

    expect(find.text('alle 2 Links geprüft ✓'), findsOneWidget);
    final overrides = container
        .read(quellenKvProvider.notifier)
        .readMap(KvKeys.linkOverrides);
    expect((overrides['kim2023'] as Map)['official'], 'https://');
    expect((overrides['dsgvo'] as Map)['official'], 'https://');
  });

  testWidgets('Referenzierungsdurchläufe: Sortierung + Status', (tester) async {
    wideView(tester);
    // dsgvo bekommt eine importierte Resolution → ✓ + „1 importiert“.
    container.read(quellenKvProvider.notifier).put(KvKeys.resolutions, {
      'dsgvo': {
        'stellen': [
          {'footnote': 2, 'fundstelle': 'Art 5'},
        ],
      },
    });
    final domain = container.read(quellenDomainProvider)!;
    await tester.pumpWidget(host(ReferenzRunsCard(domain: domain)));
    await pumpFrames(tester);

    expect(find.text('REFERENZIERUNGSDURCHLÄUFE — JE QUELLE'), findsOneWidget);
    expect(find.text('Durchlauf'), findsNWidgets(2));
    expect(find.text('✓'), findsOneWidget);
    expect(find.textContaining('· 1 importiert', findRichText: true),
        findsOneWidget);
    expect(find.textContaining('DSGVO', findRichText: true), findsWidgets);
  });
}
