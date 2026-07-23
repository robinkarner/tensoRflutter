/// 🖍 Markierungs-Prompt — Port von `marksPromptFor(sectionId)`
/// (views_studio.js:688-706), Texte wortwörtlich (inkl. der bewusst
/// ASCII-transliterierten Umlaute des Originals: „Schluesselstellen“,
/// „WOERTLICH“ …).
library;

import '../../../data/models/models.dart';
import '../../../domain/domain_context.dart';

String marksPromptFor(DomainContext ctx, String sectionId) {
  final info = ctx.unitIndex[sectionId];
  final unit = info?.unit;
  final paras = [
    for (final p in unit?.paragraphs ?? const <Paragraph>[])
      if (p.typeEnum != ParagraphType.figure && p.typeEnum != ParagraphType.table) p,
  ];
  final title =
      (unit?.isIntro ?? false) ? (info?.chapter.title ?? '') : (unit?.title ?? '');
  return [
    'Du markierst in „Thesis Studio" Schluesselstellen in Absaetzen einer wissenschaftlichen Arbeit.',
    'Fuer JEDEN Absatz unten: finde die wichtigsten Stellen und ordne sie Kategorien zu.',
    'KATEGORIEN: norm (Quelle/Rechtsnorm — nur ECHTE zitierte Quellen/Normen), frist (Frist/Datum),',
    'akteur (Akteur/Institution), tech (Technik/Standard), these (These/Wertung), luecke (Luecke/Problem),',
    'zahl (Zahl/Menge), abk (Abkuerzung — z. B. EHDS, ELGA, FHIR), schlag (Schlagwort — zentrale Fachbegriffe zum Schnell-Lesen).',
    'REGELN: "snippet" muss WOERTLICH und exakt so im Absatz vorkommen (1–6 Woerter, keine Umformulierung,',
    'keine [^n]-Marker). Pro Absatz 2–8 Markierungen, nur wirklich tragende Stellen. Keine Ueberlappungen.',
    '',
    'ANTWORTE NUR mit diesem JSON:',
    '{"sectionId": "$sectionId", "items": { "<absatz-id>": [ {"snippet": "<woertlich>", "kategorie": "<kategorie>"}, … ] }}',
    '',
    'ABSÄTZE (Abschnitt $sectionId · $title):',
    ...paras.map((p) =>
        '\n[${p.id}]\n${(p.typeEnum == ParagraphType.list ? p.items.join('\n· ') : p.text).replaceAll(RegExp(r'\[\^\d+\]'), '')}'),
  ].join('\n');
}
