# Inventar-Dossier 05 — PDF-Engine & Bildsystem

Dateien: `js/pdfengine.js` (1374 Z.), `js/figures.js` (110 Z.), `assets/vendor/pdfjs/` (Vendor-Bundle).
Referenzierte Fremd-Module (nur zur Einordnung zitiert): `js/util.js`, `js/levels.js`, `css/app.css`.

---

## 1. Zweck & Rolle

### js/pdfengine.js
Das globale Objekt `PdfEngine` (pdfengine.js:15) ist der komplette PDF-Betrachter der App: Es lädt pdf.js lazy als klassisches Script (kein ES-Modul, damit auch `file://` und falsche MIME-Types funktionieren, Kommentar pdfengine.js:10-12), rendert PDFs als Endlos-Scroll (alle Seiten untereinander, lazy gerendert, ferne Seiten werden aus dem Speicher entlassen), legt über jeden Seiten-Canvas eine pdf.js-Textebene (auswählbarer Text) und darüber eine Markierungs-/Kommentar-Ebene. Textauswahl im „Markieren“-Modus erzeugt eine persistente Markierung in der Farbe des aktiven Belegs (Fußnote) plus automatisch einen Kommentar-Pin am rechten Rand; das Zitat wird per Callback (`onCapture`) in den aktiven Beleg übernommen. Zusätzlich enthält das Modul: die Marks-Persistenz-API (localStorage `ehds.<projekt>.pdfMarks`), Volltextsuche in der Toolbar (lazy Seitentext-Cache inkl. OCR-Fallback), OCR über Tesseract.js (CDN, `deu+eng`), eine PDF→LaTeX-Extraktion (`pdfToTex`, Beta-Heuristik), eine Download-Engine (`tryDownload`) und die überall wiederverwendete „Quell-Karte“ (`assignPanel`) zum Zuordnen von Dateien/Material zu einer Quelle. Es ist damit gleichzeitig Viewer-Engine UND Quell-Datei-Verwaltungs-UI.

### js/figures.js
Bildsystem für die Abbildungen der Arbeit: `FigStore` (figures.js:8) ist ein kleiner IndexedDB-Blob-Store (DB `ehds-figstore`, Store `imgs`) für vom Nutzer hochgeladene Abbildungsbilder. `figureCard(fig)` (figures.js:58) rendert eine Abbildungs-Karte aus dem Manifest `data/figures.json` (`DATA_FIGURES`): Bild aus `figures/<datei>` (Feld `file`) ODER hochgeladenes Bild aus dem FigStore ODER Platzhalter mit Upload-Button. Klick aufs Bild öffnet eine Lightbox (`showLightbox`, figures.js:105). `tableCard(tab)` (figures.js:94) setzt Manifest-Tabellen als echte HTML-Tabellen. Genutzt vom Lesemodus (views_studio.js, views_analyse.js) und vom Notebook.

### assets/vendor/pdfjs
Existiert; enthält genau zwei Dateien: `pdf.min.js` (377 KB) und `pdf.worker.min.js` (1,1 MB) — klassische (non-module) pdf.js-Builds. Worker-Pfad wird in pdfengine.js:25 gesetzt. Die Engine unterstützt sowohl die alte API `lib.renderTextLayer(...)` als auch die neuere `new lib.TextLayer(...)` (pdfengine.js:975-979) — die Version ist also im Bereich pdf.js 3.x–4.x flexibel.

---

## 2. Öffentliche API

### Exportiert (window-Scope)

| Symbol | Signatur | Zweck | Nutzer |
|---|---|---|---|
| `PdfEngine.ensure()` | `() => Promise<pdfjsLib\|null>` (pdfengine.js:19) | pdf.js lazy laden, Worker-Src setzen. Resolved `null` bei Fehlschlag (kein Reject!). | intern (`mount`, `pdfToTex`) |
| `PdfEngine.pdfToTex(data, onProgress)` | `(ArrayBuffer/Uint8Array, (n,total)=>void) => Promise<{tex, pages, headings, footnotes, title}>` (pdfengine.js:51) | PDF→LaTeX-Heuristik (Beta) | views_projekt.js:377 (Import eigener Arbeit) |
| `PdfEngine.marks(srcId)` | `(string) => Mark[]` (pdfengine.js:198) | Alle Markierungen einer Quelle lesen | intern, extern |
| `PdfEngine.addMark(srcId, mark)` | `=> Mark` — ergänzt `id` (`'m'+Date.now().toString(36)+rand3`) und `ts` (pdfengine.js:204-210) | Markierung anlegen + persistieren | intern (mount) |
| `PdfEngine.updateMark(srcId, id, patch)` | `=> Mark\|undefined` (pdfengine.js:212) | Patch per `Object.assign` | intern (Pin-Drag, Popover) |
| `PdfEngine.removeMark(srcId, id)` | (pdfengine.js:218) | Markierung löschen | intern (Popover) |
| `PdfEngine.marksForFn(srcId, fn)` | `=> Mark[]` mit `Number(m.fn)===Number(fn)` (pdfengine.js:221) | Marks einer Fußnote | levels.js:119, views_studio.js:599/1048/1325/1332/1592/1608/1806 |
| `PdfEngine.missingInfo(host, srcId, onDone)` | delegiert an `assignPanel` (pdfengine.js:224) | „keine Datei“-Panel | views_studio.js:2001 |
| `PdfEngine.renderDocView(host, srcId)` | `=> {destroy,search,goto,refreshActive}\|null` (pdfengine.js:229) | Nicht-PDF-Quelle anzeigen (Link-Karte / Bild) | views_studio.js:1369 |
| `PdfEngine.dismissCandidate(srcId, name)` | (pdfengine.js:259) | Kandidat auf „✗ passt nicht“-Liste | intern |
| `PdfEngine.findCandidates(srcId)` | `=> [{name, score, why, sure}]` (pdfengine.js:271) | Inbox-Kandidaten via Referenz-Hash (`U.srcHash`) bzw. exakter id-Dateiname; Dateiname bewusst KEIN Erkennungsmerkmal | intern (assignPanel) |
| `PdfEngine.dlLinkFor(srcId)` | `=> url\|null` (pdfengine.js:287) | Vermuteter Download-Link (`links.file` oder `official` wenn `U.linkKind==='file'`) | intern, views_projekt |
| `PdfEngine.tryDownload(srcId)` | `=> Promise<{ok, note}>` (pdfengine.js:297) | EIN fetch-Versuch (20 s AbortController-Timeout, `%PDF`-Magic-Check), Erfolg wird sofort via `PdfStore.addFiles` zugeordnet, Status via `U.setDlStatus` persistiert | assignPanel, views_projekt.js:136/187 (Massendownload) |
| `PdfEngine.assignPanel(host, srcId, opts)` | `async => {destroy, refresh}`; opts `{onDone, onCancel, onMeta, onToggle, collapsed, extraActions:[{label,title,onClick}]}` (pdfengine.js:334) | DIE eine Quell-Karte (Identität + Aktionen + Datei-/Material-Block) | views_quellen.js:507, views_studio.js:1361/1975, views_projekt.js:148 |
| `PdfEngine.mount(host, srcId, opts)` | `async => Controller\|null`; opts `{page, getActive:()=>({fn,farbe,label})\|null, onCapture:({text,page,fn,markId})=>void, onMarksChange, compact, fit, data:Uint8Array, viewOnly}` (pdfengine.js:842). Controller: `{el, goto(page,smooth), search(q), refresh(), refreshActive(), destroy()}` (pdfengine.js:1358-1372) | Der Viewer | views_studio.js:1376/1685/2006, assignPanel-Vorschau (pdfengine.js:767) |
| `FigStore` | `{init, put(figId,file), remove(figId), has(figId), getUrl(figId)}` (figures.js:8-54); `FigStore.init()` läuft sofort beim Script-Load (figures.js:55) | Bild-Blobs für Abbildungen | figureCard, views_projekt.js:18 |
| `figureCard(fig, opts)` | `(figObj, {compact}) => HTMLElement` (figures.js:58) | Abbildungs-Karte | views_studio.js:422/442/722/731, views_analyse.js:196/213, notebook.js:247/453 |
| `tableCard(tab)` | `(tabObj) => HTMLElement` (figures.js:94) | Tabellen-Karte | views_studio.js:425/443, views_analyse.js:200/214 |
| `showLightbox(src, caption)` | (figures.js:105) | Vollbild-Overlay, Klick/Escape schließt | figureCard |

### Konsumierte Globals
- `U.*` (util.js): `storeGet/storeSet` (localStorage, Präfix `ehds.` + optional Projekt, util.js:202-211), `el`, `esc`, `modal`, `closeModal`, `copy`, `srcHash`, `srcLinks`, `linkKind`, `getFileSearch`, `detectPdf`, `pdfStatusCache`, `getDlStatus/setDlStatus`, `getResolutions`, `getSrcExtras/addSrcExtra/removeSrcExtra`, `extraKey`, `getSrcText/setSrcText`, `getSrcDoc/setSrcDoc/clearSrcDoc`, `getOcr/setOcr`, `getNote`, `noteModal`, `dossierModal`, `srcHeadHtml`, `srcTagsHtml`, `srcShort`.
- `PdfStore` (pdfstore.js): `has`, `getData`, `addFiles`, `removeFile`, `canRemove`, `listInbox`, `getInboxBlob`, `assignInbox`, `putData`, `putImage`, `getImageUrl`, `hasImage`, `removeImage`, `open`, `files` (Map), `_idb`.
- `Levels.farbHex(key)` (levels.js:31) — Belegfarben-Palette (siehe §5).
- `SRC_BY_ID` (globale Quellen-Map), `linkEditModal` (optional, pdfengine.js:563), `window.Tesseract` (CDN), `window.pdfjsLib` (Vendor).
- figures.js: `U.el/esc/richText`, `SRC_BY_ID`, `DATA_FIGURES` (indirekt über Aufrufer).

---

## 3. State & Persistenz

Alle localStorage-Keys laufen über `U.storeGet/storeSet` → realer Key = `ehds.` + (bei Projekt-Scope) `<projektId>.` + Name (util.js:200-204). `pdfMarks`, `assignDismissed`, `dlStatus`, `srcTexts`, `srcDoc`, `srcExtras` sind projekt-skopiert (util.js:200-201); `pdfZoomPref` und `ocrText` sind GLOBAL (nicht in `PROJECT_KEYS`).

### `ehds.<proj>.pdfMarks` — DER zentrale Key (Highlights + Pins)
Form: `{ [srcId]: Mark[] }`. Geschrieben bei jeder addMark/updateMark/removeMark (pdfengine.js:199-203; leere Listen werden aus dem Objekt gelöscht). Gelesen bei jedem `drawMarks`/Klick-Hit-Test.

```jsonc
{
  "nist-abac2014": [
    {
      "id": "mlxq3f8abc",          // 'm' + Date.now().toString(36) + 3 Zufallszeichen (pdfengine.js:206)
      "ts": 1753257600000,          // Anlage-Zeitstempel (pdfengine.js:207)
      "fn": 42,                     // Fußnoten-/Beleg-Nummer (null bei freiem Kommentar-Pin)
      "page": 15,                   // 1-basierte PDF-Seite
      "farbe": "blau",             // Farb-KEY (nicht Hex!) → Levels.farbHex, Fallback '#e8c33f'
      "zitat": "Der ausgewählte Text …",  // whitespace-normalisiert (\s+ → ' ', pdfengine.js:1205)
      "rects": [                    // KOORDINATENSYSTEM: relativ zur SEITE, normalisiert 0..1,
        {                           //   Ursprung oben links, unabhängig von Zoom/DPR.
          "x": 0.1523,              //   (clientRect.left - pageRect.left) / pageRect.width  (pdfengine.js:1212)
          "y": 0.3311,              //   (clientRect.top  - pageRect.top)  / pageRect.height
          "w": 0.6800,              //   clientRect.width  / pageRect.width
          "h": 0.0182               //   clientRect.height / pageRect.height
        }                           //   max. 40 Rects, Mini-Rects (<2px) gefiltert, nur Rects der Ankerseite
      ],
      "comment": {                  // Kommentar-Pin (optional; null = kein Pin)
        "x": 0.94,                  // ebenfalls 0..1 relativ zur Seite (Pin-Ankerpunkt oben links)
        "y": 0.3261,                // bei Auto-Anlage: rects[0].y - 0.005 (pdfengine.js:1222)
        "text": "[42] Beleg-Label"  // Auto-Text: `[fn] label` (pdfengine.js:1223)
      }
    },
    { "id": "m…", "ts": 0, "fn": null, "page": 3, "farbe": null, "rects": [],
      "comment": { "x": 0.44, "y": 0.2, "text": "" } }   // reiner Kommentar-Pin (Kommentar-Modus)
  ]
}
```
Wieder-Rendern: `drawMarks` (pdfengine.js:1110-1123) multipliziert x/y/w/h mit 100 → CSS-Prozentwerte auf der absolut positionierten `.pe-marks`-Ebene (`inset:0` über der Seite). Dadurch sind Marks zoom-/resize-invariant.

### Weitere Keys
- `ehds.<proj>.assignDismissed` — `{ [srcId]: ["dateiname.pdf", …] }`; „✗ passt nicht“-Liste (pdfengine.js:258-264). Gelesen in `findCandidates`.
- `ehds.pdfZoomPref` — `"fit"` oder Zahl (z. B. `1.44`). Gelesen beim Mount nicht-kompakter Viewer (pdfengine.js:856), geschrieben in `setZoom` nur wenn weder `compact` noch `fit`-Option (pdfengine.js:1291).
- `ehds.ocrText` — `{ [srcId]: { [page]: "erkannter Text" } }` (util.js:281-286). Geschrieben nach OCR (pdfengine.js:810), gelesen von Volltextsuche (pdfengine.js:1074) und OCR-Button (pdfengine.js:799).
- `ehds.<proj>.dlStatus` — `{ [srcId]: {ok:bool, note:string} }` (util.js:416-421); von `tryDownload` gesetzt.
- `ehds.<proj>.srcDoc` — `{ [srcId]: {kind:'link', url} | {kind:'image'} }` (util.js:561-567); von assignPanel gesetzt.
- `ehds.<proj>.srcTexts` — `{ [srcId]: "Quellentext" }` (util.js:590-595); OCR-Übernahme hängt an: `"\n\n[S. <n> — OCR]\n" + text` (pdfengine.js:830).
- `ehds.<proj>.srcExtras` — Material-Liste je Quelle: `[{kind:'pdf',key,name} | {kind:'image',key,name} | {kind:'link',url,name} | {kind:'tex',name,text}]`; `key` = `srcId~x<base36ts><rand>` (util.js:586).
- IndexedDB `ehds-figstore` v1, ObjectStore `imgs` (figures.js:16-17): Key = `fig.id` (z. B. `"abb-3-4-2"`), Value = File/Blob. Beim Init werden alle Keys in das In-Memory-Set `FigStore.blobs` gespiegelt (figures.js:21-22); ObjectURLs werden in `FigStore._urls` gecacht (nie revoked).
- PDF-Binärdaten selbst liegen NICHT hier, sondern in `PdfStore` (eigene IndexedDB, anderes Dossier).

### In-Memory-State des Viewers (pro `mount`)
`state = { page, fitMode, zoom, mode:'select'|'comment', destroyed, flashQuery, flashTarget }` (pdfengine.js:857-862); `textCache: Map<page, lowercased text>` (pdfengine.js:863); `pageEls[]` (1-indexiert), `pageDims: Map<n,{w,h}>`, `baseDim={w:595,h:842}` als A4-Fallback (pdfengine.js:911-913). assignPanel-State: `previewCtl, candIdx, ablageOpen, matTab('pdf'|'web'|'img'|'txt'|'tex'), spCollapsed` (pdfengine.js:336-342).

---

## 4. UI-Struktur & Layout

### Viewer (`mount`, pdfengine.js:866-889)
```
div.pe[.compact] (tabindex=0, container-type: inline-size)
├─ div.pe-bar                       (Flex, wrap, gap 6px, padding 7px 10px, border-bottom, flex:none)
│  ├─ span.pe-grp                   (Gruppen mit border-right als Trenner)
│  │  ├─ button[data-a=prev] "‹"
│  │  ├─ span.pe-pagenum: input[type=number min=1 max=N] " / N"   (input 54px breit, mono 12px)
│  │  └─ button[data-a=next] "›"
│  ├─ span.pe-grp (Zoom)
│  │  ├─ button[data-a=zoomout] "−"
│  │  ├─ button.pe-zoom[data-a=fit] "⤢ 100%"   (min-width 66px, tabular-nums)
│  │  └─ button[data-a=zoomin] "＋"
│  ├─ span.pe-grp.pe-search
│  │  ├─ input[type=search].pe-q  placeholder "im PDF suchen …"  (Breite clamp(210px,32cqw,380px))
│  │  └─ span.pe-qinfo.small.mut
│  ├─ span.pe-grp (entfällt bei viewOnly)
│  │  ├─ button.pe-mode.active[data-m=select] "✥ Markieren"
│  │  └─ button.pe-mode[data-m=comment] "💬 Kommentar"
│  └─ span.pe-active.small.mut     (margin-left:auto — rechtsbündig; entfällt bei viewOnly)
└─ div.pe-scroll                   (flex:1, overflow:auto, padding 14px; DER Scrollbereich)
   └─ div.pe-stack                 (Flex column, align-items:center, gap 14px, width:max-content, min-width:100%)
      └─ div.pe-page[data-pg=n] ×N (position:relative, background #fff, box-shadow 0 2px 14px rgb(0 0 0/.18), radius 3px)
         ├─ canvas                 (devicePixelRatio-skaliert; CSS-Größe = viewport.width/height)
         ├─ div.textLayer          (absolute inset:0; pdf.js-Spans, color:transparent, auswählbar)
         ├─ div.pe-marks           (absolute inset:0, z-index:3, pointer-events:none)
         │  ├─ div.pe-hl ×k        (absolute; left/top/width/height in %, mix-blend-mode:multiply)
         │  └─ div.pe-pin          (absolute, z-index:4, pointer-events aktiv, "💬<span>[fn]</span>")
         └─ div.pe-ocr.on-page     (nur Scan-Seiten: absolute top/left/right 8px, z-index 5)
```
- Platzhalter aller Seiten stehen SOFORT im Stack, Höhe aus Seite 1 geschätzt (`baseDim`), exakt nach Rendern (pdfengine.js:919-923, 954).
- `--scale-factor` wird pro Seite als CSS-Variable gesetzt (nötig für pdf.js-TextLayer ≥3.x, pdfengine.js:934).
- Kompakt-Modus: `.pe.compact .pe-scroll { max-height: min(62vh, 640px) }` (app.css:912); in der Kandidaten-Vorschau 340/420px (app.css:1284-1288).
- Fit-Zoom: `(scroll.clientWidth − 26) / baseDim.w`, min 0.35 (pdfengine.js:925).
- ResizeObserver auf `.pe-scroll`: bei Breitenänderung im Fit-Modus nach 140 ms Debounce neu einpassen, aktuelle Seite bleibt Anker (pdfengine.js:1300-1312).
- Dark-Mode: `.pe-hl` wechselt von `mix-blend-mode:multiply` zu `opacity:.55` (app.css:948-949).

### Quell-Karte (`assignPanel`, pdfengine.js:507-537)
```
details.src-panel.assign-inline[open]   (einklappbar; Zustand spCollapsed via toggle-Event gemerkt)
├─ summary.sp-bar: span.sp-caret "▸" · span.sp-lbl.eyebrow "Quelle" ·
│    span.sp-sum (b.ss-title Titel + span.ss-sub "Autor · Jahr") ·
│    span.sp-sum-file (Status-Chip: "✓ Datei" | "🌐 Internetquelle" | "🖼 Bild" | "📝 Text" | "▣ keine Datei")
└─ div.sp-body
   ├─ div.sp-head: U.srcHeadHtml(srcId) + div.stags (Tags, max 5)
   ├─ div.row.sp-actions: "📚 Dossier[ ✦]" · "↗ offizielle Seite" · "✎" · "📝[ ✎]" · extraActions…
   ├─ Datei-Block (4 Zustände):
   │  a) div.sp-file.has          — Chip "✓ Datei zugeordnet" + "Zuordnung entfernen" (+ "↩ zurück")
   │  b) div.sp-file.doc-link     — Chip "🌐 Internetquelle" + "✎ Link"/"↺ zurücksetzen" + a.doc-link-a
   │  c) div.sp-file.doc-image    — Chip "🖼 Bild" + "✎ Bild ändern"/"↺ zurücksetzen" + img.doc-img
   │  d) div.sp-file.missing      — div.mat-switch (5 Tabs role=tablist):
   │       "📄 PDF" | "🌐 Website" | "🖼 Bild" | "📝 Text" | "Σ LaTeX" + span.ms-state
   │       PDF-Tab: row.ai-dl ("⭳ Download" + ↗-Link + ai-dl-status) · row.ai-actions
   │         ("⭱ Datei lokal wählen" file-input, "📥 Aus Dateiverzeichnis (n)")
   │         + optional div.ai-ablage (select + "übernehmen")
   │         + optional div.ai-candidate (Chip "Vermutlich passende Datei — unbestätigt, nicht übernommen",
   │           code Dateiname, div.ai-preview.unconfirmed mit eingebettetem compact/viewOnly-Viewer
   │           bzw. iframe.ai-iframe-Fallback, Buttons "✓ Übernehmen" / "andere Vermutung (i/n) ▸" / "✗ passt nicht")
   └─ div.sp-mat — Materialliste (div.mat-row je Eintrag: Icon 📄/🖼/Σ/🌐, Name, ↗/👁-Öffnen, ✕-Löschen)
        + div.ad-opts.mat-addrow (5 Hinzufüge-Kacheln)
```

### figures.js
```
figure.fig-card[data-fig=id]
├─ img.fig-img (loading=lazy; compact: style max-height:280px)
└─ figcaption.fig-cap: <b>Nummer</b> " — " Titel · span.credit (Credit + optional Link "Quelle ↗" → #/quellen/<id>)

Fallback (kein Bild): .fig-missing mit eyebrow "🖼 <Nummer> — Abbildung nicht hinterlegt",
  Titel (13px bold), Beschreibung (small mut), Upload-Label "Bild einfügen (PNG/JPG/WebP/SVG)".

div.fig-card (Tabelle): div.tbl-wrap (padding 6px 10px) > table.tbl (thead aus tab.kopf, tbody aus
  tab.zeilen; erste Zelle jeder Zeile font-weight:600) + div.fig-cap.

div.lightbox > img + div.cap   (Vollbild-Overlay, Klick oder Escape schließt)
```

---

## 5. Design-Rohwerte

**Farben (inline im JS):**
- Fallback-Markierungsfarbe: `#e8c33f` (pdfengine.js:1115, 1136, 1256).
- Highlight-Füllung: `hex + '55'` (33 % Alpha als Hex-Suffix), `outlineColor: hex` (pdfengine.js:1118).
- Pin: CSS-Var `--pc:<hex>` (pdfengine.js:1137); CSS-Fallback `var(--warn)`.
- Beleg-Farbpalette (levels.js:25-30, Farb-KEYS wie in `mark.farbe` gespeichert): `gelb #e8c33f`, `blau #5f8fc7`, `gruen #7cab54`, `rosa #d77aa4`, `orange #dd8a3e`, `violett #9779c9`, `tuerkis #4fb3a5`, `rot #cf6d5c`.
- Suchtreffer-Flash: `rgba(255,193,7,.6)` + `outline 2px solid #e8a800` (app.css:935-938).
- Blockquote im Mark-Popover: `border-left:3px solid <hex>` (pdfengine.js:1170).
- Seiten-Hintergrund `#fff`, Schatten `0 2px 14px rgb(0 0 0/.18)` (app.css:913).

**Größen:** Stack-Gap 14px, Scroll-Padding 14px, Fit-Abzug 26px, Zoom-Faktor ×/÷1.2, Zoom-Grenzen 0.3–4 (Buttons) bzw. min 0.35 (fit), Seitenzahl-Follow-Linie bei 35 % der Viewport-Höhe (pdfengine.js:1053), Speicherfreigabe-Distanz >8 Seiten (pdfengine.js:1060), IO-rootMargin `160% 0px`, Flash-Dauer 2600 ms, Pin-Drag-Schwelle 4px, Pin-Clamp 0–0.98, max 40 Auswahl-Rects, Download-Timeout 20000 ms, ResizeObserver-Debounce 140 ms, A4-Fallback 595×842.

**Icons/Zeichen exakt:** `‹` `›` `−` `＋` (Fullwidth-Plus!) `⤢` `✥` `💬` `🔍` `⚠` `⭳` `⭱` `↗` `↺` `↩` `✎` `📝` `📚` `📥` `📄` `🌐` `🖼` `Σ` `👁` `✕` `⧉` `✔` `✓` `✗` `▸` `▣` `🖍` `☰` `„“` (deutsche Anführungszeichen in Zitaten).

**Wörtliche UI-Texte (Auswahl, exakt):**
- „im PDF suchen …“, „✥ Markieren“, „💬 Kommentar“, „Auf Breite einpassen (0)“, „Zur vorherigen Seite springen (←)“, „Zur nächsten Seite springen (→)“, „Verkleinern (−)“, „Vergrößern (+)“.
- Aktiv-Anzeige: `aktiv: [fn] — Auswahl im Text wird diesem Beleg zugeordnet` / „kein Beleg aktiv — links einen wählen“ (pdfengine.js:903-904); Warnung: „Kein Beleg aktiv — links einen Beleg wählen, dann auswählen.“ (pdfengine.js:1216, in `var(--warn)`).
- OCR: „⚠ S. {n}: kein Textlayer (Scan?)“, „🔍 OCR dieser Seite“ / „🔍 OCR-Text zeigen“, „Lade OCR-Engine (Tesseract, einmalig vom CDN) …“, „Erkenne Text (deu+eng) — je nach Seite 5–30 s …“, „Erkenne Text … {p} %“, „✗ Kein Text erkannt.“, „☰ Als Quellentext uebernehmen (anhaengen)“, „⧉ kopieren“.
- Suche: „… sucht“, „S. {n} · {k}+ Seiten“, „kein Treffer“.
- Popover: „Markierung [fn] — S. {p}“, „Kommentar“, „Speichern“, „Markierung löschen“; Chooser: „{n} Markierungen an dieser Stelle“, „Eine Markierung wählen, um Zitat/Kommentar zu bearbeiten oder sie zu löschen.“
- Download-Fehlertexte: „kein öffentlicher Datei-Link bekannt — Link ↗ von Hand laden oder über 🤖 Ergänzung nachtragen“, „HTTP {status} — Link ↗ von Hand laden, dann ⭱ Datei lokal wählen“, „Antwort ist kein PDF (vermutlich HTML-Seite) — Link ↗ prüfen“, „Zeitüberschreitung (20 s)“, „blockiert (CORS/Netzwerk) — Link ↗ von Hand laden, dann ⭱ Datei lokal wählen“, Erfolg: „geladen & zugeordnet“.
- Quell-Karte: „✓ Datei zugeordnet“, „Zuordnung entfernen“, „▣ keine Datei“, „⭳ Download“, „⭱ Datei lokal wählen“, „📥 Aus Dateiverzeichnis (n)“, „Vermutlich passende Datei — unbestätigt, nicht übernommen“, „✓ Übernehmen“, „andere Vermutung (i/n) ▸“, „✗ passt nicht“, „automatisch erkannt“ / „id-Datei“, „Kein PDF — Zitat & Fundstelle erfasst du im Beleg (rechts unten) von Hand.“, „Material dieser Quelle — flexibel erweitern“.
- figures.js: „🖼 {Nummer} — Abbildung nicht hinterlegt“, „Bild einfügen (PNG/JPG/WebP/SVG)“.
- pdfToTex-Header: „% Automatisch aus PDF extrahiert — Thesis Studio (Beta).“ (pdfengine.js:182-184).

---

## 6. Verhalten & Interaktionen

### Endlos-Scroll & Lazy-Rendering
1. Mount: pdf.js laden → `getDocument({data, isEvalSupported:false})` → Platzhalter-Divs für ALLE Seiten (pdfengine.js:919-923) → `layout()` → `goto(opts.page)` falls >1 → `renderPage(state.page)` await (pdfengine.js:1354-1356).
2. IntersectionObserver (root=`.pe-scroll`, rootMargin 160 %) rendert Seiten beim Erscheinen (pdfengine.js:1041-1044).
3. `renderPage(n)` (pdfengine.js:944-1008): Reentrancy-Guard (`dataset.done === String(zoom)` bzw. `_rendering`); Zoom-Wechsel während des Renderns bricht ab (`zoomAtStart`-Check Z.952); Canvas in DPR-Auflösung (`transform:[ratio,0,0,ratio,0,0]`); danach TextLayer (beide pdf.js-APIs, Fehler still toleriert); danach `.pe-marks` + `drawMarks`; danach OCR-Hinweis wenn `tl.textContent.trim().length < 20`; zuletzt evtl. Such-Flash.
4. Scroll-Handler (rAF-throttled, pdfengine.js:1047-1066): Seitenzahl-Follow — aktuelle Seite = letzte Seite mit `offsetTop <= scrollTop + 35 % Höhe`; Seiten mit Abstand >8 zur aktuellen werden geleert (`innerHTML=''`, `dataset.done` gelöscht) → Speicherfreigabe; IO rendert sie bei Bedarf neu.
5. `goto(p, smooth)`: setzt `state.page`+Input, scrollt zu `offsetTop − 10`, rendert Zielseite (pdfengine.js:1031-1037).

### Zoom
- Buttons/Tasten: `zoomin` ×1.2 (max 4), `zoomout` ÷1.2 (min 0.3), `fit` → `setZoom(null)` (pdfengine.js:1318-1320). `setZoom` merkt Ankerseite, persistiert `pdfZoomPref` (nur nicht-kompakt), ruft `layout()` (invalidiert gerenderte Seiten mit anderem `done`-Zoom, cancelt deren Render-Task, pdfengine.js:935-939), scrollt zum Anker, `renderVisible()` (Bereich −1 bis +2 Viewporthöhen, pdfengine.js:1011-1018).
- Zoom-Button-Label zeigt live `⤢ {Prozent}%` (pdfengine.js:941).

### Markieren (Modus `select`, Default)
- `mouseup` auf `.pe-stack` (pdfengine.js:1196-1229): Selection lesen; Ankerseite via `sel.anchorNode → closest('.pe-page')`; Text `\s+`→`' '`-normalisiert, min. 2 Zeichen; `getRangeAt(0).getClientRects()` → Filter (>2px, innerhalb der Ankerseite ±2px — seitenübergreifende Auswahl wird auf die Ankerseite beschnitten!) → Normalisierung auf 0..1 relativ zur Seiten-BoundingBox → max 40 Rects.
- Kein aktiver Beleg (`opts.getActive()` null): rote Warnung in `.pe-active`, KEINE Markierung.
- Sonst `addMark` mit `{fn, page, rects, farbe, zitat, comment:{x:0.94, y:rects[0].y−0.005, text:'[fn] label'}}` → Selection aufheben → `opts.onCapture({text,page,fn,markId})` (Studio übernimmt Zitat+Seite in den Beleg) → `refreshMarks()`.

### Klick auf Markierung / Überlapp
- Highlights sind `pointer-events:none`; Klick-Hit-Test auf `.pe-stack` (pdfengine.js:1233-1249): nur Modus `select`, keine offene Selection, nicht auf Pin/OCR-Bar; normalisierte Klickkoordinaten gegen alle `rects` der Seite. 1 Treffer → `markPopover`; >1 → `markChooser`-Modal mit Farb-Dot, `[fn]`, Zitat-Auszug (90 Zeichen) je Zeile (pdfengine.js:1252-1265).
- Popover (pdfengine.js:1168-1190): Zitat als Blockquote in Belegfarbe, Kommentar-Textarea, „Speichern“ (setzt/löscht `comment`; Default-Position rechts neben erstem Rect: `x = rects[0].x+w+0.02` max 0.9), „Markierung löschen“. Beide rufen `refreshMarks()` + `opts.onMarksChange?.()`.

### Kommentar-Pins
- Modus `comment`: Klick auf Seite → `addMark` mit leeren `rects`, `comment:{x,y,text:''}` an Klickposition, `fn`/`farbe` vom aktiven Beleg oder null → Modus springt zurück auf `select` → Popover öffnet sofort (pdfengine.js:1268-1284).
- Pin-Drag (Pointer Events + `setPointerCapture`, pdfengine.js:1142-1164): Delta/Seitengröße → neue 0..1-Koordinaten, geclamped 0–0.98, live per `%`; `moved` erst ab 4px Manhattan-Distanz. `pointerup`: bewegt → `updateMark` (persistiert), sonst → Editor-Popover (Klick).

### Volltextsuche
- Enter im `.pe-q` → `searchNext` (pdfengine.js:1081-1108): min. 2 Zeichen, lowercase; sucht ab der NÄCHSTEN Seite zirkulär; Seitentext lazy via `getTextContent` (Join mit `' '`), bei <20 Zeichen OCR-Text als Ersatz (pdfengine.js:1074); Info `S. {n}` + Trefferseitenzahl aus dem bisherigen Cache („{k}+ Seiten“); Zielseite bereits gerendert → `goto` + `flashIn`, sonst `flashQuery/flashTarget` merken, `goto` — der Flash feuert nach dem Rendern (pdfengine.js:1001-1006). `flashIn`: alle TextLayer-Spans mit Treffer bekommen 2,6 s `.pe-found`, erster wird `scrollIntoView({block:'center'})` (pdfengine.js:1020-1028). Escape leert die Suche; `search`-Event leert die Info. `searchBusy`-Flag verhindert Parallel-Suchen. Controller-`search(q)` befüllt das Feld und sucht (klickbare Suchbegriffe von außen, pdfengine.js:1361).

### Tastatur (auf `.pe`-Root, nicht in Feldern; pdfengine.js:1340-1349)
`←`/`→` Seite zurück/vor (smooth), `+`/`=` rein, `−` raus, `0` fit, `Ctrl/Cmd+F` fokussiert die PDF-Suche (preventDefault). PageUp/Down scrollt nativ. `pointerdown` auf dem Scrollbereich fokussiert den Viewer (`preventScroll`), nur wenn `document.activeElement === document.body` (pdfengine.js:1351).

### OCR (pdfengine.js:782-834)
Button auf Scan-Seiten → `_ocrPage`: Cache-Hit zeigt sofort das Ergebnis-Modal; sonst Tesseract.js 5.1.1 vom CDN `https://cdn.jsdelivr.net/npm/tesseract.js@5.1.1/dist/tesseract.min.js` laden (Fehlertext: „Tesseract nicht ladbar — OCR braucht eine Internetverbindung (CDN).“), `T.recognize(canvas,'deu+eng')` mit Fortschritts-Logger (%-Anzeige), Ergebnis → `U.setOcr`, Callback aktualisiert den Such-Cache der Seite, Ergebnis-Modal mit Textarea + „Als Quellentext übernehmen (anhängen)“ + Kopieren.

### pdfToTex (pdfengine.js:51-195) — Ablauf
Items je Seite nach y gruppieren (Toleranz `max(2, h*0.4)`), nach x sortieren, Wortabstände >`h*0.12` ⇒ Leerzeichen; Zeilengröße = längengewichtetes Mittel auf 0,5 gerundet. Brotschrift = Modus der Größen (textlängengewichtet). Kopf-/Fußzeilen: `rel>0.92`/`<0.08` + auf ≥max(3, 40 %) der Seiten wiederholt (Ziffern → `#`), plus reine Seitenzahlen/„Seite n von m“. Überschriften: nummerierte Zeilen (`3.2 Titel` → Ebene = Punkttiefe, max 3) oder ≥1.45×Brotschrift (Ebene 1) bzw. ≥1.2× ohne Satzzeichen am Ende (Ebene 2); >130 Zeichen nie. Titel = größte Zeile(n) der ersten Seite ≥1.3×. Absätze: y-Lücke >1.9×Größe oder Einzug >0.8×Brotschrift; Silbentrennung `wort-`+Kleinbuchstabe wird verschmolzen. Fußnoten-Kandidaten: ≤0.85×Brotschrift, unteres Drittel (`rel<0.35` — Achtung: rel ist y/Seitenhöhe in PDF-Koordinaten, klein = unten), beginnend mit Nummer → als `%`-Kommentare ans Ende. LaTeX-Escaping Z.107-111. Ohne erkannte Überschrift wird `\section{Inhalt}` vorangestellt (Z.179). Rückgabe `{tex, pages, headings, footnotes, title}`.

### tryDownload / assignPanel-Flows
- Download: nur EIN Versuch; Erfolg (Magic-Bytes `%PDF` geprüft) wird sofort als `<srcId>.pdf` in den PdfStore übernommen und `U.pdfStatusCache[srcId]=true` gesetzt; jeder Ausgang landet persistent in `dlStatus` (pdfengine.js:297-319).
- Kandidaten-Vorschau: eingebetteter Viewer mit `viewOnly:true` (keine Marks — „die gehören zur bestätigten Datei, nicht zur Vermutung“, pdfengine.js:760-767); Fallback iframe mit Blob-URL. „✓ Übernehmen“ schließt nur bei echtem Erfolg ab (vergifteter-Cache-Kommentar pdfengine.js:741-744).
- Lokale Dateiwahl: erste Datei wird Haupt-PDF (umbenannt zu `<srcId>.pdf`), weitere werden Extra-Material (pdfengine.js:544-550).
- `destroy()` des Viewers: `state.destroyed=true`, Observer disconnecten, alle Render-Tasks canceln, `doc.destroy()`, Host leeren (pdfengine.js:1364-1371).

### figures.js
- `figureCard`: Priorität `fig.file` (statischer Pfad) → FigStore-Blob → Platzhalter mit Upload; nach Upload sofortiges Re-Render als Karte. Bild-Klick → Lightbox; Lightbox schließt bei Klick irgendwo oder Escape (einmaliger keydown-Listener, figures.js:108).

---

## 7. Datenformen

```jsonc
// Mark (siehe §3 für Vollbeispiel) — DIE Kernstruktur
{ "id": "m…", "ts": 0, "fn": 42, "page": 15, "farbe": "blau",
  "zitat": "…", "rects": [{"x":0,"y":0,"w":0,"h":0}], "comment": {"x":0,"y":0,"text":""} }

// opts.getActive() — vom Studio geliefert
{ "fn": 42, "farbe": "blau", "label": "Kurzlabel des Belegs" }

// onCapture-Payload (pdfengine.js:1227)
{ "text": "markierter Text", "page": 15, "fn": 42, "markId": "m…" }

// tryDownload-Ergebnis / dlStatus-Eintrag
{ "ok": false, "note": "Zeitüberschreitung (20 s)" }

// findCandidates-Eintrag
{ "name": "irgendwas-<hash>.pdf", "score": 200, "why": "automatisch erkannt", "sure": true }

// pdfToTex-Ergebnis
{ "tex": "\\documentclass{article}…", "pages": 12, "headings": 5, "footnotes": 3, "title": "…" }

// DATA_FIGURES (data/figures.json) — Abbildung
{ "id": "abb-3-3-2", "nummer": "Abb. 3.1", "sectionId": "3.3.2", "paragraphId": "3.3.2-p4",
  "file": "figures/abb-3-3-2-acm.png",   // oder null → FigStore/Upload-Platzhalter
  "titel": "Beispiel der Access Control Mechanism (ACM) Funktionen",
  "credit": "Übernommen aus NIST, Hu et al. (2014): …, S. 15, Fig. 5.",
  "quelle": "nist-abac2014",              // srcId → Link "Quelle ↗" nach #/quellen/<id>
  "beschreibung": "…" }

// DATA_FIGURES — Tabelle (tableCard)
{ "nummer": "Tab. 1", "titel": "…", "credit": "…",
  "kopf": ["Spalte A", "Spalte B"], "zeilen": [["Zeile1A", "Zeile1B"]] }

// srcExtras-Eintrag (Material) — von assignPanel verwaltet
{ "kind": "pdf|image|link|tex", "key": "srcId~x…", "name": "datei.pdf", "url": "https://…", "text": "\\…" }
```

---

## 8. Abhängigkeiten

**PdfEngine nutzt:** pdf.js (Vendor), Tesseract.js (CDN, lazy), `U` (Storage, Modals, Quell-Metadaten, OCR-Cache, esc/el), `PdfStore` (PDF-/Bild-Blobs, Inbox), `Levels.farbHex`, `SRC_BY_ID`, `linkEditModal` (optional).
**PdfEngine wird genutzt von:** `views_studio.js` (Haupt-Viewer im Splitscreen 1376/1685/2006, Quell-Karte 1361/1975, Referenzmodus 1806, Marks-Abfragen 599/1048/1325/1332/1592/1608), `views_quellen.js:507` (Detailseite), `views_projekt.js` (Massendownload 136/187, Zuordnungszeile 148, PDF→LaTeX-Import 377), `levels.js:119` (Zitat aus Marks für Beleg-Info).
**figures.js nutzt:** `U.el/esc`, `SRC_BY_ID`, IndexedDB. **Genutzt von:** views_studio.js (Lesemodus, Peek-Popover 722-732), views_analyse.js, notebook.js (`figure:`-Befehl), views_projekt.js:18 (Fortschrittszählung `FigStore.has`).

---

## 9. Flutter-Hinweise

1. **Koordinatensystem ist der Schlüssel:** Marks sind seiten-relativ normalisiert (0..1, Ursprung oben links, y nach unten — NICHT das PDF-Koordinatensystem von pdf.js, das unten links beginnt). In Flutter identisch übernehmbar: Highlight-Overlay als `Positioned` in einem `Stack` über dem Seiten-Widget mit `left = r.x * pageWidth` usw. Die Datenform (JSON in §3) kann 1:1 migriert werden — Bestandsdaten aus localStorage bleiben gültig.
2. **Renderer:** `pdfrx` (pdfium-basiert) ist die beste Wahl: Text-Selection-Callbacks mit Glyph-Rects, Lazy-Rendering, Zoom. Die Auswahl-Rects von pdfrx kommen in Seitenkoordinaten → auf 0..1 normalisieren wie im Original (max 40 Rects, Mini-Rects filtern, auf Ankerseite beschneiden). `pdf_render`/`printing` reichen NICHT (keine Textauswahl).
3. **Endlos-Scroll + Speicherfreigabe:** `ListView.builder`/`ScrollablePositionedList` ersetzt IO+manuelle Freigabe nativ; die „>8 Seiten entfernt → Canvas leeren“-Logik entfällt (pdfrx cached selbst), aber die Platzhalter-Höhen-Logik (baseDim aus Seite 1, exakt nach Laden) muss nachgebaut werden, sonst springt der Scroll. Seitenzahl-Follow: Position bei 35 % Viewporthöhe messen.
4. **Fit-Zoom & Persistenz:** `fit = (Containerbreite − 26) / Seitenbreite`, min 0.35; `pdfZoomPref` global (SharedPreferences), aber kompakte Einbettungen starten IMMER mit fit und schreiben nie (pdfengine.js:852-856, 1291) — wichtiger Randfall.
5. **Highlight-Optik:** Füllung = Belegfarbe mit Alpha 0x55, plus `mix-blend-mode:multiply` (hell) bzw. Opacity .55 (dunkel). In Flutter: `BlendMode.multiply` via `Paint`/`ColorFiltered` oder schlicht `color.withAlpha(0x55)` — multiply über dem weißen PDF sieht fast identisch aus; Dark-Mode-Variante beachten.
6. **Pins:** `Positioned` + `GestureDetector`/`Listener` mit Pan; 4-Pixel-Schwelle unterscheidet Klick (Editor) von Drag (Position speichern); Clamp 0–0.98. Pin-Optik: Chip mit 💬 + `[fn]` in Belegfarbe (Border 1.5px, Mono-Font 10px bold).
7. **Überlapp-Auswahl:** Hit-Test rein datenbasiert (Punkt-in-Rect über alle Marks der Seite) — kein Widget-HitTest nötig; bei >1 Treffer BottomSheet/Dialog wie `markChooser`.
8. **Volltextsuche:** pdfrx liefert `loadText()` pro Seite → gleicher lazy Cache (`Map<int,String>` lowercase), zirkulär ab Folgeseite, OCR-Text als Ersatz bei <20 Zeichen. Flash-Hervorhebung: Treffer-Rects der Zielseite 2,6 s hervorheben (pdfrx hat Text-Search-API mit Rects — besser als der Span-Hack des Originals).
9. **OCR:** Tesseract-CDN geht nicht in Flutter. Optionen: `google_mlkit_text_recognition` (on-device, mobil), `tesseract_ocr`-FFI oder Cloud. Cache-Format (`ocrText`-Map srcId→page→text) beibehalten, inkl. Anhänge-Format `[S. n — OCR]` beim Übernehmen in den Quellentext.
10. **pdfToTex:** reine Textitem-Heuristik — mit pdfrx-Textextraktion (Glyph-Positionen nötig!) portierbar, aber prüfen, ob pdfrx per-Item-Transform/Fontgröße liefert; sonst pdfium-FFI direkt. Niedrige Priorität (Beta-Feature, nur Projekt-Import).
11. **assignPanel:** großes, eigenständiges Formular-Widget (5-Tab-Material-Switch, Kandidaten-Preview mit eingebettetem viewOnly-Viewer, Download-Engine). Für Flutter als eigenes `SourceCard`-Widget mit Zuständen has/link/image/missing; `<details>`-Einklappen → `ExpansionTile` mit erhaltenem Zustand über Rebuilds.
12. **tryDownload:** fetch → `http`/`dio` mit 20-s-Timeout und `%PDF`-Magic-Check; CORS entfällt in Flutter (Vorteil!), aber die Fehlertexte („blockiert (CORS/Netzwerk) …“) sollten angepasst, die übrigen wörtlich übernommen werden.
13. **figures.js:** IndexedDB-FigStore → gleiche Blob-Ablage wie PdfStore-Ersatz (z. B. Dateien im App-Support-Verzeichnis, Key = figId); ObjectURL-Cache entfällt. Lightbox → `showDialog` mit `InteractiveViewer`. `loading=lazy` → `Image.file` mit `cacheWidth`.
14. **NICHT 1:1 portierbar:** browserbasierte Text-Selection über DOM-Spans (Ersatz: pdfrx-Selection), `mix-blend-mode` auf DOM-Ebene, iframe-Fallback der Kandidaten-Vorschau, `window.open`-Flows (→ `url_launcher`), Tesseract vom CDN.
15. **Verstecktes Verhalten, leicht zu übersehen:** (a) `viewOnly` unterdrückt Marks UND Toolbar-Modus-Gruppe; (b) seitenübergreifende Auswahl wird stillschweigend auf die Ankerseite beschnitten; (c) Kommentar-Modus springt nach einem Pin automatisch zurück auf `select`; (d) Auto-Pin bei jeder Text-Markierung (x=0.94) — jede Markierung hat sofort einen sichtbaren Rand-Pin; (e) Zoom hält die aktuelle Seite als Anker; (f) `pdfZoomPref`-Wert kann String `"fit"` ODER Zahl sein.
