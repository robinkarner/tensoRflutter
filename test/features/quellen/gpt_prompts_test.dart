/// Tests der GPT-Prompt-Builder (S-4): filter(Boolean)-Semantik (keine
/// Leerzeilen, optionale Zeilen fallen weg), JSON-Vorlagen zeichengenau,
/// Positions-Typ-Weiche des Durchlaufs, E9-Fix (Arbeitstitel statt EHDS).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/data/models/models.dart';
import 'package:thesor/data/repos/project_repository.dart';
import 'package:thesor/features/quellen/import/gpt_prompts.dart';

void main() {
  final meta = ThesisMeta.fromJson(const {
    'title': 'Testarbeit',
    'subtitle': 'Ein Untertitel',
    'author': 'Robin K.',
  });

  group('gptErgaenzungsPrompt (js:330-365)', () {
    test('Kopf, Metadaten und JSON-Vorlage wörtlich', () {
      final s = Source.fromJson(const {
        'id': 'kraus2025',
        'title': 'Health Data Sharing',
        'author': 'Kraus, M.',
        'year': 2025,
        'doi': '10.2196/12345',
      });
      final p = gptErgaenzungsPrompt(s, meta);
      expect(p, startsWith('Du ergänzt die GPT-Voranalyse einer Quellensoftware'));
      expect(p, contains('DIE ARBEIT: „Testarbeit“ — Ein Untertitel (Robin K.).'));
      expect(p, contains('  id: kraus2025'));
      expect(p, contains('  Autor: Kraus, M.'));
      expect(p, contains('  DOI: 10.2196/12345'));
      expect(p, contains('AUFGABE — antworte NUR mit diesem JSON (importierbar auf der Quellenseite):'));
      expect(p, contains('  "sourceId": "kraus2025",'));
      // filter(Boolean): KEINE Leerzeilen im Ergebnis.
      expect(p.contains('\n\n'), isFalse);
    });

    test('optionale Zeilen fallen weg (kein Autor/Jahr/Container/URL)', () {
      final s = Source.fromJson(const {'id': 'x', 'title': 'Nur Titel'});
      final p = gptErgaenzungsPrompt(s, meta);
      expect(p.contains('Autor:'), isFalse);
      expect(p.contains('Jahr:'), isFalse);
      expect(p.contains('Container:'), isFalse);
      expect(p.contains('URL:'), isFalse);
    });
  });

  group('gptPromptForSource (js:686-710)', () {
    final s = Source.fromJson(const {
      'id': 'kraus2025',
      'title': 'Health Data Sharing',
      'author': 'Kraus, M.',
      'stellen': [
        {
          'footnote': 41,
          'sectionId': '3.2.1',
          'claim': 'Eine Aussage.',
          'fundstelle': 'S. 12',
          'suchHinweis': 'wörtliche Passage|zweite Passage',
        },
        {'footnote': 42, 'sectionId': '3.2.2', 'footnoteText': 'Kraus u.a., …'},
      ],
    });

    test('Zitierstellen-Zeilen + Links + JSON-Kopf', () {
      final p = gptPromptForSource(
        s,
        positionType: 'seite',
        links: const EffectiveSrcLinks(
            official: 'https://doi.org/10.2196/12345', file: null, isOverride: false),
        arbeitTitel: 'Testarbeit',
      );
      // E9-Fix: projektabhängiger Titel statt hartem EHDS-Text (W8).
      expect(p, contains('Du hilfst bei der Literaturprüfung der Arbeit „Testarbeit“.'));
      expect(p, contains('QUELLE: Kraus, M. — Health Data Sharing'));
      expect(p, contains('OFFIZIELLER LINK: https://doi.org/10.2196/12345'));
      expect(p.contains('DATEI-LINK:'), isFalse);
      expect(p, contains('ZITIERSTELLEN (2):'));
      expect(
          p,
          contains('- Fußnote 41 (Abschnitt 3.2.1): Aussage: „Eine Aussage.“'
              ' · vermutet: S. 12 · Suche: wörtliche Passage|zweite Passage'));
      expect(p, contains('- Fußnote 42 (Abschnitt 3.2.2): Fußnote: „Kraus u.a., …“'));
      expect(p, contains('"seite": <Seitenzahl>'));
      expect(p.contains('\n\n'), isFalse);
    });

    test('positionType fundstelle → Fundstellen-Slot im JSON', () {
      final p = gptPromptForSource(
        s,
        positionType: 'fundstelle',
        links: const EffectiveSrcLinks(official: null, file: null, isOverride: false),
        arbeitTitel: 'Testarbeit',
      );
      expect(p, contains('"fundstelle": "<Art/§/Abschnitt>"'));
      expect(p.contains('"seite": <Seitenzahl>'), isFalse);
    });
  });
}
