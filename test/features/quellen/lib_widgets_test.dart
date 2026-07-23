/// Widget-Tests der Bibliothek (S-4): Rail (Sammlungen + Werkzeuge, Zähler),
/// Liste (Filter, Suche, Sortierung, Leer-Text) und das Placeholder-Panel.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/core/theme/theme.dart';
import 'package:thesor/data/bundles/indexes.dart';
import 'package:thesor/data/db/database.dart';
import 'package:thesor/features/quellen/detail/detail_panel.dart';
import 'package:thesor/features/quellen/library/lib_list.dart';
import 'package:thesor/features/quellen/library/lib_rail.dart';
import 'package:thesor/features/quellen/state/quellen_filter.dart';
import 'package:thesor/features/quellen/state/quellen_kv.dart';

import 'quellen_kv_test.dart' show quellenTestRuntime;

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
    await container.read(quellenFilterCtlProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Widget host(Widget child) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      );

  testWidgets('LibRail: Sammlungen, Typen-Zähler, Werkzeuge', (tester) async {
    final domain = container.read(quellenDomainProvider)!;
    await tester.pumpWidget(host(SizedBox(
      width: 220,
      child: LibRail(domain: domain),
    )));
    await tester.pumpAndSettle();

    // Eyebrow rendert versal.
    expect(find.text('BIBLIOTHEK'), findsOneWidget);
    expect(find.text('TYPEN'), findsOneWidget);
    expect(find.text('STATUS'), findsOneWidget);
    expect(find.text('BELEGSTAND'), findsOneWidget);
    expect(find.text('DATEIEN (PDF)'), findsOneWidget);
    expect(find.text('📚 Alle Quellen'), findsOneWidget);
    expect(find.text('◌ Nicht fertig belegt'), findsOneWidget);
    expect(find.text('✓ Vollständig belegt'), findsOneWidget);
    expect(find.text('📄 PDF fehlt'), findsOneWidget);
    expect(find.text('✎ Mit Notizen'), findsOneWidget);
    // Keine Custom-Quellen → „＋ Manuell ergänzt" versteckt.
    expect(find.text('＋ Manuell ergänzt'), findsNothing);
    // Typen-Zähler: 1 Artikel, 1 Rechtsquelle EU.
    expect(find.text('📄 Peer-Review-Artikel'), findsOneWidget);
    expect(find.text('🇪🇺 Rechtsquelle EU'), findsOneWidget);
    // Werkzeuge wörtlich.
    expect(find.text('＋ Quelle'), findsOneWidget);
    expect(find.text('⭳ Sichern'), findsOneWidget);
    expect(find.text('⭱ Laden'), findsOneWidget);
    expect(find.text('⭱ Import (PDF/ZIP)'), findsOneWidget);
    expect(find.text('⌗ Datei-Auftrag'), findsOneWidget);
    expect(find.text('🗑 Dateispeicher leeren'), findsOneWidget);
    // Ablage leer → Knopf versteckt.
    expect(find.textContaining('📥 Ablage'), findsNothing);
  });

  testWidgets('LibRail: Sammlungs-Klick persistiert qColl', (tester) async {
    final domain = container.read(quellenDomainProvider)!;
    await tester.pumpWidget(host(SizedBox(
      width: 220,
      child: LibRail(domain: domain),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('◌ Nicht fertig belegt'));
    await tester.pumpAndSettle();

    expect(container.read(quellenFilterCtlProvider).value?.coll, 'offen');
  });

  testWidgets('LibList: Zeilen, Suche, Leer-Text', (tester) async {
    final domain = container.read(quellenDomainProvider)!;
    await tester.pumpWidget(host(SizedBox(
      width: 640,
      child: LibList(domain: domain, shrinkWrap: true),
    )));
    await tester.pumpAndSettle();

    // Beide Quellen sichtbar (Titel + Untertitel), 1×-Zähler.
    expect(find.text('Health Data Paper'), findsOneWidget);
    expect(find.text('DSGVO'), findsOneWidget);
    expect(find.text('Kim, J. · 2023'), findsOneWidget);
    expect(find.text('1×'), findsNWidgets(2));
    // Rechtsquelle: statisches §-Flag.
    expect(find.text('§'), findsOneWidget);

    // Live-Suche filtert (title+author+id+container).
    await tester.enterText(find.byType(TextField), 'kim');
    await tester.pumpAndSettle();
    expect(find.text('Health Data Paper'), findsOneWidget);
    expect(find.text('DSGVO'), findsNothing);

    await tester.enterText(find.byType(TextField), 'xyz-nix');
    await tester.pumpAndSettle();
    expect(find.text('Keine Quellen passen zum Filter.'), findsOneWidget);
  });

  testWidgets('LibDetailPlaceholder: Zähler-Zeilen + Hinweis', (tester) async {
    final domain = container.read(quellenDomainProvider)!;
    await tester.pumpWidget(host(LibDetailPlaceholder(domain: domain)));
    await tester.pumpAndSettle();

    expect(find.text('2 Quellen · 2 Zitierstellen.'), findsOneWidget);
    // Beide Fußnoten stehen auf Stufe 1 (KI-Vermutung).
    expect(find.text('0 belegt · 0 Original · 2 vermutet'), findsOneWidget);
    expect(find.textContaining('Links eine Quelle wählen.'), findsOneWidget);
  });
}
