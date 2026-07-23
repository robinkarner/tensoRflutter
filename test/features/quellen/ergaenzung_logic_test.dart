/// Tests der 🤖-Ergänzungs-Übernahme (S-4): meta-Whitelist, unantastbare
/// id, Array-Pflichten mit Original-Fehlertexten, stellen-Filterung und
/// Link-Overrides.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/features/quellen/import/ergaenzung_logic.dart';

void main() {
  test('Whitelist-Metafelder werden übernommen, Fremdes fällt weg', () {
    final res = parseErgaenzung('kraus2025', {
      'sourceId': 'kraus2025',
      'meta': {
        'title': 'Neuer Titel',
        'author': 'Kraus, M.',
        'year': 2024,
        'container': 'JMIR',
        'doi': '10.2196/12345',
        'url': 'https://example.org',
        'kind': 'artikel',
        'longTitle': 'Der ganz lange Titel',
        'id': 'HACK', // NIE übernehmbar
        'unbekannt': 'weg damit',
      },
      'dossier': '## Markdown',
      'keyPoints': ['a', 'b'],
      'zitierweise': 'Kraus, M. (2024): …',
    });
    expect(res.patch['id'], 'kraus2025'); // id bleibt die Ziel-Quelle
    expect(res.patch['title'], 'Neuer Titel');
    expect(res.patch['longTitle'], 'Der ganz lange Titel');
    expect(res.patch['dossier'], '## Markdown');
    expect(res.patch['keyPoints'], ['a', 'b']);
    expect(res.patch['zitierweise'], 'Kraus, M. (2024): …');
    expect(res.patch.containsKey('unbekannt'), isFalse);
  });

  test('leere/null-meta-Werte werden nicht übernommen', () {
    final res = parseErgaenzung('x', {
      'meta': {'title': '', 'author': null, 'year': 2020},
    });
    expect(res.patch.containsKey('title'), isFalse);
    expect(res.patch.containsKey('author'), isFalse);
    expect(res.patch['year'], 2020);
  });

  test('official/file aus meta als Link-Overrides', () {
    final res = parseErgaenzung('x', {
      'meta': {'official': 'https://doi.org/10.1/a', 'file': 'https://x.org/a.pdf'},
    });
    expect(res.official, 'https://doi.org/10.1/a');
    expect(res.file, 'https://x.org/a.pdf');
    // null-file (nichts frei verfügbar) bleibt null.
    expect(parseErgaenzung('x', {'meta': {'file': null}}).file, isNull);
  });

  test('stellen → vermuteteStellen, nur Objekt-Einträge', () {
    final res = parseErgaenzung('x', {
      'stellen': [
        {'claim': 'c1', 'fundstelle': 'S. 3'},
        'kaputt',
        42,
        {'claim': 'c2'},
      ],
    });
    expect(res.patch['vermuteteStellen'], [
      {'claim': 'c1', 'fundstelle': 'S. 3'},
      {'claim': 'c2'},
    ]);
  });

  test('Format-Fehler mit wörtlichen Meldungen', () {
    expect(() => parseErgaenzung('x', 'kein objekt'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', 'JSON-Objekt erwartet.')));
    expect(() => parseErgaenzung('x', {'keyPoints': 'kein array'}),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', '"keyPoints" muss ein Array sein.')));
    expect(() => parseErgaenzung('x', {'stellen': 'kein array'}),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', '"stellen" muss ein Array sein.')));
  });
}
