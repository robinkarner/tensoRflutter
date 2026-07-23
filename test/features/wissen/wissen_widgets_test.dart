/// Widget-Tests der Wissen-Welt (K-1): Seitenrahmen mit Tab-Clustern,
/// Überblick, Kennzahlen, Würdigung, Erklärbuch (Starter + E4-Zellen),
/// Mathe-⚠-Chip und Timeline (L1-Optik).
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/core/theme/theme.dart';
import 'package:thesor/data/bundles/indexes.dart';
import 'package:thesor/data/db/database.dart';
import 'package:thesor/features/studio/layout/studio_state.dart';
import 'package:thesor/features/wissen/charts/timeline.dart';
import 'package:thesor/features/wissen/math/math_render.dart';
import 'package:thesor/features/wissen/notebook/erklaerbuch_tab.dart';
import 'package:thesor/features/wissen/tabs/kennzahlen_tab.dart';
import 'package:thesor/features/wissen/tabs/wissen_page.dart';
import 'package:thesor/features/wissen/tabs/wuerdigung_tab.dart';

import 'wissen_fixtures.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
    container.read(activeRuntimeProvider.notifier).activate(wissenTestRuntime());
    await container.read(studioPrefsCtlProvider.future);
    await container.read(studioKvProvider.future);
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

  testWidgets('WissenPage: Kopf, Cluster-Labels und Tabs (Default Überblick)',
      (tester) async {
    await tester.pumpWidget(host(const WissenPage()));
    await tester.pumpAndSettle();

    expect(find.text('Wissen'), findsOneWidget);
    expect(find.text('✦ Cross-Projekt-Informationsspeicher'), findsOneWidget);
    // Drei Cluster (uppercase gerendert).
    expect(find.text('SCHNELLVERSTÄNDNIS'), findsOneWidget);
    expect(find.text('ZUSAMMENHÄNGE & THEMA'), findsOneWidget);
    expect(find.text('BEWERTUNG'), findsOneWidget);
    // Alle 8 Tabs.
    for (final label in [
      '📓 Erklärbuch', '🔬 Analysemodus', '🌐 Übersetzung & Instanzen',
      'Überblick', 'Kapitel', 'Connections', 'Kennzahlen', '⚖ Würdigung',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    // Default-Tab = Überblick: Executive Summary + Ergebnisse-Grid.
    expect(find.text('EXECUTIVE SUMMARY'), findsOneWidget);
    expect(find.text('Ergebnisse auf einen Blick'), findsOneWidget);
    expect(find.text('✔ erfüllt'), findsOneWidget);
    expect(find.text('▲ Lücke'), findsOneWidget);
    expect(find.text('◆ Spannung'), findsOneWidget);
    // Roter Faden + Timeline-Karte.
    expect(find.text('ROTER FADEN'), findsOneWidget);
    expect(find.text('FRISTEN-TIMELINE'), findsOneWidget);
    expect(find.text('Frage stellen'), findsOneWidget);
  });

  testWidgets('Timeline (L1): schlichte Textzeilen mit Legende',
      (tester) async {
    final runtime = container.read(activeRuntimeProvider)!;
    await tester.pumpWidget(host(TimelineList(
      runtime.meta.gesamt!.timeline,
      datumLabelOf: (it) => it.datum,
    )));
    await tester.pumpAndSettle();

    expect(
      find.text(
          '🇪🇺 EU-Frist 🇦🇹 nationaler Termin ● gefüllt = erledigt · ○ Ring = offen'),
      findsOneWidget,
    );
    expect(find.text('🇦🇹 Österreich · ✔ erledigt'), findsOneWidget);
    expect(find.text('🇪🇺 EU · ○ offen'), findsOneWidget);
    expect(find.text('ELGA-Rollout beginnt'), findsOneWidget);
  });

  testWidgets('Kennzahlen: 5 Kacheln + Chart-Karten', (tester) async {
    await tester.pumpWidget(host(const KennzahlenTab()));
    await tester.pumpAndSettle();

    expect(find.text('397'), findsOneWidget);
    expect(find.text('Fußnoten gesamt'), findsOneWidget);
    expect(find.text('verschiedene Quellen'), findsOneWidget);
    expect(find.text('Absätze'), findsOneWidget);
    expect(find.text('aufgelöste Sätze'), findsOneWidget);
    expect(find.text('Belege pro Absatz (Ø)'), findsOneWidget);
    // Ø = 397/233 = 1.7
    expect(find.text('1.7'), findsOneWidget);
    expect(find.text('BELEG-DICHTE JE KAPITEL'), findsOneWidget);
    expect(find.text('QUELLENMIX NACH TYP'), findsOneWidget);
    expect(find.text('MEISTZITIERTE QUELLEN (ZITIERSTELLEN)'), findsOneWidget);
    expect(find.text('Quellen-Bibliothek'), findsOneWidget);
  });

  testWidgets('Würdigung: Standards-Karte, ★-Noten, Akkordeons',
      (tester) async {
    await tester.pumpWidget(host(const WuerdigungTab()));
    await tester.pumpAndSettle();

    expect(find.text('BEWERTUNG NACH STANDARDS'), findsOneWidget);
    expect(find.text('★★★ stark'), findsOneWidget);
    expect(find.text('★☆☆ ausbaufähig'), findsOneWidget);
    expect(find.text('▲ VERBESSERUNGSWÜRDIG'), findsOneWidget);
    expect(find.text('▲ Schwäche'), findsOneWidget);
    // struktur offen (Body sichtbar), quellen/inhalt als Fallback-Titel.
    expect(find.text('Struktur & Aufbau'), findsOneWidget);
    expect(find.text('Der Aufbau trägt.'), findsOneWidget);
    expect(find.text('quellen'), findsOneWidget);
    expect(find.text('inhalt'), findsOneWidget);
    // zugeklapptes Akkordeon zeigt seinen Leertext nicht.
    expect(find.text('Diese Analyse wurde noch nicht generiert.'), findsNothing);
  });

  testWidgets('Erklärbuch: Starter-Buch + E4-Zellen (Code sichtbar, Hinweis)',
      (tester) async {
    await tester.pumpWidget(host(const ErklaerbuchTab()));
    await tester.pumpAndSettle();

    expect(find.text('✎ Bearbeiten'), findsOneWidget);
    expect(find.text('⭱ Import'), findsOneWidget);
    expect(find.text('⭳ Export'), findsOneWidget);
    expect(find.text('Starter-Buch'), findsOneWidget);
    expect(find.text('Referenz ↗'), findsOneWidget);
    // Starter-Inhalt gerendert (Markdown-Überschrift).
    expect(find.text('Erklärbuch — Testarbeit'), findsOneWidget);
    // E4: js-/py-Zellen rendern Code + dezenten Hinweis, ▶ deaktiviert.
    expect(find.text('▶ ausführen'), findsWidgets);
    expect(
        find.text('Ausführung in dieser Version nicht verfügbar'), findsWidgets);
    expect(find.text('⌃ Code'), findsWidgets);
    // LaTeX-Block läuft durch denselben Interpreter (Abschnitts-Überschrift).
    expect(find.text('Eingebettetes LaTeX'), findsOneWidget);
  });

  testWidgets('MathRender: unbekannter Befehl → ⚠-Chip mit Tooltip',
      (tester) async {
    await tester.pumpWidget(host(const MathBlockView(r'\frac{a}{b} \foo{x}')));
    await tester.pumpAndSettle();

    expect(find.text('⚠'), findsOneWidget);
    final tooltip = tester.widget<Tooltip>(
      find.ancestor(of: find.text('⚠'), matching: find.byType(Tooltip)).first,
    );
    expect(tooltip.message, r'\foo nicht unterstützt');
  });
}
