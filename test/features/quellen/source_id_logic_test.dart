/// Tests der id-Vorschläge und des Slug-Sanitizings (S-4):
/// newSourceModal-Live-Vorschlag, id-Säuberung, Quelle-aus-Datei-Guesses.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/features/quellen/import/source_id_logic.dart';

void main() {
  group('suggestNewSourceId (js:166-171)', () {
    test('erster Autor-Token + Jahr', () {
      expect(suggestNewSourceId(author: 'Kraus, M. u.a.', year: '2025'),
          'kraus2025');
      expect(suggestNewSourceId(author: 'Van der Berg X.', year: '2024'),
          'van2024');
    });

    test('ohne Autor: erstes Titelwort', () {
      expect(suggestNewSourceId(title: 'Health Data Sharing', year: '2023'),
          'health2023');
    });

    test('ohne alles: „quelle"', () {
      expect(suggestNewSourceId(), 'quelle');
    });

    test('nur [a-z0-9], lowercased, max 30', () {
      expect(suggestNewSourceId(author: 'Müller-Lüdenscheidt', year: '2025'),
          'mllerldenscheidt2025');
      final long = suggestNewSourceId(
          author: 'abcdefghijklmnopqrstuvwxyzabcdef', year: '2025');
      expect(long.length, 30);
    });
  });

  group('sanitizeSourceId (js:179)', () {
    test('lowercase, nur [a-z0-9-]', () {
      expect(sanitizeSourceId('  Kraus 2025!  '), 'kraus2025');
      expect(sanitizeSourceId('recht-EU_2024'), 'recht-eu2024');
    });
  });

  group('guessTitleFromFilename (js:294)', () {
    test('.pdf weg, [_-]+ → Space', () {
      expect(guessTitleFromFilename('Study_Health-Data_2024.pdf'),
          'Study Health Data 2024');
      expect(guessTitleFromFilename('paper.PDF'), 'paper');
    });
  });

  group('guessIdFromTitle (js:295)', () {
    test('NFD-Slug, Trenner kollabiert, Ränder sauber', () {
      expect(guessIdFromTitle('Étude sur les données 2024'),
          'etude-sur-les-donnees-2024');
      expect(guessIdFromTitle('  Health   Data!! '), 'health-data');
    });

    test('max 30 Zeichen, leer → „quelle"', () {
      expect(guessIdFromTitle('').isEmpty, isFalse);
      expect(guessIdFromTitle(''), 'quelle');
      expect(
          guessIdFromTitle('a b c d e f g h i j k l m n o p q r s t').length <= 30,
          isTrue);
    });
  });
}
