/// Connections-Framework — Port von `js/connections.js`.
///
/// Verweise auf Informationsbasis zwischen Abschnitten/Absätzen — aus VIER
/// Quellen zusammengeführt (der Original-Kommentar nennt nur drei, der Code
/// hat vier — W6, der Code gilt):
///   1. ki:         KI-erkannte Verbindungen (Bundle `DATA_META.connections`
///                  + Import in den Store `kiConnections`)
///   2. auto-fazit: Fazit-Befunde — Abschnitt → Fazit-Kapitel
///   3. auto-xref:  „siehe Abschnitt 3.2“ / „Kapitel 5“ im Text (Regex)
///   4. auto:       Abschnitts-Paare mit gemeinsamen SELTENEN Quellen
///                  (kapitelübergreifend, Top 40 nach Score)
/// Ergebnis ist eine deduplizierte, gecachte Kantenliste; dazu ein Importer
/// für KI-JSON und der Prompt-Generator zum (Nach-)Generieren.
library;

import 'dart:convert';

import '../data/models/json_utils.dart';
import '../data/models/models.dart';
import 'domain_context.dart';
import 'domain_store.dart';
import 'js_compat.dart';

/// Typ-Definition einer Verbindung (Unicode-Icons + Richtungs-Labels exakt).
class ConnectionTypeDef {
  final String icon;

  /// Label aus Sicht des Quell-Abschnitts („daraus gefolgert in“).
  final String out;

  /// Label aus Sicht des Ziel-Abschnitts („Folgerung aus“).
  final String inLabel;

  const ConnectionTypeDef({required this.icon, required this.out, required this.inLabel});
}

/// Endpunkt einer Kante (Abschnitt, optional Absatz).
class ConnectionEnd {
  final String? sectionId;
  final String? paraId;

  const ConnectionEnd({this.sectionId, this.paraId});
}

/// Eine Verbindungs-Kante. Trägt intern die exakte JSON-Form des Originals
/// (KI-Kanten behalten so auch unbekannte Zusatzfelder); die Getter sind
/// die typisierte Sicht.
class ConnectionEdge {
  final Map<String, Object?> json;

  const ConnectionEdge(this.json);

  String get id => asString(json['id']);
  String get typ => asString(json['typ']);

  /// 'ki' | 'auto'
  String get herkunft => asString(json['herkunft']);
  ConnectionEnd get von => _end(json['von']);
  ConnectionEnd get nach => _end(json['nach']);
  String get label => asString(json['label']);
  String get text => asString(json['text']);

  /// Nur bei typ 'fazit' gesetzt.
  String? get findingId => asStringOrNull(json['findingId']);
  String? get findingTyp => asStringOrNull(json['findingTyp']);

  static ConnectionEnd _end(Object? v) {
    final m = asMapOrNull(v);
    return ConnectionEnd(
      sectionId: asStringOrNull(m?['sectionId']),
      paraId: asStringOrNull(m?['paraId']),
    );
  }
}

/// Ein- und ausgehende Kanten eines Abschnitts (Rang-sortiert).
class SectionConnections {
  final List<ConnectionEdge> out;
  final List<ConnectionEdge> inbound;

  const SectionConnections({required this.out, required this.inbound});
}

class Connections {
  final DomainContext ctx;
  final DomainStore store;
  final int Function() nowMs;

  Connections(this.ctx, this.store, {int Function()? nowMs})
      : nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  List<ConnectionEdge>? _cache;

  /// Typdefinitionen — exakt connections.js:18-26.
  static const Map<String, ConnectionTypeDef> types = {
    'folgerung': ConnectionTypeDef(icon: '⇒', out: 'daraus gefolgert in', inLabel: 'Folgerung aus'),
    'aufgriff': ConnectionTypeDef(icon: '↻', out: 'wieder aufgegriffen in', inLabel: 'greift zurück auf'),
    'grundlage': ConnectionTypeDef(icon: '▤', out: 'Grundlage für', inLabel: 'stützt sich auf'),
    'vergleich': ConnectionTypeDef(icon: '⇄', out: 'Vergleich mit', inLabel: 'Vergleich mit'),
    'fazit': ConnectionTypeDef(icon: '◎', out: 'fließt ins Fazit ein', inLabel: 'hergeleitet aus'),
    'xref': ConnectionTypeDef(icon: '→', out: 'verweist auf', inLabel: 'referenziert von'),
    'quellen': ConnectionTypeDef(icon: '⌗', out: 'teilt Quellen mit', inLabel: 'teilt Quellen mit'),
  };

  void invalidate() => _cache = null;

  /// Alle Connections (dedupliziert, mit Herkunft) — connections.js:31-119.
  List<ConnectionEdge> all() {
    final cached = _cache;
    if (cached != null) return cached;
    final out = <ConnectionEdge>[];
    final seen = <String>{};

    void push(Map<String, Object?> c) {
      final von = asMapOrNull(c['von']);
      final nach = asMapOrNull(c['nach']);
      final vonSec = asStringOrNull(von?['sectionId']);
      final nachSec = asStringOrNull(nach?['sectionId']);
      if (!jsTruthy(vonSec) || !jsTruthy(nachSec)) return;
      if (ctx.unitIndex[vonSec!] == null || ctx.unitIndex[nachSec!] == null) return;
      if (vonSec == nachSec) return;
      final key =
          '${c['typ']}|$vonSec|${asString(von?['paraId'])}|$nachSec|${asString(nach?['paraId'])}';
      if (seen.contains(key)) return;
      seen.add(key);
      out.add(ConnectionEdge(c));
    }

    // 1. KI-Connections: Bundle (DATA_META.connections) + Import (Store).
    //    Bundle-Kanten kommen typisiert aus dem Modell und werden in die
    //    Roh-Form zurückübersetzt; Store-Kanten sind Roh-JSON (importKi
    //    speichert sie unverändert — Zusatzfelder bleiben erhalten).
    final bundleKi = [
      for (final c in ctx.meta.connections?.connections ?? const [])
        <String, Object?>{
          'id': c.id,
          'typ': c.typ,
          'von': {'sectionId': c.von.sectionId, if (c.von.paraId.isNotEmpty) 'paraId': c.von.paraId},
          'nach': {'sectionId': c.nach.sectionId, if (c.nach.paraId.isNotEmpty) 'paraId': c.nach.paraId},
          'label': c.label,
          'text': c.text,
        },
    ];
    final storeKi = [
      for (final c in asList(store.readMap('kiConnections')['connections']))
        if (c is Map) c.map((k, v) => MapEntry(k.toString(), v)),
    ];
    for (final src in [bundleKi, storeKi]) {
      for (final c in src) {
        push({
          ...c,
          'typ': types.containsKey(asString(c['typ'])) ? c['typ'] : 'aufgriff',
          'herkunft': 'ki',
        });
      }
    }

    // 2. Fazit-Befunde → Abschnitt-zu-Fazit. Fazit-Kapitel = erstes Kapitel
    //    mit fazit/zusammenfassung/conclusio im Titel, sonst das letzte.
    final chapters = ctx.thesis?.chapters ?? const <Chapter>[];
    final fazitRe = RegExp('fazit|zusammenfassung|conclusio', caseSensitive: false);
    Chapter? fazitCh;
    for (final c in chapters) {
      if (fazitRe.hasMatch(c.title)) {
        fazitCh = c;
        break;
      }
    }
    fazitCh ??= chapters.isNotEmpty ? chapters.last : null;
    final fazitSec = fazitCh != null ? '${fazitCh.num}.0' : null;
    for (final f in ctx.meta.fazit?.findings ?? const []) {
      for (final s in f.abschnitte) {
        push({
          'id': 'fz-${f.id}-$s',
          'typ': 'fazit',
          'herkunft': 'auto',
          'von': {'sectionId': s},
          'nach': {'sectionId': fazitSec, 'paraId': jsTruthy(f.fazitParagraphId) ? f.fazitParagraphId : null},
          'label': f.label,
          'text': f.beschreibung,
          'findingId': f.id,
          'findingTyp': f.typ,
        });
      }
    }

    // 3. Querverweise im Text („siehe Abschnitt X / Kapitel N“)
    final xrefRe = RegExp(r'\b(Abschnitt|Kapitel)\s+(\d+(?:\.\d+)*)\b');
    for (final secId in ctx.orderedUnitIds) {
      final u = ctx.unitIndex[secId]!.unit;
      for (final p in u.paragraphs) {
        final texts = p.typeEnum == ParagraphType.list ? p.items : [p.text];
        for (final t in texts) {
          for (final m in xrefRe.allMatches(t)) {
            final target = m.group(1) == 'Kapitel' ? '${m.group(2)}.0' : m.group(2)!;
            push({
              'id': 'xr-${p.id}-$target',
              'typ': 'xref',
              'herkunft': 'auto',
              'von': {'sectionId': secId, 'paraId': p.id},
              'nach': {'sectionId': target},
            });
          }
        }
      }
    }

    // 4. Gemeinsame SELTENE Quellen: Abschnitte (kapitelübergreifend), die
    //    sich auf dieselben, wenig gestreuten Quellen stützen. Breit zitierte
    //    Quellen (EHDS-VO & Co.) verbinden nichts sinnvoll und bleiben außen
    //    vor; die stärksten Paare gewinnen (Top 40).
    final secSrcs = <String, Set<String>>{};
    for (final secId in ctx.orderedUnitIds) {
      final set = <String>{};
      for (final n in _numsForSection(secId)) {
        for (final s in ctx.fnIndex[n]?.sources ?? const <String>[]) {
          set.add(s);
        }
      }
      if (set.isNotEmpty) secSrcs[secId] = set;
    }
    final srcSpread = <String, int>{};
    for (final set in secSrcs.values) {
      for (final s in set) {
        srcSpread[s] = (srcSpread[s] ?? 0) + 1;
      }
    }
    final ids = secSrcs.keys.toList();
    final cands = <({String a, String b, List<String> rare, int score})>[];
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        final a = ids[i], b = ids[j];
        if (a.split('.').first == b.split('.').first) continue; // gleiches Kapitel: zu naheliegend
        final shared = [for (final s in secSrcs[a]!) if (secSrcs[b]!.contains(s)) s];
        final rare = [for (final s in shared) if ((srcSpread[s] ?? 99) <= 3) s];
        final veryRare = [for (final s in rare) if ((srcSpread[s] ?? 99) <= 2) s];
        if (rare.length >= 2 || veryRare.isNotEmpty) {
          cands.add((a: a, b: b, rare: rare, score: rare.length * 2 + veryRare.length));
        }
      }
    }
    final sorted = stableSorted(cands, (x, y) => y.score - x.score);
    for (final c in sorted.take(40)) {
      final label = c.rare.take(3).map(ctx.srcShort).join(', ');
      push({
        'id': 'qs-${c.a}-${c.b}',
        'typ': 'quellen',
        'herkunft': 'auto',
        'von': {'sectionId': c.a},
        'nach': {'sectionId': c.b},
        'label': 'gemeinsame Quellen: $label${c.rare.length > 3 ? ' …' : ''}',
        'text': 'Beide Abschnitte stützen sich auf ${c.rare.length} gemeinsame, selten zitierte Quelle(n).',
      });
    }

    return _cache = out;
  }

  /// Connections eines Abschnitts (ein- und ausgehend), KI-Typen zuerst —
  /// Rang folgerung < grundlage < aufgriff < vergleich < fazit < quellen <
  /// xref (unbekannt: 9). Stabil sortiert wie das JS-Original.
  SectionConnections forSection(String sectionId) {
    const rank = {
      'folgerung': 0,
      'grundlage': 1,
      'aufgriff': 2,
      'vergleich': 3,
      'fazit': 4,
      'quellen': 5,
      'xref': 6,
    };
    int srt(ConnectionEdge a, ConnectionEdge b) => (rank[a.typ] ?? 9) - (rank[b.typ] ?? 9);
    final edges = all();
    return SectionConnections(
      out: stableSorted(edges.where((c) => c.von.sectionId == sectionId), srt),
      inbound: stableSorted(edges.where((c) => c.nach.sectionId == sectionId), srt),
    );
  }

  /// Import nachgenerierter KI-Connections (JSON-String oder Map mit
  /// "connections"). Merge per `id` in den Store; Einträge ohne id bekommen
  /// eine generierte. Liefert den Status-Text des Originals.
  String importKi(Object json) {
    final d = json is String ? jsonDecode(json) : json;
    final list = d is Map ? d['connections'] : null;
    if (list is! List) throw const FormatException('Feld "connections" (Array) fehlt.');
    final valid = <Map<String, Object?>>[];
    var skipped = 0;
    for (final raw in list) {
      final c = raw is Map ? raw.map((k, v) => MapEntry(k.toString(), v)) : null;
      final vonSec = asStringOrNull(asMapOrNull(c?['von'])?['sectionId']);
      final nachSec = asStringOrNull(asMapOrNull(c?['nach'])?['sectionId']);
      final ok = c != null &&
          jsTruthy(vonSec) &&
          jsTruthy(nachSec) &&
          ctx.unitIndex[vonSec!] != null &&
          ctx.unitIndex[nachSec!] != null &&
          vonSec != nachSec;
      if (ok) {
        valid.add(c);
      } else {
        skipped++;
      }
    }
    if (valid.isEmpty) {
      throw FormatException(
          'Keine gültigen Einträge ($skipped übersprungen — von/nach.sectionId müssen existierende Abschnitte sein).');
    }
    final cur = store.readMap('kiConnections');
    final byId = <String, Object?>{};
    for (final c in asList(cur['connections'])) {
      if (c is Map) byId[asString(c['id'])] = c;
    }
    for (final c in valid) {
      final id = jsTruthy(c['id']) ? asString(c['id']) : 'ki-${byId.length}-${nowMs()}';
      byId[id] = c;
    }
    store.write('kiConnections', {'connections': byId.values.toList()});
    invalidate();
    return skipped > 0
        ? '${valid.length} übernommen, $skipped übersprungen (ungültige/unbekannte Abschnitte)'
        : '${valid.length}';
  }

  /// Prompt: Connections für die ganze Arbeit (nach)generieren lassen —
  /// wörtlich connections.js:154-194.
  String regeneratePrompt() {
    final lines = <String>[];
    for (final ch in ctx.thesis?.chapters ?? const []) {
      lines.add('\nKAPITEL ${ch.num}: ${ch.title}');
      void rec(List<Unit> us) {
        for (final u in us) {
          if (u.paragraphs.isNotEmpty) {
            lines.add('  ${u.isIntro ? '${ch.num}.0' : u.id} ${u.isIntro ? '(Überblick)' : u.title}');
            final gen = ctx.sections[fileIdOf(u.id)];
            for (final p in gen?.paragraphs ?? const []) {
              if (jsTruthy(p.kernaussage)) lines.add('     [${p.id}] ${p.kernaussage}');
            }
          }
          rec(u.children);
        }
      }

      rec(ch.sections);
    }
    return [
      'Du analysierst die inhaltlichen Verbindungen einer wissenschaftlichen Arbeit („Connections“).',
      'Unten die Gliederung mit den Kernaussagen je Absatz (IDs in [Klammern]).',
      '',
      'AUFGABE: Finde die WICHTIGEN inhaltlichen Verbindungen zwischen Abschnitten verschiedener Kapitel',
      '(nicht bloße Querverweise — die erkennt die Software selbst):',
      '- "folgerung":  Aussage B wird aus Aussage A gefolgert/abgeleitet.',
      '- "grundlage":  A liefert die technische/rechtliche Grundlage für B.',
      '- "aufgriff":   Ein Thema aus A wird in B wieder aufgegriffen/vertieft.',
      '- "vergleich":  A und B behandeln dasselbe aus verschiedenen Blickwinkeln.',
      'Qualität vor Menge: 15–40 Verbindungen, jede mit kurzer Begründung.',
      '',
      'ANTWORTE NUR mit diesem JSON (importierbar unter Projekt → Connections):',
      '{ "connections": [{',
      '   "id": "c1", "typ": "folgerung|grundlage|aufgriff|vergleich",',
      '   "von":  { "sectionId": "5.3.3", "paraId": "5.3.3-p2" },',
      '   "nach": { "sectionId": "6.0",   "paraId": "6.0-p5" },',
      '   "label": "<Kurzname der Verbindung>",',
      '   "text": "<1 Satz: warum hängen die Stellen zusammen>" }] }',
      '',
      'DIE ARBEIT:',
      ...lines,
    ].join('\n');
  }

  /// Fußnoten eines Abschnitts (lokale Kopie von Levels.numsForSection —
  /// vermeidet die Modul-Kopplung des Originals, identische Logik).
  List<int> _numsForSection(String sectionId) {
    final info = ctx.unitIndex[sectionId];
    return [
      for (final p in info?.unit.paragraphs ?? const <Paragraph>[])
        for (final f in p.footnotes) f.num,
    ];
  }
}
