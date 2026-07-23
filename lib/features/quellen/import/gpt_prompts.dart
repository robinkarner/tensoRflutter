/// GPT-Prompt-Builder der Quellen-Welt — reine String-Funktionen, 1:1 aus
/// views_quellen.js portiert (Zeilenumbrüche/JSON-Vorlagen exakt — die
/// GPT-Antworten hängen davon ab).
///
///  * [gptErgaenzungsPrompt] (js:330-365): externes Modell findet eine
///    manuell nachgetragene Quelle und liefert Metadaten + Dossier +
///    Referenzierungsvorschläge als importierbares JSON.
///  * [gptPromptForSource] (js:686-710): der „Referenzierungsdurchlauf" —
///    je Zitierstelle die Originalstelle (Seite/Fundstelle + Zitat).
///    Abweichung E9/W8: Das Original codiert „Bachelorarbeit über den EHDS"
///    hart (falsch für fremde Arbeiten) — hier projektabhängig über den
///    Titel der aktiven Arbeit.
///
/// Detail-Parität: Das Original baut beide Prompts mit
/// `[…].filter(Boolean).join('\n')` — auch die LEEREN Zeilen (`''`) fallen
/// dadurch weg. [_joinFiltered] bildet genau das nach.
library;

import '../../../data/models/models.dart';
import '../../../data/repos/project_repository.dart';

/// `array.filter(Boolean).join('\n')` — null UND leere Strings fliegen raus.
String _joinFiltered(List<String?> lines) =>
    lines.where((l) => l != null && l.isNotEmpty).join('\n');

/// Prompt „🤖 Ergänzung" für eine manuell angelegte Quelle.
String gptErgaenzungsPrompt(Source s, ThesisMeta meta) {
  final lines = <String?>[
    'Du ergänzt die GPT-Voranalyse einer Quellensoftware („Thesis Studio“) um eine manuell nachgetragene Quelle.',
    'WICHTIG: Finde zuerst die RICHTIGE Quelle (Websuche/eigenes Wissen) und verifiziere die Metadaten.',
    '',
    'DIE ARBEIT: „${meta.title}“${meta.subtitle.isNotEmpty ? ' — ${meta.subtitle}' : ''} (${meta.author}).',
    '',
    'DIE QUELLE (Angaben ggf. korrigieren/vervollständigen):',
    '  id: ${s.id}',
    '  Titel: ${s.title}',
    (s.author ?? '').isNotEmpty ? '  Autor: ${s.author}' : null,
    s.year != null && s.year != 0 ? '  Jahr: ${s.year}' : null,
    (s.container ?? '').isNotEmpty ? '  Container: ${s.container}' : null,
    (s.doi ?? '').isNotEmpty ? '  DOI: ${s.doi}' : null,
    (s.url ?? '').isNotEmpty ? '  URL: ${s.url}' : null,
    '',
    'AUFGABE — antworte NUR mit diesem JSON (importierbar auf der Quellenseite):',
    '{',
    '  "sourceId": "${s.id}",',
    '  "meta": { "title": "…", "author": "…", "year": 2024, "container": "…", "doi": "…", "url": "…",',
    '            "official": "<offizieller Link (DOI/Verlag/EUR-Lex/RIS)>",',
    '            "file": "<IMMER versuchen: realistischster OEFFENTLICH zugaenglicher Direkt-Download-Link zum PDF (Open Access, Preprint, Autoren-/Instituts-Repositorium) — nur wenn nichts frei verfuegbar: null>" },',
    '  "dossier": "<Markdown: Was ist die Quelle? Kerninhalte. Mögliche Rolle in der Arbeit. Verlässlichkeit/Zugang>",',
    '  "keyPoints": ["…"],',
    '  "zitierweise": "<Vollzitat im Stil des Literaturverzeichnisses>",',
    '  "stellen": [ { "claim": "<Aussage der Arbeit, die diese Quelle stützen könnte>",',
    '                 "fundstelle": "<vermutet: S. x bzw. Art/§>", "suchHinweis": "<2-4 WOERTLICH im Original vorkommende Zeichenketten (je 2-6 Woerter, exakte Schreibweise und Sprache des Originals, KEINE Umformulierung), mit | getrennt - jede muss ueber die PDF-Volltextsuche 1:1 auffindbar sein>",',
    '                 "abschnittVermutet": "<z. B. 3.2.1 — wo in der Arbeit sie passt>" } ]',
    '}',
    '',
    '„stellen“ sind VERMUTUNGEN ohne Datei-Analyse — Vorschläge, wo/wofür die Quelle in der Arbeit',
    'verwendet werden kann (Referenzierungsvorschläge), so konkret wie möglich (Seiten nennen).',
  ];
  return _joinFiltered(lines);
}

/// Prompt „✦ Durchlauf" (Referenzierungsdurchlauf) für die ganze Quelle.
///
/// [positionType] = `Levels.positionType(srcId)` ('seite' | 'fundstelle'),
/// [links] = aufgelöste Links (`U.srcLinks`), [arbeitTitel] = Titel der
/// aktiven Arbeit (E9-Fix statt hartem EHDS-Text).
String gptPromptForSource(
  Source s, {
  required String positionType,
  required EffectiveSrcLinks links,
  required String arbeitTitel,
}) {
  final stellen = [
    for (final c in s.stellen)
      '- Fußnote ${c.footnote} (Abschnitt ${c.sectionId}): '
          '${c.claim.isNotEmpty ? 'Aussage: „${c.claim}“' : 'Fußnote: „${c.footnoteText}“'}'
          '${c.fundstelle.isNotEmpty ? ' · vermutet: ${c.fundstelle}' : ''}'
          '${c.suchHinweis.isNotEmpty ? ' · Suche: ${c.suchHinweis}' : ''}',
  ].join('\n');

  final lines = <String?>[
    'Du hilfst bei der Literaturprüfung der Arbeit „$arbeitTitel“. Prüfe die folgende Quelle und finde zu jeder Fußnote die Originalstelle:',
    '',
    'QUELLE: ${(s.author ?? '').isNotEmpty ? '${s.author} — ' : ''}${s.longTitle ?? s.title}'
        '${(s.container ?? '').isNotEmpty ? ' (${s.container})' : ''}'
        '${(s.doi ?? '').isNotEmpty ? ' · DOI: ${s.doi}' : ''}',
    (links.official ?? '').isNotEmpty ? 'OFFIZIELLER LINK: ${links.official}' : null,
    (links.file ?? '').isNotEmpty ? 'DATEI-LINK: ${links.file}' : null,
    '',
    'ZITIERSTELLEN (${s.stellen.length}):',
    stellen,
    '',
    'ANTWORTE NUR mit folgendem JSON (eine "stellen"-Zeile je Fußnote):',
    '{',
    '  "formatVersion": "1.0",',
    '  "sourceId": "${s.id}",',
    '  "generatedBy": "gpt",',
    '  "stellen": [{ "footnote": <Nr>, ${positionType == 'seite' ? '"seite": <Seitenzahl>' : '"fundstelle": "<Art/§/Abschnitt>"'}, "zitat": "<wörtliche Originalpassage>", "status": "bestaetigt"|"teilweise"|"nicht_gefunden", "kommentar": "<kurz>" }]',
    '}',
  ];
  return _joinFiltered(lines);
}
