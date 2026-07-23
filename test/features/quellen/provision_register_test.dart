/// Tests des Fundstellen-Registers (S-4): Regex-Ableitung §/Art/ErwGr/Anhang
/// aus Fußnotentexten, Dedupe je Fußnote, sortNum-Sortierung — gegen die
/// Original-Regexes aus views_quellen.js:659-683.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/data/models/models.dart';
import 'package:thesor/features/quellen/detail/provision_register.dart';

Source _law(String kind, List<Map<String, Object?>> stellen) => Source.fromJson({
      'id': 'law1',
      'title': 'Testgesetz',
      'kind': kind,
      'stellen': stellen,
    });

Map<String, Object?> _st(int fn, String sec, String text) =>
    {'footnote': fn, 'sectionId': sec, 'footnoteText': text};

void main() {
  test('AT: §§?-Angaben inkl. Buchstaben-Suffix, dedupe je Fußnote', () {
    final s = _law('recht-at', [
      _st(1, '2.1', 'Vgl. § 22 GTelG; siehe auch §§ 4a und § 22.'),
      _st(2, '2.2', '§ 4a Abs 2.'),
    ]);
    final provs = provisionRegister(s);
    expect(provs.map((p) => p.key), ['§ 4a', '§ 22']);
    // Fußnote 1 nennt § 22 doppelt → nur ein Eintrag.
    expect(provs.last.cites.map((c) => c.footnote), [1]);
    expect(provs.first.cites.map((c) => c.footnote), [1, 2]);
  });

  test('EU: Art/Artikel/Art. + ErwGr (1000+n) + Anhang (2000+len)', () {
    final s = _law('recht-eu', [
      _st(3, '3.1', 'Art 5 DSGVO, Artikel 12 und Art. 9; ErwGr 12; Anhang II.'),
      _st(4, '3.2', 'Anhang IV und Art 5.'),
    ]);
    final provs = provisionRegister(s);
    expect(provs.map((p) => p.key),
        ['Art 5', 'Art 9', 'Art 12', 'ErwGr 12', 'Anhang II', 'Anhang IV']);
    expect(provs.first.cites.map((c) => c.footnote), [3, 4]);
    // AT-§ in EU-Quelle wird ignoriert (saubere Trennung).
    final mixed = provisionRegister(_law('recht-eu', [
      _st(5, '3.3', 'Art 9 VO … und § 22 GTelG'),
    ]));
    expect(mixed.map((p) => p.key), ['Art 9']);
  });

  test('parseFloat-Verhalten: „12a" sortiert als 12', () {
    final s = _law('recht-at', [
      _st(1, '1.1', '§ 12a und § 3'),
    ]);
    expect(provisionRegister(s).map((p) => p.key), ['§ 3', '§ 12a']);
  });

  test('keine Treffer → leeres Register', () {
    final s = _law('recht-at', [_st(1, '1.1', 'Ohne Angabe.')]);
    expect(provisionRegister(s), isEmpty);
  });
}
