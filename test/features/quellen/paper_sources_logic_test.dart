/// „Paper → Quellen": Prompt-Bau, kind-Normalisierung und der robuste
/// JSON→Datensatz-Parser (id-Kollisionsfreiheit, doi/url-Verteilung).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/features/quellen/import/paper_sources_logic.dart';

void main() {
  group('paperSourcesPrompt', () {
    test('enthält Text, JSON-Vorgabe, kind-Vokabular und optionalen Titel', () {
      final p = paperSourcesPrompt('Ref 1. Ref 2.', arbeitTitel: 'Meine Arbeit');
      expect(p, contains('"sources"'));
      expect(p, contains('artikel'));
      expect(p, contains('Meine Arbeit'));
      expect(p, contains('Ref 1. Ref 2.'));
    });

    test('ohne Titel keine Kontextzeile', () {
      final p = paperSourcesPrompt('X');
      expect(p, isNot(contains('KONTEXT')));
    });
  });

  group('normalizeKind', () {
    test('bekannte Schlüssel bleiben, Synonyme werden gemappt, Rest online', () {
      expect(normalizeKind('artikel'), 'artikel');
      expect(normalizeKind('article'), 'artikel');
      expect(normalizeKind('preprint'), 'artikel');
      expect(normalizeKind('Conference'), 'konferenz');
      expect(normalizeKind('standard'), 'norm');
      expect(normalizeKind('regulation'), 'recht-eu');
      expect(normalizeKind('irgendwas'), 'online');
      expect(normalizeKind(null), 'online');
    });
  });

  group('parseRecognizedSources', () {
    test('Array oder {sources:[]}; Titel-Pflicht; year/doi/url verteilt', () {
      final r = parseRecognizedSources(
        '{"sources":[{"title":"A Paper","author":"Kraus, M.","year":"2025",'
        '"kind":"article","doi":"10.1/x","url":"https://x/y.pdf"}]}',
        existingIds: {},
      );
      expect(r.records, hasLength(1));
      final rec = r.records.single;
      expect(rec['title'], 'A Paper');
      expect(rec['kind'], 'artikel');
      expect(rec['year'], 2025);
      expect(rec['doi'], '10.1/x');
      expect(rec['url'], 'https://x/y.pdf');
      expect(rec['id'], isNotEmpty);
    });

    test('bloßes Array wird akzeptiert', () {
      final r = parseRecognizedSources('[{"title":"T"}]', existingIds: {});
      expect(r.records, hasLength(1));
    });

    test('ungültige doi/url landen nicht in den falschen Feldern', () {
      final r = parseRecognizedSources(
        '[{"title":"T","doi":"nicht-doi","url":"ftp://x"}]',
        existingIds: {},
      );
      expect(r.records.single['doi'], isNull);
      expect(r.records.single['url'], isNull);
    });

    test('titellose Einträge werden übersprungen', () {
      final r = parseRecognizedSources(
        '[{"author":"X"},{"title":"Gut"}]',
        existingIds: {},
      );
      expect(r.records, hasLength(1));
      expect(r.skipped, 1);
    });

    test('id-Kollisionen (bestehend + innerhalb) werden eindeutig gemacht', () {
      final r = parseRecognizedSources(
        '[{"id":"kraus2025","title":"A"},{"id":"kraus2025","title":"B"}]',
        existingIds: {'kraus2025'},
      );
      final ids = r.records.map((e) => e['id']).toList();
      expect(ids.toSet(), hasLength(2));
      expect(ids, isNot(contains('kraus2025'))); // Bestehendes bleibt unberührt
      expect(r.renamed, 2);
    });

    test('kaputtes JSON / fehlendes Feld wirft FormatException', () {
      expect(() => parseRecognizedSources('{', existingIds: {}),
          throwsA(isA<FormatException>()));
      expect(() => parseRecognizedSources('{"x":1}', existingIds: {}),
          throwsA(isA<FormatException>()));
    });
  });
}
