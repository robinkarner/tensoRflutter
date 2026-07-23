/// Belegsystem (dynamisch) — Port von `js/levels.js`.
///
/// Jede Fußnote ist ein Beleg-Vorgang. Der Status wird NICHT manuell über
/// Stufen geschaltet, sondern automatisch aus dem abgeleitet, was tatsächlich
/// erfasst ist:
///   ✦ vermutet   — nur KI-Rohdaten (Claim, vermutete Fundstelle, Suchbegriffe)
///   ❝ Original   — die Originalpassage (Zitat) liegt vor
///   ✓ belegt     — Position gesichert: Seite im PDF bzw. Fundstelle (Art/§)
///                  bei Rechtstexten/Websites
/// Zusätzlich verwaltet das Modul je Beleg eine Markierungsfarbe (für den
/// PDF-Referenzierungsmodus, automatisch rotierende 8er-Palette, manuell
/// übersteuerbar) und den Gesamt-Export/Import des Prüfstands als
/// `ehds-belegstand` v2 — das zentrale Backup-/Austauschformat der App.
///
/// Die HTML-Renderer des Originals (badge/dot/bar) sind hier bewusst NICHT
/// enthalten — sie werden in Welle 1 als Widgets gebaut; [LevelCounts]
/// liefert die Balken-Daten dafür.
library;

import 'dart:convert';

import '../data/models/json_utils.dart';
import '../data/models/models.dart';
import 'domain_context.dart';
import 'domain_store.dart';
import 'js_compat.dart';

/// Definition einer Beleg-Stufe (Icon/Label/Beschreibung wörtlich).
class LevelDef {
  final String key;
  final String label;
  final String desc;
  final String icon;

  const LevelDef({required this.key, required this.label, required this.desc, required this.icon});
}

/// Eine Markierungsfarbe der 8er-Palette.
class BelegFarbe {
  final String key;
  final String hex;

  const BelegFarbe({required this.key, required this.hex});
}

/// Effektiver Status einer Fußnote — das `info()`-Ergebnis. Trägt intern die
/// exakte JSON-Form des Originals (inkl. der Unterscheidung „Feld fehlt“ vs.
/// „Feld ist null“), damit Export und Golden-Vergleich bitgleich bleiben;
/// die Getter sind die typisierte Sicht für die UI.
class LevelInfo {
  final Map<String, Object?> json;

  const LevelInfo(this.json);

  int get level => asInt(json['level']);
  String? get zitat => asStringOrNull(json['zitat']);

  /// Seite kann Zahl ODER String sein (Handeingabe „S. 14“) — Typ-Mix des
  /// Originals bewusst erhalten.
  Object? get seite => json['seite'];
  String? get fundstelle => asStringOrNull(json['fundstelle']);
  String? get kommentar => asStringOrNull(json['kommentar']);
  String? get herkunft => asStringOrNull(json['herkunft']);
  String? get farbe => asStringOrNull(json['farbe']);

  /// true, wenn der Status abgeleitet ist (nicht direkt gespeichert).
  bool get derived => json['derived'] == true;
}

/// Zählung über eine Fußnoten-Menge (Grundlage des Fortschrittsbalkens).
class LevelCounts {
  final int l0;
  final int l1;
  final int l2;
  final int l3;
  final int total;

  const LevelCounts({this.l0 = 0, this.l1 = 0, this.l2 = 0, this.l3 = 0, this.total = 0});

  Map<String, Object?> toJson() => {'l0': l0, 'l1': l1, 'l2': l2, 'l3': l3, 'total': total};
}

/// Eine PDF-Markierung, so weit die Levels-Kaskade sie braucht
/// (`PdfEngine.marksForFn`-Ergebnis: zitat/page/farbe).
class PdfMarkLevelInput {
  final String? zitat;

  /// Gedruckte Seite (Zahl) — null/0 = keine Position.
  final Object? page;
  final String? farbe;

  const PdfMarkLevelInput({this.zitat, this.page, this.farbe});
}

/// Zugriff auf die PDF-Markierungen einer Fußnote — im Original der
/// `typeof PdfEngine !== 'undefined'`-Zweig. Solange die PDF-Engine (S-1)
/// nicht verdrahtet ist, bleibt der Parameter null und die Kaskade
/// überspringt die Markierungs-Stufe (identisch zum Original ohne Engine).
typedef MarksForFn = List<PdfMarkLevelInput> Function(String srcId, int fnNum);

class Levels {
  final DomainContext ctx;
  final DomainStore store;
  final MarksForFn? marksForFn;

  /// Uhr injizierbar (Tests/Golden-Fixtures) — Default: echte Zeit.
  final int Function() nowMs;

  Levels(this.ctx, this.store, {this.marksForFn, int Function()? nowMs})
      : nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// Stufen-Definition — Texte wörtlich (levels.js:16-20).
  static const Map<int, LevelDef> levelDefs = {
    1: LevelDef(key: 'l1', label: 'vermutet', desc: 'Nur KI-Analyse — Fundstelle vermutet, nichts nachgewiesen', icon: '✦'),
    2: LevelDef(key: 'l2', label: 'Original', desc: 'Originalpassage (Zitat) liegt vor — Position noch offen', icon: '❝'),
    3: LevelDef(key: 'l3', label: 'belegt', desc: 'Position gesichert: Seite im PDF bzw. Fundstelle bestätigt', icon: '✓'),
  };

  /// Markierungsfarben — möglichst unterscheidbare Palette, Hex exakt
  /// (levels.js:25-30). Die Farbe wird AUTOMATISCH vorgeschlagen (je
  /// Zitierstelle einer Quelle eine andere) und ist manuell übersteuerbar.
  static const List<BelegFarbe> farben = [
    BelegFarbe(key: 'gelb', hex: '#e8c33f'),
    BelegFarbe(key: 'blau', hex: '#5f8fc7'),
    BelegFarbe(key: 'gruen', hex: '#7cab54'),
    BelegFarbe(key: 'rosa', hex: '#d77aa4'),
    BelegFarbe(key: 'orange', hex: '#dd8a3e'),
    BelegFarbe(key: 'violett', hex: '#9779c9'),
    BelegFarbe(key: 'tuerkis', hex: '#4fb3a5'),
    BelegFarbe(key: 'rot', hex: '#cf6d5c'),
  ];

  static String? farbHex(String? key) {
    for (final f in farben) {
      if (f.key == key) return f.hex;
    }
    return null;
  }

  /// Automatischer Farbvorschlag: Position der Fußnote unter den
  /// Zitierstellen ihrer Quelle → rotierende Palette (deterministisch,
  /// innerhalb einer Quelle maximal unterschiedlich).
  String autoFarbe(String srcId, int fnNum) {
    final nums = numsForSource(srcId);
    var idx = nums.indexOf(fnNum);
    if (idx < 0) idx = 0;
    return farben[idx % farben.length].key;
  }

  /// Effektive Farbe: manuell gesetzt > automatisch vorgeschlagen.
  String farbeFor(String srcId, int fnNum) {
    final e = entry(fnNum);
    final manual = e == null ? null : asStringOrNull(e['farbe']);
    return jsTruthy(manual) ? manual! : autoFarbe(srcId, fnNum);
  }

  Map<String, Object?> _all() => store.readMap('belegLevels');
  void _saveAll(Map<String, Object?> m) => store.write('belegLevels', m);

  /// Gespeicherter Zustand einer Fußnote (oder null).
  Map<String, Object?>? entry(int num) {
    final v = _all()['$num'];
    return v is Map ? v.map((k, val) => MapEntry(k.toString(), val)) : null;
  }

  /// Dynamisches Speichern: der Status ergibt sich aus den Feldern.
  /// data: {zitat, seite, fundstelle, kommentar, herkunft, farbe}
  /// Seite/Fundstelle → belegt (3) · Zitat → Original (2) · sonst nur
  /// Farbe/Meta. Liefert das abgeleitete Level (0/2/3).
  int save(int num, Map<String, Object?> data) {
    final m = _all();
    final cur = <String, Object?>{...(entryFrom(m, num) ?? {}), ...data};
    // Leere Felder aufräumen
    for (final k in ['zitat', 'seite', 'fundstelle', 'kommentar', 'farbe']) {
      if (cur[k] == null || cur[k] == '') cur.remove(k);
    }
    final level = jsTruthy(jsOr(cur['seite'], cur['fundstelle']))
        ? 3
        : (jsTruthy(cur['zitat']) ? 2 : 0);
    if (level == 0 && !jsTruthy(cur['farbe']) && !jsTruthy(cur['kommentar'])) {
      m.remove('$num');
      _saveAll(m);
      return 0;
    }
    m['$num'] = {...cur, 'level': level, 'ts': nowMs()};
    _saveAll(m);
    return level;
  }

  /// Kompatibilität (Import alter Stände / direkte Zuweisung) — merge ohne
  /// Level-Logik, `ts` wird gesetzt.
  void set(int num, Map<String, Object?> data) {
    final m = _all();
    m['$num'] = {...(entryFrom(m, num) ?? {}), ...data, 'ts': nowMs()};
    _saveAll(m);
  }

  void clear(int num) {
    final m = _all();
    m.remove('$num');
    _saveAll(m);
  }

  /// Positionsart der (primären) Quelle: PDF-Seite oder Fundstelle
  /// (Rechtstext/Website/Norm) — levels.js:83-87.
  String positionType(String sourceId) {
    final s = ctx.srcById[sourceId];
    if (s == null) return 'seite';
    return s.zitiertNachFundstelle ? 'fundstelle' : 'seite';
  }

  String positionLabel(String sourceId) =>
      positionType(sourceId) == 'fundstelle' ? 'Fundstelle (Art/§/Abschnitt)' : 'Seite im PDF';

  /// Effektiver Status einer Fußnote: gespeicherter Zustand > abgeleitet aus
  /// Import-Resolutions/Alt-Annotationen > PDF-Markierung > vermutet (1),
  /// wenn KI-Beleg existiert, sonst 0 (levels.js:94-130).
  LevelInfo info(int num) {
    final stored = entry(num);
    if (stored != null && jsTruthy(stored['level'])) {
      return LevelInfo({'level': stored['level'], ...stored});
    }

    // Abgeleitet: manuelle Fundstellen (V1) und importierte Resolutions
    final srcs = ctx.fnIndex[num]?.sources ?? const [];
    final resolutions = store.readMap('resolutions');
    final annotations = store.readMap('annotations');
    for (final srcId in srcs) {
      final res = asMapOrNull(resolutions[srcId]);
      final stellen = <Map<String, Object?>>[
        for (final s in asList(res?['stellen']))
          if (s is Map)
            {
              ...s.map((k, v) => MapEntry(k.toString(), v)),
              'herkunft': jsOr(res?['generatedBy'], 'import'),
            },
        for (final s in asList(annotations[srcId]))
          if (s is Map) {...s.map((k, v) => MapEntry(k.toString(), v)), 'herkunft': 'manuell'},
      ].where((s) => asIntOrNull(s['footnote']) == num).toList();
      for (final st in stellen) {
        if (st['status'] == 'bestaetigt' && jsTruthy(jsOr(st['seite'], st['fundstelle']))) {
          return LevelInfo({
            'level': 3,
            'zitat': jsOr(st['zitat'], ''),
            'seite': jsOr(st['seite'], null),
            'fundstelle': jsOr(st['fundstelle'], ''),
            'kommentar': jsOr(st['kommentar'], ''),
            'herkunft': st['herkunft'],
            'farbe': ?stored?['farbe'],
            'derived': true,
          });
        }
        if (jsTruthy(st['zitat'])) {
          return LevelInfo({
            'level': 2,
            'zitat': st['zitat'],
            'seite': jsOr(st['seite'], null),
            'kommentar': jsOr(st['kommentar'], ''),
            'herkunft': st['herkunft'],
            'farbe': ?stored?['farbe'],
            'derived': true,
          });
        }
      }
    }

    // Eine gesetzte PDF-Markierung ist ein vollwertiger Nachweis — die von
    // Hand getippte Originalpassage ist optional (Zitat + Seite stecken in
    // der Markierung selbst).
    final marks = marksForFn;
    if (marks != null) {
      for (final srcId in srcs) {
        PdfMarkLevelInput? m;
        for (final x in marks(srcId, num)) {
          if (jsTruthy(x.zitat)) {
            m = x;
            break;
          }
        }
        if (m != null) {
          final level = (jsTruthy(m.page) && positionType(srcId) == 'seite') ? 3 : 2;
          final farbe = jsOr(stored?['farbe'], m.farbe);
          return LevelInfo({
            'level': level,
            'zitat': m.zitat,
            'seite': jsOr(m.page, null),
            'herkunft': 'markierung',
            'farbe': ?farbe,
            'derived': true,
          });
        }
      }
    }

    // KI-Beleg vorhanden → vermutet, sonst 0 (kein Material)
    final beleg = ctx.findBeleg(num);
    return LevelInfo({
      'level': beleg != null ? 1 : 0,
      'farbe': ?stored?['farbe'],
      'derived': true,
    });
  }

  LevelCounts countsFor(Iterable<int> nums) {
    var l0 = 0, l1 = 0, l2 = 0, l3 = 0, total = 0;
    for (final n in nums) {
      switch (info(n).level) {
        case 3:
          l3++;
        case 2:
          l2++;
        case 1:
          l1++;
        default:
          l0++;
      }
      total++;
    }
    return LevelCounts(l0: l0, l1: l1, l2: l2, l3: l3, total: total);
  }

  /// Alle Fußnoten-Nummern (aufsteigend — JS `Object.keys` liefert
  /// Integer-Keys in numerischer Ordnung).
  List<int> allNums() => ctx.fnIndex.keys.toList()..sort();

  List<int> numsForSource(String srcId) =>
      [for (final c in ctx.srcById[srcId]?.citations ?? const <Citation>[]) c.footnote];

  List<int> numsForSection(String sectionId) {
    final info = ctx.unitIndex[sectionId];
    return [
      for (final p in info?.unit.paragraphs ?? const <Paragraph>[])
        for (final f in p.footnotes) f.num,
    ];
  }

  List<int> numsForChapter(int chNum) {
    final out = <int>[];
    for (final ch in ctx.thesis?.chapters ?? const <Chapter>[]) {
      if (ch.num != chNum) continue;
      void rec(List<Unit> units) {
        for (final u in units) {
          for (final p in u.paragraphs) {
            for (final f in p.footnotes) {
              out.add(f.num);
            }
          }
          rec(u.children);
        }
      }

      rec(ch.sections);
    }
    return out;
  }

  // ---- Export/Import des gesamten Prüfstands (Status + manuelle Stellen) --

  /// `ehds-belegstand` v2 — bündelt 21 Store-Bereiche. Feldnamen exakt wie
  /// im Original; einzige Umbenennung: Export-Feld `notes` speist sich aus
  /// Store-Key `srcNotes` (W7 — Kompatibilitätsfalle!). Ausgabe mit Indent 1
  /// wie `JSON.stringify(…, null, 1)`.
  String exportState() {
    Object? get(String key) => store.read(key);
    final data = <String, Object?>{
      'format': 'ehds-belegstand',
      'version': 2,
      'exportiert': DateTime.fromMillisecondsSinceEpoch(nowMs(), isUtc: true).toIso8601String(),
      'belegLevels': _all(),
      'annotations': store.readMap('annotations'),
      'resolutions': store.readMap('resolutions'),
      'pdfManual': store.readMap('pdfManual'),
      'linkOverrides': store.readMap('linkOverrides'),
      'notes': store.readMap('srcNotes'),
      'srcTexts': store.readMap('srcTexts'),
      'pdfMarks': store.readMap('pdfMarks'),
      'kiConnections': get('kiConnections'),
      'customSources': store.readList('customSources'),
      'textMentions': store.readMap('textMentions'),
      'fileSearch': store.readMap('fileSearch'),
      'dlStatus': store.readMap('dlStatus'),
      'paraDock': store.readMap('paraDock'),
      'paraEdits': store.readMap('paraEdits'),
      'dockBySection': store.readMap('dockBySection'),
      'marksExtra': store.readMap('marksExtra'),
      'notebook': get('notebook'),
      'texEdits': store.readMap('texEdits'),
      'fnEdits': store.readMap('fnEdits'),
      'belegSpans': store.readMap('belegSpans'),
      'titleEdits': store.readMap('titleEdits'),
    };
    return const JsonEncoder.withIndent(' ').convert(data);
  }

  /// Import eines Belegstands. Prüft nur das `format`-Feld (nicht die
  /// Version!) und überschreibt jeden vorhandenen Abschnitt einzeln mit
  /// JS-Truthy-Semantik: `{}` ist truthy und überschreibt, `null`/fehlend
  /// lässt den Bestand stehen. Liefert die Anzahl belegLevels-Einträge.
  int importState(String json) {
    final d = asMap(jsonDecode(json));
    if (d['format'] != 'ehds-belegstand') {
      throw const FormatException('Unbekanntes Format — erwartet "ehds-belegstand".');
    }
    void put(String field, String key) {
      if (jsTruthy(d[field])) store.write(key, d[field]);
    }

    put('belegLevels', 'belegLevels');
    put('annotations', 'annotations');
    put('resolutions', 'resolutions');
    put('pdfManual', 'pdfManual');
    put('linkOverrides', 'linkOverrides');
    put('notes', 'srcNotes');
    put('srcTexts', 'srcTexts');
    put('pdfMarks', 'pdfMarks');
    put('kiConnections', 'kiConnections');
    put('customSources', 'customSources');
    put('textMentions', 'textMentions');
    put('fileSearch', 'fileSearch');
    put('dlStatus', 'dlStatus');
    put('paraDock', 'paraDock');
    put('paraEdits', 'paraEdits');
    put('dockBySection', 'dockBySection');
    put('marksExtra', 'marksExtra');
    put('notebook', 'notebook');
    put('texEdits', 'texEdits');
    put('fnEdits', 'fnEdits');
    put('belegSpans', 'belegSpans');
    put('titleEdits', 'titleEdits');
    return asMap(d['belegLevels']).length;
  }

  /// Roh-Eintrag aus einer bereits gelesenen Map (vermeidet Doppel-Reads).
  static Map<String, Object?>? entryFrom(Map<String, Object?> all, int num) {
    final v = all['$num'];
    return v is Map ? v.map((k, val) => MapEntry(k.toString(), val)) : null;
  }
}
