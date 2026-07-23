/// Fundstellen-Register — Port von `provisionRegister`
/// (views_quellen.js:659-683): Art/§/ErwGr/Anhang-Angaben aus den
/// Fußnotentexten einer Rechtsquelle ableiten. AT-Rechtsquellen zählen
/// §-Angaben, EU-Quellen Art/ErwGr/Anhang — gemischte Fußnoten
/// („Art 9 VO … und § 22 GTelG“) bleiben so sauber getrennt.
library;

import '../../../data/models/models.dart';

/// Eine Register-Gruppe: Schlüssel („Art 9“ / „§ 22“ / …) + Zitierstellen.
class ProvisionGroup {
  final String key;
  final double sortNum;
  final List<({int footnote, String sectionId})> cites;

  ProvisionGroup({required this.key, required this.sortNum}) : cites = [];
}

List<ProvisionGroup> provisionRegister(Source? s) {
  if (s == null) return const [];
  final groups = <String, ProvisionGroup>{};

  void add(String key, double sortNum, ({int footnote, String sectionId}) cite) {
    groups
        .putIfAbsent(key, () => ProvisionGroup(key: key, sortNum: sortNum))
        .cites
        .add(cite);
  }

  // `stellen` bevorzugt (angereichert), sonst rohe `citations`.
  final entries = s.stellen.isNotEmpty
      ? [
          for (final c in s.stellen)
            (footnote: c.footnote, sectionId: c.sectionId, text: c.footnoteText),
        ]
      : [
          for (final c in s.citations)
            (footnote: c.footnote, sectionId: c.sectionId, text: c.footnoteText),
        ];

  double numOf(String v) =>
      double.tryParse(RegExp(r'^\d+').firstMatch(v)?.group(0) ?? '') ?? 0;

  for (final c in entries) {
    final t = c.text;
    final cite = (footnote: c.footnote, sectionId: c.sectionId);
    if (s.kind == 'recht-at') {
      for (final m
          in RegExp(r'§§?\s*(\d+[a-z]?)', caseSensitive: false).allMatches(t)) {
        add('§ ${m.group(1)}', numOf(m.group(1)!), cite);
      }
    } else {
      for (final m in RegExp(r'\bArt(?:ikel)?\.?\s*(\d+[a-z]?)',
              caseSensitive: false)
          .allMatches(t)) {
        add('Art ${m.group(1)}', numOf(m.group(1)!), cite);
      }
      for (final m
          in RegExp(r'\bErwGr\s*(\d+)', caseSensitive: false).allMatches(t)) {
        add('ErwGr ${m.group(1)}', 1000 + numOf(m.group(1)!), cite);
      }
      for (final m
          in RegExp(r'\bAnhang\s*([IVX]+)', caseSensitive: false).allMatches(t)) {
        add('Anhang ${m.group(1)}', 2000 + m.group(1)!.length.toDouble(), cite);
      }
    }
  }

  // Doppelte Fußnote je Gruppe nur einmal.
  final out = groups.values.toList();
  for (final g in out) {
    final seen = <int>{};
    g.cites.retainWhere((c) => seen.add(c.footnote));
  }
  out.sort((a, b) {
    final d = a.sortNum.compareTo(b.sortNum);
    return d != 0 ? d : a.key.compareTo(b.key);
  });
  return out;
}
