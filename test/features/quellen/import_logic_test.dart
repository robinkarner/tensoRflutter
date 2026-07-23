/// Kernlogik-Tests des Sammel-Imports (S-4): Matching-Kaskade
/// (ts-Hash → exakte id → Vorschlag → Ablage), „kein stiller Verlust"
/// (Go-Zähler + Button-Texte) und die Status-Chips.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/data/models/models.dart';
import 'package:thesor/data/repos/file_store.dart';
import 'package:thesor/features/quellen/import/import_logic.dart';

Source _src(String id, {String? title, String? author, int? year}) =>
    Source.fromJson({
      'id': id,
      'title': title ?? id,
      'author': author,
      'year': year,
      'kind': 'artikel',
    });

void main() {
  final kraus = _src('kraus2025',
      title: 'Health Data Sharing in Europe', author: 'Kraus, M.', year: 2025);
  final kim = _src('kim2023',
      title: 'Wearable Sensor Networks', author: 'Kim, J.', year: 2023);
  final sources = [kraus, kim];
  final srcById = {for (final s in sources) s.id: s};
  final data = Uint8List.fromList(List.filled(2048, 7));

  group('buildImportItem — Matching-Kaskade', () {
    test('(a) ts-Hash im Dateinamen → „✓ automatisch erkannt", Häkchen an', () {
      final hash = srcHashOfSource(kraus);
      final it = buildImportItem('Rücklauf_$hash.pdf', data,
          srcById: srcById, sources: sources);
      expect(it.match?.id, 'kraus2025');
      expect(it.match?.hash, isTrue);
      expect(it.sel, 'kraus2025');
      expect(it.checked, isTrue);
      expect(importChipFor(it).label, '✓ automatisch erkannt');
      expect(importChipFor(it).cat, 'ok');
    });

    test('(a) Hash gewinnt auch bei GROSS geschriebenem Dateinamen', () {
      final hash = srcHashOfSource(kim).toUpperCase();
      final it = buildImportItem('$hash.PDF', data,
          srcById: srcById, sources: sources);
      expect(it.match?.id, 'kim2023');
      expect(it.match?.hash, isTrue);
    });

    test('(b) Dateiname exakt = Quellen-id → „= Quellen-id"', () {
      final it = buildImportItem('kim2023.pdf', data,
          srcById: srcById, sources: sources);
      expect(it.match?.id, 'kim2023');
      expect(it.match?.hash, isFalse);
      expect(it.match?.exact, isTrue);
      expect(it.checked, isTrue);
      expect(importChipFor(it).label, '= Quellen-id');
    });

    test('(b) ZIP-Pfadanteile werden vor dem Matching entfernt', () {
      final it = buildImportItem('ordner/unterordner/kim2023.pdf', data,
          srcById: srcById, sources: sources);
      expect(it.name, 'kim2023.pdf');
      expect(it.match?.id, 'kim2023');
    });

    test('(c) freier Dateiname → NUR unverbindlicher Vorschlag (Häkchen AUS)',
        () {
      final it = buildImportItem('kraus_health_data_sharing_2025.pdf', data,
          srcById: srcById, sources: sources);
      expect(it.match, isNull);
      expect(it.suggest?.id, 'kraus2025');
      expect(it.sel, 'kraus2025'); // Select vorbelegt …
      expect(it.checked, isFalse); // … aber erst das Häkchen ordnet zu
      expect(importChipFor(it).label, '✦ Vorschlag (bestätigen)');
      expect(importChipFor(it).cat, 'ki');
    });

    test('(d) unbekannter Name → „→ Ablage"', () {
      final it = buildImportItem('scan0815.pdf', data,
          srcById: srcById, sources: sources);
      expect(it.match, isNull);
      expect(it.suggest, isNull);
      expect(it.sel, isNull);
      expect(it.checked, isFalse);
      expect(importChipFor(it).label, '→ Ablage');
      expect(importChipFor(it).cat, 'warn');
    });

    test('kein PDF → Fehlerzeile (bleibt in der Liste stehen)', () {
      final it = buildImportItem('notizen.txt', data,
          srcById: srcById, sources: sources);
      expect(it.err, 'kein PDF');
      expect(it.checked, isFalse);
    });
  });

  group('goCounts / goButtonLabel — „kein stiller Verlust"', () {
    ImportItem item({String? sel, bool checked = false, bool fromInbox = false}) =>
        ImportItem(name: 'x.pdf', data: data, sel: sel, checked: checked, fromInbox: fromInbox);

    test('checked+sel zählt als Zuordnung, Rest (nicht aus Inbox) als Ablage', () {
      final c = goCounts([
        item(sel: 'kim2023', checked: true),
        item(), // neue Datei ohne Zuordnung → Ablage
        item(fromInbox: true), // Inbox-Datei ohne Zuordnung → bleibt einfach
        ImportItem.error('kaputt.pdf', 'ZIP-Fehler'),
      ]);
      expect(c.n, 1);
      expect(c.rest, 1);
    });

    test('Button-Texte exakt (js:787)', () {
      expect(goButtonLabel(3, 2), '✓ 3 zuordnen · 2 in Ablage');
      expect(goButtonLabel(3, 0), '✓ 3 zuordnen');
      expect(goButtonLabel(0, 4), '📥 4 in die Ablage');
      expect(goButtonLabel(0, 0), '✓ Zuordnen');
    });
  });
}
