#!/usr/bin/env node
/* ===== Golden-Fixture-Generator für die Domänen-Ports (Paket F-D) =====
 *
 * Lädt die ORIGINAL-JS-Module der Web-App (js/util.js, levels.js,
 * connections.js, mentions.js, stylecheck.js, texparse.js, editor.js) in
 * einer Node-vm-Sandbox (Shims für window/localStorage/location, fixierte
 * Uhr für deterministische Timestamps) und erzeugt JSON-Fixtures, gegen die
 * die Dart-Ports in test/domain/ verglichen werden:
 *
 *   texparse_thesis.json   TexParse.parse(thesis-source.tex, {registry})
 *   texparse_sensors.json  TexParse.parse(sensors-paper.tex)  (\cite-Modus)
 *   texparse_cases.json    synthetische Randfälle (Fehlerpfade, Level-Shift)
 *   sentences.json         U.splitSentences für 30 echte Absätze
 *   stylecheck.json        StyleCheck.analyzePara für 20 Absätze (DE + EN)
 *   mentions.json          Mentions.forPara für 10 Abschnitte
 *   connections.json       Connections.all() + forSection-Stichproben
 *   levels.json            Levels-Kaskade (leer + geseedet) und Export
 *   editor.json            Editor.reconstruct/fullDocument/lint/preview
 *
 * Aufruf:  node tools/golden_gen.mjs   (aus flutter_conversion/)
 */
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const HERE = path.dirname(fileURLToPath(import.meta.url));
const CONV = path.resolve(HERE, '..');            // flutter_conversion/
const ROOT = path.resolve(CONV, '..');            // thesoR/ (Original)
const OUT = path.join(CONV, 'test', 'domain', 'fixtures');
fs.mkdirSync(OUT, { recursive: true });

// Fixierte Uhr — Levels schreibt ts: Date.now(); der Dart-Test injiziert
// denselben Wert.
const FIXED_NOW = 1753222000000;

/* ---------- Sandbox mit Browser-Shims ---------- */
function makeSandbox() {
  const storage = new Map();
  const sandbox = {
    console,
    localStorage: {
      getItem: (k) => (storage.has(k) ? storage.get(k) : null),
      setItem: (k, v) => storage.set(k, String(v)),
      removeItem: (k) => storage.delete(k),
    },
    location: { protocol: 'https:', hash: '' },
    navigator: {},
    setTimeout, clearTimeout,
    __storageDump: () => Object.fromEntries(storage),
  };
  class FixedDate extends Date {
    constructor(...a) { a.length ? super(...a) : super(FIXED_NOW); }
    static now() { return FIXED_NOW; }
  }
  sandbox.Date = FixedDate;
  sandbox.window = sandbox;
  sandbox.globalThis = sandbox;
  vm.createContext(sandbox);
  return sandbox;
}

function load(sandbox, file) {
  vm.runInContext(fs.readFileSync(file, 'utf8'), sandbox, { filename: file });
}

const sb = makeSandbox();
for (const f of ['data/data_thesis.js', 'data/data_sections.js', 'data/data_sources.js', 'data/data_meta.js', 'data/data_figures.js']) {
  load(sb, path.join(ROOT, 'js', f));
}
for (const f of ['util.js', 'levels.js', 'connections.js', 'mentions.js', 'stylecheck.js', 'texparse.js', 'editor.js']) {
  load(sb, path.join(ROOT, 'js', f));
}
const run = (code) => vm.runInContext(code, sb);
const write = (name, data) => {
  fs.writeFileSync(path.join(OUT, name), JSON.stringify(data, null, 1) + '\n');
  console.log(`✓ ${name}`);
};

/* ---------- 1./2. TexParse: echte Arbeiten ---------- */
// Registry der eingebauten Arbeit: RegExp-Literale → Regex-QUELLSTRINGS
// (dasselbe Format wie registry.json aus dem Gesamt-Prompt; TexParse
// kompiliert sie mit new RegExp(a, 'i')).
const registryRaw = require(path.join(ROOT, 'tools', 'source-registry.js'));
const registry = registryRaw.map((e) => ({
  ...e,
  aliases: (e.aliases || []).map((a) => (a instanceof RegExp ? a.source : String(a))),
}));
const thesisTex = fs.readFileSync(path.join(ROOT, 'data', 'thesis-source.tex'), 'utf8');
const sensorsTex = fs.readFileSync(path.join(ROOT, 'data', 'sensors-paper.tex'), 'utf8');

sb.__registry = registry;
sb.__thesisTex = thesisTex;
sb.__sensorsTex = sensorsTex;
const thesisParse = run('TexParse.parse(__thesisTex, { registry: __registry })');
const sensorsParse = run('TexParse.parse(__sensorsTex)');
console.log(`  thesis: fussnoten=${thesisParse.stats.fussnoten} quellen=${thesisParse.stats.quellen} abschnitte=${thesisParse.stats.abschnitte}`);
console.log(`  sensors: fussnoten=${sensorsParse.stats.fussnoten} quellen=${sensorsParse.stats.quellen}`);
write('texparse_thesis.json', { registry, result: thesisParse });
write('texparse_sensors.json', { result: sensorsParse });

/* ---------- 3. TexParse: synthetische Randfälle ---------- */
const cases = [
  { name: 'leer', tex: '' },
  { name: 'zu-kurz', tex: '\\section{Hi} x' },
  { name: 'pdf-statt-tex', tex: '%PDF-1.7 xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' },
  {
    name: 'keine-gliederung',
    tex: '\\begin{document}\nNur Text ohne jede Überschrift, aber lang genug für die Mindestlänge.\n\\end{document}',
  },
  {
    name: 'section-shift-sticky',
    tex: ['\\begin{document}', '\\section{Alpha}', 'Text A.', '\\subsubsection{Tief}', 'Text T.',
      '\\subsubsection{Tief2}', 'Text T2.', '\\subsection{Beta}', 'Text B.', '\\end{document}'].join('\n'),
  },
  {
    name: 'mixed-features',
    tex: ['% Kommentarzeile', '\\documentclass{article}', '\\usepackage{tikz}', '\\usepackage{siunitx}',
      '\\title{Misch-Test}', '\\author{Tester}', '\\begin{document}', '\\maketitle',
      '\\chapter{Eins}', 'Intro mit Fußnote.\\footnote{Vgl. Quelle-X, S.~3.} Und Mathe $x^2$ dazu.',
      '\\paragraph{Absatzkopf.} Es folgt \\enquote{zitiert} und \\textbf{fett}~mit \\S~5 und 100\\,\\%.',
      '\\section{Liste}', '\\begin{itemize}\\item Erstens\\item Zweitens\\end{itemize}',
      '\\begin{description}\\item[Begriff] Erklärung\\end{description}',
      '\\begin{figure}\\includegraphics{x}\\caption{Eine Grafik}\\end{figure}',
      '\\begin{verbatim}code %here\\end{verbatim}',
      'Akzente: Gr\\"o\\ss e, caf\\\'e, gar\\c{c}on. \\unknowncmd{bleibt}.',
      '\\section*{Literatur}', 'Weg damit.', '\\end{document}'].join('\n'),
  },
  {
    name: 'unbalancierte-fussnote',
    tex: ['\\begin{document}', '\\section{S}', 'Text mit kaputter Fußnote.\\footnote{offen bleibt das',
      'und noch mehr Text damit die Länge reicht.', '\\end{document}'].join('\n'),
  },
];
sb.__cases = cases;
const caseResults = run('__cases.map(c => ({ name: c.name, tex: c.tex, result: TexParse.parse(c.tex) }))');
write('texparse_cases.json', caseResults);

/* ---------- Auswahl echter Absätze ---------- */
const collectParas = run(`(() => {
  const out = [];
  for (const id of orderedUnits()) {
    const u = UNIT_INDEX[id].unit;
    for (const p of u.paragraphs || []) if (p.type === 'text' && p.text) out.push(p.text);
  }
  return out;
})()`);
const pick = (arr, n, offset = 0) => {
  const step = Math.max(1, Math.floor(arr.length / n));
  const out = [];
  for (let i = offset; i < arr.length && out.length < n; i += step) out.push(arr[i]);
  return out;
};

/* ---------- 4. splitSentences: 30 echte Absätze ---------- */
const sentTexts = pick(collectParas, 30);
sb.__sentTexts = sentTexts;
write('sentences.json', run('__sentTexts.map(t => ({ text: t, sents: U.splitSentences(t) }))'));

/* ---------- 5. StyleCheck: 20 Absätze (10 DE + 10 EN) ---------- */
const enParas = [];
for (const ch of sensorsParse.thesis.chapters) {
  (function rec(units) {
    for (const u of units) {
      for (const p of u.paragraphs || []) if (p.type === 'text' && p.text.length > 120) enParas.push(p.text);
      if (u.children) rec(u.children);
    }
  })(ch.sections);
}
// Echte Absätze sind (erfreulich) unauffällig — synthetische Absätze decken
// deshalb gezielt Floskeln, Vage-Deckelung, Konnektor-Ketten und
// „Einordnung ohne Beleg“ ab.
const styleSynth = [
  'AI plays a crucial role in modern healthcare. Furthermore, it is important to note that leveraging data holds great promise. Moreover, various stakeholders delve into numerous aspects seamlessly.',
  'Datenschutz spielt eine zentrale Rolle in der heutigen Zeit. Darüber hinaus ist Interoperabilität von großer Bedeutung. Zudem gewinnt der EHDS zunehmend an Bedeutung.',
  'Interoperability is essential for exchange. It is broadly relevant overall.',
  'Die Ergebnisse zeigen 42 % Verbesserung (Fig. 3). Das System ist wichtig für die Praxis, wie Studien (2021) belegen.[^1]',
  'Not only does the framework improve outcomes but also reduces cost. In recent years, ever-growing datasets underscore the need for comprehensive analysis.',
  'Zusammenfassend lässt sich festhalten, dass zahlreiche vielfältige und verschiedenste Ansätze grundsätzlich denkbar sind. Folglich bleibt das Thema wichtig. Somit ist der Ausblick zentral.',
];
const styleTexts = [...pick(collectParas, 8, 3), ...pick(enParas, 6), ...styleSynth];
sb.__styleTexts = styleTexts;
write('stylecheck.json', run('__styleTexts.map(t => ({ text: t, flagged: StyleCheck.analyzePara(t) }))'));

/* ---------- 6. Mentions: 10 Abschnitte ---------- */
const mentionSections = run(`(() => {
  const withHits = [];
  for (const id of orderedUnits()) {
    const u = UNIT_INDEX[id].unit;
    let hits = 0;
    for (const p of u.paragraphs || []) hits += Mentions.forPara(id, p).length;
    if (hits) withHits.push(id);
  }
  const chosen = withHits.slice(0, 10);
  for (const id of orderedUnits()) {
    if (chosen.length >= 10) break;
    if (!chosen.includes(id)) chosen.push(id);
  }
  return chosen.map(id => ({
    sectionId: id,
    paragraphs: (UNIT_INDEX[id].unit.paragraphs || []).map(p => ({ id: p.id, mentions: Mentions.forPara(id, p) })),
  }));
})()`);
console.log(`  mentions: ${mentionSections.reduce((a, s) => a + s.paragraphs.reduce((x, p) => x + p.mentions.length, 0), 0)} Treffer in 10 Abschnitten`);
// Zusätzlich: synthetische detect-Fälle auf Basis ECHTER Quellen-Muster —
// die deutsche Arbeit enthält kaum Autor-Jahr-Klammern, deshalb hier
// gezielte Abdeckung von Fenster, Nähe-Unterdrückung, Mehrdeutigkeit.
const detectCases = run(`(() => {
  const pats = Mentions._patterns().slice(0, 6);
  const texts = [];
  if (pats.length >= 2) {
    const a = pats[0], b = pats[1];
    const fnOfSrc = (srcId) => { for (const k of Object.keys(FN_INDEX)) { if ((FN_INDEX[k].sources || []).includes(srcId)) return k; } return null; };
    const fnA = fnOfSrc(a.srcId);
    texts.push('Wie ' + a.names[0] + ' (' + a.year + ') zeigt, ist das Thema relevant.');
    texts.push('Einleitung ohne Namen (' + a.year + ') in Klammern.');
    texts.push(a.names[0] + ' und Kollegen (' + a.year + ') sowie ' + b.names[0] + ' (' + b.year + ') im selben Satz.');
    if (fnA) {
      texts.push('Direkt belegt: ' + a.names[0] + ' (' + a.year + ') stellt fest.[^' + fnA + '] Danach mehr Text.');
      texts.push('Vorher belegt.[^' + fnA + '] Wie ' + a.names[0] + ' (' + a.year + ') feststellt, geht es weiter.');
    }
    texts.push('Jahr passt nicht: ' + a.names[0] + ' (1875) ist zu alt.');
  }
  return texts.map(t => ({ text: t, hits: Mentions.detect(t, []) }));
})()`);
write('mentions.json', { sections: mentionSections, detect: detectCases });

/* ---------- 7. Connections: alle Kanten + Stichproben ---------- */
const connAll = run('Connections.all()');
const sampleSecs = run('[orderedUnits()[0], "3.2", "6.0"].filter(id => UNIT_INDEX[id])');
const forSection = {};
for (const id of sampleSecs) {
  sb.__sec = id;
  const r = run('Connections.forSection(__sec)');
  forSection[id] = { out: r.out.map((c) => c.id), in: r.in.map((c) => c.id) };
}
console.log(`  connections: ${connAll.length} Kanten`);
write('connections.json', { edges: connAll, forSection });

/* ---------- 8. Levels: Kaskade leer + geseedet, Export ---------- */
// Leerer Store: Level je Fußnote (KI-Beleg → 1, sonst 0) + Zählung.
const emptyLevels = run(`(() => {
  const per = {};
  for (const n of Levels.allNums()) per[n] = Levels.info(n).level;
  return { per, counts: Levels.countsFor(Levels.allNums()) };
})()`);
// Seed-Szenario: direkte Saves + Resolutions/Annotationen; srcIds dynamisch
// aus den echten Fußnoten (Dart wiederholt exakt dieselben Schritte).
const seedPlan = run(`(() => {
  const src50 = (FN_INDEX[50].sources || [])[0] || null;
  const src60 = (FN_INDEX[60].sources || [])[0] || null;
  const saves = [
    [17, { zitat: 'Der Wortlaut der Passage.', seite: 14, kommentar: 'leicht gekürzt', farbe: 'blau', herkunft: 'manuell' }],
    [23, { farbe: 'gelb' }],
    [30, { zitat: 'Nur ein Zitat ohne Position.' }],
    [40, { fundstelle: 'Art 5 Abs 1' }],
    [45, { kommentar: '' }],
  ];
  const returns = saves.map(([n, d]) => Levels.save(n, d));
  if (src50) U.storeSet('resolutions', { [src50]: { generatedBy: 'gpt-run-1', stellen: [
    { footnote: 50, status: 'bestaetigt', seite: 'S. 3', zitat: 'Resolution-Zitat' },
  ] } });
  if (src60) U.storeSet('annotations', { [src60]: [ { footnote: 60, zitat: 'Annotations-Zitat', seite: 7 } ] });
  const infos = {};
  for (const n of [17, 23, 30, 40, 45, 50, 60, 99]) infos[n] = Levels.info(n);
  return { src50, src60, saves, returns, infos,
    belegLevels: U.storeGet('belegLevels', {}),
    counts: Levels.countsFor(Levels.allNums()),
    exportState: Levels.exportState(),
    farben: { auto50: src50 ? Levels.autoFarbe(src50, 50) : null, for17: null } };
})()`);
write('levels.json', { empty: emptyLevels, seeded: seedPlan });
// Store zurücksetzen, damit Editor/weitere Fixtures unbeeinflusst bleiben
run(`U.storeSet('belegLevels', {}); U.storeSet('resolutions', {}); U.storeSet('annotations', {});`);

/* ---------- 9. Editor: reconstruct / fullDocument / lint / preview ---------- */
// Preview-HTML → normalisierte Blockform (die Dart-Seite rendert ihr
// Struktur-Modell in exakt dieselbe Form; Fett/Kursiv-Nesting wird bewusst
// NICHT verglichen — das prüft ein Dart-Unit-Test).
function normalizePreview(html) {
  let s = html;
  s = s.replace(/<sup class="pv-fn" title="([^"]*)">(\d+)<\/sup>/g, (_, t, n) => '\u27e6fn' + n + '|' + t + '\u27e7');
  s = s.replace(/<h2>/g, '\nh2|').replace(/<h3>/g, '\nh3|').replace(/<h4>/g, '\nh4|');
  s = s.replace(/<p class="lesen-p ff">/g, '\np|');
  s = s.replace(/<ul class="lesen-list">/g, '\nul|').replace(/<ol class="lesen-list">/g, '\nol|');
  s = s.replace(/<\/ul>|<\/ol>/g, '\n/list|');
  s = s.replace(/<li>/g, '\nli|');
  s = s.replace(/<div class="fig-missing small"><span class="eyebrow">Platzhalter<\/span>/g, '\nph|');
  s = s.replace(/<\/(h2|h3|h4|p|li|div)>/g, '');
  s = s.replace(/<\/?(b|em)>/g, '');
  s = s.replace(/&thinsp;/g, '\u2009').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, '&');
  return s.split('\n').map((l) => l.trimEnd()).filter(Boolean);
}
const editorFix = run(`(() => {
  const rec = {};
  for (const id of orderedUnits()) rec[id] = Editor.reconstruct(id);
  const lintCases = [
    Editor.reconstruct(orderedUnits()[0]),
    '\\\\section{Ok}\\n\\nText mit \\\\textbf{fett} und \\\\enquote{Zitat}.',
    '\\\\section{Kaputt} \\\\unknown{x} \\\\begin{tabular}a\\\\end{tabular}',
    'Offene Klammer { hier\\nund } zu } viel',
    'Mathe $x^2$ inline\\n\\\\begin{itemize}\\n\\\\item A\\n\\\\end{itemize}\\n\\\\begin{itemize}',
  ];
  return {
    reconstruct: rec,
    fullDocument: Editor.fullDocument(),
    lint: lintCases.map(t => ({ tex: t, ...Editor.lint(t) })),
    previewInputs: null,
  };
})()`);
// Preview-Stichproben: Intro-Abschnitt (Kapitel-Kopf), einer mit Liste,
// einer mit Figur/Tabelle (%-Platzhalter) + ein synthetischer Misch-Fall.
const previewIds = run(`(() => {
  const ids = orderedUnits();
  const withList = ids.find(id => (UNIT_INDEX[id].unit.paragraphs || []).some(p => p.type === 'list'));
  const withFig = ids.find(id => (UNIT_INDEX[id].unit.paragraphs || []).some(p => p.type === 'figure' || p.type === 'table'));
  return [ids[0], withList, withFig].filter(Boolean);
})()`);
const synth = '\\section{Misch}\n\nA \\textbf{fett \\textit{kursiv}} B\\footnote{Fuß \\textbf{note}} -- und \\enquote{Zitat}, \\S 5, 10\\,\\% \\dots\n\n% Platzhalterzeile\n\n\\begin{enumerate}\n\\item Eins\n\\item Zwei\n\\end{enumerate}\n';
sb.__previewIds = previewIds;
sb.__synth = synth;
const previews = run(`__previewIds.map(id => ({ id, html: Editor.preview(Editor.reconstruct(id)) }))
  .concat([{ id: '_synth', tex: __synth, html: Editor.preview(__synth) }])`);
editorFix.preview = previews.map((p) => ({
  id: p.id,
  tex: p.tex ?? null,
  blocks: normalizePreview(p.html),
}));
delete editorFix.previewInputs;
write('editor.json', editorFix);

console.log('Fertig: ' + OUT);
