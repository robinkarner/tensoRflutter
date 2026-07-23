/// „Paper → Quellen" — reine, testbare Kernlogik für den KI-Quellen-Import:
///
///  * [paperSourcesPrompt] baut den Prompt, mit dem ein Modell (eingebaute
///    Claude-API ODER externes GPT per Copy/Paste) aus einem Paper bzw.
///    dessen Literaturverzeichnis ALLE zitierten Quellen als importierbares
///    JSON liefert — inkl. bestem öffentlich zugänglichem PDF-Link, damit der
///    anschließende „⭳ Alle laden"-Lauf sie direkt herunterladen kann.
///  * [parseRecognizedSources] validiert die Antwort und macht daraus fertige
///    Datensätze für [ProjectRepository.saveCustomSource] — id-Sanitizing,
///    kollisionsfreie ids (nichts wird still überschrieben) und ein robustes
///    Mapping der Quellen-Art auf die sieben `kindLabels`-Schlüssel.
///
/// Bewusst UI-frei (wie `import_logic`/`gpt_prompts`): das Modal ist nur eine
/// Projektion dieser Funktionen.
library;

import 'dart:convert';

import '../../../data/bundles/kind_labels.dart';
import 'source_id_logic.dart';

/// Prompt für die KI-Quellenerkennung aus einem Paper.
///
/// [paperText] ist der eingefügte Text (ganzes Paper oder nur das
/// Literaturverzeichnis). [arbeitTitel] blendet — wenn vorhanden — den Titel
/// der aktiven Arbeit als Kontext ein.
String paperSourcesPrompt(String paperText, {String? arbeitTitel}) {
  final kinds = kindLabels.entries.map((e) => '${e.key} (${e.value})').join(', ');
  final ctx = (arbeitTitel != null && arbeitTitel.trim().isNotEmpty)
      ? 'KONTEXT — die Arbeit, für die die Quellen gesammelt werden: „${arbeitTitel.trim()}".'
      : null;
  final lines = <String?>[
    'Du extrahierst aus dem folgenden wissenschaftlichen Text ALLE zitierten '
        'Quellen (Literaturverzeichnis/Bibliografie, sonst die im Text '
        'referenzierten Werke) für die Quellensoftware „Thesis Studio".',
    ctx,
    'WICHTIG: Verifiziere Metadaten mit eigenem Wissen/Websuche, wenn möglich, '
        'und ergänze fehlende Angaben. Erfinde nichts — unsichere Felder leer '
        'lassen (null).',
    '',
    'Für "url" IMMER den besten ÖFFENTLICH zugänglichen Direkt-Link zum PDF '
        'versuchen (arXiv, Open Access, Preprint, Autoren-/Instituts-'
        'Repositorium). Nur wenn nichts frei verfügbar ist: die DOI-/Verlags-'
        'seite eintragen. "doi" nur die reine DOI (beginnt mit 10.).',
    'Für "kind" genau EINEN dieser Schlüssel wählen: $kinds.',
    '',
    'ANTWORTE NUR mit diesem JSON (keine Erklärung davor/danach):',
    '{',
    '  "sources": [',
    '    { "title": "…", "author": "Nachname, V. u.a.", "year": 2024, '
        '"container": "Journal/Verlag/Reihe", "kind": "artikel", '
        '"doi": "10.…"|null, "url": "https://…/paper.pdf"|null }',
    '  ]',
    '}',
    '',
    '--- TEXT ANFANG ---',
    paperText.trim(),
    '--- TEXT ENDE ---',
  ];
  return lines.where((l) => l != null && l.isNotEmpty).join('\n');
}

/// Ergebnis von [parseRecognizedSources].
class RecognizedSources {
  /// Fertige Datensätze für `saveCustomSource` (id garantiert kollisionsfrei).
  final List<Map<String, dynamic>> records;

  /// Anzahl Einträge, deren id gegen bestehende/andere kollidierte und darum
  /// eindeutig gemacht (Suffix) wurde.
  final int renamed;

  /// Anzahl übersprungener Einträge (kein Titel / keine brauchbare id).
  final int skipped;

  const RecognizedSources({
    required this.records,
    this.renamed = 0,
    this.skipped = 0,
  });
}

/// Bekannte Quellen-Art oder ein tolerantes Mapping häufiger Synonyme auf die
/// sieben `kindLabels`-Schlüssel; unbekannt ⇒ 'online' (neutralste Wahl).
String normalizeKind(Object? raw) {
  final k = '${raw ?? ''}'.trim().toLowerCase();
  if (kindLabels.containsKey(k)) return k;
  const alias = {
    'article': 'artikel',
    'paper': 'artikel',
    'journal': 'artikel',
    'preprint': 'artikel',
    'proceedings': 'konferenz',
    'conference': 'konferenz',
    'inproceedings': 'konferenz',
    'standard': 'norm',
    'iso': 'norm',
    'techreport': 'report',
    'report': 'report',
    'book': 'report',
    'web': 'online',
    'website': 'online',
    'webpage': 'online',
    'misc': 'online',
    'regulation': 'recht-eu',
    'directive': 'recht-eu',
    'eu': 'recht-eu',
    'law': 'recht-at',
    'gesetz': 'recht-at',
  };
  return alias[k] ?? 'online';
}

/// Antwort-JSON in anzulegende Quellen-Datensätze überführen. Akzeptiert
/// `{"sources":[…]}` oder ein bloßes Array `[…]`. [existingIds] verhindert das
/// Überschreiben bereits vorhandener Quellen (saveCustomSource ersetzt per id).
///
/// Wirft [FormatException] bei kaputtem JSON oder fehlendem sources-Feld.
RecognizedSources parseRecognizedSources(
  String jsonText, {
  required Set<String> existingIds,
}) {
  final decoded = jsonDecode(jsonText);
  final list = decoded is List
      ? decoded
      : (decoded is Map ? decoded['sources'] : null);
  if (list is! List) {
    throw const FormatException('Feld "sources" fehlt (erwartet Liste).');
  }

  final taken = {...existingIds};
  final records = <Map<String, dynamic>>[];
  var renamed = 0, skipped = 0;

  for (final raw in list) {
    if (raw is! Map) {
      skipped++;
      continue;
    }
    final title = '${raw['title'] ?? ''}'.trim();
    if (title.isEmpty) {
      skipped++;
      continue;
    }
    final author = '${raw['author'] ?? ''}'.trim();
    final yearStr = '${raw['year'] ?? ''}';
    final year = int.tryParse(RegExp(r'\d{4}').firstMatch(yearStr)?.group(0) ?? '');

    // id aus Vorgabe oder Autor+Jahr/Titel, säubern, dann kollisionsfrei.
    var id = sanitizeSourceId('${raw['id'] ?? ''}');
    if (id.isEmpty) {
      id = sanitizeSourceId(suggestNewSourceId(
        author: author,
        title: title,
        year: year?.toString() ?? '',
      ));
    }
    if (id.isEmpty) {
      skipped++;
      continue;
    }
    if (taken.contains(id)) {
      final base = id;
      var n = 2;
      while (taken.contains('$base-$n')) {
        n++;
      }
      id = '$base-$n';
      renamed++;
    }
    taken.add(id);

    final doi = '${raw['doi'] ?? ''}'.trim();
    final url = '${raw['url'] ?? raw['link'] ?? raw['pdf'] ?? ''}'.trim();
    records.add({
      'id': id,
      'title': title,
      'kind': normalizeKind(raw['kind']),
      'author': author,
      'year': year,
      'container': '${raw['container'] ?? ''}'.trim(),
      'doi': RegExp(r'^10\.').hasMatch(doi) ? doi : null,
      'url': RegExp(r'^https?:').hasMatch(url) ? url : null,
    });
  }

  return RecognizedSources(records: records, renamed: renamed, skipped: skipped);
}
