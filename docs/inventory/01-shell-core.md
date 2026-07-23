# Inventar-Dossier 01 — App-Shell, Router, Gate, Core-Utilities

**Dateien:** `index.html` (81 Z.), `js/app.js` (271 Z.), `js/gate.js` (62 Z.), `js/util.js` (1013 Z.), `server.py` (99 Z.), `start-website.bat` (25 Z.), `.github/workflows/pages.yml` (33 Z.)

---

## 1. Zweck & Rolle

### index.html
Statische Single-Page-Shell der gesamten App. Enthält die komplette Topbar (Marke, Hauptnavigation, Aktions-Buttons), das leere `<main id="app">` (Router-Ziel), einen Footer und drei Overlay-Wurzeln (`#enhRoot`, `#modalRoot`, `#cmdkRoot`). Lädt zuerst `gate.js` (Passwort-Gate, blockierend im `<head>`), dann alle `js/data/data_*.js` (Inhaltsdaten als globale `window.DATA_*`-Objekte), am Body-Ende alle Modul-Skripte in fester Reihenfolge und zuletzt `app.js` (Bootstrap). Alle Skripte/CSS tragen den Cache-Buster `?v=24`. Sprache `lang="de"` (index.html:2).

### js/app.js
Bootstrap + Hash-Router + Topbar-Verhalten. Eine async-IIFE (app.js:6-249): lädt die aktive Arbeit (`Projects.boot()`), wartet auf `PdfStore.ready`, baut die Daten-Indizes, importiert ggf. einmalig den Belegstand aus dem Repo, setzt Titel/Arbeitsname in der Topbar, verdrahtet Theme-Umschalter, Fußnoten-Chips (global delegiert), Markierungs-Klicks, Arbeiten-Dropdown, GPT-Hub-Dropdown, Speicher-Button, Command-Palette (Strg/⌘+K) und den Router (`route()` auf `hashchange`). Außerhalb der IIFE: `showFootnoteModal(num)` (app.js:252-271) — das globale Fußnoten-Detail-Modal.

### js/gate.js
Clientseitiges Passwort-Gate für die veröffentlichte Version (GitHub Pages). Prüft beim Laden `localStorage['ehds.gateOk']` gegen einen fest kodierten SHA-256-Hash; wenn nicht vorhanden, wird ein Vollbild-Overlay mit Passwort-Formular über die App gelegt. Korrektes Passwort → Hash wird persistiert, Overlay entfernt. Explizit KEINE Server-Authentifizierung (Kommentar gate.js:3-8). Ohne WebCrypto oder ohne localStorage-Zugriff greift das Gate nicht (App bleibt nutzbar, gate.js:19-22).

### js/util.js
Das zentrale Utility-Modul; definiert das globale Objekt `U` plus die globalen Konstanten `CAT_LABELS`, `CAT_ORDER`, `KIND_LABELS`, `KIND_ICONS`, die Daten-Indizes `SRC_BY_ID`, `UNIT_INDEX`, `FN_INDEX`, `FIG_BY_PARA`, `TAB_BY_PARA` sowie die globalen Funktionen `fileIdOf`, `rebuildDataIndexes`, `orderedUnits`. Enthält: HTML-Escaping, Mini-Markdown, Rich-Text-Renderer (Fußnoten-Chips, Marks, Mentions, Querverweise), den kompletten localStorage-Layer (projekt-gescoped über `PROJECT_KEYS`), Satz-Zerlegung/Belegspannen, das Modal-System, Tooltip, Drag-Resizer und das wiederverwendete GPT-Dialog-Muster (`U.gptModal`) inkl. Claude-Konfigurationsformular. Wird als erstes Modul-Skript geladen (index.html:58) und von praktisch allen anderen Modulen benutzt.

### server.py
Lokaler Dev-/Nutzungsserver (Python-Stdlib). Erzwingt korrekte MIME-Types (Windows-Registry-Problem bei .js), sendet `Cache-Control: no-store`, probiert die Ports 8000, 8001, 8002, 8010, 8080, 8123 der Reihe nach und öffnet nach 0,4 s automatisch den Browser. Bindet nur an `127.0.0.1`. Loggt nichts (log_message leer, server.py:58-59).

### start-website.bat
Windows-Doppelklick-Starter: versucht `python server.py`, dann `py -3 server.py`; ohne Python wird `index.html` direkt per `file:`-Protokoll geöffnet (die App unterstützt file:-Betrieb, siehe die `location.protocol === 'file:'`-Checks in app.js:23, util.js:606/638).

### .github/workflows/pages.yml
GitHub-Actions-Deployment: Das Repo selbst IST die Website (kein Build). Bei Push auf `main` (oder manuell) wird das komplette Repo-Verzeichnis als Pages-Artefakt hochgeladen und deployt (Projekt-Pages unter `/thesoR/`).

---

## 2. Öffentliche API (window-Scope)

### Exportiert von util.js

| Symbol | Signatur | Zweck | Genutzt von |
|---|---|---|---|
| `U` | Objekt (util.js:4-917) | Utility-Namespace, siehe unten | alle Module |
| `CAT_LABELS` | `{norm, frist, akteur, tech, these, luecke, zahl, abk, schlag}` → Label-Strings (util.js:919-923) | Kategorie-Namen für Marks | richText, Studio-Views |
| `CAT_ORDER` | Array der 9 Kategorie-Keys (util.js:924) | Anzeige-Reihenfolge der Kategorien | Studio/Legenden |
| `KIND_LABELS` | `{artikel:'Peer-Review-Artikel', konferenz:'Konferenzbeitrag', norm:'Norm', report:'Report/Bericht', online:'Online-Quelle', 'recht-eu':'Rechtsquelle EU', 'recht-at':'Rechtsquelle AT'}` (util.js:926-929) | Quellen-Art-Labels | Quellen-Views, Modals |
| `KIND_ICONS` | `{artikel:'📄', konferenz:'🎤', norm:'📐', report:'📊', online:'🌐', 'recht-eu':'🇪🇺', 'recht-at':'🇦🇹'}` (util.js:930-932) | Quellen-Art-Icons | Quellen-Views, srcHeadHtml |
| `SRC_BY_ID` | `{[srcId]: sourceObj}` (util.js:937) | Quellen-Index | überall |
| `UNIT_INDEX` | `{[sectionId]: {unit, chapter}}` (util.js:938) | Abschnitts-Index | Router, richText-Xrefs, Views |
| `FN_INDEX` | `{[num]: {…footnote, sectionId, paragraphId}}` (util.js:939) | Fußnoten-Index | showFootnoteModal, richText, Levels |
| `FIG_BY_PARA` | `{[paragraphId]: figur}` (util.js:940) | Figuren je Absatz | Studio/figures |
| `TAB_BY_PARA` | `{[paragraphId]: tabelle}` (util.js:941) | Tabellen je Absatz | Studio/figures |
| `fileIdOf(sectionId)` | → `sectionId.replace(/\./g,'_')` (util.js:942) | „3.2“ → „3_2“ (Key in DATA_SECTIONS) | findBeleg, Views |
| `rebuildDataIndexes()` | () → void (util.js:944-1001) | Indizes leeren + neu bauen, Overrides anwenden | app.js:14/36, Projects (Arbeitswechsel), Editoren |
| `orderedUnits()` | () → `string[]` sectionIds (util.js:1005-1013) | DFS-Reihenfolge aller Abschnitte MIT Absätzen | Router-Fallbacks, Cmdk, Vor/Zurück-Navigation |

### `U`-Mitglieder (vollständig)

**Rendering/Text:**
- `U.esc(s)` (util.js:5-7) — HTML-Escape von `& < > " '` (`&amp; &lt; &gt; &quot; &#39;`); `null/undefined` → `''`.
- `U.el(html)` (util.js:9-13) — HTML-String → erstes Element (via `<template>`).
- `U.md(src)` (util.js:16-43) — Mini-Markdown → HTML, umhüllt mit `<div class="md">`. Regeln: `#`–`####` → `<h2>`–`<h5>` (Level+1!), `` `code` ``, `**strong**`, `*em*`, `[Text](https?:…)` → `<a target="_blank" rel="noopener">`, `- `/`* ` → `<ul><li>`, `1. ` → `<ol><li>`, `> ` → `<blockquote>`, Leerzeile trennt Absätze, aufeinanderfolgende Zeilen werden mit Leerzeichen zu einem `<p>` verbunden.
- `U.srcShort(id)` (util.js:46-66, Cache `U._shortCache`) — Kurzname einer Quelle. Feste Map (util.js:48-55): `'ehds-vo'→'EHDS-VO'`, `dsgvo→'DSGVO'`, `gtelg2012→'GTelG'`, `'elga-vo2015'→'ELGA-VO'`, `nis2→'NIS-2'`, `dga→'DGA'`, `datenverordnung→'Data Act'`, `cra→'CRA'`, `eidas→'eIDAS'`, `'rl-2011-24'→'RL 2011/24'`, `aeuv→'AEUV'`, `asvg→'ASVG'`, `nisg→'NISG'`, `aerzteg1998→'ÄrzteG'`, `'elga-gesamtarchitektur2017'→'ELGA-Architektur'`, `'rh-elga2024'→'RH 2024'`, `'ihe-iti2026'→'IHE ITI'`, `iso13606→'ISO 13606'`, `'empfehlung2019-243'→'Empf. 2019/243'`, `erlaeuterungen38me→'ErlME 38'`. Sonst: Autor-Nachname (+ Jahr), bei `kind==='online'`: Titel auf 16 Zeichen gekürzt, sonst die id.
- `U.matchSourceInText(snippet)` (util.js:94-105) — findet zu einem Textausschnitt die Quellen-id (längstes passendes Pattern gewinnt) oder `null`. Patterns pro Quelle (util.js:73-93, Cache `U._srcPatCache`): normalisierter srcShort (≥3 Zeichen, nicht rein numerisch), Nummern-Muster `\d{4}/\d{2,4}` aus Titel/longTitle, Klammer-Kürzel `(DSGVO)`/`(GTelG 2012)` aus Titeln, Autor-Nachname (≥4 Buchstaben). Normalisierung: lowercase + NFD ohne Diakritika.
- `U.richText(text, opts)` (util.js:114-186) — Kernrenderer, Details in §6.
- `U.fmtDate(d)` (util.js:188-193) — `"2024-03-07"` → `"7.3.2024"`, `"2024-03"` → `"3.2024"`; sonst String unverändert.
- `U.searchTerms(hinweis)` (util.js:291-296) — suchHinweis → max. 8 Suchbegriffe; bevorzugt an `| · ;` getrennte wörtliche Passagen (≥3 Zeichen), sonst Einzelwörter ≥4 Zeichen (dedupliziert).

**Satz-/Range-Logik:**
- `U.splitSentences(text)` (util.js:302-330) → `[{start,end,text}]`, abkürzungsfest (Details §6).
- `U.sentenceIndexAt(sents, pos)` (util.js:331-334) — Satzindex zu einer Zeichenposition.
- `U.domRangeFor(container, needle)` (util.js:338-364) — Roh-Textspanne im gerenderten DOM wiederfinden (whitespace-tolerant, `sup.fn-chip`-Inhalte werden übersprungen) → `Range` oder `null`.
- `U.setHighlight(name, ranges)` / `U.clearHighlight(name)` (util.js:367-374) — CSS Custom Highlight API; ohne Browser-Support No-op (`false`).
- `U.spanBack(fnNum)` / `U.setSpanBack(fnNum, n)` (util.js:381-386) — persistierte Zahl zusätzlicher Sätze je Fußnote (`belegSpans`).
- `U.belegSpan(pText, fnNum, mts)` (util.js:387-405) → `{from, to, sents, text}` oder `null`; Heuristik: ohne gespeicherten Wert zieht eine mit dem Beleg zusammengeführte Erwähnung (status `'beleg'`, gleiche fn) weiter vorn die Spanne bis zu ihrem Satz auf.

**Storage-Getter/Setter (alle über storeGet/storeSet, Details §3):**
- `U.getAnnotations()/addAnnotation(sourceId,a)/removeAnnotation(sourceId,idx)` (util.js:214-223)
- `U.getResolutions()/setResolution(res)` (util.js:226-231)
- `U.srcLinks(srcId)` (util.js:236-245) → `{official?, file?, …, _override:bool}`; Fallback `official` = `https://doi.org/<doi>` bzw. `s.url`. `U.setSrcLink(srcId, which, url)` (util.js:246-252).
- `U.srcHash(srcId)` (util.js:258-265, Cache `U._hashCache`) → `'ts-' + crc32hex8` aus normalisiertem `longTitle||title | author | year` (via `ZipUtil.crc32`; ohne ZipUtil Hash `'ts-00000000'`). `U.srcByHash(hash)` (util.js:267-270).
- `U.getFileSearch(srcId)/setFileSearch(srcId,data)` (util.js:273-278)
- `U.getOcr(srcId,page)/setOcr(srcId,page,text)` (util.js:281-286) — Key `ocrText`, GLOBAL (nicht in PROJECT_KEYS!)
- `U.getFnEdits()/setFnEdit(num,text)` (util.js:408-413)
- `U.getDlStatus(srcId)/setDlStatus(srcId,data)` (util.js:416-421)
- `U.getNote(srcId)/setNote(srcId,text)` (util.js:550-555) — Key `srcNotes`
- `U.getSrcDoc/setSrcDoc/clearSrcDoc(srcId)` (util.js:561-567) — Key `srcDoc`
- `U.getSrcExtras/setSrcExtras/addSrcExtra/removeSrcExtra(srcId,…)` (util.js:574-585); `U.extraKey(srcId)` (util.js:586) → `'<srcId>~x' + Date.now().toString(36) + rand(0..1295).toString(36)`
- `U.getSrcText(srcId)/setSrcText(srcId,text)` (util.js:590-595) — Key `srcTexts`
- `U.getPdfManual()/setPdfManual(id,v)` (util.js:599-600); `U.pdfStatusCache` (In-Memory); `U.detectPdf(id)` async (util.js:601-611): 1. `PdfStore.has(id)` → true, 2. Cache, 3. manuell markiert → true, 4. `file:` → `null` (unbekannt), 5. `HEAD sources/<id>.pdf` → r.ok.
- `U.findBeleg(num)` (util.js:614-623) — Beleg `{num, claim, fundstelle, suchHinweis, quellen}` aus `DATA_SECTIONS[fileIdOf(sectionId)].paragraphs[].belege[]`.

**UI-Bausteine:**
- `U.modal(title, bodyHtml)` / `U.closeModal()` / `U._escClose` / `U._modalCleanup` (util.js:647-667) — Details §6.
- `U.showTip(html,x,y)` / `U.hideTip()` / `U.tip` (util.js:670-679) — Chart-Tooltip `div.viz-tip` am `document.body`; Position `x+14/y+14`, geklemmt auf Viewport minus 10 px.
- `U.resizer(handle, opts)` (util.js:686-719) — universeller Drag-Resizer, Details §6.
- `U.dossierModal(srcId)` (util.js:425-442), `U.noteModal(srcId, onDone)` (util.js:446-464) — Details §6.
- `U.srcHeadHtml(srcId, opts)` (util.js:469-480), `U.srcTags(srcId)` / `U.srcTagsHtml(srcId,max=4)` (util.js:483-498), `U.srcStripHtml(srcId)` (util.js:504-513) — Quellen-Darstellungsbausteine, Details §4.
- `U.linkKind(url)` (util.js:517-523) → `'file'` wenn URL auf `\.pdf($|[?#])`, `/pdf(/|$)`, `arxiv.org/pdf` oder `(download|fulltext|pdfdirect|epdf|viewcontent)` matcht, sonst `'page'`; leer → `null`.
- `U.matchFilename(filename)` (util.js:526-547) → `{id, score, sure}` oder `null`. Scoring: id exakt +100, id-Teilstring +50, Titel-Token-Überlappung bis +40 (`40 * hits/min(8, titleTokens)`), Autor-Nachname +25, Jahr +15. `null` unter Score 25; `sure` ab 60.
- `U._claudeCfgForm(host, onChange)` (util.js:724-758), `U.claudeConfigModal(onChange)` (util.js:759-767), `U.gptModal(opts)` (util.js:779-908) — Details §6.
- `U.copy(text)` async (util.js:625-634) — Clipboard API, Fallback `document.execCommand('copy')` über temporäres Textarea; gibt immer `true` zurück.
- `U.fetchResolution(id)` async (util.js:637-644) — `data/resolutions/<id>.json` laden (bei `file:` → `null`).
- `U.download(filename, text, type='application/json')` (util.js:910-916) — Blob + unsichtbarer `<a download>`-Klick, URL nach 500 ms revoked.

### Exportiert von app.js
- `showFootnoteModal(num)` (app.js:252-271) — global; wird vom delegierten `.fn-chip`-Klick (app.js:76-81) und von anderen Views aufgerufen.

### Von app.js konsumierte Globals
`Projects` (`.boot()`, `.activeId`, `.DEFAULT`, `.activeName`, `.mergeCustomSources()`), `PdfStore.ready`, `rebuildDataIndexes`, `U` (storeGet/storeSet/esc/srcShort/findBeleg/modal/closeModal/PROJECT_KEYS), `Levels` (`.importState`, `.numsForSource`, `.info`, `.badge`), `window.DATA_THESIS`, `window.DATA_SOURCES`, `Enhance.hub`, `projektArbeitenCard` (aus views_projekt.js), `storeModal` (optional, typeof-Check), `fileShow` (optional), `Studio.mode` (optional), `closeRefMode` (optional), `renderDetailPdf._ctl` (optional), Render-Funktionen: `renderStudio`, `renderDoc`, `renderQuellen`, `renderAnalyse`, `renderProjekt`, `renderHilfe`, `orderedUnits`, `UNIT_INDEX`, `FN_INDEX`, `SRC_BY_ID`, `KIND_LABELS`.

### Von util.js konsumierte Globals
`window.DATA_SOURCES`, `window.DATA_THESIS`, `window.DATA_SECTIONS`, `window.DATA_FIGURES`, `Levels.info` (typeof-geprüft, util.js:178), `ZipUtil.crc32` (typeof-geprüft, util.js:263), `PdfStore.has` (typeof-geprüft, util.js:603 — Achtung Kommentar: PdfStore ist Skript-`const`, NICHT `window.PdfStore`), `ClaudeAI` (typeof-geprüft: `.cfg/.setCfg/.MODELS/.DEFAULTS/.isDemo/.ready/.estimate/.model/.fmtUsd/.fmtTok/.run/.clean`), `CSS.highlights`/`Highlight` (Feature-Detect).

### gate.js
Exportiert nichts; reine IIFE. Konsumiert nur `crypto.subtle`, `localStorage`, DOM.

---

## 3. State & Persistenz

### Key-Schema (util.js:195-211)
Alle Zugriffe laufen über `U.storeGet(key, fallback)` / `U.storeSet(key, val)` (JSON-serialisiert; Lese-/Schreibfehler werden verschluckt → fallback bzw. No-op). Der reale localStorage-Key entsteht in `U._storeKey` (util.js:202-205):

```
'ehds.' + (U.storeProject && key ∈ U.PROJECT_KEYS ? U.storeProject + '.' : '') + key
```

- `U.storeProject` (util.js:199): `''` für die eingebaute Standard-Arbeit (unpräfixierte Alt-Schlüssel `ehds.<key>`), sonst die Projekt-id → `ehds.<projId>.<key>`. Wird von `Projects` gesetzt.
- **`U.PROJECT_KEYS`** (util.js:200-201) — exakt diese 26 Keys sind pro Arbeit getrennt:
  `belegLevels, annotations, resolutions, pdfManual, linkOverrides, srcNotes, srcTexts, texEdits, pdfMarks, customSources, kiConnections, textMentions, fileSearch, dlStatus, paraDock, paraEdits, dockBySection, marksExtra, notebook, studioLast, assignDismissed, fnEdits, belegSpans, titleEdits, srcDoc, srcExtras`
- Alle NICHT gelisteten Keys sind global (UI-Einstellungen, OCR, Theme …).

### In diesem Modul-Set gelesene/geschriebene Keys

| Key (logisch) | Scope | Form + Beispiel | Lesen/Schreiben |
|---|---|---|---|
| `theme` | global (`ehds.theme`) | `"light"` \| `"dark"` \| `null` | app.js:67 lesen beim Boot; app.js:71 schreiben bei jedem Klick auf `#themeToggle` |
| `belegstandImported` | global | `true` | app.js:25 lesen, app.js:34 schreiben (einmaliger Repo-Import) |
| `studioLast` | projekt | `"3.2"` (sectionId) | app.js:152-154/236-237 lesen (Cmdk + Alt-Routen-Fallback); geschrieben von views_studio.js |
| `annotations` | projekt | `{"ehds-vo":[{"footnote":12,"seite":"S. 4","zitat":"…","kommentar":"","status":"ok"}]}` | util.js:214-223 |
| `resolutions` | projekt | `{"ehds-vo":{"sourceId":"ehds-vo", …KI-Resolution-JSON}}` | util.js:226-231 |
| `linkOverrides` | projekt | `{"ehds-vo":{"official":"https://…","file":"https://…/x.pdf"}}` | util.js:236-252 |
| `fileSearch` | projekt | `{"kim2023":{"venue":"JMIR","publisher":"JMIR","openAccess":true,"problem":null}}` | util.js:273-278 |
| `ocrText` | **GLOBAL** (`ehds.ocrText`) | `{"kim2023":{"3":"erkannter Seitentext …"}}` (je Quelle je Seite) | util.js:281-286 |
| `belegSpans` | projekt | `{"12":2}` (fnNum → Zahl zusätzlicher Sätze, ≥0) | util.js:381-386 |
| `fnEdits` | projekt | `{"12":"Neuer Fußnotentext"}` | util.js:408-413; angewendet in rebuildDataIndexes (util.js:985-990) |
| `dlStatus` | projekt | `{"kim2023":{"ok":false,"note":"Paywall"}}` | util.js:416-421 |
| `srcNotes` | projekt | `{"kim2023":"Meine Notiz …"}` (leer → Key gelöscht) | util.js:550-555; noteModal |
| `srcDoc` | projekt | `{"gtelg2012":{"kind":"link","url":"https://ris.bka.gv.at/…"}}` oder `{"kind":"image"}` | util.js:561-567 |
| `srcExtras` | projekt | `{"kim2023":[{"kind":"pdf","key":"kim2023~xltz4a3f","name":"Anhang.pdf"},{"kind":"link","url":"https://…","name":"Projektseite"}]}` | util.js:574-585 |
| `srcTexts` | projekt | `{"gtelg2012":"§ 1. (1) Dieses Bundesgesetz …"}` | util.js:590-595 |
| `pdfManual` | projekt | `{"ehds-vo":true}` | util.js:599-600 |
| `paraEdits` | projekt | `{"p-3-2-4":"Neuer Absatztext … [^12]"}` | gelesen in rebuildDataIndexes (util.js:953, 977-981); geschrieben vom Editor |
| `titleEdits` | projekt | `{"ch3":"Neuer Kapiteltitel","3.2":"Neuer Abschnittstitel"}` (Kapitel-Key = `'ch'+num`) | gelesen util.js:958-974; geschrieben vom Studio-Baum |
| (Resizer-Keys, variabel) | je Aufrufer | Zahl (px, gerundet) oder `null` | util.js:707/716 (`U.resizer` mit `opts.store`) |
| `ehds.gateOk` | global, **RAW** (nicht via storeGet — direkte Strings!) | der GATE_HASH-Hex-String | gate.js:22 lesen, gate.js:46 schreiben |

**In-Memory-State:** `U._shortCache` (srcShort-Cache), `U._srcPatCache` (Quellen-Patterns), `U._hashCache` (srcHash), `U.pdfStatusCache` (PDF-HEAD-Ergebnisse), `U.tip` (Tooltip-DOM-Knoten), `U._modalCleanup` (Aufräum-Hook des offenen Modals). `_shortCache`/`_srcPatCache` werden in `rebuildDataIndexes` geleert (util.js:948-949); `_hashCache` und `pdfStatusCache` NICHT (Risiko bei Projektwechsel mit customSources → §9).

Zusätzlich mutiert `rebuildDataIndexes` die DATA-Objekte selbst: `p._orig`, `f._origText`, `ch._origTitle`, `u._origTitle` als Sicherungskopien vor Overrides (util.js:959-996).

---

## 4. UI-Struktur & Layout

### Grundgerüst (index.html:21-57)
```
body
├─ header.topbar
│  ├─ a.skip-link[href="#app"]                      „Zum Inhalt springen“
│  ├─ a.brand[href="#/studio"]
│  │  ├─ span.brand-badge                            „TS“
│  │  └─ span.brand-text  „Thesis Studio“ + span.brand-sub „Quellen- & Belegarbeit“
│  ├─ nav.mainnav
│  │  ├─ a[href="#/studio"][data-nav=studio]         „Studio“
│  │  ├─ a[href="#/quellen"][data-nav=quellen]       „Quellen“
│  │  ├─ a[href="#/projekt"][data-nav=projekt]       „Status“
│  │  ├─ a[href="#/hilfe"][data-nav=hilfe]           „Hilfe“
│  │  └─ a[href="#/analyse"][data-nav=analyse].nav-wissen  „Wissen“
│  └─ div.topbar-actions
│     ├─ button.magic-top#gptBtn        span.mt-lb „Generate GPT“
│     ├─ button.btn.btn-ghost.btn-sm.ta-btn#cmdkBtn  span.ta-ic „🔍“ + span.ta-lb „Suchen“
│     ├─ a.btn.btn-ghost.btn-sm.ta-btn#docBtn[href="#/doc"]  span.ta-ic „▤“ + span.ta-lb „PDF Dokument“
│     ├─ button.btn.btn-ghost.btn-sm.ta-btn#storeBtn span.ta-ic „🗄“ + span.ta-lb „Speicher“
│     ├─ button.work-switch#worksBtn
│     │  ├─ span.ws-ic „🗂“
│     │  ├─ span.ws-body > span.ws-label „Arbeit“ + span.ws-name#worksName (Boot-Platzhalter „…“)
│     │  └─ span.ws-caret „▾“
│     ├─ button.btn.btn-ghost.btn-sm.theme-btn#themeToggle  „◐“
│     ├─ div#worksPop.works-pop[hidden]   (Dropdown; Inhalt = projektArbeitenCard())
│     └─ div#gptPop.gpt-pop[hidden]       (Dropdown; Inhalt = Enhance.hub())
├─ main#app            (Router-Ziel; initial div.loading „Lade …“)
├─ footer.footer
│  ├─ span „Thesis Studio — KI-gestützte Quellen- und Belegarbeit für wissenschaftliche Arbeiten“
│  └─ span mit Links: „Bibliothek“(#/quellen) · „Status“(#/projekt) · „Wissen“(#/analyse) · „Hilfe“(#/hilfe)
├─ div#enhRoot         (Enhance-Overlays)
├─ div#modalRoot       (U.modal)
└─ div#cmdkRoot        (Command-Palette)
```
Aktiver Nav-Link erhält Klasse `active` (app.js:221-222); `view==='home'` oder leer aktiviert „Studio“. `main#app` bekommt bei der Wissen-Route von deren Renderer die Klasse `wissen-page`, die der Router bei jedem Wechsel entfernt (app.js:224).

### Gate-Overlay (gate.js:27-58)
```
html.gated                       (Klasse solange Gate aktiv)
└─ div.gate                      (Vollbild-Overlay, an body angehängt)
   └─ form.gate-card
      ├─ span.gate-logo          „TS“
      ├─ h1                      „Thesis Studio“
      ├─ p                       „Zugang geschützt — Passwort einmal eingeben, dieser Browser bleibt danach angemeldet.“
      ├─ input[type=password][placeholder="Passwort"][aria-label="Passwort"][autofocus][autocomplete=current-password]
      ├─ button.btn.btn-primary[type=submit]  „Öffnen“
      └─ span.gate-err[role=alert]            (Fehlertext; Klasse .shake für Animation)
```

### Modal (util.js:648-659)
```
div#modalRoot
└─ div.modal-back                          (Backdrop; Klick auf sich selbst schließt)
   └─ div.modal[role=dialog][aria-modal=true]
      ├─ div.modal-h > h3 {title, HTML erlaubt!} + button.btn.btn-ghost.x[aria-label=Schließen] „✕“
      └─ div.modal-b {bodyHtml}            (Rückgabewert von U.modal)
```

### Command-Palette (app.js:172-176)
```
div#cmdkRoot
└─ div.cmdk-back                          (Backdrop; Klick schließt)
   └─ div.cmdk
      ├─ input[type=text][placeholder="Abschnitt, Quelle oder Ansicht suchen …"][autofocus]
      ├─ div.cmdk-list
      │  ├─ div.cmdk-item[.sel][data-n]   > span.t {Titel} + span.k {Kategorie}
      │  └─ (leer:) div.cmdk-empty        „Nichts gefunden.“
      └─ div.cmdk-hint  <kbd>↑↓</kbd> wählen · <kbd>↵</kbd> öffnen · <kbd>Esc</kbd> schließen
```
Maximal 40 Treffer (app.js:184). Auswahl-Markierung Klasse `sel`.

### GPT-Dropdown-Positionierung (app.js:126-131)
`#gptPop` wird absolut positioniert: `style.left = gptBtn.offsetLeft + 'px'`; ragt es rechts über `window.innerWidth - 8` hinaus, wird `left` um den Überstand reduziert.

### Quellen-Bausteine (util.js)
- `U.srcHeadHtml` (util.js:469-480):
```
div.src-head[.compact]
├─ div.row (gap:6px, flex-wrap:wrap)
│  ├─ span.chip  {KIND_ICON} {KIND_LABEL || kind || 'Quelle'}
│  ├─ span.chip  {Jahr}                (optional)
│  ├─ code       {id}
│  └─ span.chip.warn „＋ manuell“      (nur wenn s.custom)
├─ div.sh-title  {Titel in Serif}
└─ p.small.mut.sh-sub  {Autor · DOI-Link}   (Autor-Fallback: longTitle, wenn weder author noch doi)
```
- `U.srcTagsHtml` (util.js:495-498): `span.stag.{venue|publisher|oa|paywall|problem}`; Labels: `veröffentlicht: <venue>`, `Publisher: <p>`, `Open Access`, `Paywall`, `⚠ <problem>`; Kürzung auf 45 Zeichen + `…` ab Länge > 46. Max. 4 Tags (Default).
- `U.srcStripHtml` (util.js:504-513): `span.src-strip > span.ss-id > b.ss-title {Titel} + span.ss-sub {Autor · Jahr}`; title-Attribut = `Titel — Autor · Jahr`.

### gptModal-Layout (util.js:781-802)
```
div.modal-b
├─ p.small.mut {opts.what}
├─ {opts.extra}                            (freies HTML des Aufrufers)
├─ div.ai-bar
│  ├─ button.ai-magic#gmMagic  > span.aim-body > span.aim-main „Mit Claude ausführen“ + span.aim-sub#gmCost
│  └─ div.ai-tools
│     ├─ button.ai-chip#gmCopy „⧉ Prompt“
│     ├─ button.ai-chip#gmEdit „✎ Bearbeiten“
│     └─ button.ai-chip#gmCfg  „⚙“
├─ div.ai-cfg#gmCfgPanel[hidden]           (Claude-Konfig-Formular, inline)
├─ textarea.ai-prompt#gmPrompt[hidden]     (Prompt-Editor)
├─ div.ai-run#gmRun[hidden]                (Statuszeile: .working/.done/.demo/.err)
├─ textarea#gmJson  (min-height:110px; font-family:var(--font-mono); font-size:12px)
└─ div.row (margin-top:8px)
   ├─ button.btn.btn-sm.btn-primary#gmGo „⭱ Übernehmen“
   ├─ label.btn.btn-sm „Datei laden“ + input[type=file hidden]#gmFile   (accept: application/json,text/markdown,.md,.json,.txt; entfällt bei opts.file===false)
   └─ span.small.mut#gmImpMsg               (Erfolg .small.ok / Fehler .small.err)
```

### Claude-Konfig-Formular (util.js:727-742)
`div.cc-grid` mit: `label.cc-full` „Eigener API-Key“ + `input[type=password]#ccKey` (Placeholder „sk-ant-… (bleibt in diesem Browser)“), `label` „Modell“ + `select#ccModel` (Optionen `{label} · {tier} (${in}/${out})`), `label` „max. Antwort-Tokens“ + `input[type=number]#ccMax` (min 1024, step 512), `label.cc-full` „Basis-URL (eigener Proxy — hält den Key serverseitig)“ + `input#ccUrl`, Checkbox `#ccThink` „Tiefes Denken (adaptiv — nur Opus/Sonnet/Fable, etwas teurer & besser)“, Checkbox `#ccDemo` „Demo-Modus, solange kein Zugang gesetzt ist (Knopf wirkt „verbunden“, Ablauf wird simuliert)“. Darunter `p.small.mut.cc-note` mit Link `console.anthropic.com` und Status-Span `#ccState`.

Responsive-Verhalten ist ausschließlich CSS-Sache (css/app.css, nicht Teil dieses Dossiers); die JS-Seite erzeugt keine Media-Query-Logik außer der Viewport-Klemmung des GPT-Popups und des Tooltips.

---

## 5. Design-Rohwerte

**Farben (inline in JS/HTML):**
- Theme-Color hell: `#f4f2ec`; dunkel: `#27231d` (index.html:6-7, app.js:64)
- Fußnoten-Blockquote im Modal: `border-left:3px solid var(--accent-line); padding-left:12px; color:var(--ink-2)` (app.js:264)
- Mark-Hintergrund: `--c: var(--cat-<kategorie>)` als CSS-Custom-Property inline (util.js:140)

**Icon-/Symbol-Zeichen (exakt):**
- Topbar: 🔍 (Suchen), ▤ (PDF Dokument), 🗄 (Speicher), 🗂 (Arbeit), ▾ (Caret), ◐/☀/☾ (Theme auto/light/dark, app.js:57)
- Cmdk-Kategorien: ⚒ (Studio), 📚 (Quellen-Bibliothek), ◈ (Wissen), ⚙ (Status & Setup), ▤ (PDF Dokument), ？ (Hilfe — Fullwidth-Fragezeichen U+FF1F, app.js:159)
- KIND_ICONS: 📄 🎤 📐 📊 🌐 🇪🇺 🇦🇹 (util.js:930-932)
- Modals/Buttons: ✕ (Modal schließen), ⧉ (kopieren), ✔ (kopiert-Feedback), ✎ (bearbeiten), ⚙ (Zugang), ⭱ (Übernehmen), ✦ (KI-Chip „vermutet“), ❝ (Zitat), ☰ (Lesemodus-Link), 📚 (Dossier), 📝 (Notizen), 🤖 (Ergänzung), ＋ (manuell-Chip, Fullwidth-Plus U+FF0B), ↗ (extern), ↺ (wiederherstellen, Kommentar), ✓/✗ (Erfolg/Fehler), ⚠ (Problem-Tag)
- Cmdk-Hinweise: ↑↓, ↵, Esc in `<kbd>` (app.js:175)

**Wörtliche UI-Texte (Auswahl der in diesen Dateien definierten):**
- „Zum Inhalt springen“, „Thesis Studio“, „Quellen- & Belegarbeit“, „Studio“, „Quellen“, „Status“, „Hilfe“, „Wissen“, „Generate GPT“, „Suchen“, „PDF Dokument“, „Speicher“, „Arbeit“, „Lade …“ (index.html)
- Footer: „Thesis Studio — KI-gestützte Quellen- und Belegarbeit für wissenschaftliche Arbeiten“ · „Bibliothek · Status · Wissen · Hilfe“
- Tooltips Topbar: „Generate GPT — alle KI-Funktionen an einem Ort: direkt ausführen, Prompt kopieren, Antwort einfügen, Konzept“ · „Suchen und springen (Strg/⌘ K)“ · „PDF Dokument: die ganze Arbeit als EIN Dokument — komplettes LaTeX generieren oder als PDF drucken“ · „Quellen- & Dateispeicher: alle Quellen + nicht zugeordnete Dateien, zuweisen & Quelle aus Datei erstellen“ · „Aktive Arbeit wechseln, neue aus .tex anlegen, Gesamt-Prompt / Analysen / Export“ · „Hell/Dunkel umschalten“ · Theme-Button dynamisch: „Theme: {auto|light|dark} (klicken zum Wechseln)“
- Gate: „Zugang geschützt — Passwort einmal eingeben, dieser Browser bleibt danach angemeldet.“, „Passwort“, „Öffnen“, „Falsches Passwort.“
- Cmdk: „Abschnitt, Quelle oder Ansicht suchen …“, „Nichts gefunden.“, „wählen“, „öffnen“, „schließen“; Einträge: „⚒ Studio — Lesen/Prüfen/Editor“, „📚 Quellen-Bibliothek“, „◈ Wissen — Informationsspeicher“, „⚙ Status & Setup“, „▤ PDF Dokument (ganze Arbeit)“, „？ Hilfe & Anleitung“; Kategorien: „Ansicht“, „Abschnitt“, „Quelle“
- Fußnoten-Modal: Titel „Fußnote {num} {Levels.badge}“; „Was hier belegt wird“, „✦ vermutet: **{fundstelle}**“, „Suche: *{suchHinweis}*“, „Nachgewiesen“, „❝ „{zitat}“ — S. {seite} — {fundstelle}“, „Quelle(n)“, „Abschnitt {id} · Absatz {pid} · im Lesemodus ☰“
- Fehleranzeige Router: „Fehler beim Rendern: {msg}“ (app.js:243)
- richText-Level-Namen (util.js:182): `0:'offen'`, `1:'Stufe 1 · KI-vermutet'`, `2:'Stufe 2 · Original gefunden'`, `3:'Stufe 3 · belegt'`; Chip-Tooltip „Fußnote {n} — {lvlName} · klicken für Beleg“
- Mark-Tooltips: „Quelle: {short} — klicken: hervorheben + in der Quellen-Spalte öffnen“ (util.js:138) · „{CAT_LABEL} — klicken zum Hervorheben“ (util.js:140)
- Mention-Tooltips (util.js:157-159): „Erwähnung — mit Beleg [{fn}] zusammengeführt ({short}) · klicken: Beleg in der Quellen-Spalte öffnen“ · „{Bestätigte|Erkannte} Quellen-Erwähnung — {short}{ (N mögliche Quellen)} · klicken: Quelle in der Quellen-Spalte prüfen“
- Xref-Tooltip: „Zu {Abschnitt|Kapitel} {num} springen“ (util.js:171)
- Dossier-Modal: „📚 Dossier — {title}“, „_Kein Dossier hinterlegt — auf der Quellenseite per 🤖 Ergänzung nachtragbar._“, „Kernpunkte“, „Zitierweise“, „Quellenseite ↗“
- Notiz-Modal: „📝 Notizen — {title(60)}“, Placeholder „Eigene Notizen zu dieser Quelle — bleiben lokal im Browser …“, „✓ gespeichert“
- gptModal: „Mit Claude ausführen“, „Abbrechen“, „⧉ Prompt“, „✔ kopiert“, „✎ Bearbeiten“, „⭱ Übernehmen“, „Datei laden“, „Zugang einrichten →“, „Claude verbindet …“, „Claude denkt …“, „Claude schreibt … {N} Tokens“, „✓ Fertig · {in}→{out} Tokens · {$}“, Demo: „Demo abgeschlossen ({N} Tokens · ~{$}). [Echten Zugang einrichten] für übernehmbare Ergebnisse.“, „Abgebrochen.“, Placeholder-Default „Antwort hier einfügen …“
- claudeConfigModal: Titel „GPT Magic — Zugang einrichten“; Fließtext „Drei Wege zur Magie: **⧉ extern kopieren** (gratis, immer frei) · **🔑 eigener Claude-Key** (unten, bleibt lokal) · **☁ Thesis-Studio AI-Space** (zentral über den Anbieter, ≈ 1 €/Durchlauf — die zugeteilte Adresse als Basis-URL eintragen, sobald verfügbar).“
- CAT_LABELS (util.js:919-923): norm→„Quelle/Rechtsnorm“, frist→„Frist/Datum“, akteur→„Akteur/Institution“, tech→„Technik/Standard“, these→„These/Wertung“, luecke→„Lücke/Problem“, zahl→„Zahl/Menge“, abk→„Abkürzung“, schlag→„Schlagwort“

**Größen (inline):** Notiz-Textarea `min-height:140px` (util.js:449); gmJson `min-height:110px`, `font-size:12px`, `font-family:var(--font-mono)` (util.js:797); Tooltip-Versatz 14 px, Viewport-Rand 10 px (util.js:676-677); GPT-Popup-Randabstand 8 px (app.js:130); Resizer-Defaults min 220 / max 1100 px (util.js:687); worksName max. 46 Zeichen (app.js:49), document.title max. 60 Zeichen Titel (app.js:50); Dossier-Kernpunkte `font-size:13px` (util.js:434). Favicon: Inline-SVG mit Emoji 📖, `font-size:90` (index.html:12).

---

## 6. Verhalten & Interaktionen

### Boot-Sequenz (app.js:6-50)
1. `Projects.boot()` (aktive Arbeit + `U.storeProject` setzen; Fehler → console.error, App läuft weiter).
2. `await PdfStore.ready` (verhindert Race: zugeordnete PDFs würden sonst kurz als fehlend angezeigt, Kommentar app.js:9-11).
3. `rebuildDataIndexes()`.
4. `navigator.storage.persist()` (best effort, iPad/Safari).
5. **Belegstand-Import** (app.js:23-41): NUR wenn `Projects.activeId === Projects.DEFAULT` UND nicht `file:`-Protokoll UND `belegstandImported` nicht gesetzt UND in KEINEM `PROJECT_KEYS`-Store (außer `studioLast`) lokal Daten liegen (Array mit Länge, Objekt mit Keys oder truthy Wert). Dann `fetch('data/belegstand.json')` → `Levels.importState(text)` → `belegstandImported=true` → `Projects.mergeCustomSources()` → `rebuildDataIndexes()` → console.info. Fetch-Fehler still ignoriert (Datei optional).
6. Topbar: `#worksName` = Meta-Titel der Arbeit (`DATA_THESIS.meta.title`, außer „Unbenannte Arbeit“ → dann `Projects.activeName`), gekürzt auf 46 Zeichen, voller Titel im title-Attribut. `document.title` = „Thesis Studio — {Titel(60)}“.

### Theme-Umschalter (app.js:52-73)
Zyklus bei Klick: `null (auto) → 'light' → 'dark' → null`. Anwendung: `data-theme`-Attribut auf `<html>` setzen (light/dark) bzw. entfernen (auto). Button-Zeichen: auto `◐`, light `☀`, dark `☾`. Zusätzlich werden ALLE `meta[name=theme-color]` entfernt und EIN neues gesetzt: dunkel `#27231d`, hell `#f4f2ec` (dunkel = explizit dark ODER auto + `prefers-color-scheme: dark`). Persistenz Key `theme`.

### Globale Klick-Delegation (app.js:76-99)
1. `.fn-chip`-Klick (Fußnoten-Chip überall im Text): preventDefault + stopPropagation → `showFootnoteModal(Number(chip.dataset.fn))`.
2. Klick auf `mark.hl`, `.mk-src` oder `.mention[data-src]`: toggelt Klasse `lit` (Hervorhebung an/aus). Wenn dadurch AN und Element hat `data-src` und ist NICHT `mark.hl` und `fileShow` existiert und `Studio.mode === 'pruefen'`: `fileShow(srcId, Number(data-fn) || Levels.numsForSource(srcId)[0])` — öffnet die Quelle (bzw. bei zusammengeführter Erwähnung direkt deren Fußnote) in der Quellen-Spalte.

### Arbeiten-Dropdown (app.js:103-115)
Klick auf `#worksBtn`: stopPropagation; `#gptPop` schließen; wenn offen → schließen; sonst `#worksPop` leeren, `projektArbeitenCard()` (aus views_projekt.js) anhängen, anzeigen. Dokumentweiter Klick außerhalb von Pop+Button schließt.

### GPT-Hub (app.js:119-138)
Klick auf `#gptBtn`: stopPropagation; `worksPop` schließen; Toggle; beim Öffnen `Enhance.hub(gptPop)` rendern, `left = gptBtn.offsetLeft`, danach Klemmung: ragt `getBoundingClientRect().right` über `innerWidth - 8`, wird left um den Überstand verringert. Outside-Klick schließt. Bei `hashchange` wird der Hub geschlossen (Kontext wird beim nächsten Öffnen neu abgeleitet, app.js:138).

### Speicher-Button (app.js:141)
Klick → `storeModal()` (falls definiert; aus views_quellen.js).

### Command-Palette (app.js:143-207)
Öffnen: Klick `#cmdkBtn` ODER `Strg/⌘+K` (keydown, `e.key.toLowerCase()==='k'`, preventDefault). Einträge (`cmdkItems`, app.js:150-168): 8 feste Ansichten (Studio Lesen/Prüfen/Editor nutzen `studioLast` oder `orderedUnits()[0]` als Ziel-Abschnitt), dann alle Abschnitte (`{id} {Titel}` — bei `unit.isIntro` der Kapiteltitel), dann alle Quellen (`{srcShort} — {title}`). Verhalten:
- Tippen filtert case-insensitive per `includes` auf dem Titel, max. 40 Treffer, Auswahl-Reset auf 0.
- `↓`/`↑` bewegen `sel` (geklemmt), `↵` öffnet (`location.hash = go`), Klick auf Eintrag öffnet.
- `Escape` wird mit Capture-Listener (`stopImmediatePropagation` + preventDefault) abgefangen — schließt NUR die Palette, nichts darunter (app.js:191-196).
- Klick auf Backdrop (`e.target === back`) schließt.
- Fokus aufs Input nach 10 ms Timeout (app.js:206).

### Router (app.js:210-248)
Bei jedem `hashchange` und einmal initial:
1. `closeRefMode()` (falls vorhanden).
2. PDF-Viewer der Quellen-Detailseite freigeben: `renderDetailPdf._ctl?.destroy?.(); renderDetailPdf._ctl = null` (verhindert lebende pdf.js-Worker/Observer nach DOM-Tausch, app.js:212-217).
3. Hash parsen: `#/a/b/c/d` → parts; `view = parts[0] || 'studio'`; Parts 1-3 werden `decodeURIComponent`-dekodiert. Part 3 = Absatz-Anker (`#/studio/<sec>/<modus>/<absatz>`).
4. Nav-Active setzen; `app.innerHTML=''`; Klasse `wissen-page` entfernen.
5. Dispatch (in try/catch):
   - `studio` | `home` | `''` → `renderStudio(app, p1, p2, p3)`
   - `doc` → `renderDoc(app)`
   - `quellen` → `renderQuellen(app, p1)`
   - `analyse` → `renderAnalyse(app, p1, p2)`
   - `projekt` → `renderProjekt(app)`
   - `hilfe` → `renderHilfe(app, p1)`
   - **Alt-Routen (V1/V2), Redirect per Hash-Zuweisung + return:**
     - `lesen` → `#/studio/<p1>/lesen`, ohne p1 → `#/studio/<studioLast || orderedUnits()[0]>/lesen`
     - `editor` → `#/studio/<p1>/editor`, ohne p1 analog
     - `explorer` → `#/studio/<p1>` bzw. `#/studio`
     - `zusammenfassung` → `#/analyse`
   - unbekannt → `renderStudio(app, null, null)`
6. Renderfehler → `app.innerHTML = '<div class="notice">Fehler beim Rendern: …</div>'` + console.error.
7. `window.scrollTo(0, 0)`.

### Fußnoten-Modal (app.js:252-271)
`showFootnoteModal(num)`: kein Eintrag in `FN_INDEX` → No-op. Titel: `Fußnote {num} {Levels.badge(level)}` (Badge-HTML unescaped in h3!). Quellenliste: `beleg.quellen` falls vorhanden, sonst `fn.sources`. Inhalt in fester Reihenfolge: Blockquote Fußnotentext → optional „Was hier belegt wird“ + claim → optional KI-Chip „✦ vermutet: fundstelle“ + Such-Hinweis → bei Level ≥ 2 mit Zitat: „Nachgewiesen“ + „❝ „zitat“ — S. seite — fundstelle“ → „Quelle(n)“-Liste (Links zu `#/quellen/<id>` mit `onclick="U.closeModal()"`, Chip mit KIND_LABEL; leer → `<li>—</li>`) → Fußzeile mit Links zu `#/studio/<sec>/pruefen` und `#/studio/<sec>/lesen`.

### Gate (gate.js)
Ablauf: WebCrypto fehlt → Gate aus. `localStorage.getItem('ehds.gateOk') === GATE_HASH` → Gate aus; localStorage-Zugriff wirft → Gate aus (App nutzbar!). Sonst Overlay (sofort bzw. bei `DOMContentLoaded`). Submit: `SHA-256(GATE_SALT + eingabe)` als Hex; Treffer → Key speichern (Fehler ignoriert), Overlay entfernen, `html.gated` entfernen. Fehlschlag → Fehlertext „Falsches Passwort.“, Shake-Animation neu triggern (Klasse entfernen → `requestAnimationFrame` → wieder setzen), `input.select()`. Konstanten: `GATE_SALT='thesor-gate-v1|'`, `GATE_HASH='593978b8d47d12529c765c73b5204f46fd1f38b7bbb76126f43bd47154b838d0'`, `KEY='ehds.gateOk'` (gate.js:15-17).

### U.richText — Renderpipeline (util.js:114-186)
Reihenfolge ist verhaltensrelevant:
1. **Fußnoten-Platzhalter:** `[^N]` → `\x01<laufindex>\x01` (Steuerzeichen U+0001 als Sentinel — im Quelltext unsichtbar!), Nummern in Array `fns` gesammelt (util.js:120). Verhindert, dass Marks/Xrefs die Marker zerschneiden.
2. `U.esc` auf den ganzen Text.
3. **Marks** (`opts.marks`, gefiltert nach `activeCats`-Set falls gesetzt), längste Snippets zuerst; pro Snippet erstes `indexOf` im HTML, bereits abgedeckte (Teil eines schon gesetzten) übersprungen. Kategorie `norm` → nur wenn `matchSourceInText` eine echte Register-Quelle liefert: `<span class="mk-src" data-src …>`; sonst verworfen. Andere Kategorien → `<mark class="hl" data-cat="…" style="--c: var(--cat-…)">`.
4. **Mentions** (`opts.mentions`), nach `start` sortiert, Suche mit fortlaufendem Anker `mFrom` (identische Snippets treffen je die EIGENE Stelle): `<span class="mention {merged|bestaetigt|offen}" data-src="…" [data-fn="…"]>`; Status `'beleg'` erhält die Darstellungsklasse `merged` und `data-fn`.
5. **Querverweise** (nur mit `opts.xrefBase`): `Abschnitt 3.2`/`Kapitel 5` → `<a class="xref" href="{xrefBase}{target}">`; `Kapitel N` zielt auf `N.0`; ohne `UNIT_INDEX`-Eintrag bleibt Text unverändert.
6. **Platzhalter → Chips:** `/\x01(\d+)\x01/g` → `<sup class="fn-chip [mini] lv{level}" data-fn="{n}" title="Fußnote {n} — {lvlName} · klicken für Beleg"><span class="fnl"></span>{n}[<span class="fns">{srcShort}</span>]</sup>`. Level via `Levels.info(n).level` (0 ohne Levels-Modul). `fnStyle:'mini'` (Lesemodus) → Zusatzklasse `mini`; `showSrc` (Default: true bei `'chip'`) blendet den Quellen-Kurznamen ein (erste Quelle aus `FN_INDEX[n].sources`).

### U.splitSentences (util.js:302-330)
Regex `[.!?]+[”“"’')\]]*` als Satzend-Kandidat; verworfen wenn: Wort davor ist Einzel-Großbuchstabe (Initial, außer A/I), oder in Abkürzungsliste `et al, al, e.g, i.e, cf, vs, ca, approx, etc, Fig, Tab, Eq, No, Nr, Dr, Prof, Mr, Mrs, Ms, St, Art, Abs, Abschn, Kap, bzw, inkl, ggf, zit, Aufl, Hrsg, Ed, eds, vgl, Vgl, sog, resp` (case-insensitive); direkt anschließende `[^N]`-Marker gehören noch zum Satz; danach muss Leerraum oder Textende folgen („3.1“ bleibt ganz); der Folgetext muss mit `A-ZÄÖÜ0-9„“"([` beginnen. Rest-Text am Ende wird als letzter Satz angehängt.

### Modal-System (util.js:647-667)
`U.modal` schließt zuerst per `U._modalCleanup?.()` ein evtl. offenes Modal (Aufrufer können dort Teardown registrieren), rendert in `#modalRoot`, registriert: Backdrop-Klick (nur `e.target === back`), ✕-Button, `keydown`-Escape (Document-Listener `U._escClose` — `stopPropagation`, damit darunterliegende Esc-Handler nicht feuern). `closeModal` räumt Listener + `_modalCleanup` ab und leert `#modalRoot`. Es gibt immer max. EIN Modal (kein Stapeln). Rückgabe: das `.modal-b`-Element für Nachverdrahtung.

### U.resizer (util.js:686-719)
Pointer-basiert (Pointer Capture auf dem Handle, nur Haupttaste): `pointerdown` merkt Startposition `p0` und `w0 = read()`; `pointermove` setzt `apply(clamp(min,max, w0 + (p-p0)*dir))`; letzter Wert wird in `lastPx` gehalten (read() wäre während CSS-Transitionen falsch, Kommentar util.js:693). Während des Drags: `body.resizing` (+ `body.resizing-y` bei `axis:'y'`). `pointerup/-cancel`: Listener lösen, bei `opts.store` gerundeten Wert per storeSet persistieren, `opts.done?.()`. **Doppelklick** aufs Handle: `apply(null)` (Standardbreite) + Store auf `null` + done. Defaults: `min=220, max=1100, dir=1, axis='x'`.

### U.gptModal — Ablauf (util.js:779-908)
- `refreshCost` (util.js:813-822): ohne ClaudeAI leer; `magicBtn` erhält `.unset` wenn `!ClaudeAI.ready()` (ausgegraut nur wenn Demo aus & kein Key), `.demo` wenn Demo-Modus; Kostenzeile `≈ {$} · {Modell}[ · Demo]` bzw. „Zugang einrichten →“.
- ⧉ Prompt: kopiert `effPrompt()` (Override oder `opts.buildPrompt()`); Button zeigt 1500 ms „✔ kopiert“.
- ✎ Bearbeiten: Toggle des Prompt-Textareas; bearbeiteter Text gilt für Kopieren UND Senden (`promptOverride`; identisch mit buildPrompt() → Override wieder null); Button-Klasse `on`.
- ⚙: Konfig-Panel inline auf-/zuklappen (`U._claudeCfgForm`), Klasse `on`.
- ✦ Magic-Klick: nicht ready → Konfig öffnen + `#ccKey` fokussieren. Laufend → `aborter.abort()` (zweiter Klick bricht ab). Sonst: `busy`-Klasse, Label „Abbrechen“, Statuszeile `.working` „Claude verbindet …“ → `onThink`: „Claude denkt …“ → `onUsage`: „Claude schreibt … {N} Tokens“; gestreamter Text landet live im `#gmJson` (autoscroll). Demo-Ergebnis: Status `.demo`, KEIN Auto-Import (ehrlich gekennzeichnet + Inline-Button „Echten Zugang einrichten“). Echt: `ClaudeAI.clean()` auf die Antwort, Status `.done` „✓ Fertig · in→out Tokens · $“, dann automatisch `doImport`. Fehler: AbortError → „Abgebrochen.“; sonst `.err` „✗ {msg}“. Finally: Zustand zurücksetzen.
- `doImport(text)` (util.js:824-832): `opts.onImport(text)` (wirft bei Fehler); Erfolg → `#gmImpMsg` „✓ {Text}“ Klasse `small ok`, nach 800 ms `closeModal()` + `opts.onDone?.()`; Fehler → „✗ {msg}“ Klasse `small err`.
- ⭱ Übernehmen: manueller `doImport` des Textfelds. „Datei laden“: Dateiinhalt → `doImport`.
- noteModal: speichert beim Tippen mit 400 ms Debounce, zeigt 1200 ms „✓ gespeichert“ (util.js:452-463). dossierModal: ⧉-Button kopiert Zitierweise, zeigt 1200 ms „✔“ (util.js:437-441).

### rebuildDataIndexes (util.js:944-1001)
1. Alle 5 Index-Objekte in-place leeren (Referenzen bleiben gültig — wichtig, da Module sie direkt importiert halten).
2. `U._shortCache = {}`, `U._srcPatCache = null`.
3. `SRC_BY_ID` aus `window.DATA_SOURCES` füllen.
4. Overrides laden: `paraEdits`, `fnEdits`, `titleEdits` — und auf die DATA-Objekte ANWENDEN, mit Original-Sicherung (`p._orig`, `f._origText`, `ch._origTitle`/`u._origTitle`); entfernte Overrides stellen das Original wieder her (relevant beim Projektwechsel, util.js:980-981).
5. Rekursiv über `DATA_THESIS.chapters[].sections[]` (+ `children`): `UNIT_INDEX[u.id] = {unit, chapter}`; je Absatz je Fußnote `FN_INDEX[f.num] = {...f, sectionId: u.id, paragraphId: p.id}`.
6. `FIG_BY_PARA`/`TAB_BY_PARA` aus `DATA_FIGURES.figuren/tabellen` nach `paragraphId`.
Wird beim Skriptladen sofort ausgeführt (util.js:1002) und nach jedem Projektwechsel/Datenimport erneut.

---

## 7. Datenformen

```jsonc
// UNIT_INDEX-Eintrag (util.js:975)
{ "unit": { "id": "3.2", "title": "…", "isIntro": false, "paragraphs": [/*…*/], "children": [/*…*/] },
  "chapter": { "num": 3, "title": "…", "sections": [/*…*/] } }

// FN_INDEX-Eintrag (util.js:991)
{ "num": 12, "text": "Vgl. Kim 2023, S. 4.", "sources": ["kim2023"],
  "sectionId": "3.2", "paragraphId": "p-3-2-4" }

// Quelle (DATA_SOURCES-Element, von util.js konsumierte Felder)
{ "id": "kim2023", "title": "…", "longTitle": "…", "author": "Kim, J.; Lee, S.",
  "year": 2023, "kind": "artikel",            // Schlüssel von KIND_LABELS
  "doi": "10.1000/xyz", "url": "https://…", "container": "JMIR",
  "links": { "official": "https://…", "file": "https://…/a.pdf" },
  "custom": false,                              // true → Chip „＋ manuell“
  "dossier": "Markdown …", "keyPoints": ["…"], "zitierweise": "Kim 2023, …" }

// Beleg (aus DATA_SECTIONS[fileId].paragraphs[].belege[], util.js:614-623)
{ "num": 12, "claim": "Was hier belegt wird", "fundstelle": "Kap. 4.2",
  "suchHinweis": "wörtliche Passage | zweite Passage", "quellen": ["kim2023"] }

// Levels.info(num) — konsumiert in app.js:256/263-267, util.js:178
{ "level": 2, "zitat": "…", "seite": "4", "fundstelle": "…" }

// Cmdk-Item (app.js:151-166)
{ "t": "⚒ Studio — Lesen", "k": "Ansicht", "go": "#/studio/3.2/lesen" }

// richText-opts (util.js:114)
{ "marks": [{ "snippet": "wörtlicher Ausschnitt", "kategorie": "norm" }],
  "activeCats": null,               // oder Set(['norm','frist',…])
  "fnStyle": "chip",                // 'chip' | 'mini'
  "showSrc": true, "xrefBase": "#/studio/",
  "mentions": [{ "snippet": "Kim et al. (2023)", "start": 120, "status": "beleg",
                  "fn": 12, "srcId": "kim2023", "candidates": ["kim2023"] }] }
                  // status: 'beleg' (zusammengeführt) | 'bestaetigt' | 'offen'

// splitSentences-Ergebnis (util.js:324)
[{ "start": 0, "end": 87, "text": "Erster Satz mit Marker.[^12]" }]

// belegSpan-Ergebnis (util.js:404)
{ "from": 1, "to": 3, "sents": [/*splitSentences*/], "text": "…umfasster Rohtext…" }

// srcLinks-Ergebnis (util.js:244)
{ "official": "https://doi.org/10.1000/xyz", "file": "https://…", "_override": false }

// matchFilename-Ergebnis (util.js:546)
{ "id": "kim2023", "score": 78, "sure": true }

// fileSearch-Eintrag (util.js:273)
{ "venue": "JMIR", "publisher": "JMIR Publications", "openAccess": true, "problem": null }

// dlStatus-Eintrag (util.js:415)
{ "ok": false, "note": "Paywall" }

// srcDoc (util.js:560)  |  srcExtras-Element (util.js:573)
{ "kind": "link", "url": "https://…" }
{ "kind": "pdf", "key": "kim2023~xltz4a3f", "name": "Anhang.pdf" }

// ClaudeAI.cfg() — von _claudeCfgForm gelesene/geschriebene Felder (util.js:726-751)
{ "apiKey": "sk-ant-…", "model": "…", "baseUrl": "https://…",
  "maxTokens": 8192, "deepThink": false, "demo": true }
```

Storage-Formen mit Beispielen: siehe Tabelle in §3.

---

## 8. Abhängigkeiten

**Ladereihenfolge ist hart (index.html:13-79):** gate.js (head, synchron VOR Renderbeginn) → data_* (head) → util.js → claude.js → enhance.js → ziputil.js → levels.js → texparse.js → projects.js → connections.js → mentions.js → stylecheck.js → pdfstore.js → pdfengine.js → figures.js → charts.js → editor.js → views_studio.js → views_quellen.js → notebook.js → views_analyse.js → views_projekt.js → views_hilfe.js → app.js (letztes; startet alles).

- **util.js** hängt ab von: DATA_* (Daten), optional Levels, ZipUtil, PdfStore, ClaudeAI (alle typeof-geprüft, da util.js VOR ihnen lädt — Aufrufe passieren erst zur Laufzeit). `rebuildDataIndexes()` läuft schon beim Laden von util.js (util.js:1002) — zu diesem Zeitpunkt ohne Projekt-Scope (Overrides der Default-Arbeit).
- **app.js** hängt ab von: Projects, PdfStore, Levels, Enhance, U, allen `render*`-Funktionen, `projektArbeitenCard`, optional `storeModal`/`fileShow`/`Studio`/`closeRefMode`/`renderDetailPdf`.
- **Wer ruft dieses Set auf:** alle Views nutzen `U.*`, die Indizes und `KIND_*`/`CAT_*`; `Projects` setzt `U.storeProject` und ruft `rebuildDataIndexes()`; Studio/Editoren rufen `rebuildDataIndexes()` nach Edits; `showFootnoteModal` wird aus Views heraus getriggert (delegierter `.fn-chip`-Klick genügt aber überall).
- Der Router ruft implizit via HTML-`onclick="U.closeModal()"`-Attribute in Modal-Links (app.js:260/270, util.js:436) — U muss global erreichbar sein.

---

## 9. Flutter-Hinweise

1. **Globale Singletons → Services:** `U`, Indizes, `Projects` sind implizite Singletons mit Ladereihenfolge-Abhängigkeit. In Flutter: ein `AppState`/Repository (z. B. via Provider/Riverpod) mit expliziter Boot-Sequenz wie app.js:12-14 (Projekte laden → PDF-Store bereit → Indizes bauen), BEVOR die erste Route rendert (Splash „Lade …“).
2. **Hash-Router:** `go_router` mit Pfaden `/studio/:sec/:mode/:para`, `/quellen/:id`, `/analyse/:a/:b`, `/projekt`, `/hilfe/:a`, `/doc` + Redirects für `lesen|editor|explorer|zusammenfassung` (app.js:236-239). Wichtig: unbekannte Route → Studio-Fallback, KEINE 404. Web-Ziel: Hash-URL-Strategie beibehalten, wenn Deep-Links aus Altdaten (gespeicherte `#/…`-Links in Modals) funktionieren sollen.
3. **localStorage-Layer:** `shared_preferences` reicht für die Key-Struktur; das Prefix-Schema `ehds.[<projekt>.]<key>` und die `PROJECT_KEYS`-Liste (util.js:200-201) MÜSSEN exakt übernommen werden, wenn Datenübernahme aus der Web-App (Export/Import) geplant ist. Alle Werte sind JSON-serialisiert; Fehler werden still geschluckt (Fallback-Semantik nachbauen).
4. **richText:** Der Sentinel-Trick mit U+0001 (util.js:120/176 — im Editor unsichtbar!) und die Insert-Reihenfolge Marks→Mentions→Xrefs→Chips sind verhaltensrelevant (Überschneidungs-Vermeidung, `mFrom`-Anker für identische Mention-Snippets). In Flutter als eigener Parser auf dem ROHEN Text → `TextSpan`/`WidgetSpan`-Baum (Chips als `WidgetSpan` mit `GestureRecognizer`), NICHT als HTML-String. Die Klassiken `lit`-Toggle + „Quelle öffnen nur im Prüfen-Modus“ (app.js:86-99) als State im Span-Modell.
5. **CSS Custom Highlight API** (`U.setHighlight`) hat kein Flutter-Pendant — Belegspannen-Hervorhebung stattdessen über berechnete TextSpan-Hintergründe (splitSentences liefert Rohtext-Offsets; `domRangeFor` entfällt komplett, da man in Flutter direkt auf dem Datenmodell arbeitet).
6. **Modal-System:** Ein-Modal-Semantik (neues Modal schließt altes, `_modalCleanup`) → `showDialog` mit vorherigem `Navigator.pop`, oder eigener Modal-Manager. Die HTML-Titel mit eingebettetem Badge-HTML (app.js:263) brauchen Widget-Titel statt Strings. Esc/Backdrop-Klick-Schließen nachbauen; Cmdk-Escape muss das darunterliegende Modal NICHT schließen (Capture-Semantik app.js:196).
7. **Command-Palette:** eigenes Overlay + `RawKeyboardListener`/`Shortcuts` (Ctrl/Cmd+K), Filterung `contains` lowercase, max. 40, Pfeil-/Enter-Navigation. Achtung: mobile Geräte ohne Tastatur → Button `#cmdkBtn` ist der primäre Zugang.
8. **U.resizer:** `GestureDetector`+`onPanUpdate` bzw. `MouseRegion` mit Persistenz (gerundete px, Doppelklick = Reset auf null). min 220/max 1100 als Defaults übernehmen; die `resizing`-Body-Klasse (Cursor/Userselect) entspricht `MouseCursor`-Wechsel + IgnorePointer während des Drags.
9. **Theme:** Dreiwertiger Zyklus auto/light/dark (Icons ◐ ☀ ☾) → `ThemeMode.system/light/dark`; theme-color-Meta entspricht `SystemChrome.setSystemUIOverlayStyle` (App-Farbe `#f4f2ec`/`#27231d`).
10. **Gate:** SHA-256 via `crypto`-Package trivial; Persistenz-Key `ehds.gateOk` (RAW String, nicht JSON!). Bewusst nur clientseitige Hürde — Verhalten „ohne Crypto/Storage: Gate aus, App nutzbar“ übernehmen oder bewusst entscheiden.
11. **detectPdf-HEAD-Fallback** (`sources/<id>.pdf`, util.js:608) und `fetchResolution`/Belegstand-Import setzen HTTP-Hosting voraus; in Flutter durch Asset-Existenzprüfung bzw. optionalen Remote-Fetch ersetzen. Die `file:`-Sonderfälle (Status „unbekannt“ = null) entfallen bzw. werden zum Offline-Zweig.
12. **Mutierende Indizes:** `rebuildDataIndexes` mutiert die DATA-Objekte (Override + `_orig*`-Backups). In Flutter besser: unveränderliche Quelldaten + berechnete „effektive“ Sicht (Overrides als Map darüber) — das 1:1-Verhalten (Original wiederherstellbar, projektabhängige Overrides) bleibt, ohne Mutation.
13. **Nicht 1:1 portierbar:** `document.execCommand('copy')`-Fallback (→ `Clipboard.setData`), Blob-Download (`U.download` → `file_saver`/Share-Sheet), `navigator.storage.persist()` (entfällt), pdf.js-Teardown im Router (Flutter-eigene Viewer-Lifecycle), Emoji-Flaggen 🇪🇺/🇦🇹 rendern plattformabhängig (Windows zeigt Buchstaben) — ggf. Assets.
14. **server.py / start-website.bat / pages.yml** sind reine Hosting-Infrastruktur ohne App-Logik — für Flutter irrelevant (ersetzt durch Build/Deploy der Flutter-Web- bzw. App-Targets). Einzig relevantes Verhalten: `Cache-Control: no-store` + `?v=24`-Cache-Busting zeigen, dass Update-Sicherheit gewollt ist.
15. **`U.copy` gibt immer `true` zurück** (auch bei Fehlschlag, util.js:625-634) — UI zeigt also immer „kopiert“. Bei 1:1-Konvertierung dieses (fehlertolerante) Verhalten beibehalten oder bewusst verbessern.
