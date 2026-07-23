/// ✓ Format-Checker — Port von `Enhance._check*` (enhance.js:215-318):
/// die eingefügte Antwort NUR prüfen (nichts wird übernommen), mit dem, was
/// der Import sehen WÜRDE. Alle Meldungen wortwörtlich; statt HTML liefert
/// jeder Checker das strukturierte [AiCheckResult].
library;

import 'dart:convert';

import '../../../core/richtext/categories.dart';
import 'ai_flow.dart';

/// `Enhance._checkJson` — JSON parsen oder mit der Original-Meldung werfen.
Object? aiCheckJson(String raw) {
  try {
    return jsonDecode(raw);
  } catch (e) {
    var msg = e is FormatException ? e.message : '$e';
    if (msg.length > 80) msg = msg.substring(0, 80);
    throw FormatException(
        'kein gültiges JSON ($msg). Tipp: nur das JSON einfügen, ohne Text drumherum — ein ```-Codeblock wird automatisch entfernt.');
  }
}

/// 🖍 Markierungen (`_checkMarks`, enhance.js:232-253).
AiCheckResult aiCheckMarks(String raw) {
  final d = aiCheckJson(raw);
  final items = d is Map ? d['items'] : null;
  if (items is! Map) {
    throw const FormatException('Feld "items" fehlt (erwartet: {"items":{"<absatz-id>":[…]}}).');
  }
  final badCat = <String>{};
  var ok = 0, empty = 0;
  for (final list in items.values) {
    if (list is! List) continue;
    for (final m in list) {
      final snippet = m is Map ? m['snippet'] : null;
      if (m == null || snippet is! String || snippet.trim().isEmpty) {
        empty++;
        continue;
      }
      if (!catLabels.containsKey(m['kategorie'])) {
        badCat.add('${m['kategorie']}');
        continue;
      }
      ok++;
    }
  }
  final probs = <String>[
    if (empty > 0) '$empty Eintrag/Einträge ohne Snippet (werden übersprungen)',
    if (badCat.isNotEmpty)
      'unbekannte Kategorie(n): ${badCat.join(', ')} — erlaubt: ${catLabels.keys.join(', ')}',
  ];
  return AiCheckResult(
    ok: ok > 0,
    head: [
      const RichBit('Format erkannt: '),
      const RichBit('Markierungen', bold: true),
      const RichBit(' · '),
      RichBit('$ok', bold: true),
      RichBit(' gültige über ${items.length} Absätze.'),
    ],
    problems: probs,
    bereit: probs.isEmpty,
  );
}

/// ⤳ Connections (`_checkConn`, enhance.js:254-268) — gleiche Regel wie der
/// Importer: von/nach mit sectionId + typ.
AiCheckResult aiCheckConn(String raw) {
  final d = aiCheckJson(raw);
  final list = d is Map ? d['connections'] : null;
  if (list is! List) throw const FormatException('Feld "connections" (Array) fehlt.');
  var ok = 0, incomplete = 0;
  final byTyp = <String, int>{};
  for (final c in list) {
    final von = c is Map ? c['von'] : null;
    final nach = c is Map ? c['nach'] : null;
    final vonSec = von is Map ? von['sectionId'] : null;
    final nachSec = nach is Map ? nach['sectionId'] : null;
    final typ = c is Map ? c['typ'] : null;
    final hasVon = vonSec is String ? vonSec.isNotEmpty : vonSec != null;
    final hasNach = nachSec is String ? nachSec.isNotEmpty : nachSec != null;
    final hasTyp = typ is String ? typ.isNotEmpty : typ != null;
    if (c == null || !hasVon || !hasNach || !hasTyp) {
      incomplete++;
      continue;
    }
    byTyp['$typ'] = (byTyp['$typ'] ?? 0) + 1;
    ok++;
  }
  final verteilung = byTyp.entries.map((e) => '${e.key}: ${e.value}').join(' · ');
  return AiCheckResult(
    ok: ok > 0,
    head: [
      const RichBit('Format erkannt: '),
      const RichBit('Connections', bold: true),
      const RichBit(' · '),
      RichBit('$ok', bold: true),
      RichBit(' vollständig (${verteilung.isEmpty ? '—' : verteilung}).'),
    ],
    problems: [
      if (incomplete > 0)
        '$incomplete ohne von/nach (mit sectionId) oder typ (werden ignoriert)',
    ],
    bereit: incomplete == 0,
  );
}

/// 🎛 Instanzen (`_checkInst`, enhance.js:269-285). [knownIds] = ids der
/// nicht-speziellen Views (`dockDefs().filter(x=>!x.special)`).
AiCheckResult aiCheckInst(String raw, Set<String> knownIds) {
  final d = aiCheckJson(raw);
  var n = 0;
  final skipped = <String>{};
  final perInst = <String, int>{};
  void scan(String instId, Object? items) {
    if (!knownIds.contains(instId)) {
      skipped.add(instId);
      return;
    }
    if (items is! Map) return;
    for (final md in items.values) {
      if (md is String && md.trim().isNotEmpty) {
        n++;
        perInst[instId] = (perInst[instId] ?? 0) + 1;
      }
    }
  }

  final inst = d is Map ? d['instanzen'] : null;
  if (inst is Map) {
    for (final e in inst.entries) {
      scan('${e.key}', e.value);
    }
  } else if (d is Map && d['items'] != null && (d['mode'] != null || d['instanz'] != null)) {
    scan('${d['mode'] ?? d['instanz']}', d['items']);
  } else {
    throw const FormatException(
        'Feld "instanzen" fehlt (erwartet: {"instanzen":{"<instanz-id>":{"<absatz-id>":"<markdown>"}}}).');
  }
  final verteilung = perInst.entries.map((e) => '${e.key}: ${e.value}').join(' · ');
  return AiCheckResult(
    ok: n > 0,
    head: [
      const RichBit('Format erkannt: '),
      const RichBit('Instanzen', bold: true),
      const RichBit(' · '),
      RichBit('$n', bold: true),
      RichBit(' Absatz-Texte (${verteilung.isEmpty ? '—' : verteilung}).'),
    ],
    problems: [
      if (skipped.isNotEmpty)
        'unbekannte Instanz-IDs (übersprungen): ${skipped.join(', ')}',
    ],
    bereit: skipped.isEmpty,
  );
}

/// 📚 Quellen-Durchlauf (`_checkQuellen`, enhance.js:286-305) — Schema wie
/// im Prompt/Importer: je Stelle "footnote" (Alias "num" toleriert).
AiCheckResult aiCheckQuellen(String raw, String? srcId) {
  final d = aiCheckJson(raw);
  final stellen = d is Map ? d['stellen'] : null;
  if (stellen is! List) throw const FormatException('Feld "stellen" (Array) fehlt.');
  var mitZitat = 0, mitPos = 0, ohneNum = 0;
  for (final s in stellen) {
    final m = s is Map ? s : null;
    if (m == null || (m['footnote'] ?? m['num']) == null) {
      ohneNum++;
      continue;
    }
    bool truthy(Object? v) =>
        v != null && v != false && v != 0 && v != '' && !(v is double && v.isNaN);
    if (truthy(m['zitat'])) mitZitat++;
    if (truthy(m['seite']) || truthy(m['fundstelle'])) mitPos++;
  }
  final probs = <String>[
    if (ohneNum > 0) '$ohneNum Stelle(n) ohne "footnote" (Fußnoten-Zuordnung fehlt)',
  ];
  final answerSrc = d is Map ? d['sourceId'] : null;
  if (answerSrc != null &&
      '$answerSrc'.isNotEmpty &&
      srcId != null &&
      '$answerSrc' != srcId) {
    probs.add(
        'sourceId „$answerSrc“ ≠ aktive Quelle „$srcId“ — beim Übernehmen wird die aktive Quelle gesetzt');
  }
  final fv = d is Map ? d['formatVersion'] : null;
  if (fv == null || fv == '' || fv == false || fv == 0) {
    probs.add('kein "formatVersion" (erwartet "1.0") — wird toleriert');
  }
  return AiCheckResult(
    ok: stellen.length - ohneNum > 0,
    head: [
      const RichBit('Format erkannt: '),
      const RichBit('Quellen-Durchlauf', bold: true),
      const RichBit(' · '),
      RichBit('${stellen.length}', bold: true),
      RichBit(' Stellen ($mitPos mit Seite/Fundstelle, $mitZitat mit Zitat).'),
    ],
    problems: probs,
    bereit: probs.isEmpty,
  );
}

/// 📓 Erklärbuch (`_checkBuch`, enhance.js:306-318) — Markdown mit
/// „# Titel“-Pflicht, ```-Zäune paarig, JSON-Anfang abgelehnt.
AiCheckResult aiCheckBuch(String raw) {
  if (raw.startsWith('{') || raw.startsWith('[')) {
    throw const FormatException(
        'Das sieht nach JSON aus — das Erklärbuch erwartet Markdown (beginnend mit „# Titel“).');
  }
  final head = RegExp(r'^#\s+(.+)$', multiLine: true).firstMatch(raw)?.group(1);
  final fences = RegExp('```').allMatches(raw).length;
  final cells = fences ~/ 2;
  final probs = <String>[
    if (head == null) 'keine „# Titel“-Überschrift gefunden',
    if (fences.isOdd) 'ungerade Zahl von ```-Zäunen — ein Block ist nicht geschlossen',
  ];
  return AiCheckResult(
    ok: head != null,
    head: [
      const RichBit('Format erkannt: '),
      const RichBit('Erklärbuch (Markdown)', bold: true),
      if (head != null) ...[
        const RichBit(' · Titel „'),
        RichBit(head, bold: true),
        const RichBit('“'),
      ],
      RichBit(' · ~$cells Code-/Chart-Zellen.'),
    ],
    problems: probs,
    bereit: probs.isEmpty,
  );
}

/// `Enhance._check` — der Rahmen um alle Checker: leert/cleant, fängt
/// Format-Fehler und formt sie zur ✗-Meldung (enhance.js:218-227).
/// [clean] ist `ClaudeAI.clean` (hereingereicht gegen Import-Zyklen).
AiCheckResult runAiCheck(AiFlow flow, String text, String Function(String?) clean) {
  final raw = clean(text).trim();
  if (raw.isEmpty) {
    return AiCheckResult.plain(
        'Nichts zu prüfen — die Antwort (z. B. aus dem externen GPT) oben einfügen.',
        ok: false);
  }
  try {
    final check = flow.check;
    if (check != null) return check(raw);
    return AiCheckResult.plain(
        'Format frei — dieser Import nimmt den Text unverändert an.',
        ok: true);
  } catch (e) {
    return AiCheckResult.plain('✗ Kein gültiges Format: ${aiErrText(e)}', ok: false);
  }
}
