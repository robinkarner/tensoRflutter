/// Widget-Tests der Analyse-Bausteine (S-2): Absatzkarte (öffnen →
/// Beleg-Zeilen), Beleg-Checkliste (n/3-Zähler, reaktive Stufen).
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/core/theme/theme.dart';
import 'package:thesor/data/bundles/indexes.dart';
import 'package:thesor/data/db/database.dart';
import 'package:thesor/features/studio/layout/studio_state.dart';
import 'package:thesor/features/studio/pruefen/beleg_checklist.dart';
import 'package:thesor/features/studio/pruefen/paragraph_card.dart';

import 'studio_state_test.dart' show testRuntime;

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

  Widget host(Widget child) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      );

  testWidgets('ParagraphCard: Hint-Zeile, Öffnen zeigt Beleg-Zeile + Claim',
      (tester) async {
    final domain = container.read(studioDomainProvider)!;
    final p = domain.ctx.unitIndex['1.1']!.unit.paragraphs.first;

    await tester.pumpWidget(host(ParagraphCard(sectionId: '1.1', paragraph: p)));
    await tester.pumpAndSettle();

    // Fußhinweis mit Zählung + Absatz-ID (1 Beleg, Stufe 1 = vermutet).
    expect(
      find.text('▸ 1 Beleg — 0 belegt · 0 Original · 1 vermutet · 1.1-p1'),
      findsOneWidget,
    );
    // Karte zu: keine Beleg-Zeilen sichtbar.
    expect(find.text('BELEGE IN DIESEM ABSATZ'), findsNothing);

    // Klick auf den Absatz-Body öffnet die Auflösung. (Der Body trägt auch
    // einen Doppelklick-Handler — die Tap-Arena entscheidet erst nach dem
    // Double-Tap-Timeout, deshalb der zusätzliche pump.)
    await tester.tap(
        find.text('▸ 1 Beleg — 0 belegt · 0 Original · 1 vermutet · 1.1-p1'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('BELEGE IN DIESEM ABSATZ'), findsOneWidget);
    expect(find.text('[1]'), findsOneWidget);
    expect(find.text('Was belegt wird.'), findsOneWidget);
    expect(find.text('⌖ Große Ansicht'), findsOneWidget);
    // Suchbegriff-Chips aus dem suchHinweis („health data | secondary use“).
    expect(find.text('🔎 health data'), findsOneWidget);
    expect(find.text('🔎 secondary use'), findsOneWidget);
  });

  testWidgets('ParagraphCard: Kategorie-Chip togglet global (prefs.cats)',
      (tester) async {
    final domain = container.read(studioDomainProvider)!;
    final p = domain.ctx.unitIndex['1.1']!.unit.paragraphs.first;

    await tester.pumpWidget(host(ParagraphCard(sectionId: '1.1', paragraph: p)));
    await tester.pumpAndSettle();

    // Der Absatz hat eine schlag-Markierung → Chip „Schlagwort“ sichtbar.
    expect(find.text('Schlagwort'), findsOneWidget);
    await tester.tap(find.text('Schlagwort'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    final prefs = container.read(studioPrefsCtlProvider).value!;
    expect(prefs.activeCats, isNot(contains('schlag')));
  });

  testWidgets('BelegChecklist: 0/3 → Zitat speichern → 1/3 + ❝-Stufe',
      (tester) async {
    await tester
        .pumpWidget(host(const BelegChecklist(srcId: 'kim2023', fnNum: 1)));
    await tester.pumpAndSettle();

    expect(find.text('⌖ BELEG-NACHWEIS'), findsOneWidget);
    expect(find.text('0/3'), findsOneWidget);
    expect(find.text('keine — im PDF markieren'), findsOneWidget);

    // Zitat direkt ins „fehlt“-Feld tippen und committen (Enter).
    await tester.enterText(
        find.widgetWithText(TextField, '').at(1), 'Die Originalpassage.');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('1/3'), findsOneWidget);
    final domain = container.read(studioDomainProvider)!;
    expect(domain.levels.info(1).level, 2);
  });
}
