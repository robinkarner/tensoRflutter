/// Quell-Karte (Widget): Datei-Zustände „▣ keine Datei" (Material-Switch,
/// Download-Zeile, Kandidat) und „✓ Datei zugeordnet"; Kopfzeile mit
/// Einklapp-Verhalten; Abbildungs-/Tabellen-Karten.
library;

import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/core/theme/theme.dart';
import 'package:thesor/data/bundles/indexes.dart';
import 'package:thesor/data/db/database.dart';
import 'package:thesor/data/models/models.dart';
import 'package:thesor/data/repos/file_store.dart';
import 'package:thesor/features/pdf/assign_panel/assign_panel.dart';
import 'package:thesor/features/pdf/figures/figure_card.dart';

Uint8List _pdf() => Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2d]);

ThesisRuntime _runtime() => ThesisRuntime(
      projectId: 'default',
      projectName: 'Test',
      thesis: Thesis.fromJson({
        'meta': {'title': 'T'},
        'chapters': [],
      }),
      sources: [
        Source.fromJson({
          'id': 'kraus2025',
          'kind': 'artikel',
          'title': 'Health Data Sharing in Europe',
          'author': 'Kraus, M. u.a.',
          'year': 2025,
          'container': 'JMIR 27(3)',
          'doi': '10.2196/12345',
        }),
      ],
    );

Widget _app(Widget child) => MaterialApp(
      theme: appThemeLight,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    // Runtime VOR dem ersten Build aktivieren (srcById braucht sie).
    container.read(activeRuntimeProvider.notifier).activate(_runtime());
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Widget scope(Widget child) => UncontrolledProviderScope(
        container: container,
        child: _app(child),
      );

  group('AssignPanel', () {
    testWidgets('„▣ keine Datei": Material-Switch + Download-Zeile',
        (tester) async {
      await tester.pumpWidget(scope(const AssignPanel(srcId: 'kraus2025')));
      await tester.pumpAndSettle();

      // Kopf: Identität + Status-Chip.
      expect(find.text('Health Data Sharing in Europe'), findsOneWidget);
      expect(find.text('▣ keine Datei'), findsOneWidget);
      // Aktionen.
      expect(find.text('📚 Dossier'), findsOneWidget);
      expect(find.text('↗ offizielle Seite'), findsOneWidget);
      // 5-Tab-Material-Switch.
      expect(find.text('📄 PDF'), findsOneWidget);
      expect(find.text('🌐 Website'), findsOneWidget);
      expect(find.text('🖼 Bild'), findsOneWidget);
      expect(find.text('📝 Text'), findsOneWidget);
      expect(find.text('Σ LaTeX'), findsOneWidget);
      expect(find.text('keine Datei'), findsOneWidget); // ms-state
      // PDF-Tab-Inhalt.
      expect(find.text('⭳ Download'), findsOneWidget);
      expect(find.text('⭱ Datei lokal wählen'), findsOneWidget);
      expect(find.text('📥 Aus Dateiverzeichnis'), findsOneWidget);
      // veröffentlicht-Tag aus dem Container.
      expect(find.text('veröffentlicht: JMIR 27(3)'), findsOneWidget);
    });

    testWidgets('Tab-Wechsel auf 🌐 Website zeigt URL-Zeile', (tester) async {
      await tester.pumpWidget(scope(const AssignPanel(srcId: 'kraus2025')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('🌐 Website'));
      await tester.pumpAndSettle();
      expect(find.text('Übernehmen'), findsOneWidget);
      expect(
        find.text(
            'Öffnet im neuen Tab; Zitat & Fundstelle erfasst du unten im Beleg von Hand.'),
        findsOneWidget,
      );
    });

    testWidgets('mit Datei: „✓ Datei zugeordnet" + Entfernen-Knopf',
        (tester) async {
      // Datei VOR dem ersten Build in den Store legen.
      final store = FileStore(db.fileBlobsDao);
      await store.init();
      await store.addFiles([('kraus2025.pdf', _pdf())]);
      store.dispose();

      await tester.pumpWidget(scope(const AssignPanel(srcId: 'kraus2025')));
      await tester.pumpAndSettle();

      expect(find.text('✓ Datei'), findsOneWidget); // Status-Chip
      expect(find.text('✓ Datei zugeordnet'), findsOneWidget);
      expect(find.text('Zuordnung entfernen'), findsOneWidget);
      // Material-Sektion sichtbar (5 Hinzufüge-Kacheln).
      expect(find.text('MATERIAL DIESER QUELLE — FLEXIBEL ERWEITERN'),
          findsOneWidget);
    });

    testWidgets('Kandidat aus der Ablage (Referenz-Hash) wird angeboten',
        (tester) async {
      final store = FileStore(db.fileBlobsDao);
      await store.init();
      final hash = srcHashOfSource(Source.fromJson({
        'id': 'kraus2025',
        'title': 'Health Data Sharing in Europe',
        'author': 'Kraus, M. u.a.',
        'year': 2025,
      }));
      await store.addInbox('studie-$hash.pdf', _pdf());
      store.dispose();

      await tester.pumpWidget(scope(const AssignPanel(srcId: 'kraus2025')));
      await tester.pumpAndSettle();

      expect(
        find.text('Vermutlich passende Datei — unbestätigt, nicht übernommen'),
        findsOneWidget,
      );
      expect(find.text('studie-$hash.pdf'), findsOneWidget);
      expect(find.text('automatisch erkannt'), findsOneWidget);
      expect(find.text('✓ Übernehmen'), findsOneWidget);
      expect(find.text('✗ passt nicht'), findsOneWidget);
      expect(find.text('VORSCHAU — UNBESTÄTIGT · NICHT ÜBERNOMMEN'),
          findsOneWidget);
    });

    testWidgets('Einklappen: nur Kopfzeile mit Titel · Autor · Jahr bleibt',
        (tester) async {
      await tester
          .pumpWidget(scope(const AssignPanel(srcId: 'kraus2025', collapsed: true)));
      await tester.pumpAndSettle();
      expect(find.text('Health Data Sharing in Europe'), findsOneWidget);
      expect(find.text('Kraus, M. u.a. · 2025'), findsOneWidget);
      // Body zugeklappt: keine Aktionen.
      expect(find.text('📚 Dossier'), findsNothing);
    });
  });

  group('Figures', () {
    testWidgets('FigureCard ohne Bild: Platzhalter mit Upload-Knopf',
        (tester) async {
      const fig = Figur(
        id: 'abb-9-9',
        nummer: 'Abb. 9.9',
        titel: 'Testbild',
        beschreibung: 'Beschreibung',
      );
      await tester.pumpWidget(scope(const FigureCard(fig)));
      await tester.pumpAndSettle();
      expect(find.text('🖼 ABB. 9.9 — ABBILDUNG NICHT HINTERLEGT'), findsOneWidget);
      expect(find.text('Testbild'), findsOneWidget);
      expect(find.text('Bild einfügen (PNG/JPG/WebP/SVG)'), findsOneWidget);
    });

    testWidgets('TableCard: Kopf + Zeilen + Unterschrift', (tester) async {
      const tab = Tabelle(
        id: 'tab-1',
        nummer: 'Tab. 1',
        titel: 'Vergleich',
        credit: 'Eigene Darstellung.',
        kopf: ['Spalte A', 'Spalte B'],
        zeilen: [
          ['Zeile1A', 'Zeile1B'],
        ],
      );
      await tester.pumpWidget(scope(const TableCard(tab)));
      await tester.pumpAndSettle();
      expect(find.text('Spalte A'), findsOneWidget);
      expect(find.text('Zeile1B'), findsOneWidget);
      // Unterschrift ist EIN Rich-Text: „Tab. 1 — Vergleich".
      expect(find.text('Tab. 1 — Vergleich', findRichText: true), findsOneWidget);
      expect(find.text('Eigene Darstellung.'), findsOneWidget);
    });
  });
}

