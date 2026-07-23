# Inventar-Dossier 06 — Wissen-Welt: Analyse-Views, Erklärbuch-Notebook, Charts

Dateien: `js/views_analyse.js` (496 Z.), `js/notebook.js` (697 Z.), `js/charts.js` (168 Z.)
Kontext-Dateien (nur referenziert): `js/views_studio.js` (dock*-Funktionen), `js/util.js` (U.*, UNIT_INDEX), `js/figures.js` (figureCard/tableCard), `js/app.js` (Router), `css/app.css`, `css/theme.css`, `js/data/data_meta.js` (DATA_META).

---

## 1. Zweck & Rolle

### js/views_analyse.js
Rendert die komplette **„Wissen“-Welt** (Route `#/analyse[/<tab>[/<arg>]]`, views_analyse.js:19) — der „Cross-Projekt-Informationsspeicher“ neben dem Studio, mit eigenem Farbton (`--wissen`, Blau statt Terracotta). Enthält acht Tabs in drei beschrifteten Clustern: **Schnellverständnis** (📓 Erklärbuch, 🔬 Analysemodus, 🌐 Übersetzung & Instanzen), **Zusammenhänge & Thema** (Überblick, Kapitel, Connections, Kennzahlen), **Bewertung** (⚖ Würdigung). Der Erklärbuch-Tab (views_analyse.js:57) ist das Frontend der Notebook-Plattform (notebook.js) inkl. Split-Editor mit Live-Vorschau. Der Analysemodus (views_analyse.js:123) zeigt die Arbeit Kapitel für Kapitel als Original-Text mit Abbildungen/Tabellen und einer wählbaren Erklärungs-„Linse“ direkt unter jedem Absatz. Überblick/Kapitel/Connections/Würdigung/Kennzahlen visualisieren die KI-Voranalyse aus `DATA_META` (Executive Summary, roter Faden, Fristen-Timeline, Kapitel-Kurzfassungen, Fazit-Herleitungsgraph, Standards-Bewertung, Statistik-Charts).

### js/notebook.js
Die **Erklärbuch-Engine**: EIN Markdown-Dokument als oberste Ebene, alles Weitere als Fenced-Blöcke eingebettet (notebook.js:1–21). Enthält (a) einen eigenen **LaTeX-Mathe-Renderer** `MathRender` (Subset, kein KaTeX; notebook.js:27–151), (b) den Block-**Parser** (Markdown + ``` -Fences + `$$…$$`; notebook.js:171), (c) eine eigene **SVG-Diagramm-Engine** `Notebook.chart` (bar/barh/line/area/scatter/pie/donut; notebook.js:268), (d) Tabellen-Rendering aus CSV/TSV/Pipe/Semikolon (notebook.js:385), (e) **js-Rechenzellen** (sofort via `new Function`, notebook.js:458) und **Python-Zellen** (Pyodide v0.26.4 lazy vom CDN, notebook.js:487–567), (f) das **Datenpaket** `Notebook.dataset()` mit den echten Zahlen der aktiven Arbeit (notebook.js:414), (g) das **Starter-Buch** (live rechnendes Beispieldokument, notebook.js:570) und (h) den **🤖 Generier-Prompt** für die KI-Erzeugung eines kompletten Buchs (notebook.js:653). Persistenz: localStorage-Key `notebook` (projektbezogen).

### js/charts.js
Vier wiederverwendbare, **theme-aware SVG/HTML-Visualisierungen ohne Fremdbibliotheken** (charts.js:1): `barH` (horizontale Balken, eine Serie), `kapitelFluss` (6 Kapitel-Knoten mit Nachbar-Pfeilen + Bogen-Kanten für Fernbezüge), `fazitGraph` (bipartiter Graph: Befunde links ↔ Herleitungs-Abschnitte rechts, mit Hover-Hervorhebung), `timeline` (vertikale HTML-Timeline mit EU/AT-Kategorie-Farben). Alle Farben sind CSS-Variablen (`var(--…)`) direkt in SVG-`style`-Attributen — dadurch folgen die Grafiken automatisch Hell/Dunkel-Theme. Tooltips über gemeinsames `data-tip`-Attribut + `Charts._wireTips` → `U.showTip` (charts.js:162).

---

## 2. Öffentliche API

### views_analyse.js exportiert (implizit window-Scope, kein Modul-System)
| Symbol | Signatur | Zweck | Nutzer |
|---|---|---|---|
| `TYP_CHIP` | `{positiv:'ok', luecke:'bad', spannung:'warn', ausblick:'accent', staerke:'ok', schwaeche:'bad', hinweis:'warn'}` (views_analyse.js:10) | Befund-Typ → Chip-CSS-Klasse | intern (`typChip`) |
| `TYP_LABEL` | `{positiv:'✔ erfüllt', luecke:'▲ Lücke', spannung:'◆ Spannung', ausblick:'➜ Ausblick', staerke:'✔ Stärke', schwaeche:'▲ Schwäche', hinweis:'◆ Hinweis'}` (views_analyse.js:11) | Befund-Typ → Anzeige-Label | intern |
| `typChip(t)` | `→ HTML-String '<span class="chip {cls}" style="flex:none">{label}</span>'` (views_analyse.js:12) | Chip-Renderer | Überblick, Fazit, Würdigung, showFinding |
| `renderAnalyse(root, tab, arg)` | root: Element, tab: string \| undefined (Default `'ueberblick'`), arg: string (Kapitel-Nr. bzw. Instanz-Modus) (views_analyse.js:19) | Haupteinstieg der Wissen-Seite | Router `app.js:232` (`#/analyse/<tab>/<arg>`), Selbst-Re-Render (views_analyse.js:88,114,147), `enhance.js:90` |
| `analyseBuch/analyseModus/analyseInstanzen/analyseUeberblick/analyseKapitel/analyseFazit/analyseWuerdigung/analyseKennzahlen` | `(root[, arg])` | Tab-Renderer | nur `renderAnalyse` |
| `nbEditModal(src, root)` (views_analyse.js:93) | öffnet Editor-Modal | analyseBuch |
| `amodSection(u, ch, lens, count)` (views_analyse.js:177) | rendert einen Abschnitt im Analysemodus | analyseModus |
| `showFinding(id)` (views_analyse.js:483) | Befund-Detail-Modal | analyseKapitel, analyseFazit, fazitGraph-Callback |

### notebook.js exportiert
| Symbol | Signatur/Felder | Zweck | Nutzer |
|---|---|---|---|
| `MathRender` | `.block(tex)→html`, `.inline(tex)→html`, `.GREEK`, `.SYM`, `.BIGOPS`, `._parse(tex, display)` (notebook.js:27–151) | LaTeX-Mathe-Subset → HTML | Notebook (math-Block, `$…$`, cell-api `math()`) |
| `Notebook.PALETTE` | `['--accent','--cat-norm','--cat-frist','--cat-akteur','--cat-zahl','--cat-luecke','--cat-these','--cat-abk']` (notebook.js:160) | Datenfarben-Reihenfolge | `Notebook.color` |
| `Notebook.color(i)` | Token via `getComputedStyle(document.documentElement).getPropertyValue(...)` auflösen, Fallback `'#b4552d'` (notebook.js:161) | Serie i → konkreter Hex-Wert (SVG kann kein `var()` in fill-Attributen der pie-Segmente… hier bewusst aufgelöst) | chart() |
| `Notebook.get()` / `Notebook.set(md)` | localStorage `'notebook'`; `set` speichert `null` wenn leer/blank (notebook.js:167–168) | Eigenes Buch laden/speichern | analyseBuch, nbEditModal, enhance.js:91–92 |
| `Notebook.parse(src)` | `→ [{kind:'md',body} \| {kind:'code',lang,meta,body}]` (notebook.js:171) | Block-Zerlegung | render |
| `Notebook.render(host, src)` | rendert alle Blöcke in host, fängt Fehler je Block (notebook.js:215) | Haupt-Renderer | analyseBuch, nbEditModal (Live-Preview) |
| `Notebook.chart(spec)` | `→ Element` (notebook.js:268) | SVG-Diagramm aus JSON-Spec | chart-Block, js-/py-Zellen |
| `Notebook.tableBlock(body, meta)` / `Notebook.tableFrom(rows, opts)` | (notebook.js:385/392) | Tabellen | table-Block, Zellen-API |
| `Notebook.findFigure(key)` | id → figNum → 1-basierter Index (notebook.js:408) | Abbildungssuche | figure-Block, Zellen-API |
| `Notebook.dataset()` | echtes Datenpaket der Arbeit (notebook.js:414, Form s. §7) | Grundlage aller Rechenzellen + Prompt | jsCell, pyCell, prompt |
| `Notebook.jsCell(b)` / `Notebook.pyCell(b)` | `→ Element` (notebook.js:458/528) | Rechenzellen | _renderBlock |
| `Notebook.ensurePy(statusCb)` | `→ Promise<pyodide>`; `PY_VERSION='v0.26.4'` (notebook.js:488–507) | Pyodide-Lazy-Load | pyCell |
| `Notebook.starter()` | `→ Markdown-String` (notebook.js:570) | Starter-Buch | analyseBuch (Fallback) |
| `Notebook.prompt()` | `→ Prompt-String` (notebook.js:653) | 🤖 KI-Generierung | enhance.js (GPT-Magic „Erklärbuch“) |

### charts.js exportiert
| Symbol | Signatur | Nutzer |
|---|---|---|
| `Charts.barH(items, {valueLabel=v=>String(v), height=null})` — items: `[{label, value, tip?, color?}]` (charts.js:6) | analyseKennzahlen (3×), Notebook.chart type 'barh', views_projekt.js |
| `Charts.kapitelFluss(chapters, edges, {onClick})` — chapters: `[{num,title,tip}]`, edges: `[{from,to,label}]` (charts.js:30) | analyseFazit |
| `Charts.fazitGraph(findings, {onFinding, title=''})` (charts.js:68) | analyseFazit, analyseKapitel |
| `Charts.timeline(items)` — items: `[{datum,datumLabel?,label,kategorie:'at'\|'eu',status}]` (charts.js:142) | analyseUeberblick |
| `Charts._wireTips(root)` (charts.js:162) | intern + Notebook.chart (`Charts._wireTips?.(wrap)`, notebook.js:303,380) |

### Konsumierte Globals (Abhängigkeiten nach außen)
- `U.el, U.esc, U.md, U.richText, U.modal, U.closeModal, U.download, U.fmtDate, U.storeGet, U.storeSet, U.srcShort, U.showTip, U.hideTip` (util.js).
- `window.DATA_THESIS` (chapters/sections/paragraphs/meta), `window.DATA_META` (gesamt/kapitel/fazit/analyse/stats), `window.DATA_SOURCES`, `window.DATA_FIGURES`, `window.PROJECT_ERKLAERBUCH` (von projects.js:57,162 gesetzt aus `DATA_META.erklaerbuch` bzw. `rec.generated.erklaerbuch`).
- Aus views_studio.js: `dockDefs()` (Instanz-Definitionen; DOCK_DEFAULTS views_studio.js:2127: `uebersetzung '🌐 Übersetzung'`, `erklaerung '✎ Erklärung'`, `analyse '✦ Analyse'` + Projekt-Instanzen; `special`-Einträge werden gefiltert), `dockGet(mode, paraId)` (gespeicherte Instanz-Texte aus localStorage `paraDock`), `dockAuto(mode, sectionId, p)` (Auto-Vorbefüllung aus KI-Voranalyse, views_studio.js:2184), `dockLabel(id)`, `stripFigMarker(text)` (views_studio.js:319), `Studio.genPara` (indirekt via dockAuto).
- Aus util.js: `UNIT_INDEX` (sectionId → {unit, chapter}), `FIG_BY_PARA`, `TAB_BY_PARA`, `orderedUnits()`, `KIND_LABELS` (util.js:926).
- Aus figures.js: `figureCard(fig, opts)` (figures.js:58, inkl. Lightbox + „Bild einfügen“-Upload bei fehlender Datei), `tableCard(tab)` (figures.js:94).
- Aus editor.js: `Editor.preview(tex)`, `Editor.lint(tex)` (latex-Block — DERSELBE Interpreter wie die Arbeit).
- Aus levels.js/connections.js: `Levels.countsFor(Levels.allNums())`, `Connections.all()` (nur in `Notebook.dataset`).

---

## 3. State & Persistenz

Alle Keys laufen über `U.storeGet/storeSet` (util.js:206–211): tatsächlicher localStorage-Key = `'ehds.' + (projektbezogen ? projektId + '.' : '') + key`, Wert JSON-serialisiert. `notebook`, `paraDock`, `dockBySection`, `instDefs`… sind in `U.PROJECT_KEYS` (util.js:200) → **pro Arbeit getrennt**; UI-Keys wie `wissenLens` sind global.

| Key (logisch) | projektbezogen | Form / Beispiel | gelesen | geschrieben |
|---|---|---|---|---|
| `notebook` | ja | Markdown-String des eigenen Erklärbuchs, z. B. `"# Erklärbuch — …\n\n```js auto\nchart({…})\n```"` — oder `null` (= kein eigenes Buch) | `Notebook.get()` (notebook.js:167) bei jedem Buch-Render; `enhance.js:91` (Status-Chip) | `Notebook.set(ta.value)` beim Speichern im Editor (views_analyse.js:110); `Notebook.set(null)` beim Reset (views_analyse.js:85) |
| `wissenLens` | **nein** (global) | String, Default `'erklaerung'` — id einer Text-Instanz, z. B. `"analyse"` | analyseModus (views_analyse.js:129) | Klick auf Linsen-Button (views_analyse.js:143) |
| `paraDock` (fremd, views_studio.js:2167) | ja | `{ "<mode>": { "<paraId>": "<markdown>" } }`, z. B. `{"erklaerung":{"2.1-p1":"Der Absatz erklärt …"}}` | `dockGet` in analyseModus/analyseInstanzen | nur im Studio |
| `instDefs` (fremd, views_studio.js:2149) | nein | eigene Instanz-Definitionen `[{id,label,color,desc}]` | via `dockDefs()` | nur im Studio |

**In-Memory:** `Notebook._py` (Pyodide-Instanz, einmalig), `Notebook._pyLoading` (Promise-Latch, notebook.js:165); `U.tip` (Singleton-Tooltip-DOM). Die Views selbst sind zustandslos — jeder Tabwechsel = kompletter Re-Render über den Hash-Router; Scroll-Position wird nur beim Linsen-Wechsel manuell restauriert (views_analyse.js:145–148).

---

## 4. UI-Struktur & Layout

### 4.1 Seitenrahmen (alle Tabs, views_analyse.js:19–50)
```
#app.wissen-page
├─ .page-head.wissen-head
│  ├─ h1 "Wissen" + span.chip.wissen-chip "✦ Cross-Projekt-Informationsspeicher" (vertical-align:middle)
│  └─ p.page-sub  (Text s. §5)
├─ .a-tabgroups                       ← flex, wrap, gap 8px 22px, align-items flex-end,
│  │                                     border-bottom 1px var(--border), margin-bottom 18px (app.css:803)
│  ├─ .a-tabgroup (flex column, gap 2px)
│  │  ├─ span.a-tabgroup-l  "SCHNELLVERSTÄNDNIS" (9.5px, uppercase, letter-spacing .1em,
│  │  │                       Farbe var(--wissen-ink) auf .wissen-page; app.css:806–807)
│  │  └─ .a-tabs (flex, gap 2px, ohne eigene border)   ← <a href="#/analyse/<k>"> je Tab;
│  │        a: 600 13.5px var(--font-ui), padding 9px 13px 11px, border-bottom 2px transparent;
│  │        a.active: color var(--wissen-ink), border-color var(--wissen), background var(--wissen-soft) (app.css:797–799, 1241)
│  ├─ .a-tabgroup "ZUSAMMENHÄNGE & THEMA" …
│  └─ .a-tabgroup "BEWERTUNG" …
└─ <div> (body des aktiven Tabs)
```
`.wissen-page .card { border-top: 2px solid var(--wissen-line); }` — **jede Card in der Wissen-Welt hat eine blaue Oberkante** (app.css:1243). `.wissen-page .eyebrow` ist `var(--wissen-ink)` (app.css:1242).

### 4.2 📓 Erklärbuch (analyseBuch, views_analyse.js:57–90)
```
.row.nb-bar (margin-bottom 12px)
├─ button#nbEdit  .btn.btn-sm  "✎ Bearbeiten"
├─ button#nbExport .btn.btn-sm "⭳ Export"   (title "Aktuelles Erklärbuch als .md sichern")
├─ [wenn eigenes Buch]  button#nbReset "↺ Eingebautes Buch" | "↺ Starter"
│  [sonst wenn builtin] span.chip.ki.mini "✦ eingebautes Buch"
│  [sonst]              span.chip.mini "Starter-Buch"
├─ span style="flex:1"                     ← Spacer
└─ a.btn.btn-ghost.btn-sm href="docs/ERKLAERBUCH.md" target=_blank  "Referenz ↗"
.nb-doc                                    ← max-width 900px, margin-inline auto; Kinder margin-bottom 14px (app.css:1425–1426)
└─ (Notebook.render-Ausgabe, Blöcke s. 4.6)
```

### 4.3 Editor-Modal (nbEditModal, views_analyse.js:93–116)
`U.modal('✎ Erklärbuch bearbeiten', …)`; das Modal wird per CSS auf `width: min(1180px, 96vw)` verbreitert (`.modal:has(.nb-edit-grid)`, app.css:1484).
```
.nb-edit-grid                 ← grid 1fr 1fr, gap 12px, min-height 420px; @media ≤860px: 1 Spalte (app.css:1480–1483)
├─ textarea#nbSrc (spellcheck=false; min-height 420px, mono 12.5px/1.65, resize vertical)
└─ .nb-edit-prev.nb-doc       ← border, radius, padding 12px 16px, overflow-y auto, max-height 60vh
.row (margin-top 10px)
├─ button#nbSave .btn.btn-sm.btn-primary "Speichern"
└─ span.small.mut "Vorschau aktualisiert beim Tippen · Bausteine: docs/ERKLAERBUCH.md"
```
Live-Vorschau: `input`-Event mit **350 ms-Debounce** → `Notebook.render(prev, ta.value)` (views_analyse.js:107).

### 4.4 🔬 Analysemodus (analyseModus/amodSection, views_analyse.js:123–218)
```
.row (margin-bottom 10px)                  ← Kapitel-Picker: a.btn.btn-sm je Kapitel "N Titel",
│                                             aktives Kapitel .btn-primary, href #/analyse/modus/<n>
.row.amod-lens (margin-bottom 14px)
├─ span.small.mut "Erklärung durch:"
├─ button.btn.btn-sm[.on] je Text-Instanz (data-lens=<id>); .on = var(--wissen-soft)-Hintergrund (app.css:1255)
├─ span.small.mut.amod-meter               ← nachträglich befüllt: "· 12 von 40 Absätzen erklärt" (views_analyse.js:174)
├─ span flex:1
└─ span.small.mut "Inhalte entstehen über den GPT-Knopf oben in der Kopfleiste (global) — sonst zeigt die KI-Voranalyse"
section.card.amod-head (margin-bottom 14px)        ← nur wenn DATA_META.kapitel[n] existiert
├─ .eyebrow "Kapitel N — worum es geht"
├─ U.md(kurzfassung)
├─ .amod-kern (grid, gap 6px)  → .amod-k "✦ <Kernaussage>" (13px, var(--ink-2))
└─ .row (gap 6px) → span.chip.warn <datum> + span.small <was>   je Frist
.amod-doc (max-width 880px, app.css:1246)
└─ section.card.amod-sec (margin-bottom 14px)  je Abschnitt mit Absätzen (rekursiv über children, views_analyse.js:166)
   ├─ h3 (flex, gap 10px, baseline)
   │  ├─ span.mono 12px var(--wissen-ink):  "2.1" bzw. "Kapitel 2" (bei isIntro)
   │  ├─ Abschnittstitel (bei isIntro Kapiteltitel)
   │  ├─ span flex:1
   │  └─ a.btn.btn-sm "⌖ Studio" → #/studio/<id>/pruefen
   └─ je Absatz (Reihenfolge!):
      • p.type==='figure' → figureCard(fig)  ODER .fig-missing (eyebrow "🖼 Abbildung" + Rohtext)
      • p.type==='table'  → tableCard(tab)   ODER .fig-missing (eyebrow "▦ Tabelle" + Rohtext)
      • p.type==='list'   → ul.amod-list > li (U.richText, fnStyle 'mini', xrefBase '#/studio/')
      • sonst Text        → p.amod-p (14px/1.75; stripFigMarker angewandt)
      dann: .amod-exp (Erklärungs-Box: border-left 3px var(--wissen), bg var(--wissen-soft),
            radius 0 10px 10px 0, 13px/1.6; app.css:1250)
            ├─ span.ae-t  = dockLabel(lens)  (10px uppercase var(--wissen-ink))
            └─ div = U.md(dockGet(lens,p.id) || dockAuto(lens,u.id,p))
      dann: an den Absatz gebundene figureCard/tableCard (FIG_BY_PARA/TAB_BY_PARA, views_analyse.js:213–214)
```

### 4.5 🌐 Übersetzung & Instanzen (analyseInstanzen, views_analyse.js:223–272)
```
.row (margin-bottom 14px): Mode-Picker (a.btn.btn-sm[.btn-primary] je Instanz, href #/analyse/instanzen/<k>)
  + span.small.mut "X von Y Absätzen vorhanden" + Spacer
  + span.small.mut "erstellen/ändern: GPT-Knopf oben in der Kopfleiste generiert global; direkt in den Fenstern schreibbar"
    (+ bei mode==='analyse' Suffix " · generell (ohne Kapitel): 📓 Erklärbuch")
je Abschnitt mit Inhalten: section.card (margin-bottom 14px)
├─ h3: span.mono 12px var(--accent-ink) <sectionId> + Titel + flex:1 + a.btn.btn-sm "⌖ Studio"
└─ .stack (margin-top 10px, gap 10px)
   └─ .inst-row              ← grid 44px / minmax(0,1fr), gap 10px, border-bottom 1px dashed (app.css:1667)
      ├─ span.mono.small var(--muted):  "p3"  (p.id ohne "<secId>-"-Präfix)
      └─ .inst-md (14px/1.7) = U.md(text)
```

### 4.6 Notebook-Blöcke (Notebook._renderBlock, notebook.js:225–265)
- `md` → `.nb-md` (Markdown 15px/1.75, max-width aufgehoben; app.css:1427).
- `math`/`$$` → `.nb-math > .mth.mth-block` (zentriert via flex, 1.22em, Serif `var(--font-serif)`, bg `var(--surface-2)`, Rahmen; app.css:1456–1459).
- `latex` → `.nb-latex` (border-left 3px `var(--accent-line)`; app.css:1434) mit `Editor.preview`-HTML; bei Lint-Fehlern `.tex-lint` mit Kopf **„✗ LaTeX-Code nicht kompilierbar — Ausgabe des Prüfers:“** + max. 4 `· <fehler>`-Zeilen (notebook.js:234).
- `chart` → `.nb-chart.card.flat` (padding 14 16) mit optionaler `.eyebrow`-Titelzeile; Achsen-SVG in `.viz`, Legende `.nb-legend > .nb-leg` (Swatch `<i>` 11×11 radius 3; app.css:1430–1432).
- `table` → `.tbl-wrap.nb-table > table.tbl` (thead/tbody[/tfoot Σ]).
- `figure` → `figureCard` (`figure.fig-card > img.fig-img + figcaption.fig-cap`; Klick → Lightbox; fehlende Datei → `.fig-missing` mit Datei-Upload-Button „Bild einfügen (PNG/JPG/WebP/SVG)“, figures.js:75–89).
- `include` → `blockquote.nb-include` (border-left 3px `var(--cat-norm)`, bg `var(--surface-2)`; app.css:1439): eyebrow „Aus der Arbeit — Abschnitt <id>“ (Link) + **max. 12** Absätze als `p.lesen-p`/`ul.lesen-list` (notebook.js:254).
- `js`/`py` → `.nb-cell[.nb-py]`:
  ```
  .nb-cell (border, radius, overflow hidden)
  ├─ .nb-cell-h (flex, gap 8, padding 6 10, bg var(--surface-2), border-bottom)
  │  ├─ span.nb-lang "JS" (mono 10.5px uppercase; js: var(--accent-ink)/var(--accent-soft);
  │  │                     py: var(--cat-norm) auf 12%-Mix; app.css:1447–1448)
  │  ├─ button.btn.btn-sm.nb-run "▶ ausführen"
  │  ├─ button.btn.btn-ghost.btn-sm.nb-code-toggle "⌄ Code"  (Toggle → "⌃ Code")
  │  └─ [py] span.small.mut.nb-py-status
  ├─ pre.cmd.nb-code [hidden]  (max-height 300px, scroll)
  └─ .nb-cell-out (flex column, gap 8; :empty → display:none)
  ```
- unbekannte Sprache → `pre.cmd.nb-pre` (max-height 320px, scroll; app.css:1441).

### 4.7 Überblick (analyseUeberblick, views_analyse.js:275–317)
```
.grid  grid-template-columns: minmax(0, 1.6fr) minmax(280px, 1fr); align-items:start
       ← bei matchMedia('(max-width: 900px)') EINMALIG beim Render auf '1fr' gesetzt (views_analyse.js:280 — NICHT reaktiv!)
├─ links .stack
│  ├─ section.card: .eyebrow "Executive Summary" + U.md(g.executiveSummary)
│  ├─ h2 "Ergebnisse auf einen Blick" (margin-top 8px)
│  └─ .grid.grid-3: je Card [positiv|luecken|spannungen]:
│     typChip + ul (margin 10px 0 0 18px) > li (margin 7px 0):
│       b 13px <titel> <br> span.small var(--ink-2) <text> [+ span.chip <frist>]
└─ rechts .stack
   ├─ section.card "Roter Faden": .faden-step (flex, gap 12) je Schritt:
   │  .faden-col (column, centered): .faden-n (26×26px, mono 12px bold, var(--accent-ink) auf var(--accent-soft),
   │     border var(--accent-line); app.css:831) = kapitel ?? schritt; + .bar (2px breit, var(--accent-line) 50%) außer letztem
   │  .faden-body (padding-bottom 14px, 14px): b <label> + div var(--ink-2) <text>
   └─ section.card "Fristen-Timeline": Charts.timeline(g.timeline mit datumLabel=U.fmtDate(datum))
```

### 4.8 Kapitel (analyseKapitel, views_analyse.js:320–367)
Kapitel-Picker-Row → Card „Kapitel N kompakt“ (Kurzfassung + Buttons **„Im Studio prüfen ⌖“** `#/studio/N.0/pruefen`, **„Kapitel lesen ☰“** `#/studio/N.0/lesen`) → `.grid.grid-2` (margin-top 16px) mit bis zu 4 Cards: **Kernaussagen** (ul, li 13.5px), **Begriffe in diesem Kapitel** (.stack gap 7px: `b <begriff> — <erklaerung>`), **Fristen** (chip.warn + Text), **Abschnitte** (ul ohne Bullets: Link `#/studio/<id>` mit mono-id 11.5px + Titel, darunter `.small.mut <einzeiler>`) → Card **„Verbindung zum Fazit“** (fazitBeitrag-Absatz 13.5px; relevante Findings — Kap. 6 = alle, sonst Filter `abschnitte.startsWith(chNum+'.')` — als `Charts.fazitGraph`, sonst „Keine direkten Fazit-Befunde aus diesem Kapitel.“). Default-Kapitel ohne arg: **6** (views_analyse.js:45).

### 4.9 Connections/Fazit-Netz (analyseFazit, views_analyse.js:370–391)
Card „Kapitelfluss — wie die Arbeit ihr Fazit herleitet“ (`Charts.kapitelFluss`, Klick auf Knoten → `#/analyse/kapitel/<n>`; Chapter-tip `ab S. <page>`) → Card „Fazit-Connections — Befunde und ihre Herleitung“ (`Charts.fazitGraph`, `.viz-note` „Hover hebt Herleitungspfade hervor · Klick auf einen Befund zeigt Details · Klick auf einen Abschnitt öffnet das Studio.“) → Card „Alle Befunde“: `.punkt.finding-row` (flex gap 10, padding 9 0, border-bottom; app.css:815) je Finding: typChip + `b <label>` — Beschreibung + Fristen-Chips; ganze Zeile klickbar (cursor:pointer, app.css:818) → `showFinding`.

### 4.10 Würdigung (analyseWuerdigung, views_analyse.js:394–438)
Intro-Absatz (s. §5) → optionale Card `.std-card`: eyebrow (std.titel || „Bewertung nach Standards“), `.std-verdikt` (15px/1.6, U.md), Markdown, `.std-grid` (grid auto-fill minmax(240px,1fr), gap 10; app.css:811) mit `.std-krit`-Kacheln (`.std-krit-h`: `b name` + `span.chip[ok|warn|bad]` mit Sterne-Label), Abschnitt eyebrow **„▲ Verbesserungswürdig“** mit `.punkt`-Zeilen (typChip 'schwaeche' = „▲ Schwäche“) → drei Akkordeons `details.acc` (struktur **open**, quellen, inhalt): `summary` = a.titel || key (Pfeil ▸ rotiert 90° bei open, app.css:823), `.acc-b` = U.md(markdown) + `.punkt`-Liste.

### 4.11 Kennzahlen (analyseKennzahlen, views_analyse.js:441–480)
`.statgrid` (grid auto-fit minmax(155px,1fr), gap 12; app.css:103) mit 5 `.stat`-Kacheln (`.v` 22px display-Font tabular-nums, `.l` 11.5px muted): **„Fußnoten gesamt“, „verschiedene Quellen“, „Absätze“, „aufgelöste Sätze“, „Belege pro Absatz (Ø)“** (= `(fussnoten/absaetze).toFixed(1)`; Fallback jeweils `'–'`). Darunter `.grid.grid-2` mit Cards: **„Beleg-Dichte je Kapitel“** (barH je Kapitel, tip `"<n> Fußnoten · <m> Absätze"`, valueLabel `v+' Fn.'`), **„Quellenmix nach Typ“** (barH, feste Reihenfolge `['recht-eu','recht-at','artikel','report','online','konferenz','norm']`, valueLabel `v+' Quellen'`), **„Meistzitierte Quellen (Zitierstellen)“** (volle Breite via `grid-column: 1 / -1`, tip `"<KIND_LABELS[kind]> · id: <id>"`, `.viz-note` mit Link auf `#/quellen`).

### 4.12 Chart-Geometrien (exakt)
- **barH** (charts.js:6–27): SVG `viewBox 0 0 720 h`, `h = items*30 + 8` (oder param); Zeilenhöhe 30, Label-Spalte 210px (rechtsbündig, 12.5px, `var(--ink-2)`, >32 Zeichen → 30+`…`), Balken ab x=210, Höhe 18 (rowH−12), `rx 4`, `fill it.color || var(--accent)`, opacity .92, Mindestbreite 4; Wertetext 12px/600 `var(--ink)` 8px rechts vom Balken; unsichtbares Hover-Rect über die volle Zeile trägt `data-tip`.
- **kapitelFluss** (charts.js:30–65): `viewBox 0 0 980 168`; 6 Knoten 148×58, `rx 10`, `fill var(--surface-2)`, `stroke var(--border)`; y0=96; Gap dynamisch `(980−6·148−24)/5`; Pfeilspitze `marker#arr` `fill var(--baseline)`; Nachbar-Pfeile: `stroke var(--baseline)` width 2; Fern-Kanten als kubische Bézier-Bögen oberhalb, `lift = 26 + (b−a)·13`, `stroke var(--grid)` 1.6, nur wenn `to > from+1`; Knotentext „Kap. N“ 13px/700 `var(--accent-ink)` + Titel 11.5px `var(--ink-2)` (>22 Z. → 21+`…`).
- **fazitGraph** (charts.js:68–139): `viewBox 0 0 980 h`, `h = max(findings·56, secs·30) + 60`; linke Knoten-Spalte x=330, rechte x=690; Abschnitte alphanumerisch sortiert (`localeCompare de, numeric`); Kanten kubisch (`C xL+150 …, xR−150 …`), `stroke-width 1.7`, `opacity .5`; Befund-Punkt `circle r 7` (Typ-Farbe, `stroke var(--surface)` 2), Label 12.5px/650 rechtsbündig (>36 → 34+`…`), Subzeile 10.5px in Typ-Farbe `"✔ Positiv · Fazit p2"`; Abschnitts-Punkt `circle r 5 fill var(--surface-2) stroke var(--baseline)` 1.6, Text 12px (>34 → 32+`…`); Spaltenköpfe **„FAZIT-BEFUNDE“** / **„HERGELEITET AUS“** 11px/700 `var(--muted)` letter-spacing 1.
- **timeline** (charts.js:142–160): reines HTML: `.viz > .legend + .tl > .tl-row*` mit `.tl-date`, `.tl-dotcol > .tl-dot[.done]{--c:<farbe>} + .tl-line`, `.tl-body > .tl-label + .tl-sub`. **Achtung: Für `.tl*`, `.viz` (Container), `.legend`, `.li`, `.sw` existieren KEINE CSS-Regeln in app.css/theme.css** — nur `.viz-note` und `.viz-tip` sind gestylt. Die Timeline erscheint im Original also als ungestylte, untereinander gestapelte Divs; die SVGs in `.viz` skalieren über das SVG-Default `width=100%` + viewBox responsiv.

### Responsive
Einzige explizite Breakpoints in diesem Bereich: Überblick-Grid ≤900px → 1 Spalte (JS, einmalig); `.nb-edit-grid` ≤860px → 1 Spalte (CSS). Alles andere: fluid (flex-wrap der Tab-/Button-Rows, auto-fit/auto-fill-Grids, skalierende SVG-viewBoxen).

---

## 5. Design-Rohwerte

### Farb-Tokens (theme.css; hell → dunkel)
| Token | hell | dunkel | Verwendung hier |
|---|---|---|---|
| `--accent` | `#b4552d` | `#e28a5d` | Balken-Default, Ausblick-Typ, EU-Timeline, Palette[0]; Fallback in `Notebook.color` |
| `--accent-ink` | `#a04a26` | `#e69670` | „Kap. N“-Text, Instanzen-Abschnitts-IDs, js-Zellen-Badge |
| `--wissen` | `#3f5d8c` | `#8ba7d6` | aktiver Tab-Balken, `.amod-exp`-Border, Linsen-Button .on |
| `--wissen-ink` | `#38537d` | `#9db5de` | h1, Eyebrows, Abschnitts-IDs im Analysemodus, Cluster-Labels |
| `--wissen-soft` | `#e8edf5` | `#232a3a` | Chip-/Erklärungs-Hintergrund |
| `--wissen-line` | `#c2cfe3` | `#3e4c68` | Card-Oberkante der Wissen-Welt |
| `--good` | `#3f7449` | `#8fb87f` | Typ „positiv“ im fazitGraph, Erklärung-Instanzfarbe |
| `--warn`→`--warning` | `#96702c` | `#cfa05e` | Typ „spannung“, chip.warn |
| `--bad`→`--critical` | `#a04b3c` | `#d1806f` | Typ „luecke“ |
| `--cat-norm` | `#2e6b74` | `#6fb5c0` | Palette[1], include-Border, py-Badge, Übersetzungs-Instanz |
| `--cat-frist` | `#a8721e` | `#d6a44e` | Palette[2] |
| `--cat-akteur` | `#7d5a96` | `#b291cc` | Palette[3], Analyse-Instanz |
| `--cat-zahl` | `#587f3f` | `#9dc07f` | Palette[4] |
| `--cat-luecke` | `#ad5151` | `#e07f7f` | Palette[5] |
| `--cat-these` | `#46679c` | `#85a5d8` | Palette[6] |
| `--cat-abk` | `#8a6d4e` | `#c2a179` | Palette[7] |
| `--cat-tech` | `#34786f` | `#6fbcb0` | AT-Timeline-Punkte |
| `--grid` | `#dbd7cc` | `#403a30` | Chart-Gitterlinien, Bogen-Kanten |
| `--baseline` | `#8a8990` | `#938d80` | Null-/Grundlinien, Pfeile, Abschnitts-Punkte |

Chart-Serienfarben werden **zur Renderzeit** aus den Tokens aufgelöst (`Notebook.color`, notebook.js:161–164) — Reihenfolge = `PALETTE` (notebook.js:160).

### Icon-/Sonderzeichen (exakt)
`✦` (Wissen-Chip, Kernaussagen, eingebautes Buch, Analyse-Instanz) · `📓 🔬 🌐 ⚖` (Tab-Icons) · `✎ ⭳ ↺ ↗ ⌖ ☰ 🤖` (Buttons) · `▶` (ausführen) · `⌄`/`⌃` (Code-Toggle) · `✔ ▲ ◆ ➜ ○ ●` (Typ-/Status-Icons) · `★★★/★★☆/★☆☆/☆☆☆` (Standards-Noten) · `🖼 ▦` (fehlende Abbildung/Tabelle) · `🇪🇺 🇦🇹` (Timeline) · `⚠ ✗ ✓ √ − Σ` (Mathe/Fehler/Summe) · `×` (Modal/Fenster schließen).

### Wörtliche UI-Texte (Auswahl, exakt zu übernehmen)
- Seitenkopf: **„Wissen“** + Chip **„✦ Cross-Projekt-Informationsspeicher“**; Untertitel: „Die eigene Welt neben dem Studio — Erklärungsauflösung, Buchkapitel, visuell Generiertes (Charts, Tabellen), Übersetzungen und Kennzahlen. GPT-generierbar, direkt einfügbar, mit den Quellen verbunden.“ (views_analyse.js:22–24)
- Cluster: „Schnellverständnis“, „Zusammenhänge & Thema“, „Bewertung“; Tabs: „📓 Erklärbuch“, „🔬 Analysemodus“, „🌐 Übersetzung & Instanzen“, „Überblick“, „Kapitel“, „Connections“, „Kennzahlen“, „⚖ Würdigung“ (views_analyse.js:27–31).
- Erklärbuch-Bar: „✎ Bearbeiten“, „⭳ Export“, „↺ Eingebautes Buch“/„↺ Starter“, „✦ eingebautes Buch“, „Starter-Buch“, „Referenz ↗“; Reset-Confirm: „Eigenes Erklärbuch verwerfen und zum {mitgelieferten Buch dieser Arbeit|Starter-Buch} zurückkehren?“ (views_analyse.js:84); Tooltips wortwörtlich in views_analyse.js:67–72.
- Analysemodus: „Erklärung durch:“, „· {c} von {t} Absätzen erklärt“, „Inhalte entstehen über den GPT-Knopf oben in der Kopfleiste (global) — sonst zeigt die KI-Voranalyse“, „Kapitel {n} — worum es geht“, „⌖ Studio“.
- Instanzen: „{covered} von {totalParas} Absätzen vorhanden“, „Keine Text-Instanzen definiert — im Studio über ✎ in der Instanz-Leiste anlegen.“, „Noch keine {Label}-Instanzen vorhanden. Über den GPT-Knopf oben in der Kopfleiste global generieren — oder direkt in den Instanz-Fenstern schreiben.“
- Überblick: „Executive Summary“, „Ergebnisse auf einen Blick“, „Roter Faden“, „Fristen-Timeline“, „Gesamtzusammenfassung nicht generiert.“
- Kapitel: „Kapitel {n} kompakt“, „Im Studio prüfen ⌖“, „Kapitel lesen ☰“, „Kernaussagen“, „Begriffe in diesem Kapitel“, „Fristen“, „Abschnitte“, „Verbindung zum Fazit“, „Keine direkten Fazit-Befunde aus diesem Kapitel.“, „Kapitel-Zusammenfassung nicht generiert.“
- Fazit: „Kapitelfluss — wie die Arbeit ihr Fazit herleitet“, „Fazit-Connections — Befunde und ihre Herleitung“, „Alle Befunde“, „Hergeleitet aus“, „Zum Fazit-Absatz ({id}) →“; Legende: „✔ Positiv erfüllt“, „▲ Lücke“, „◆ Spannung“, „➜ Ausblick“.
- Würdigung: Intro „Die **Bewertung** der Arbeit — kritische Einordnung gegen wissenschaftliche Standards, mit Stärken und **verbesserungswürdigen** Stellen. Basis, Zusammenhänge und schnelles Verständnis stehen in den anderen Tab-Gruppen.“; „Bewertung nach Standards“, „▲ Verbesserungswürdig“, „Diese Analyse wurde noch nicht generiert.“; Noten-Labels: „★★★ stark“, „★★☆ solide“, „★☆☆ ausbaufähig“, „☆☆☆ schwach“.
- Kennzahlen: Kachel-Labels s. 4.11; „Beleg-Dichte je Kapitel“, „Quellenmix nach Typ“, „Meistzitierte Quellen (Zitierstellen)“, „Die Arbeit stützt sich primär auf die Rechtsakte selbst — Details je Quelle in der Quellen-Bibliothek.“
- Notebook: „▶ ausführen“, „⌄ Code“/„⌃ Code“, „Lade Python-Umgebung (Pyodide, ~10 MB, einmalig) …“, „… rechnet“, „✓“, „✗ js-Zelle: {msg}“, „✗ Python: {msg}“, „Pyodide nicht ladbar — Python braucht eine Internetverbindung (CDN).“, „chart: JSON ungültig — {msg}“, „chart: keine „series“ angegeben.“, „chart: Typ „{t}“ unbekannt (bar, barh, line, area, scatter, pie, donut).“, „figure: „{key}“ nicht gefunden — verfügbar: {ids|keine}“, „include: Abschnitt „{id}“ existiert nicht.“, „Aus der Arbeit — Abschnitt {id}“, „table: leer.“, „table: keine Zeilen.“, „Block ({lang}) nicht darstellbar: {msg}“, „✗ LaTeX-Code nicht kompilierbar — Ausgabe des Prüfers:“.
- Timeline: „🇦🇹 Österreich“ / „🇪🇺 EU“, „✔ erledigt“ / „○ offen“, „🇪🇺 EU-Frist“, „🇦🇹 nationaler Termin“, „● gefüllt = erledigt · ○ Ring = offen“.

### Schrift-/Größenwerte in JS inline
Chart-Fonts: 10.5px (Achsen-Ticks/X-Labels), 12/12.5px (barH), 11.5/13px (kapitelFluss), 10.5/12/12.5px (fazitGraph), 11px letter-spacing 1 (Spaltenköpfe). Zahlformat `fmt`: ≥1000 → `toLocaleString('de-AT')`, sonst auf 2 Nachkommastellen gerundet (notebook.js:275). Inline-Styles in views: `font-size:12px` mono-Abschnitts-IDs, `13.5px` Kernaussagen-/Fazit-Text, `11.5px` Abschnitts-ID-Links, `margin:7px 0` Ergebnisse-li usw. (Zeilenangaben in §4).

---

## 6. Verhalten & Interaktionen

1. **Routing**: `#/analyse` → Überblick; `#/analyse/<tab>`; `#/analyse/modus/<kapitelNum>` (Default Kap.-Nr. 0 → erstes Kapitel); `#/analyse/kapitel/<n>` (Default 6); `#/analyse/instanzen/<modeId>`. Alt-Route `#/zusammenfassung` leitet auf `#/analyse` um (app.js:239). Jede Navigation = voller Re-Render.
2. **Erklärbuch-Quellen-Priorität** (views_analyse.js:58–62): `Notebook.get()` (eigenes) → `window.PROJECT_ERKLAERBUCH` (mitgeliefert) → `Notebook.starter()`. Der Reset-Button existiert nur bei eigenem Buch; `confirm()`-Dialog, dann `Notebook.set(null)` + Re-Render.
3. **Export**: `U.download('erklaerbuch.md', src, 'text/markdown')` (views_analyse.js:82).
4. **Editor-Modal**: Tippen → 350 ms Debounce → volle Neu-Render der Vorschau (inkl. `js auto`-Zellen, die dabei erneut ausgeführt werden!). „Speichern“ → persistieren, Modal zu, Tab-Re-Render (views_analyse.js:109–115).
5. **Linsen-Wechsel im Analysemodus**: Klick → `storeSet('wissenLens')` → `app.innerHTML=''` → `renderAnalyse(...)` → `requestAnimationFrame(() => scrollTo(0, y))` (Scroll-Restaurierung, views_analyse.js:142–149). Abdeckungs-Meter wird erst NACH dem Abschnitts-Rendern in die Lens-Bar geschrieben (views_analyse.js:173–174).
6. **Erklärungs-Fallback-Kette je Absatz**: `dockGet(lens, p.id)` (vom Nutzer/GPT gespeichert) `|| dockAuto(lens, u.id, p)` (KI-Voranalyse: `erklaerung` = Einfach-Sätze verkettet, `analyse` = „**Kernaussage:** … **Belegt wird:** …“, `uebersetzung` = gp.uebersetzung, sonst mitgelieferte `PROJECT_INSTANZEN.items`; views_studio.js:2184–2198). Kein Inhalt → keine Box.
7. **js-Zelle**: „▶ ausführen“ → Output leeren, `new Function('nb','data','print','show','md','chart','table','figure','math', body)` synchron ausführen; Exceptions → Notice. `meta` enthält `auto` → läuft sofort beim Rendern (notebook.js:483). Code-Sichtbarkeit per Toggle (initial `hidden`).
8. **py-Zelle**: NIE auto. Erster Klick lädt Pyodide v0.26.4 per `<script>` von `cdn.jsdelivr.net` (Status-Text, einmalig, Promise-Latch gegen Doppel-Load); dann `setStdout/setStderr` (batched → `print`, stderr mit „⚠ “-Präfix), Datenpaket als JSON in `__NB_DATA`, Brücken `__nb_chart`/`__nb_show`, `loadPackagesFromImports` (numpy/pandas/matplotlib/sklearn autom.), Prelude + Body via `runPythonAsync`; letzter Ausdruck ≠ None wird geprintet; Status „✓“ (notebook.js:539–559). `show_plt()` rendert matplotlib als base64-PNG `<img class="nb-img">` (dpi 110, AGG; notebook.js:515–524).
9. **Chart-Tooltips**: alle Elemente mit `data-tip` → `mousemove` zeigt `.viz-tip` (fixed, +14px Versatz, an Viewport geklemmt), `mouseleave` versteckt (charts.js:162–167, util.js:671–679). Tip-HTML-Muster: `<b>Label</b>Wert` (der `<b>`-Block wirkt als Titelzeile).
10. **fazitGraph-Hover**: `mouseenter` auf Befund-Knoten → alle `.fz-edge` mit passender `data-f` auf opacity 1, andere auf 0.12; `mouseleave` → alle 0.5 (charts.js:130–133). Klick Befund → `onFinding(id)` (öffnet `showFinding`-Modal); Klick Abschnitts-Knoten → `location.hash = '#/explorer/<sec>'`, was der Router auf `#/studio/<sec>'` umbiegt (app.js:238).
11. **kapitelFluss-Klick** → `#/analyse/kapitel/<n>`; Cursor nur `pointer`, wenn onClick übergeben.
12. **showFinding-Modal** (views_analyse.js:483–496): Titel = typChip + Label; Body: Beschreibung, Fristen-Chips, „Hergeleitet aus“-Linkliste (Klick schließt Modal via inline `onclick="U.closeModal()"`), optional „Zum Fazit-Absatz (6.0-pX) →“.
13. **Akkordeons** (Würdigung): natives `<details>`; „struktur“ initial offen; Pfeil-Rotation via CSS-Transition .15s.
14. **figureCard**: Klick auf Bild → Lightbox (Escape/Klick schließt); fehlende Bilddatei → Upload-Feld, gespeichert in FigStore (IndexedDB, figures.js).
15. **Fehler-/Leerzustände**: „Keine Arbeit geladen.“ (Modus ohne Kapitel), fehlende `DATA_META`-Teile → Notices (Texte §5); Notebook fängt jeden Block-Fehler einzeln (Dokument bricht nie ganz ab, notebook.js:218–222); Mathe-Parser rendert `⚠` mit title `\cmd nicht unterstützt` statt zu werfen (notebook.js:53).
16. **Vollkreis-Sonderfall** Pie/Donut: Anteil > 99.95 % wird als `<circle>` statt Bogen gezeichnet (Bogen mit Start=Ende kollabiert; notebook.js:287–292); Null-Werte erscheinen nur in der Legende (notebook.js:285).

---

## 7. Datenformen

### Erklärbuch-Quelltext (localStorage `notebook` / `PROJECT_ERKLAERBUCH` / Starter)
Ein Markdown-String; exakte Block-Syntax (notebook.js:176–195):
````markdown
# Überschrift, **fett**, Listen, > Zitate …   ← Markdown-Segment (U.md + Inline-$…$)

```chart
{ "type": "bar",              // bar | barh | line | area | scatter | pie | donut
  "title": "Fußnoten je Kapitel",
  "labels": ["1","2","3"],
  "series": [ { "name": "Fußnoten", "values": [3, 88, 96], "color": "#2e6b74" } ],
  "stacked": false,           // nur bar/area
  "height": 300,              // optional, Achsen-Charts
  "x": "Kapitel", "y": "Anzahl" }   // optionale Achsen-Notiz
```
```table sum                  ← meta 'sum' ⇒ Σ-Fußzeile; Delimiter-Auto: | > Tab > ; > ,
Quelle,Typ,Zitierstellen
EHDS-VO,recht-eu,107
```
```math
\bar{x} = \frac{1}{n} \sum_{i=1}^{n} x_i
```
$$                            ← gleichwertig zu ```math
…
$$
```latex
\section{…} \textbf{…} \enquote{…} \footnote{…}   ← Editor.preview + Editor.lint
```
```figure abb-architektur     ← id | figNum | 1-basierter Index; meta ODER body
```
```include 2.1                ← Abschnitts-ID; max. 12 Absätze im Lesen-Stil
```
```js auto                    ← 'auto' ⇒ läuft beim Rendern; API-Variablen:
print(data.kapitel.length)    //   nb, data, print, show, md, chart, table, figure, math
```
```py                         ← Pyodide; data (dict), print, chart(spec), show(html), show_plt()
import statistics
```
````
Inline-Mathe im Markdown: `$\bar{x}$` (notebook.js:203–212).

### `Notebook.dataset()` — Datenpaket der Rechenzellen (notebook.js:414–441)
```jsonc
{
  "arbeit": { "titel": "…", "autor": "…", "universitaet": "…" },
  "kapitel": [ { "num": 2, "titel": "Der Europäische Gesundheitsdatenraum", 
                 "abschnitte": 12, "absaetze": 47, "fussnoten": 88 } ],
  "quellen": [ { "id": "ehds-vo", "titel": "Verordnung (EU) 2025/327 (EHDS-Verordnung)",
                 "kurz": "EHDS-VO", "typ": "recht-eu", "jahr": 2025, "zitierstellen": 107 } ],
  "belegStatus": { "offen": 0, "vermutet": 0, "original": 0, "belegt": 0, "gesamt": 397 },
  "verbindungen": { "gesamt": 42, "nachTyp": { "stuetzt": 12 } },
  "abbildungen": [ { "id": "abb-1", "titel": "…" } ]
}
```

### `DATA_META`-Teilstrukturen (echte Beispiele aus data_meta.js)
```jsonc
// gesamt (Überblick)
{ "einSatz": "…", "executiveSummary": "### Fragestellung und Vorgehen\nMit der Verordnung …",
  "ergebnisse": {
    "positiv":   [ { "titel": "Zugangsrecht umgesetzt", "text": "Das Bürger-Zugangsportal erfüllt …" } ],
    "luecken":   [ { "titel": "Automatische Zugriffs-Benachrichtigung", "text": "…", "frist": "26. März 2029" } ],
    "spannungen": [ { "titel": "…", "text": "…" } ] },
  "roterFaden": [ { "schritt": 1, "kapitel": 1, "label": "Frage stellen", "text": "Erfüllt ELGA …?" } ],
  "timeline":   [ { "datum": "2015-01-01", "label": "ELGA-Rollout beginnt (öffentliche Krankenanstalten)",
                    "kategorie": "at", "status": "erledigt" } ] }   // kategorie: 'at'|'eu' (alles ≠'at' = EU)

// kapitel[n] (Kapitel-Tab + Analysemodus-Kopf)
{ "chapter": 2, "title": "…", "kurzfassung": "Markdown …",
  "kernaussagen": ["…"],
  "begriffe":  [ { "begriff": "EEHRxF", "erklaerung": "European Electronic Health Record exchange Format — …" } ],
  "fristen":   [ { "datum": "26. März 2027", "was": "…" } ],
  "abschnitte":[ { "id": "2.1", "titel": "…", "einzeiler": "…" } ],
  "fazitBeitrag": "…" }

// fazit (Connections)
{ "kapitelFluss": [ { "from": "1", "to": "2", "label": "Forschungsfrage → EU-Maßstab" } ],
  "findings": [ { "id": "f1", "label": "Zugang & Portal erfüllt", "typ": "positiv",
                  "beschreibung": "…", "fazitParagraphId": "6.0-p2",
                  "abschnitte": ["5.1.1","5.1.3","2.3.1"], "fristen": [] } ] }
                  // typ ∈ positiv|luecke|spannung|ausblick

// analyse (Würdigung)
{ "standards": { "titel": "…", "verdikt": "Markdown …", "markdown": "…",
                 "kriterien": [ { "name": "Fragestellung & Methodik", "note": "stark", "text": "…" } ],
                 "verbesserung": [ "Fazit-Konsistenz: …" ] },   // note ∈ stark|solide|ausbaufaehig|schwach
  "struktur": { "titel": "…", "markdown": "…", "punkte": [ { "typ": "staerke", "text": "…" } ] },
  "quellen": { … }, "inhalt": { … } }

// stats (Kennzahlen)
{ "fussnoten": 397, "quellen": 74, "absaetze": 233, "saetze": 688,
  "fnPerChapter": { "1": 3, "2": 88, "3": 96, "4": 81, "5": 129, "6": 0 },
  "paraPerChapter": { … },
  "byKind": { "artikel": 20, "konferenz": 1, "norm": 1, "report": 8, "online": 28, "recht-eu": 10, "recht-at": 6 },
  "kindLabels": { "artikel": "Peer-Review-Artikel", "recht-eu": "Rechtsquelle EU", … },
  "topSources": [ { "id": "ehds-vo", "title": "Verordnung (EU) 2025/327 (EHDS-Verordnung)",
                    "kind": "recht-eu", "cites": 107 } ] }
```

### Instanz-Definitionen (dockDefs, views_studio.js:2127–2134)
```jsonc
[ { "id": "uebersetzung", "label": "🌐 Übersetzung", "color": "var(--cat-norm)", "desc": "…" },
  { "id": "erklaerung",   "label": "✎ Erklärung",   "color": "var(--good)",     "desc": "…" },
  { "id": "analyse",      "label": "✦ Analyse",     "color": "var(--cat-akteur)","desc": "…" } ]
// + Projekt-Instanzen (PROJECT_INSTANZEN.defs) + eigene (localStorage 'instDefs');
// special-Einträge (schnell/connections/srcview/clear) werden in der Wissen-Welt gefiltert.
```

### Charts-Eingaben
`barH`: `[{label, value, tip?, color?}]`; `kapitelFluss`: chapters `[{num, title, tip}]` + edges `[{from, to, label}]` (Strings „1“–„6“); `fazitGraph`: findings wie oben; `timeline`: items wie `gesamt.timeline` + `datumLabel` (vorformatiert via `U.fmtDate`).

---

## 8. Abhängigkeiten (Aufrufgraph)

**Wer ruft diese Module:**
- `app.js:232` → `renderAnalyse(app, p1, p2)` bei Route `analyse`; app.js:156 Command-Palette-Eintrag „◈ Wissen — Informationsspeicher“; Topbar-Nav `<a href="#/analyse" class="nav-wissen">Wissen</a>` (index.html:34).
- `enhance.js:90–92` (GPT-Magic „Erklärbuch“): nach KI-Generierung `Notebook`-Status prüfen + `renderAnalyse(app,'buch')`; `enhance.js` nutzt `Notebook.prompt()` als Prompt-Basis und `window.PROJECT_ERKLAERBUCH` für Status.
- `views_projekt.js`/`levels.js` exportieren/nutzen `notebook`-Key im Projekt-Export.
- `Charts.barH` zusätzlich von `views_projekt.js`; `Charts.timeline/kapitelFluss/fazitGraph` nur aus views_analyse.js.

**Was diese Module rufen:** s. §2 „Konsumierte Globals“. Zirkularität: `Notebook.chart('barh')` delegiert an `Charts.barH` (notebook.js:368); `Notebook` ruft `Editor.preview/lint` (latex), `figureCard` (figures.js), `UNIT_INDEX`/`orderedUnits` (util.js), `Levels`/`Connections` (dataset). Externe Ressource: **Pyodide-CDN** `https://cdn.jsdelivr.net/pyodide/v0.26.4/full/` (einzige Netz-Abhängigkeit des ganzen Bereichs).

---

## 9. Flutter-Hinweise

1. **Tab-Cluster**: kein Standard-TabBar — drei beschriftete Gruppen in einer umbruchfähigen Zeile. Empfehlung: `Wrap` aus eigenen `_TabGroup`-Widgets (Label 9.5sp uppercase + Unterstreichungs-Tabs); aktiver Tab = Farbwechsel + 2px-Bottom-Border + `wissenSoft`-Fill. Navigation über go_router-Subrouten `/analyse/:tab/:arg?`.
2. **Wissen-Farbwelt**: eigenes Theme-Extension-Set (`wissen`, `wissenInk`, `wissenSoft`, `wissenLine` je hell/dunkel, Werte §5) + Regel „Card-Oberkante 2px wissenLine“ nur innerhalb dieser Seite — als eigenes `WissenCard`-Widget kapseln.
3. **Notebook = Kernaufwand.** Architektur 1:1 übernehmbar: Parser (reine String-Logik, direkt portierbar) → Blockliste → `ListView`/`SliverList` von Block-Widgets. Markdown: `flutter_markdown`/`gpt_markdown` mit Inline-Mathe-Interception (`$…$` als Platzhalter, wie `_mdWithMath`).
4. **MathRender**: bewusst KEIN KaTeX — ein handgeschriebenes Subset. In Flutter besser `flutter_math_fork` (echtes TeX-Layout) verwenden und das Subset darauf mappen; 1:1-Nachbau der HTML-sup/sub-Stapelung wäre schlechter als das Original-Ziel. Fehlerfall: `⚠`-Chip mit Tooltip beibehalten.
5. **Chart-Engine**: `Notebook.chart` + `Charts.*` sind reine Geometrie → idiomatisch als `CustomPainter` nachbauen (Werte in §4.12/„Achsen-Diagramme“ notebook.js:308–381: W 760, padL 52/padR 14/padT 10/padB 42, nice-Tick-Algorithmus notebook.js:316–320, Balken-Slots 0.62/0.72, Punkt-Radien 3.4/4). KEIN Chart-Package nötig — die Optik (Gitter, Baseline, rx 2.5-Balken, Legenden-Swatches 11×11 r3) ist pixelgenau spezifiziert. Tooltips: `MouseRegion`+`Overlay` (Versatz +14, Viewport-Klemmung wie util.js:675–677); auf Touch: LongPress.
6. **fazitGraph-Hover-Dimming** (opacity 1/0.12/0.5) braucht Hit-Testing pro Knoten — im CustomPainter Regionen speichern oder Knoten als positionierte Widgets über dem Kanten-Painter stapeln (empfohlen: Stack aus Painter für Kanten + Positioned-Widgets für Knoten).
7. **js-Zellen sind NICHT portierbar** (`new Function` über ein JS-Datenpaket). Optionen: (a) Dart-Interpreter-DSL (nicht 1:1), (b) `flutter_js`/QuickJS-Engine mit nachgebauter Zellen-API (`data/print/show/md/chart/table/figure/math` als Host-Bindings) — empfohlen, da Starter-Buch und generierte Bücher js-Zellen enthalten, (c) Websicht. Das Starter-Buch (notebook.js:570–650) ist wortwörtlich zu übernehmen — es enthält js-, py-, latex-, math-Blöcke als Referenz-Content.
8. **py-Zellen (Pyodide)** gehen in Flutter nativ nicht. Ersatz: `serious_python`/eingebettetes Python oder WebView mit Pyodide; mindestens aber den UI-Rahmen (Badge „py“, Status-Text, ▶) mit klarer Meldung nachbauen. `show_plt` → PNG-Bytes anzeigen bleibt konzeptgleich.
9. **latex-Block** hängt am Editor-Interpreter (`Editor.preview`/`Editor.lint`) — Dossier des Editor-Agents beachten; derselbe Transformer MUSS wiederverwendet werden (erklärtes Designziel „ein Interpreter für alles“, notebook.js:9–10).
10. **Persistenz**: Key-Schema `ehds.[<projekt>.]notebook` als `SharedPreferences`/DB-Zeile pro Projekt spiegeln; `wissenLens` global. Reset-Logik: eigenes Buch → mitgeliefertes → Starter (Priorität exakt einhalten, views_analyse.js:62).
11. **Scroll-Restaurierung** beim Linsen-Wechsel (views_analyse.js:145–148): in Flutter trivial via State statt Re-Mount — Verhalten (Position bleibt) muss erhalten bleiben.
12. **Überblick-Responsive-Bug übernehmen oder fixen?** `matchMedia` wird nur beim Render ausgewertet (views_analyse.js:280) — kein Live-Umbruch bei Fenster-Resize. In Flutter mit `LayoutBuilder` automatisch korrekt; bewusste Verbesserung, dokumentieren.
13. **Timeline unstyled**: `.tl-*`-Klassen haben KEINE CSS-Regeln — das Original zeigt schlichte gestapelte Text-Divs (Datum, Punkt-Div unsichtbar bzw. leer, Label, Sub). Für die 1:1-Optik den IST-Zustand prüfen (Screenshot!) statt eine „gedachte“ Timeline zu erfinden; Legende/Icons/Texte sind definiert, das visuelle Timeline-Styling nicht.
14. **`confirm()`/Modals**: natives `confirm` → `AlertDialog`; `U.modal` → Dialog-Route; Inline-`onclick="U.closeModal()"` in Links (views_analyse.js:489) → onTap + `Navigator.pop`.
15. **figure-Block/figureCard**: fehlende Bilder erlauben Upload in IndexedDB (FigStore) — in Flutter: file_picker + lokale DB; Lightbox → Fullscreen-Dialog mit `InteractiveViewer`.
16. **Zahlformatierung**: `toLocaleString('de-AT')` → `intl` mit `de_AT`; `toFixed(1)` für Ø-Kachel.
