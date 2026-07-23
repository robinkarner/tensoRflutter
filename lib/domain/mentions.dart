/// Text-Erwähnungen von Quellen (ohne Fußnote/\cite) — Port von
/// `js/mentions.js`.
///
/// Erkennt DETERMINISTISCH (ohne KI), wenn eine Quelle im Fließtext nur über
/// die Autorennennung referenziert wird — „Abowd and Dey (1999) defined …“ —
/// ohne dass an der Stelle eine Fußnote derselben Quelle steht. Die Treffer
/// sind VORSCHLÄGE: erst die Bestätigung macht sie zu einer Erwähnung der
/// bestehenden Quellen-Instanz (gleiche Quelle wie im Register — keine
/// Duplikate).
///
/// Mehrdeutigkeit: Passen MEHRERE Quellen auf dieselbe Textstelle (z. B.
/// zwei „Vallejo (2021)“), wird das EINE Erwähnung mit candidates[] (nach
/// Score sortiert, wahrscheinlichste zuerst) — die Auswahl entscheidet der
/// Nutzer.
///
/// Persistenz: Store-Key `textMentions` (pro Arbeit, im Belegstand
/// enthalten): `{ "<paraId>|<start>": { status, srcId, fn? } }`.
/// Das Alt-Format `"<paraId>|<srcId>|<start>": "<status>"` wird beim Lesen
/// verlustfrei migriert.
library;

import '../data/models/json_utils.dart';
import '../data/models/models.dart';
import 'domain_context.dart';
import 'domain_store.dart';
import 'js_compat.dart';

/// Erkennungs-Muster einer Quelle: Nachnamen (alle Autoren) + Jahr.
class SourcePattern {
  final String srcId;
  final int year;
  final List<String> names;

  const SourcePattern({required this.srcId, required this.year, required this.names});
}

/// Ein Kandidat an einer Erwähnungs-Stelle.
class MentionCandidate {
  final String srcId;

  /// (Quelle bereits per Fußnote im Absatz zitiert ? 100 : 0) + Namenslänge.
  final int score;

  /// Zeichen-Offset des Namensbeginns im Roh-Absatztext.
  final int start;

  const MentionCandidate({required this.srcId, required this.score, required this.start});

  Map<String, Object?> toJson() => {'srcId': srcId, 'score': score, 'start': start};
}

/// Roh-Treffer aus [Mentions.detect]: EINE Textstelle (Jahres-Klammer),
/// ggf. mit mehreren Kandidaten.
class RawMention {
  /// Wahrscheinlichste Quelle (Top-Kandidat).
  final String srcId;

  /// Offsets im Roh-Absatztext (inkl. `[^N]`-Marker!).
  final int start;
  final int end;
  final String snippet;
  final List<MentionCandidate> candidates;

  const RawMention({
    required this.srcId,
    required this.start,
    required this.end,
    required this.snippet,
    required this.candidates,
  });

  Map<String, Object?> toJson() => {
        'srcId': srcId,
        'start': start,
        'end': end,
        'snippet': snippet,
        'candidates': [for (final c in candidates) c.toJson()],
      };
}

/// Gespeicherter Status einer Erwähnungs-Stelle.
class MentionStatusEntry {
  /// 'bestaetigt' | 'verworfen' | 'beleg'
  final String status;
  final String? srcId;

  /// Fußnotennummer bei status 'beleg' (zusammengeführt).
  final int? fn;

  const MentionStatusEntry({required this.status, this.srcId, this.fn});
}

/// Angereicherte Erwähnung eines Absatzes ([Mentions.forPara]-Ergebnis).
class Mention extends RawMention {
  final String paraId;
  final String sectionId;

  /// `"<paraId>|<start>"` — der Store-Key der Stelle.
  final String key;

  /// 'offen' | 'bestaetigt' | 'verworfen' | 'beleg'
  final String status;

  /// Fußnotennummer bei status 'beleg', sonst null.
  final int? fn;

  const Mention({
    required super.srcId,
    required super.start,
    required super.end,
    required super.snippet,
    required super.candidates,
    required this.paraId,
    required this.sectionId,
    required this.key,
    required this.status,
    this.fn,
  });

  @override
  Map<String, Object?> toJson() => {
        ...super.toJson(),
        'paraId': paraId,
        'sectionId': sectionId,
        'key': key,
        'status': status,
        'fn': fn,
      };
}

class Mentions {
  final DomainContext ctx;
  final DomainStore store;

  Mentions(this.ctx, this.store);

  List<SourcePattern>? _patCache;
  final Map<String, List<RawMention>> _paraCache = {};

  /// Muster je Quelle: Nachnamen (alle Autoren, `;`-getrennt) + Jahr —
  /// mentions.js:23-39. „Nachname, V.“ → Nachname; sonst (Institution)
  /// ganzer Name; nur Namen mit Länge ≥ 3.
  List<SourcePattern> patterns() {
    final cached = _patCache;
    if (cached != null) return cached;
    final out = <SourcePattern>[];
    final etAlRe = RegExp(r'\bu\.\s?a\.|\bet al\.?', caseSensitive: false);
    for (final s in ctx.sources) {
      if (!jsTruthy(s.year) || !jsTruthy(s.author)) continue;
      final names = <String>[];
      for (final part in s.author!.split(';')) {
        final cleaned = part.replaceAll(etAlRe, '').trim();
        if (cleaned.isEmpty) continue;
        final last = cleaned.contains(',') ? cleaned.split(',').first.trim() : cleaned;
        if (last.length >= 3) names.add(last);
      }
      if (names.isNotEmpty) out.add(SourcePattern(srcId: s.id, year: s.year!, names: names));
    }
    return _patCache = out;
  }

  void invalidate() {
    _patCache = null;
    _paraCache.clear();
  }

  /// Roh-Erkennung in einem Absatztext (mit `[^N]`-Markern) —
  /// mentions.js:47-107. Unterdrückt Treffer, wenn die Quelle im Fenster um
  /// die Nennung ohnehin per Fußnote zitiert wird (320 Zeichen danach bzw.
  /// 90 Zeichen davor).
  List<RawMention> detect(String? text, Iterable<String>? footnoteSources) {
    final raw = text ?? '';
    final fnSrcs = Set<String>.of(footnoteSources ?? const []);
    final found = <({String srcId, int start, int end, int score})>[];
    final yearRe = RegExp(r'\(\s*((?:19|20)\d{2})[a-z]?\s*\)');
    final markerRe = RegExp(r'\[\^(\d+)\]');

    for (final m in yearRe.allMatches(raw)) {
      final year = int.parse(m.group(1)!);
      final end = m.start + m.group(0)!.length;
      final windowStart = m.start - 55 < 0 ? 0 : m.start - 55;
      final before = raw.substring(windowStart, m.start);
      for (final pat in patterns()) {
        if (pat.year != year) continue;
        // Namensfenster: das SPÄTESTE Vorkommen (größte absolute Position)
        // gewinnt.
        var best = -1;
        String? bestName;
        for (final name in pat.names) {
          final re = RegExp(
            '(^|[^\\wÄÖÜäöü])(${RegExp.escape(name)})(?=[^\\wÄÖÜäöü]|\$)',
            caseSensitive: false,
          );
          for (final nm in re.allMatches(before)) {
            final abs = windowStart + nm.start + nm.group(1)!.length;
            if (abs > best) {
              best = abs;
              bestName = name;
            }
          }
        }
        if (best == -1) continue;

        // Nähe-Unterdrückung: Fußnote DERSELBEN Quelle direkt nach der
        // Nennung (bis ~320 Zeichen) → die Stelle ist bereits regulär belegt.
        final after = raw.substring(end, end + 320 > raw.length ? raw.length : end + 320);
        var covered = false;
        for (final fm in markerRe.allMatches(after)) {
          final fn = ctx.fnIndex[int.parse(fm.group(1)!)];
          if (fn != null && fn.sources.contains(pat.srcId)) {
            covered = true;
            break;
          }
        }
        // Auch: Marker unmittelbar VOR der Nennung (…[^12] Wie Abowd (1999) …)
        if (!covered) {
          final beforeAll = raw.substring(best - 90 < 0 ? 0 : best - 90, best);
          for (final fm in markerRe.allMatches(beforeAll)) {
            final fn = ctx.fnIndex[int.parse(fm.group(1)!)];
            if (fn != null && fn.sources.contains(pat.srcId)) {
              covered = true;
              break;
            }
          }
        }
        if (covered) continue;
        // Score: Quelle bereits im Absatz zitiert > längerer (spezifischerer)
        // Namens-Match
        final score = (fnSrcs.contains(pat.srcId) ? 100 : 0) + bestName!.length;
        found.add((srcId: pat.srcId, start: best, end: end, score: score));
      }
    }

    // Nach Textstelle gruppieren: gleiche Jahres-Klammer (end) = EINE
    // Erwähnung, mehrere passende Quellen werden Kandidaten (wahrscheinlichste
    // zuerst — Score-Ties behalten die Muster-Reihenfolge, stabil sortiert).
    final byEnd = <int, List<({String srcId, int start, int end, int score})>>{};
    for (final f in found) {
      final grp = byEnd.putIfAbsent(f.end, () => []);
      if (!grp.any((g) => g.srcId == f.srcId)) grp.add(f);
    }
    final result = <RawMention>[];
    for (final grp in byEnd.values) {
      final sortedGrp = stableSorted(grp, (a, b) => b.score - a.score);
      var start = sortedGrp.first.start;
      for (final g in sortedGrp) {
        if (g.start < start) start = g.start;
      }
      result.add(RawMention(
        srcId: sortedGrp.first.srcId,
        start: start,
        end: sortedGrp.first.end,
        snippet: raw.substring(start, sortedGrp.first.end),
        candidates: [
          for (final g in sortedGrp) MentionCandidate(srcId: g.srcId, score: g.score, start: g.start),
        ],
      ));
    }
    return stableSorted(result, (a, b) => a.start - b.start);
  }

  Map<String, Object?> _store() => store.readMap('textMentions');
  void _saveStore(Map<String, Object?> m) => store.write('textMentions', m);

  String keyFor(String paraId, RawMention f) => '$paraId|${f.start}';

  /// Status + gewählte Quelle einer Stelle; migriert Alt-Einträge
  /// (`"paraId|srcId|start": "status"`) verlustfrei ins neue Format
  /// (in-place, mit Store-Write) — mentions.js:114-132.
  MentionStatusEntry? statusEntry(String paraId, RawMention f) {
    final m = _store();
    final nk = keyFor(paraId, f);
    Object? v = m[nk];
    if (v == null) {
      for (final c in f.candidates) {
        final lk = '$paraId|${c.srcId}|${c.start}';
        final legacy = m[lk];
        if (legacy is String) {
          v = {'status': legacy, 'srcId': c.srcId};
          m[nk] = v;
          m.remove(lk);
          _saveStore(m);
          break;
        }
      }
    }
    if (v is String) v = {'status': v, 'srcId': f.srcId};
    final map = asMapOrNull(v);
    if (map == null) return null;
    return MentionStatusEntry(
      status: asString(map['status']),
      srcId: asStringOrNull(map['srcId']),
      fn: asIntOrNull(map['fn']),
    );
  }

  /// status: 'bestaetigt' | 'verworfen' | 'beleg' (mit Fußnote fn
  /// zusammengeführt — gleiche Quellen-Instanz, zeigt auf denselben Beleg);
  /// 'offen' löscht den Eintrag.
  void setStatus(String key, String status, String srcId, [int? fn]) {
    final m = _store();
    if (status == 'offen') {
      m.remove(key);
    } else {
      m[key] = jsTruthy(fn)
          ? {'status': status, 'srcId': srcId, 'fn': fn}
          : {'status': status, 'srcId': srcId};
    }
    _saveStore(m);
  }

  /// Merge-Kandidat einer Erwähnung: die nächste Fußnote DERSELBEN Quelle
  /// weiter hinten im Absatz (pre-KI: „Zitat endet erst Sätze später“).
  /// Liefert die Fußnotennummer oder null — mentions.js:145-157.
  int? mergeTarget(Paragraph? p, RawMention? mt) {
    if (p == null || mt == null || mt.srcId.isEmpty) return null;
    final text = p.typeEnum == ParagraphType.list ? p.items.join('\n') : p.text;
    int? best;
    for (final fm in RegExp(r'\[\^(\d+)\]').allMatches(text)) {
      final num = int.parse(fm.group(1)!);
      final fn = ctx.fnIndex[num];
      if (fn == null || !fn.sources.contains(mt.srcId)) continue;
      if (fm.start >= mt.end) {
        best = num; // nächste dahinter
        break;
      }
      best ??= num; // sonst: irgendeine im Absatz
    }
    return best;
  }

  /// Erwähnungen eines Absatzes inkl. Status (gecacht pro Sitzung).
  /// srcId ist die GEWÄHLTE Quelle (bestätigt/verworfen) bzw. der
  /// wahrscheinlichste Kandidat, solange die Stelle offen ist.
  List<Mention> forPara(String sectionId, Paragraph? p) {
    if (p == null || p.typeEnum == ParagraphType.figure || p.typeEnum == ParagraphType.table) {
      return const [];
    }
    final raw = _paraCache.putIfAbsent(p.id, () {
      final text = p.typeEnum == ParagraphType.list ? p.items.join('\n') : p.text;
      final fnSrcs = [for (final f in p.footnotes) ...f.sources];
      return detect(text, fnSrcs);
    });
    return [
      for (final f in raw)
        () {
          final entry = statusEntry(p.id, f);
          final chosen = (entry?.srcId != null && f.candidates.any((c) => c.srcId == entry!.srcId))
              ? entry!.srcId!
              : f.srcId;
          final fn = entry?.fn;
          return Mention(
            srcId: chosen,
            start: f.start,
            end: f.end,
            snippet: f.snippet,
            candidates: f.candidates,
            paraId: p.id,
            sectionId: sectionId,
            key: keyFor(p.id, f),
            status: entry?.status ?? 'offen',
            fn: jsTruthy(fn) ? fn : null,
          );
        }(),
    ];
  }

  /// Alle Erwähnungen der ganzen Arbeit (für Quellenseite/Statistik).
  List<Mention> scanAll() {
    final out = <Mention>[];
    for (final ch in ctx.thesis?.chapters ?? const <Chapter>[]) {
      void rec(List<Unit> units) {
        for (final u in units) {
          for (final p in u.paragraphs) {
            out.addAll(forPara(u.id, p));
          }
          rec(u.children);
        }
      }

      rec(ch.sections);
    }
    return out;
  }

  /// Erwähnungen einer Quelle — auch offene Stellen, bei denen die Quelle
  /// (noch) nur einer von mehreren Kandidaten ist.
  List<Mention> forSource(String srcId) => [
        for (final f in scanAll())
          if (f.srcId == srcId ||
              (f.status == 'offen' && f.candidates.any((c) => c.srcId == srcId)))
            f,
      ];
}
