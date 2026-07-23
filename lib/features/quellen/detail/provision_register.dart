/// Fundstellen-Register — Art/§/ErwGr/Anhang aus den Fußnotentexten einer
/// Rechtsquelle ableiten (Port von `provisionRegister`, views_quellen.js:659-683).
///
/// AT-Rechtsquellen zählen §-Angaben; EU-Rechtsquellen Art/ErwGr/Anhang.
/// So bleiben gemischte Fußnoten („Art 9 VO … und § 22 GTelG") sauber
/// getrennt. Reine Funktion — Golden-testbar gegen die JS-Regexes.
library;

import '../../../data/models/models.dart';

/// Eine Zitierstelle innerhalb einer Register-Gruppe.
class ProvisionCite {
  final int footnote;
  final String sectionId;

  const ProvisionCite({required this.footnote, required this.sectionId});
}

/// Eine Register-Gruppe („§ 22", „Art 5", „ErwGr 12", „Anhang II").
class ProvisionGroup {
  final String key;
  final double sortNum;
  final List<ProvisionCite> cites;

  const ProvisionGroup({required this.key, required this.sortNum, required this.cites});
}

/// `parseFloat`-Pendant: führende Ziffern (JS liest „12a" als 12).
double _leadingNum(String s) {
  final m = RegExp(r'^\d+').firstMatch(s);
  return m == null ? 0 : double.parse(m.group(0)!);
}

/// Register einer Quelle. Grundlage sind `stellen` (bzw. `citations` als
/// Fallback) — exakt `s.stellen || s.citations` des Originals.
List<ProvisionGroup> provisionRegister(Source s) {
  final groups = <String, ({double sortNum, List<ProvisionCite> cites})>{};
  void add(String key, double sortNum, ProvisionCite cite) {
    (groups[key] ??= (sortNum: sortNum, cites: [])).cites.add(cite);
  }

  // Gemeinsame Projektion aus Stelle/Citation (footnoteText + Fundort).
  final rows = s.stellen.isNotEmpty
      ? [
          for (final c in s.stellen)
            (footnote: c.footnote, sectionId: c.sectionId, text: c.footnoteText),
        ]
      : [
          for (final c in s.citations)
            (footnote: c.footnote, sectionId: c.sectionId, text: c.footnoteText),
        ];

  for (final c in rows) {
    final t = c.text;
    final cite = ProvisionCite(footnote: c.footnote, sectionId: c.sectionId);
    if (s.kind == 'recht-at') {
      for (final m in RegExp(r'§§?\s*(\d+[a-z]?)', caseSensitive: false).allMatches(t)) {
        add('§ ${m.group(1)}', _leadingNum(m.group(1)!), cite);
      }
    } else {
      for (final m
          in RegExp(r'\bArt(?:ikel)?\.?\s*(\d+[a-z]?)', caseSensitive: false).allMatches(t)) {
        add('Art ${m.group(1)}', _leadingNum(m.group(1)!), cite);
      }
      for (final m in RegExp(r'\bErwGr\s*(\d+)', caseSensitive: false).allMatches(t)) {
        add('ErwGr ${m.group(1)}', 1000 + double.parse(m.group(1)!), cite);
      }
      for (final m in RegExp(r'\bAnhang\s*([IVX]+)', caseSensitive: false).allMatches(t)) {
        add('Anhang ${m.group(1)}', 2000 + m.group(1)!.length.toDouble(), cite);
      }
    }
  }

  // Doppelte Fußnote je Gruppe nur einmal (Reihenfolge bleibt).
  final out = <ProvisionGroup>[];
  for (final e in groups.entries) {
    final seen = <int>{};
    out.add(ProvisionGroup(
      key: e.key,
      sortNum: e.value.sortNum,
      cites: [
        for (final c in e.value.cites)
          if (seen.add(c.footnote)) c,
      ],
    ));
  }
  out.sort((a, b) {
    final d = a.sortNum.compareTo(b.sortNum);
    return d != 0 ? d : a.key.compareTo(b.key);
  });
  return out;
}
