/// Tests der Link-Übernahme „✓ alle übernehmen“ (views_projekt.js:94-99,
/// 168-172) inklusive des `https://`-Platzhalter-Randfalls.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/data/models/models.dart';
import 'package:thesor/features/projekt/dashboard/projekt_state.dart';

void main() {
  Source src(Map<String, dynamic> json) => Source.fromJson(json);

  test('takeOverAllLinks: DOI-Kaskade, file-Link, Platzhalter, Bestand bleibt',
      () {
    final sources = [
      // DOI → official = https://doi.org/<doi> (Kaskade wie U.srcLinks).
      src({'id': 'a', 'title': 'A', 'doi': '10.1/xyz'}),
      // Registry-file-Link → beide Overrides.
      src({
        'id': 'b',
        'title': 'B',
        'url': 'https://example.org/b',
        'links': {'file': 'https://example.org/b.pdf'},
      }),
      // GAR keine Links → Platzhalter official='https://' (zählt als geprüft).
      src({'id': 'c', 'title': 'C'}),
      // Bereits übernommen → unangetastet.
      src({'id': 'd', 'title': 'D', 'url': 'https://example.org/d'}),
    ];
    final before = <String, Object?>{
      'd': {'official': 'https://manuell.example'},
    };

    final next = takeOverAllLinks(before, sources);

    expect((next['a'] as Map)['official'], 'https://doi.org/10.1/xyz');
    expect((next['b'] as Map)['official'], 'https://example.org/b');
    expect((next['b'] as Map)['file'], 'https://example.org/b.pdf');
    expect((next['c'] as Map)['official'], 'https://');
    expect((next['d'] as Map)['official'], 'https://manuell.example');
    // Eingabe-Map bleibt unverändert (reine Funktion).
    expect(before.keys, ['d']);

    // Danach gelten ALLE als geprüft (_override truthy).
    for (final s in sources) {
      expect(srcLinksFromSnapshot(next, s).isOverride, isTrue,
          reason: 'Quelle ${s.id} muss als geprüft zählen');
    }
  });
}
