/// Gate-1-Verdrahtung: [wireAppSlots] füllt alle statischen Slots der
/// Welle-1-Pakete, [installAppWiring] spiegelt die MarksForFn-Funktion der
/// PDF-Engine reaktiv in [StudioSlots.marksForFn] und invalidiert den
/// Studio-Domänen-Graphen (Levels-Kaskade sieht neue Markierungen sofort).
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/app_wiring.dart';
import 'package:thesor/core/theme/theme.dart';
import 'package:thesor/data/bundles/indexes.dart';
import 'package:thesor/data/db/database.dart';
import 'package:thesor/data/db/kv.dart';
import 'package:thesor/data/models/models.dart';
import 'package:thesor/data/repos/project_repository.dart';
import 'package:thesor/features/pdf/pdf.dart';
import 'package:thesor/features/quellen/quellen.dart';
import 'package:thesor/features/studio/layout/studio_slots.dart';
import 'package:thesor/features/studio/layout/studio_state.dart';
import 'package:thesor/features/studio/refmode/ref_mode.dart';

import 'features/studio/studio_state_test.dart' show testRuntime;

/// Boot-Fake: Mini-Runtime ohne Assets/Seeding (Muster aus
/// test/features/pdf/pdf_marks_store_test.dart).
class _FakeBoot extends ProjectBoot {
  @override
  Future<BootResult> build() async => BootResult(
        runtime: testRuntime(),
        overrides: TextOverrideState.empty,
        activeId: ProjectRecord.defaultId,
        activeName: 'Test',
        warnings: const [],
      );
}

/// Host-Provider, der die reaktive Verdrahtung wie `appBoot` installiert.
final _wiringHost = Provider<void>(installAppWiring);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      projectBootProvider.overrideWith(_FakeBoot.new),
    ]);
    container.read(activeRuntimeProvider.notifier).activate(testRuntime());
    await container.read(studioPrefsCtlProvider.future);
    await container.read(studioKvProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('wireAppSlots füllt alle Slots und Hooks der Welle 1', () {
    wireAppSlots();

    // S-1 → S-2 (Quellen-Spalte + Figuren):
    expect(StudioSlots.fileCard, isNotNull);
    expect(StudioSlots.fileView, isNotNull);
    expect(StudioSlots.figureCard, isNotNull);
    expect(StudioSlots.tableCard, isNotNull);
    // S-3 (Editor/Views/RefMode/Absatz-Edit):
    expect(StudioSlots.editorPane, isNotNull);
    expect(StudioSlots.instanzBar, isNotNull);
    expect(StudioSlots.paraSide, isNotNull);
    expect(StudioSlots.openRefMode, isNotNull);
    expect(StudioSlots.paraEditStart, isNotNull);
    // S-4 (Quell-Karten-Hooks) + ⌖ Referenzieren der Bibliothek:
    expect(AssignPanelHooks.linkEditModal, isNotNull);
    expect(AssignPanelHooks.openQuellenseite, isNotNull);
    expect(QuellenRefModeHook.open, isNotNull);
  });

  test(
      'installAppWiring: Marks-Brücke setzt StudioSlots.marksForFn und '
      'invalidiert studioDomain — Markierung hebt die Levels-Kaskade', () async {
    // Aktiv abonnieren — wie `appBoot`, das vom Wurzel-Widget gewatcht wird
    // (ein bloßes read ließe die interne listen-Brücke pausiert).
    container.listen(_wiringHost, (_, _) {});

    // Marks-Store laden lassen — der Listener spiegelt die Funktion.
    await container.read(pdfMarksProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(StudioSlots.marksForFn, isNotNull);

    // Ausgangslage: Fußnote 1 ist unbelegt (Stufe 0/1, ohne Markierung).
    final before = container.read(studioDomainProvider)!;
    expect(before.levels.info(1).zitat ?? '', isEmpty);

    // Markierung mit Zitat + Seite anlegen (PDF-Engine-Weg).
    container.read(pdfMarksProvider.notifier).addMark(
          'kim2023',
          PdfMark.neu(
            fn: 1,
            page: 4,
            rects: const [MarkRect(x: .1, y: .2, w: .5, h: .02)],
            farbe: 'blau',
            zitat: 'Wörtliches Zitat aus dem PDF.',
          ),
        );
    await Future<void>.delayed(Duration.zero);

    // Der Domänen-Graph wurde invalidiert; die Kaskade sieht die Markierung:
    // Seite + positionType 'seite' ⇒ Stufe 3 (levels.js:121).
    final after = container.read(studioDomainProvider)!;
    expect(identical(before, after), isFalse);
    final info = after.levels.info(1);
    expect(info.level, 3);
    expect(info.zitat, 'Wörtliches Zitat aus dem PDF.');
    // Auch der Slot liefert die Markierung (🖍-Chips, Checkliste, Dropdown).
    expect(StudioSlots.marksForFn!('kim2023', 1), hasLength(1));
  });

  testWidgets(
      'fileView-Slot: ohne Datei „Lade Datei …“ → leer; mit srcDoc-Link '
      'die Internetquellen-Karte (renderDocView-Pfad)', (tester) async {
    wireAppSlots();

    Widget host(Widget child) => UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(Brightness.light),
            home: Scaffold(body: child),
          ),
        );

    // Ohne Datei/Definition: Probe → leere Fläche (Original: viewHost leer).
    await tester.pumpWidget(host(Builder(
      builder: (context) => StudioSlots.fileView!(
        context,
        'kim2023',
        fn: 1,
        startPage: null,
        gen: 1,
      ),
    )));
    expect(find.text('Lade Datei …'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Lade Datei …'), findsNothing);
    expect(find.byType(SrcDocView), findsNothing);

    // Internetquelle definieren → neue Generation zeigt die 🌐-Karte.
    await container
        .read(kvStoreProvider)
        .setSrcDoc('kim2023', const SrcDocDef(kind: 'link', url: 'https://x.y'));
    await tester.pumpWidget(host(Builder(
      builder: (context) => StudioSlots.fileView!(
        context,
        'kim2023',
        fn: 1,
        startPage: null,
        gen: 2,
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.byType(SrcDocView), findsOneWidget);
    expect(find.text('Internetquelle'), findsOneWidget);
  });

  testWidgets(
      '⌖ Referenzieren (Quellen-Detail) öffnet den RefMode an der ersten '
      'Zitierstelle', (tester) async {
    wireAppSlots();

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => QuellenRefModeHook.open!(context, 'kim2023'),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    final screen = tester.widget<RefModeScreen>(find.byType(RefModeScreen));
    expect(screen.sectionId, '1.1');
    expect(screen.paraId, '1.1-p1');
    expect(screen.focusSrcId, 'kim2023');
    expect(screen.focusFn, 1);
  });
}
