/// Widget-Smoke-Test der `#/doc`-Ansicht (S-3): Kopf mit Meta-Zeile,
/// Aktionsleiste (⭳/🖨/◱), Views-Leiste und der fortlaufende Lesen-Satz
/// aller Abschnitte; die Selbst-Verdrahtung füllt die S-3-Slots.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/core/theme/theme.dart';
import 'package:thesor/data/bundles/indexes.dart';
import 'package:thesor/data/db/database.dart';
import 'package:thesor/features/doc/screen.dart';
import 'package:thesor/features/studio/layout/studio_slots.dart';
import 'package:thesor/features/studio/layout/studio_state.dart';

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

  testWidgets('rendert Kopf, Aktionen, Views-Leiste und den Lesen-Satz',
      (tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: const DocScreen(),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Kopf: Arbeitstitel als h1.
    expect(find.text('Testarbeit'), findsOneWidget);

    // Aktionsleiste wortwörtlich.
    expect(find.text('⭳ Ganzes LaTeX (.tex)'), findsOneWidget);
    expect(find.text('🖨 Als PDF drucken'), findsOneWidget);
    expect(find.text('◱ LaTeX ansehen'), findsOneWidget);

    // Views-Leiste (InstanzBar) mit „∅ Ohne“.
    expect(find.text('VIEWS'), findsOneWidget);
    expect(find.text('∅ Ohne'), findsOneWidget);

    // Lesen-Satz: Abschnittskopf des Test-Abschnitts.
    expect(find.textContaining('Motivation'), findsWidgets);

    // Die Selbst-Verdrahtung hat die S-3-Slots gefüllt.
    expect(StudioSlots.editorPane, isNotNull);
    expect(StudioSlots.instanzBar, isNotNull);
    expect(StudioSlots.paraSide, isNotNull);
    expect(StudioSlots.openRefMode, isNotNull);
    expect(StudioSlots.paraEditStart, isNotNull);
  });
}
