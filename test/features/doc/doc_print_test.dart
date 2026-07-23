/// Tests der `#/doc`-Druckaufbereitung (K-4): Fußnoten-Marker-Zerlegung,
/// Fußnoten-Reihenfolge (gesamt + je Kapitel, Endnoten-Grundlage) und der
/// eigentliche PDF-Bau (printing/pdf-Paket: Titelseite, Kapitel-Seitenläufe,
/// eingebettete Manifest-Bilder/-Tabellen, PT-Serif+Inter direkt von der
/// Platte — ohne Asset-Bundle).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:thesor/data/models/models.dart';
import 'package:thesor/features/doc/doc_print.dart';

Thesis _testThesis() => Thesis.fromJson({
      'meta': {
        'title': 'Testarbeit',
        'subtitle': 'Untertitel',
        'author': 'A. Autorin',
        'university': 'TU Test',
        'date': '1. Juli 2026',
      },
      'chapters': [
        {
          'id': '1',
          'num': 1,
          'title': 'Einleitung',
          'sections': [
            {
              'id': '1.0',
              'title': 'Überblick',
              'level': 2,
              'isIntro': true,
              'paragraphs': [
                {
                  'id': '1.0-p1',
                  'type': 'text',
                  'text': 'Absatz mit Beleg.[^2] Und noch einer.[^1]',
                  'footnotes': [
                    {'num': 2, 'text': 'Fußnote zwei.'},
                    {'num': 1, 'text': 'Fußnote eins.'},
                  ],
                },
                {
                  'id': '1.0-p2',
                  'type': 'list',
                  'items': ['Punkt A', 'Punkt B[^3]'],
                },
                {'id': '1.0-p3', 'type': 'figure', 'text': 'Architektur'},
                {'id': '1.0-p4', 'type': 'table', 'text': 'Vergleich'},
              ],
            },
          ],
        },
        {
          'id': '2',
          'num': 2,
          'title': 'Hauptteil',
          'sections': [
            {
              'id': '2.1',
              'title': 'Analyse',
              'level': 2,
              'paragraphs': [
                {
                  'id': '2.1-p1',
                  'type': 'text',
                  'text': 'Kapitel zwei zitiert.[^4]',
                  'footnotes': [
                    {'num': 4, 'text': 'Fußnote vier.'},
                  ],
                },
              ],
            },
          ],
        },
      ],
    });

/// Manifest passend zu den figure-/table-Absätzen der Test-Arbeit.
FiguresManifest _testFigures() => FiguresManifest.fromJson({
      'figuren': [
        {
          'id': 'abb-1',
          'nummer': 'Abb. 1.1',
          'paragraphId': '1.0-p3',
          'titel': 'Architektur',
          'credit': 'Eigene Darstellung',
        },
      ],
      'tabellen': [
        {
          'id': 'tab-1',
          'nummer': 'Tab. 1.1',
          'paragraphId': '1.0-p4',
          'titel': 'Vergleich',
          'kopf': ['Kriterium', 'A', 'B'],
          'zeilen': [
            ['Kosten', 'niedrig', 'hoch'],
            ['Aufwand', 'mittel'], // ragged — wird aufgefüllt
          ],
        },
      ],
    });

/// 1×1-PNG (Base64) — kleinste einbettbare Abbildung.
final _tinyPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

DocPrintFonts _fonts() {
  pw.Font f(String name) => pw.Font.ttf(
      File('assets/fonts/$name').readAsBytesSync().buffer.asByteData());
  return DocPrintFonts(
    serif: f('PT_Serif-Web-Regular.ttf'),
    serifBold: f('PT_Serif-Web-Bold.ttf'),
    serifItalic: f('PT_Serif-Web-Italic.ttf'),
    sans: f('inter-400.ttf'),
    sansBold: f('inter-600.ttf'),
  );
}

void main() {
  group('splitFnMarkers', () {
    test('zerlegt Text + [^N]-Marker in Reihenfolge', () {
      final parts = splitFnMarkers('A[^1]B[^23] C');
      expect(parts, [
        (text: 'A', fn: null),
        (text: '1', fn: 1),
        (text: 'B', fn: null),
        (text: '23', fn: 23),
        (text: ' C', fn: null),
      ]);
    });

    test('ohne Marker: ein Stück', () {
      expect(splitFnMarkers('Nur Text.'), [(text: 'Nur Text.', fn: null)]);
    });
  });

  group('collectFnOrder / chapterFnOrder', () {
    test('Dokumentreihenfolge der Marker, dedupliziert, inkl. Listen-Items',
        () {
      // Marker-Reihenfolge im Text: 2 vor 1; Fußnote 3 steckt im
      // Listen-Item; 4 kommt erst in Kapitel 2.
      expect(collectFnOrder(_testThesis()), [2, 1, 3, 4]);
    });

    test('chapterFnOrder trennt die Endnoten je Kapitel', () {
      final t = _testThesis();
      expect(chapterFnOrder(t.chapters[0]), [2, 1, 3]);
      expect(chapterFnOrder(t.chapters[1]), [4]);
    });
  });

  group('buildThesisPdfBytes', () {
    test(
        'liefert ein echtes PDF (%PDF-Magic) mit Titelseite, Kapiteln, '
        'Bild + Tabelle und meldet Fortschritts-Schritte', () async {
      final schritte = <String>[];
      final bytes = await buildThesisPdfBytes(
        thesis: _testThesis(),
        fnTexts: const {
          1: 'Fußnote eins.',
          2: 'Fußnote zwei.',
          3: 'Fußnote drei.',
          4: 'Fußnote vier.',
        },
        figures: _testFigures(),
        images: {'abb-1': _tinyPng},
        fonts: _fonts(),
        onProgress: schritte.add,
      );
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');

      // Fortschritt: Schriften → Titelseite → beide Kapitel → Schreiben.
      expect(schritte.first, 'Schriften einbetten …');
      expect(schritte, contains('Titelseite setzen …'));
      expect(schritte, contains('Kapitel 1/2 setzen …'));
      expect(schritte, contains('Kapitel 2/2 setzen …'));
      expect(schritte.last, 'PDF schreiben …');
    });

    test('ohne Manifest/Bilder: Platzhalter statt Absturz', () async {
      final bytes = await buildThesisPdfBytes(
        thesis: _testThesis(),
        fnTexts: const {1: 'Fußnote eins.'},
        fonts: _fonts(),
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('unlesbare Bild-Bytes fallen auf den Platzhalter zurück', () async {
      final bytes = await buildThesisPdfBytes(
        thesis: _testThesis(),
        fnTexts: const {},
        figures: _testFigures(),
        // Kein gültiges PNG/JPEG — figureBlock muss das abfangen.
        images: {
          'abb-1': base64Decode('R0lGODlhAQABAAAAACw='),
        },
        fonts: _fonts(),
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });
}
