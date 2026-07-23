# Inventar-Dossier 04 — Quellen-Bibliothek (`js/views_quellen.js`, 904 Z.) + PDF-Speicher (`js/pdfstore.js`, 313 Z.)

Analysierte Dateien (vollständig gelesen):
- `/home/user/thesoR/js/views_quellen.js` (904 Zeilen)
- `/home/user/thesoR/js/pdfstore.js` (313 Zeilen)

Kontext-Belege aus abhängigen Dateien (nur zur Präzisierung, gehören in andere Dossiers):
`js/util.js` (U.*, KIND_LABELS/ICONS, storeGet-Prefix, srcHash, matchFilename), `css/app.css` (Layout `.lib*`), `js/pdfengine.js:334-620` (assignPanel = Kopf des Detailpanels), `js/views_studio.js:1652-1697` (renderDetailPdf), `js/app.js` (Router/Topbar).

---

## 1. Zweck & Rolle

### views_quellen.js
Die Quellen-Bibliothek im Zotero-Layout: drei Spalten — Sammlungen/Werkzeuge (Rail), Quellenliste, Detailpanel (Kommentar views_quellen.js:1-6). Routen `#/quellen` und `#/quellen/<id>` (app.js:231 ruft `renderQuellen(app, p1)`). Das Detailpanel zeigt pro Quelle: den einheitlichen Quell-Kopf (delegiert an `PdfEngine.assignPanel`, views_quellen.js:507-514) mit Werkzeugzeile (📚 Dossier · ↗ offizielle Seite · ✎ Link ändern · 📝 Notizen), Datei-Block (⭳ Download-Engine, ⭱ Datei lokal wählen, 📥 Aus Dateiverzeichnis, Material-Switch PDF/Website/Bild/Text/LaTeX), darunter einklappbare Sektionen: Referenzierungsvorschläge (nur custom), Fundstellen-Register (nur Rechtsquellen), Anhang-PDF (eingebetteter PdfEngine-Viewer), Zitierstellen, Text-Erwähnungen, Text der Quelle. Zusätzlich enthält die Datei fünf Modals: ＋ Neue Quelle (`newSourceModal`), 🗄 Quellen- & Dateispeicher (`storeModal`, von der Topbar aus überall aufrufbar, app.js:141), ＋ Quelle aus Datei (`sourceFromFile`), ⭱ Import PDF/ZIP (`importFilesModal`) und ✎ Offizielle Seite (`linkEditModal`) — plus den ⌗ Datei-Auftrag-Export (`exportDateiAuftrag`) und zwei GPT-Prompt-Builder (`gptErgaenzungsPrompt`, `gptPromptForSource`).

### pdfstore.js
Browser-lokaler Dateispeicher für Quell-PDFs (und Bilder) auf IndexedDB-Basis, damit die App ohne Server funktioniert (pdfstore.js:1-8). Drei Beschaffungswege: (1) Legacy: gemerkter Ordner-Handle über die File System Access API (nur Chrome/Edge; Feature-„Neuverbinden" ist entfernt, Bestandsverbindungen bleiben nutzbar, pdfstore.js:101-109); (2) in IndexedDB kopierte Blobs (alle Browser, dauerhaft); (3) HTTP-Fallback auf statische `sources/<id>.pdf` (pdfstore.js:290-297). Verwaltet zusätzlich die „Ablage"/Inbox (importierte, noch keiner Quelle zugewiesene Dateien) und Bild-Blobs (`img:<id>`). Publiziert Änderungen über ein eigenes Listener-System mit DOM-Anker-Autocleanup (pdfstore.js:21-27). Boot: `PdfStore.ready = PdfStore.init()` (pdfstore.js:313) — ein Promise, auf das Aufrufer vor dem ersten Zugriff warten können.

---

## 2. Öffentliche API

### views_quellen.js exportiert (Skript-Scope, kein Modul — alles global)
| Symbol | Signatur | Zweck | Genutzt von |
|---|---|---|---|
| `Quellen` | `{ filter: {q, coll, sort}, _smart }` | View-State der Bibliothek (views_quellen.js:9-11, 56) | intern |
| `renderQuellen(root, openId)` | views_quellen.js:13 | Ganze Bibliotheksseite rendern | Router app.js:231; nach ＋ Quelle views_quellen.js:199 |
| `newSourceModal()` | views_quellen.js:147 | Modal „＋ Neue Quelle anlegen" | Rail-Button views_quellen.js:143, storeModal views_quellen.js:258 |
| `storeModal()` | views_quellen.js:207 | Modal „🗄 Quellen- & Dateispeicher" | Topbar `#storeBtn` (app.js:141) |
| `sourceFromFile(name, onDone)` | views_quellen.js:293 | Quelle aus Ablage-Datei erstellen + zuweisen | storeModal views_quellen.js:277 |
| `gptErgaenzungsPrompt(srcId)` | views_quellen.js:330 | Prompt-Text „🤖 Ergänzung" | ergModal views_quellen.js:473 |
| `renderLibRail / renderLibList / libDetailPlaceholder / renderLibDetail` | views_quellen.js:46/368/432/446 | Teil-Renderer | intern; `renderLibDetail._fetched` als Memo (views_quellen.js:453) |
| `linkEditModal(srcId, onDone)` | views_quellen.js:642 | Modal „↗ Offizielle Seite — Link ändern" | PdfEngine.assignPanel (pdfengine.js:563, per `typeof`-Guard!) |
| `provisionRegister(srcId)` | views_quellen.js:659 | Art/§-Register aus Fußnotentexten | renderLibDetail views_quellen.js:534 |
| `gptPromptForSource(srcId)` | views_quellen.js:686 | Prompt „Referenzierungsdurchlauf" (ganze Quelle) | GPT-Hub/Studio (extern) |
| `importFilesModal(onDone, opts)` | views_quellen.js:718 | Modal „⭱ Dateien importieren (PDF/ZIP)"; `opts.inbox:true` lädt Ablage vor | Rail views_quellen.js:103/142, storeModal views_quellen.js:257 |
| `exportDateiAuftrag()` | views_quellen.js:867 | ZIP „datei-auftrag.zip" erzeugen | Rail views_quellen.js:104 |

### views_quellen.js konsumiert
- `U.*` (util.js): `el, esc, modal, closeModal, gptModal, download, storeGet, storeSet, resizer, srcShort, srcHash, srcByHash, matchFilename, srcLinks, setSrcLink, getNote, getSrcText, setSrcText, getResolutions, setResolution, fetchResolution, getFileSearch, pdfStatusCache, detectPdf`.
- `Levels.*` (levels.js): `allNums(), numsForSource(srcId), countsFor(nums)→{total,l1,l2,l3}, positionType(srcId)→'seite'|'fundstelle', bar(nums)→HTML, dot(num,srcId)→HTML, info(num)→{level,zitat,seite,fundstelle}, exportState(), importState(json)`.
- `Mentions.forSource(srcId)`, `Mentions.setStatus(key, status, srcId)` (mentions.js:198/135).
- `PdfEngine.assignPanel(host, srcId, {onDone, onMeta, extraActions})` (pdfengine.js:334).
- `renderDetailPdf(body, srcId, fnNum)` (views_studio.js:1657) für den Anhang.
- `PdfStore.*` (siehe unten), `ZipUtil.read(file)/create(entries)`, `Projects.saveCustomSource/mergeCustomSources/removeCustomSource`, `rebuildDataIndexes()` (util.js:944), `KIND_LABELS/KIND_ICONS` (util.js:926-932), `SRC_BY_ID` (util.js:937), `window.DATA_SOURCES`, `window.DATA_THESIS.meta`.

### pdfstore.js exportiert (`const PdfStore = {…}`, Skript-Scope — NICHT `window.PdfStore`, s. Hinweis util.js:602)
| Methode | Zweck |
|---|---|
| `PdfStore.ready` | Boot-Promise (= `init()`, pdfstore.js:313) |
| `onChange(fn, anchor?)` / `_emit()` | Listener; `anchor`-DOM-Element ⇒ Autoremove wenn `!anchor.isConnected` (pdfstore.js:23-27) |
| `init()` | DB öffnen, Blob-Keys klassifizieren (inbox:/img:/plain), Dir-Handle laden + `queryPermission` (pdfstore.js:29-64) |
| `supportsDirPicker()` | `typeof window.showDirectoryPicker === 'function'` (Z.75) |
| `pickDirectory()` / `reconnect()` / `forgetDirectory()` / `_scanDir()` | Legacy-Ordner (Z.78-120); reconnect via `requestPermission({mode:'read'})` |
| `addFiles(fileList)` | PDFs als Blob unter `<dateiname ohne .pdf>` speichern, ObjectURL-Cache invalidieren, Anzahl zurück (Z.123-139) |
| `canRemove(id)` / `removeFile(id)` | nur `kind:'blob'` löschbar; Ordner-Dateien kämen beim Scan zurück (Z.143-153) |
| `clearAll()` | ALLE Blob-Keys löschen (inkl. inbox/img), Maps/Sets/URLs leeren (Z.160-171) |
| `has(id)` / `countDir()` / `count()` | Abfragen (Z.173-175) |
| `addInbox(name, blobOrData)` / `listInbox()` (sortiert) / `getInboxBlob(name)` / `removeInbox(name)` / `assignInbox(name, srcId)` | Ablage; assignInbox kopiert Blob auf Key `srcId`, entfernt Inbox-Eintrag (Z.180-209) |
| `putData(srcId, data)` | Uint8Array → Blob `application/pdf` unter `srcId` (Z.211-221) |
| `hasImage(id)` / `putImage(id,file)` / `getImageUrl(id)` / `removeImage(id)` | Bild-Quelle unter `img:<id>` (Z.225-256) |
| `getUrl(id)` | ObjectURL (Cache `_urls`); dir → `dirHandle.getFileHandle(id+'.pdf')` (Z.258-275) |
| `getData(id)` | Uint8Array; Fallback-Kette dir → blob → HTTP `fetch('sources/<id>.pdf')` außer unter `file:` (Z.278-298) |
| `open(id, page)` | `window.open(url#page=N, '_blank')`; HTTP-Fallback nur wenn `U.pdfStatusCache[id]===true` (Z.301-310) |

Konsumiert: `indexedDB`, `window.showDirectoryPicker`, `URL.createObjectURL/revokeObjectURL`, `fetch`, `U.pdfStatusCache` (nur in `open`).

---

## 3. State & Persistenz

### localStorage (immer via `U.storeGet/Set`; realer Key = `'ehds.' + key` bzw. bei Projekt-Keys `'ehds.<projekt>.' + key`, util.js:200-211)
| Key (logisch) | Realer Key | Form / Beispiel | Lesen/Schreiben |
|---|---|---|---|
| `qColl` | `ehds.qColl` (global, NICHT projekt-scoped) | `"alle"` \| `"kind:artikel"` \| `"offen"` \| `"fertig"` \| `"pdf-fehlt"` \| `"notizen"` \| `"custom"` | Lesen views_quellen.js:10; Schreiben bei Klick auf Sammlung Z.89 und beim Fallback auf `alle` Z.389 |
| `qSort` | `ehds.qSort` (global) | `"zit"` \| `"titel"` \| `"jahr"` \| `"status"` | Z.10 / Z.426 |
| `uiLibPct` | `ehds.uiLibPct` (global) | `34` (Ganzzahl-%, geklemmt 18–60) oder `null` | Z.26-27 lesen; Z.31/34 schreiben (Drag), `null` bei Doppelklick |
| `linkOverrides` | `ehds.<proj>.linkOverrides` | `{ "kraus2025": { "official": "https://…", "file": "https://….pdf" } }` | indirekt via `U.setSrcLink` (ergModal Z.495-496, linkEditModal Z.650) |
| `srcTexts` | `ehds.<proj>.srcTexts` | `{ "gtelg2012": "§ 1. (1) Dieses Bundesgesetz…" }` | `U.getSrcText` Z.613, `U.setSrcText` Z.627/634 |
| `srcNotes` | `ehds.<proj>.srcNotes` | `{ "kraus2025": "Noch prüfen: Kap. 3" }` | indirekt (📝-Modal in assignPanel; Smart-Filter `notizen` liest Z.53) |
| `resolutions` | `ehds.<proj>.resolutions` | `{ "kraus2025": { "formatVersion":"1.0", "sourceId":"kraus2025", "stellen":[…] } }` | Auto-Fetch-Übernahme Z.453-457 |
| `customSources` | `ehds.<proj>.customSources` | Array von Quell-Patches (via `Projects.saveCustomSource`, Z.184/313/494) | ＋ Quelle, Quelle aus Datei, 🤖 Ergänzung |
| `fileSearch` | `ehds.<proj>.fileSearch` | `{ "kraus2025": { "venue":"JMIR", "publisher":"…", "openAccess":true, "problem":null } }` | nur gelesen (Datei-Auftrag Z.873) |
| Export-Datei | — | `ehds-belegstand.json` = `Levels.exportState()` (Status, Zitate, Positionen, Links, Notizen) | ⭳ Sichern Z.95; ⭱ Laden Z.96-101 → `Levels.importState` + `location.reload()` |

### IndexedDB (pdfstore.js) — KOMPLETTES Schema
- **DB-Name:** `ehds-pdfstore`, **Version:** `1` (pdfstore.js:32). Beim `onupgradeneeded` werden zwei Object-Stores OHNE keyPath/Indizes angelegt (out-of-line keys):
  - **Store `handles`**: genau ein Eintrag — Key `'dir'` → `FileSystemDirectoryHandle` (strukturiert klonbar; Z.55, 81, 104).
  - **Store `blobs`**: Key-Namensräume (Klassifikation beim init, Z.44-51):
    - `<srcId>` (z. B. `kraus2025`) → `Blob`/`File` (PDF) — Haupt-PDF einer Quelle.
    - `inbox:<Original-Dateiname>` (z. B. `inbox:Study_Health_2024.pdf`) → `Blob` — Ablage, unzugewiesen.
    - `img:<srcId>` → Bild-`Blob` — Quelle als Bild definiert.
    - `<srcId>~x<ts36><rand36>` (via `U.extraKey`, util.js:586, geschrieben von PdfEngine-Material) → weitere PDFs/Bilder; landen beim init als normale `files`-Einträge `kind:'blob'` (kein eigener Präfix!).
- **WICHTIG:** Der Speicher ist arbeitsübergreifend/global (keine Projekt-Scopes) — Warntexte erwähnen explizit „auch Mobile Sensors" (views_quellen.js:107, pdfstore.js:155-159).

### In-Memory
- `PdfStore`: `db`, `dirHandle`, `status: 'none'|'connected'|'needs-permission'`, `files: Map<id,{kind:'dir'|'blob'}>`, `images: Set<id>`, `inbox: Set<name>`, `_urls: Map<key,objectURL>`, `listeners: [{fn,anchor}]` (pdfstore.js:11-19).
- `Quellen.filter` `{q:'', coll, sort}` + `Quellen._smart` (Filterfunktionen, Z.49-56).
- `renderLibDetail._fetched: {srcId:true}` — Resolution-Fetch nur 1× pro Session (Z.453-454).
- `renderDetailPdf._ctl` — aktive PDF-Engine-Instanz (views_studio.js:1660; vom Router bei Routenwechsel zerstört, app.js:214-216).
- `U.pdfStatusCache: {id: true|false|null}` — wird nach jedem Datei-Import/-Reset auf `{}` zurückgesetzt (Z.103, 109, 126, 130, 257, 264, 274, 322, 839).

---

## 4. UI-Struktur & Layout

### Seitengerüst (views_quellen.js:17-23)
```
div.lib
├─ aside.lib-rail            ← Spalte 1: Sammlungen + Werkzeuge
├─ section.lib-list          ← Spalte 2: Suchleiste + Zeilenliste
├─ div.pane-resize           ← Drag-Griff (role=separator, aria-orientation=vertical,
│                               title="Breite ziehen · Doppelklick = Standard")
└─ aside.card.lib-detail     ← Spalte 3: Detailpanel
```
- **Grid** (app.css:714): `grid-template-columns: 220px minmax(280px, var(--lib-list-w, 34%)) 7px minmax(360px, 1fr); gap:14px; align-items:start`.
- **Drag-Resize** (views_quellen.js:26-37): `U.resizer` auf `.pane-resize`; setzt `--lib-list-w` in % (geklemmt 18–60 %), px-Klemmen `min:240, max:innerWidth-620`; Persistenz `uiLibPct` (gerundet); Doppelklick → `removeProperty` + `storeSet(null)` = Standard 34 %.
- **Responsive** (app.css:716-717): `≤1199px`: 2 Spalten `205px minmax(0,1fr)`, Resizer versteckt, `.lib-detail` über volle Breite (`grid-column:1/-1`, rutscht unter die Liste); `≤720px`: einspaltig.
- **Sticky**: `.lib-rail` und `.lib-detail` beide `position:sticky; top:calc(var(--topbar-h) + 14px); max-height:calc(100vh - var(--topbar-h) - 30px); overflow-y:auto` (app.css:719-722, 762-766). `.lib-detail` zusätzlich `.card` mit `padding:18px 20px`.

### Spalte 1 — Rail (views_quellen.js:62-85)
```
div.eyebrow "Bibliothek"
button.lib-coll[data-c=alle] > span(flex:1;text-align:left) + span.cnt
div.eyebrow "Typen"           → je KIND ein button.lib-coll[data-c=kind:<k>]
div.eyebrow "Status"          → offen/fertig/pdf-fehlt/notizen (+custom, nur wenn vorhanden)
div.lib-tools
├─ button#qNew.btn.btn-sm.btn-primary (margin-top:6px)
├─ div.eyebrow "Belegstand"
├─ button#qExport.btn.btn-sm · label.btn.btn-sm(>input#qImport[type=file][accept=application/json][hidden])
├─ div.eyebrow "Dateien (PDF)"
├─ button#qImportFiles · button#qAuftrag · button#qInbox[hidden] · button#qStoreReset
├─ div.small.mut#qPdfMsg (margin-top:4px)
└─ [Legacy, nur wenn PdfStore.dirHandle] div.row(gap:5px;margin-top:5px;flex-wrap:nowrap)
     #qDirRe (btn, flex:1) ODER span.small.mut "📁 Ordner verbunden (N)" · #qDirForget (btn-ghost "✕")
```
`.lib-coll`: `font:500 13px/1.3; padding:6px 9px; border-radius:8px`; aktiv = `background:var(--accent-soft); color:var(--accent-ink); font-weight:600`; `.cnt` = `600 10.5px mono, var(--muted)` (app.css:726-735). `.lib-tools .btn-primary` invertiert: transparent + `1px solid var(--accent-line)` (app.css:125-126).

### Spalte 2 — Liste (views_quellen.js:370-380, 405-415)
```
div.lib-listbar (flex, gap:8px, margin-bottom:10px)
├─ input#qSearch[type=search] (flex:1) placeholder="Titel, Autor, id …"
└─ select#qSort (4 Optionen)
div.lib-rows (flex-col, border, radius, surface, overflow:hidden)
└─ a.lib-row[href=#/quellen/<id>] (+.active)
   ├─ span.ic  (KIND_ICONS, gefiltert: saturate(.55) contrast(.95), opacity:.85)
   ├─ span.bd > span.ttl (600/14px, ellipsis) + span.sub (12.5px muted, ellipsis)
   └─ span.meta > span.mono.small "N×" + Levels.bar(nums) (54px breit) + span.pdfflag[data-id]
```
`.lib-row`: `padding:10px 12px; border-bottom:1px solid var(--border)`; hover `--surface-2`; aktiv `--accent-soft` + `inset 2.5px 0 0 var(--accent)` (app.css:743-752). `pdfflag` 11px/20px breit; `.missing` → `var(--warn)`.

### Spalte 3 — Detail (views_quellen.js:464-466, 554-624)
```
div.libd-head   ← PdfEngine.assignPanel: <details.src-panel.assign-inline[open]>
│                 summary.sp-bar (▸-Caret · eyebrow "Quelle" · Titel+Autor·Jahr · Datei-Status-Chip)
│                 div.sp-body: U.srcHeadHtml (Chips Art·Jahr·id·＋manuell, Serif-Titel 19.5px, Autor·DOI)
│                 div.row.sp-actions: 📚 Dossier · [↗ offizielle Seite] · ✎ · 📝[ ✎] · extraActions
│                 Datei-Block (✓ Datei zugeordnet / mat-switch 📄🌐🖼📝Σ / ⭳ Download / ⭱ lokal / 📥 Dateiverzeichnis / Kandidaten-Vorschau)
│                 sp-mat (Material-Liste + Hinzufügen)
div.libd-body (flex-col, gap:8px, margin-top:12px)
├─ [custom+vermuteteStellen] details.libd-sec[open] "Referenzierungsvorschläge" + span.chip.ki.mini "✦ N"
│    └─ .sec-b > .cite-list > .cite-row (num="✦"; claim; Link "passt zu #/studio/<abschnitt>"; span.br-vermutet "vermutet <b>…</b>")
├─ [Rechtsquelle] details.libd-sec[open] "Fundstellen-Register" + chip "N §§|Artikel"
│    └─ Hinweistext + .prov-list > .prov-row (b=Key mono 12px min-width:74px · .cites Links "<sectionId><sup>fn</sup>" → #/studio/<sec>/pruefen · mut mono "N×")
├─ details.libd-sec[open wenn isDoc] "Anhang — PDF der Quelle" [+ chip.mini "konsolidierte Fassung" bei Recht]
│    └─ .sec-b.pdfhost → renderDetailPdf: chip "✓ Datei zugeordnet" + btn#dPdfOpen "↗ Tab" + .qd-pdfhost (PdfEngine.mount, fit)
│       oder mut-Text "Keine Datei zugeordnet — Zuordnung oben im Kopf (⭳ Download · ⭱ Datei lokal wählen · 📥 Aus Dateiverzeichnis)."
│       bei !isDoc zusätzlich notice.info über Fundstellen-Nachweis (views_studio.js:1669-1670)
├─ details.libd-sec[open] "Zitierstellen" + chip N
│    └─ .cite-list > .cite-row:
│       span.num = Levels.dot(fn) + "[<fn>]" (mono 11px, accent-ink)
│       a.btn.btn-sm.cite-go "→ Studio" → #/studio/<sectionId>/pruefen[/<paragraphId>]
│       span.bd: claim/footnoteText (small) · [span.br-vermutet "vermutet <b>fundstelle</b>"]
│                · [Level≥2: "❝ „Zitat…"" (120 Zeichen, color:var(--ink-2))] · [chip.mini "S. N"] · [Level≥3: chip.mini.ok fundstelle]
├─ [wenn Mentions] details.libd-sec[open wenn offene] "Text-Erwähnungen" + chip[.ok].mini "N bestätigt" + [chip.ki.mini "✦ N offen"]
│    └─ Hinweistext + .ment-list > .mention-row.<status|merged>:
│       span.st: ❞ (bestätigt/beleg) · "·" (verworfen) · ✦ (offen)
│       span.bd: a "⌖ <sectionId> · <paraId>" → #/studio/<sec>/pruefen/<para> · „Snippet“
│                · [chip.ki.mini "N Kandidaten"] · [chip.ok.mini "⇒ Beleg [fn]"] · [mut "(verworfen)"]
│       span.acts: offen → ✓(btn-primary,data-mv=bestaetigt) + ✗(data-mv=verworfen); sonst ↺(data-mv=offen, title="zurücksetzen")
└─ details.libd-sec[open wenn !isDoc && kein Text] "Text der Quelle" + chip.ok.mini "✓ N.Nk Zeichen" | chip.mini "markierbare Alternative zum PDF"
     └─ Hinweistext + textarea#qdSrcText (min-height:90px; font-size:12.5px)
        + row: btn#qdSrcTextSave "Speichern" · label "\.txt laden" (input#qdSrcTextFile accept=.txt,text/plain) · span#qdSrcTextMsg
```
Sektionen: `details.libd-sec` = Border+Radius auf `--surface-2`; Summary `600 13px, padding:10px 13px`, eigener `▸`-Marker mit `transform:rotate(90deg)`-Transition `.13s ease` bei `[open]` (app.css:776-786).

### Modals (alle über `U.modal` → `#modalRoot > .modal-back > .modal[role=dialog]`, Kopf mit ✕, ESC/Backdrop schließt; util.js:648-667)
1. **＋ Neue Quelle anlegen** (Z.148-164): Intro-Absatz; `div.grid.grid-2 (gap:10px)` mit 6 Labeln (Titel*, Autor(en), Jahr[number, width:100px], Typ[select KIND_LABELS], Container/Journal, DOI oder URL); darunter volle Breite `id (interner Schlüssel)`; Row: btn-primary „Anlegen" + `#nsMsg`.
2. **🗄 Quellen- & Dateispeicher** (Z.207-288): Intro mit Zählern; Button-Row (`＋ Dateien laden` primary · `＋ Neue Quelle` · spacer · `🗑 Speicher leeren` ghost); Eyebrow „Nicht zugeordnete Dateien · N"; `.st-inbox > .st-file` (Dateiname 600 13px ellipsis; `.st-file-acts`: select.st-sel[flex:1 1 180px] + „→ zuweisen" primary + „＋ Quelle aus Datei" + 🗑 ghost); Eyebrow „Quellen · N/M mit Datei"; `.st-srclist (max-height:40vh, scroll) > a.st-src` (Status-Dot 9px rund, grün `.on` · Kurzname+Untertitel · Tag rechts: „✓ Datei" | „＋ manuell" | „kein PDF"), Klick navigiert zu `#/quellen/<id>` + `U.closeModal()`.
3. **＋ Quelle aus Datei erstellen** (Z.296-306): Titel* (grid-column:1/-1, vorbelegt aus Dateinamen), Autor(en), Jahr (width:110px), Typ (default `artikel`), id (vorbelegter Slug); Button „Anlegen & zuweisen".
4. **⭱ Dateien importieren (PDF / ZIP)** (Z.719-732): Erklärtext; Row: label-btn-primary „Dateien wählen" (input multiple, accept `.pdf,.zip,application/pdf,application/zip`) + Checkbox `#imAllSrc` „alle Quellen in der Auswahl zeigen (auch schon belegte)"; `#imList (max-height:320px, scroll)` mit `.qs-row[.rich]`-Zeilen (Checkbox · `<code>Name</code>` · „X.X MB" · Status-Chip · select max-width:420px); Footer: `#imGo` (disabled-Logik s. §6) + `#imMsg`.
5. **↗ Offizielle Seite — Link ändern** (Z.642-654): Hinweis „DOI/Verlag/EUR-Lex/RIS. Leer + Übernehmen stellt den automatischen Vorschlag wieder her."; `input#qlUrl[type=url]` (nur Override vorbelegt); ggf. „Aktueller Vorschlag: `<code>url</code>`"; Button „Übernehmen".
6. **🤖 Ergänzung** (Z.469-500): `U.gptModal` — Standard-GPT-Dialog (Magic-Bar „Mit Claude ausführen" · ⧉ Prompt · ✎ Bearbeiten · ⚙; Antwort-Textarea; „⭱ Übernehmen"; util.js:779-802).

---

## 5. Design-Rohwerte

**Farben:** ausschließlich CSS-Variablen — im JS inline nur `var(--ink-2)` (Zitat-Farbe, views_quellen.js:573) und `var(--bad)` (Import-Fehlertext, Z.753). Alles andere über Klassen (chip/ok/ki/warn, accent-soft usw.).

**Inline-Größen im JS:** Rail-Label `style="flex:1;text-align:left"` (Z.60); Eyebrow-Margins `2px 0 6px` / `12px 0 6px` (Z.63-79); `#qPdfMsg margin-top:4px`; Modal-Grids `gap:10px;margin-top:10px`; Jahr-Inputs `width:100px` bzw. `110px`; Import-Liste `max-height:320px;overflow-y:auto`; Import-Select `max-width:420px`; Quellentext-Textarea `min-height:90px;font-size:12.5px`; Notiz-Textarea `min-height:140px` (util.js:449); GPT-Antwortfeld `min-height:110px;font-family:var(--font-mono);font-size:12px`.

**Icon-/Symbolzeichen (exakt):** 📚 (Alle Quellen/Dossier) · ◌ („Nicht fertig belegt") · ✓ · ✎ · ＋ (U+FF0B Fullwidth Plus!) · ⭳ (U+2B73) · ⭱ (U+2B71) · ⌗ (U+2317) · 📥 · 🗑 · 🗄 · 🤖 · ✦ (KI/Vermutung) · ❝ ❞ (Zitat/Erwähnung) · ⌖ (Textstelle) · ↺ · ✗ · ✕ · 📁 · 📄 · 🌐 · 🖼 · 📝 · Σ · § · Mittelpunkt `·` · Gedankenstrich `—` · ⇒ · ▸ · ↗ · ⧉ · ⚙ · KIND_ICONS: artikel 📄, konferenz 🎤, norm 📐, report 📊, online 🌐, recht-eu 🇪🇺, recht-at 🇦🇹 (util.js:930-932).

**KIND_LABELS (util.js:926-929):** artikel „Peer-Review-Artikel", konferenz „Konferenzbeitrag", norm „Norm", report „Report/Bericht", online „Online-Quelle", recht-eu „Rechtsquelle EU", recht-at „Rechtsquelle AT".

**Wörtliche UI-Texte (Auswahl, exakt):**
- Sammlungen: „📚 Alle Quellen" · „◌ Nicht fertig belegt" · „✓ Vollständig belegt" · „📄 PDF fehlt" · „✎ Mit Notizen" · „＋ Manuell ergänzt".
- Rail-Buttons: „＋ Quelle" · „⭳ Sichern" · „⭱ Laden" · „⭱ Import (PDF/ZIP)" · „⌗ Datei-Auftrag" · „📥 Ablage (N)" · „🗑 Dateispeicher leeren" · „📁 Ordner wieder verbinden" · „📁 Ordner verbunden (N)".
- Sortier-Optionen: „Zitierstellen ↓" · „Titel A–Z" · „Jahr ↓" · „Offene zuerst"; Such-Placeholder „Titel, Autor, id …".
- Leere Liste: „Keine Quellen passen zum Filter."
- Placeholder-Panel (Z.435-443): Eyebrow „Bibliothek"; „N Quellen · M Zitierstellen."; „X belegt · Y Original · Z vermutet"; „Links eine Quelle wählen. Dateien aus dem ⌗ Datei-Auftrag (extern besorgen → ZIP zurückgeben) ordnet der ⭱ Import automatisch der richtigen Quelle zu."
- Store-Reset-Confirm (Z.107): „Dateispeicher wirklich leeren?\n\nN im Browser gespeicherte Datei(en) inkl. Ablage werden gelöscht — für ALLE Arbeiten (auch Mobile Sensors). Repo-Dateien (sources/…) bleiben. Belege/Markierungen bleiben ebenfalls erhalten, verweisen aber ggf. auf andere Seiten, wenn eine neuere Fassung geladen wird."; Erfolgsmeldung: „✓ Dateispeicher geleert — neueste Dateien über ⭳ Download je Quelle oder ⭱ Import laden."
- Import-Chips (Z.756-759): „✓ automatisch erkannt" · „= Quellen-id" · „✦ Vorschlag (bestätigen)" · „→ Ablage"; Button-Zustände: „✓ N zuordnen · M in Ablage" / „📥 M in die Ablage" / „✓ Zuordnen"; Ergebnis: „✓ N zugeordnet · M in der Ablage (Zuweisen-Dialog)".
- Validierungen: „✗ id und Titel sind Pflicht." · „✗ id „X“ existiert schon." · „✗ id „X“ existiert schon — dann lieber „→ zuweisen“." · „Import fehlgeschlagen: <msg>" · „kein PDF" · „ZIP ist leer".
- Zitierstellen-Zeile: „→ Studio"; „vermutet **<fundstelle>**"; Erwähnungen: „N bestätigt" / „✦ N offen" / „⇒ Beleg [n]" / „(verworfen)" / „N Kandidaten".
- Quellentext-Sektion: „Der hinterlegte Text ist im Splitscreen unter **☰ Text** markierbar wie ein PDF — praktisch für Gesetzestexte (EUR-Lex/RIS „Text kopieren“) und Online-Quellen."; „✓ N.Nk Zeichen" · „markierbare Alternative zum PDF" · „✓ gespeichert".
- ANLEITUNG.txt des Datei-Auftrags: 9 Zeilen ASCII (bewusst ohne Umlaute, Z.883-893).

---

## 6. Verhalten & Interaktionen

### Rail
- **Sammlung klicken** (Z.87-92): setzt `Quellen.filter.coll`, persistiert `qColl`, togglet `.active` nur per Klassen (kein Rerender der Rail), ruft `onChange` = `renderLibList` neu.
- **⭳ Sichern** (Z.95): `U.download('ehds-belegstand.json', Levels.exportState())`.
- **⭱ Laden** (Z.96-101): File-Input → `Levels.importState(text)` → `location.reload()`; Fehler → `alert('Import fehlgeschlagen: …')`.
- **🗑 Dateispeicher leeren** (Z.105-113): `confirm` mit Zähler → `PdfStore.clearAll()` → `pdfStatusCache={}` → Meldung in `#qPdfMsg` → Liste + Inbox-Button aktualisieren.
- **📥 Ablage**: nur sichtbar wenn `listInbox().length>0`; Label live „📥 Ablage (N)" via `PdfStore.onChange(refreshInbox, rail)` (Z.134-142); öffnet `importFilesModal(…, {inbox:true})`.
- **Legacy-Ordner** (Z.118-133): nur bei vorhandenem `dirHandle`; `needs-permission` → Button „wieder verbinden" (`PdfStore.reconnect()`, braucht Nutzer-Geste); sonst Status-Text; ✕ → `forgetDirectory()`.

### Liste
- **Suche** (input, Z.425): live, case-insensitive über `title+author+id+container`; **Sortierung** (change, Z.426) persistiert.
- **Sortierlogik** (Z.395-399): `titel` → `localeCompare(…, 'de')`; `jahr` → Jahr absteigend; `status` → Erledigungsquote aufsteigend, Tiebreak Zitierstellen absteigend; Default `zit` → `citations.length` absteigend.
- **Unbekannte Sammlung** (Z.386-391): Fallback auf `alle` inkl. Persistenz + Rail-Highlight (z. B. `custom` gewählt, aber keine Custom-Quellen mehr).
- **PDF-Flag** (Z.414-420): Dokument-Quellen starten mit „·", dann async `U.detectPdf` → „📄" (title „PDF verfügbar") oder „—" (+`.missing`, title „PDF fehlt"); Rechtsquellen zeigen statisch „§". `U.detectPdf`-Kette: PdfStore.has → Cache → pdfManual → unter `file:` `null` → HTTP-HEAD `sources/<id>.pdf` (util.js:601-611).
- `PdfStore.onChange(()=>draw(), rowsEl)` — Liste zeichnet bei jeder Store-Änderung neu (Z.427).

### Detailpanel
- **Auto-Resolution** (Z.452-458): Wenn keine Resolution gespeichert und noch nicht versucht → `U.fetchResolution` (`data/resolutions/<id>.json`, nur HTTP); bei Treffer `U.setResolution` + komplettes Rerender des Panels.
- **Kopf**: `PdfEngine.assignPanel` mit `onDone`/`onMeta` = Panel-Rerender; bei `s.custom` zwei `extraActions`: „🤖 Ergänzung" und „🗑" (Z.507-514).
- **🤖 Ergänzung importieren** (Z.475-497): JSON parsen; nur Whitelist-Metafelder `title,author,year,container,doi,url,kind,longTitle` übernehmen (id NIE überschreibbar); `dossier` (string), `keyPoints` (muss Array), `zitierweise` (string), `stellen` (muss Array, Objekte gefiltert) → `vermuteteStellen`; `meta.official`/`meta.file` → `U.setSrcLink`; Rückgabe „übernommen"; `onDone` → `location.reload()`.
- **🗑 Quelle löschen** (Z.501-506): `confirm(„Quelle „T“ wirklich entfernen?")` → `Projects.removeCustomSource` → `location.hash='#/quellen'` + `location.reload()`.
- **Zitierstellen-Zeile**: Link „→ Studio" springt zu `#/studio/<sec>/pruefen[/<para>]`; Anzeige eskaliert mit Beleg-Level (Zitat ab L2, gekürzt auf 120 Zeichen mit „…"; grüner Fundstellen-Chip ab L3).
- **Erwähnungen** (Z.590-608): ✓/✗/↺ rufen `Mentions.setStatus(mt.key, status, srcId)` und zeichnen NUR die Erwähnungsliste neu (`drawM`), nicht das Panel. Sektion default-offen nur bei offenen Erwähnungen.
- **Quellentext speichern** (Z.626-630): `U.setSrcText` → „✓ gespeichert" → nach 600 ms komplettes Panel-Rerender (damit Chip „✓ N.Nk Zeichen" erscheint). `.txt laden` (Z.631-636) liest `file.text()` und rendert sofort neu.
- **linkEditModal**: leerer Wert löscht den Override → automatischer Vorschlag (DOI→`https://doi.org/<doi>` bzw. url, util.js:236-245) gilt wieder.

### ＋ Quelle / Quelle aus Datei
- **id-Vorschlag live** (Z.166-175): erster Token von Autor (Split an Space/Komma) sonst erstes Titelwort sonst „quelle", lowercased, nur `[a-z0-9]`, + Jahr, max 30 Zeichen; stoppt sobald das id-Feld manuell berührt wurde (`dataset.touched`).
- **Speichern** (Z.177-200): id-Sanitizing `[^a-z0-9-]`→''; Pflicht id+Titel; Kollisionsprüfung `SRC_BY_ID`; DOI-Feld wird heuristisch verteilt: `/^10\./`→doi, `/^https?:/`→url; danach `saveCustomSource`+`mergeCustomSources`+`rebuildDataIndexes`, Modal zu, `location.hash='#/quellen/<id>'`, App-Container geleert + `renderQuellen(app, id)` direkt (kein Reload).
- **sourceFromFile** (Z.293-325): Titel-Guess = Dateiname ohne `.pdf`, `[_-]+`→Space; id-Guess = NFD-normalisierter Slug (max 30); nach Anlegen `await PdfStore.assignInbox(name, id)`.

### Import-Modal (Z.718-859)
1. Dateiauswahl (mehrfach, wiederholbar): ZIPs via `ZipUtil.read` entpackt (Fehler je Eintrag als ✗-Zeile; leeres ZIP = Fehler), PDFs direkt; `e.target.value=''` erlaubt Re-Auswahl derselben Dateien.
2. **Matching je Datei** (`addItem`, Z.791-811): (a) Referenz-Hash `ts-[0-9a-f]{8}` im (lowercased) Dateinamen → `U.srcByHash` → `{sure,exact,hash}` = „✓ automatisch erkannt", Häkchen an; (b) Dateiname exakt = Quellen-id → „= Quellen-id", Häkchen an; (c) sonst `U.matchFilename` → unverbindlicher „✦ Vorschlag (bestätigen)" — Select vorbelegt, Häkchen AUS; (d) sonst „→ Ablage".
3. Select-Änderung setzt `sel` und `checked=!!value` (Rerender); Checkbox-Änderung aktualisiert nur den Go-Button (`syncGo`, ohne Rerender, Z.769-772).
4. **Go-Button** (Z.783-788): aktiv sobald zuzuordnende ODER neue (nicht aus der Inbox stammende) Dateien da sind — Unbestätigtes wandert in die Ablage, „kein stiller Verlust"; Ausführung (Z.832-850): checked+sel → `assignInbox` (Inbox-Herkunft) bzw. `putData` (Blob→Uint8Array); sonst `addInbox`; `pdfStatusCache[sel]=true`; Erfolgsmeldung; Fehlerzeilen bleiben in der Liste stehen.
5. `opts.inbox:true` (Z.852-857): lädt alle Inbox-Blobs als vorbefüllte Items (`fromInbox=true`).

### Datei-Auftrag (Z.867-903)
Filter: alle Quellen ohne `PdfStore.has`; je Eintrag Referenz-Hash + Metadaten + Links (s. §7); ZIP `datei-auftrag.zip` aus `auftrag.json` (JSON.stringify mit Einrückung 1) + `ANLEITUNG.txt` via `ZipUtil.create`; Download über temporäres `<a download>` + `URL.revokeObjectURL` nach 500 ms.

### PdfStore-Verhalten (Randfälle)
- `init` schluckt alle Fehler (privater Modus o. Ä. → App läuft ohne Speicher weiter).
- ObjectURL-Cache wird bei jedem put/remove/assign invalidiert (revoke + delete), sonst würden alte PDFs angezeigt.
- `removeFile` auf `kind:'dir'` → `false` (Ordner ist read-only); `clearAll` löscht NUR Blobs, Ordner-Einträge bleiben.
- `getData`-HTTP-Fallback ist unter `file:` deaktiviert; `open`-HTTP-Fallback nur bei bestätigtem `pdfStatusCache===true`.
- Listener-Autocleanup: bei jedem `_emit` werden Listener toter DOM-Anker entfernt (verhindert Leaks pro View, Z.24-27).

---

## 7. Datenformen

```jsonc
// Quelle (window.DATA_SOURCES[i] / SRC_BY_ID[id]) — von der Bibliothek genutzte Felder
{
  "id": "kraus2025",
  "title": "Health Data Sharing in Europe",
  "longTitle": "…voller Titel…",              // optional
  "author": "Kraus, M. u.a.",
  "year": 2025,
  "container": "JMIR 27(3)",
  "doi": "10.2196/12345", "url": null,
  "kind": "artikel",                            // artikel|konferenz|norm|report|online|recht-eu|recht-at
  "custom": true,                               // manuell angelegt (Projects.customSources)
  "links": { "official": "https://…", "file": "https://….pdf" },  // optional, + linkOverrides
  "citations": [ /* wie stellen */ ],
  "stellen": [{                                 // Zitierstellen der Arbeit
    "footnote": 41, "sectionId": "3.2.1", "paragraphId": "p-3-2-1-2",
    "claim": "Aussage der Arbeit …", "footnoteText": "Kraus u.a., …",
    "fundstelle": "S. 12", "suchHinweis": "wörtliche Passage|zweite Passage"
  }],
  "vermuteteStellen": [{                        // nur custom, aus 🤖 Ergänzung
    "claim": "…", "fundstelle": "S. 3", "suchHinweis": "…|…", "abschnittVermutet": "3.2.1"
  }],
  "dossier": "Markdown …", "keyPoints": ["…"], "zitierweise": "Vollzitat …"
}

// 🤖 Ergänzung — erwartetes Antwort-JSON (views_quellen.js:349-360)
{ "sourceId": "kraus2025",
  "meta": { "title": "…", "author": "…", "year": 2024, "container": "…", "doi": "…", "url": "…",
            "official": "<offizieller Link>", "file": "<Direkt-PDF-Link oder null>" },
  "dossier": "<Markdown>", "keyPoints": ["…"], "zitierweise": "…",
  "stellen": [{ "claim": "…", "fundstelle": "S. x bzw. Art/§", "suchHinweis": "…|…", "abschnittVermutet": "3.2.1" }] }

// Referenzierungsdurchlauf — erwartetes Antwort-JSON (views_quellen.js:703-708)
{ "formatVersion": "1.0", "sourceId": "kraus2025", "generatedBy": "gpt",
  "stellen": [{ "footnote": 41, "seite": 12,            // ODER "fundstelle": "Art 5" bei positionType 'fundstelle'
                "zitat": "wörtliche Originalpassage", "status": "bestaetigt", // |"teilweise"|"nicht_gefunden"
                "kommentar": "kurz" }] }

// auftrag.json im Datei-Auftrag-ZIP (views_quellen.js:869-896)
{ "format": "thesis-studio-dateiauftrag", "version": 1,
  "eintraege": [{
    "hash": "ts-3fa9c012", "dateiname": "ts-3fa9c012.pdf",
    "titel": "…", "autor": "… | null", "jahr": 2025,
    "doi": "10… | null", "venue": "… | null",
    "linkOffiziell": "https://… | null", "linkDatei": "https://… | null",
    "openAccessBevorzugt": true }] }

// Import-Item (importFilesModal, in-memory; views_quellen.js:737, 806-810)
{ "name": "paper.pdf", "data": "<File|Uint8Array>", "fromInbox": false, "size": 1234567,
  "match": { "id": "kraus2025", "sure": true, "exact": true, "hash": true },  // oder null
  "suggest": { "id": "kraus2025", "score": 65, "sure": true },               // U.matchFilename, oder null
  "sel": "kraus2025", "checked": true, "err": null }                          // err: "kein PDF" | ZIP-Fehler

// Erwähnung (Mentions.forSource; views_quellen.js:592-603)
{ "key": "…", "sectionId": "3.2.1", "paraId": "p-3-2-1-2", "snippet": "Kraus (2025) zeigt …",
  "status": "offen",   // offen|bestaetigt|verworfen|beleg (beleg = mit Fußnote zusammengeführt)
  "fn": 41, "candidates": ["kraus2025", "kraus2023"] }

// Levels.countsFor(nums) → { "total": 12, "l1": 3, "l2": 4, "l3": 5 }
// U.matchFilename Scoring: id exakt=100 · id-Teilstring=50 · Titel-Token-Quote max 40 ·
//   Autor-Nachname 25 · Jahr 15; Ergebnis null unter Score 25; sure ab 60 (util.js:526-547)
// U.srcHash: 'ts-' + CRC32hex8( norm(longTitle||title) + '|' + norm(author) + '|' + jahr )
//   norm = lowercase, NFD ohne Diakritika, nur [a-z0-9] (util.js:258-265) → Identität Titel+Autor+Jahr
```

---

## 8. Abhängigkeiten

**Wird aufgerufen von:** Router `app.js:231` (`renderQuellen`); Topbar `app.js:141` (`storeModal`); `pdfengine.js:563` (`linkEditModal`, guarded); Studio-Views verlinken hierher (`#/quellen/<id>`, z. B. util.js:436, figures.js:66). `renderDetailPdf._ctl` wird vom Router bei jedem Routenwechsel zerstört (app.js:214-216).

**Ruft auf:** `U` (util.js), `Levels` (levels.js), `Mentions` (mentions.js), `PdfEngine` (pdfengine.js: assignPanel, mount via renderDetailPdf), `renderDetailPdf` (views_studio.js:1657), `PdfStore` (pdfstore.js), `ZipUtil` (ziputil.js: read/create/crc32), `Projects` (projects.js: saveCustomSource:256, removeCustomSource:262, mergeCustomSources:238), `rebuildDataIndexes` (util.js:944), Browser-APIs (`confirm`, `alert`, `location.hash/reload`, `FileReader`-frei via `file.text()`, `URL`, `TextEncoder`).

**PdfStore wird genutzt von:** views_quellen.js (überall), pdfengine.js (assignPanel-Dateiblock, Kandidaten, Bilder, Material), views_studio.js (Viewer, `PdfStore.open`), app.js (Boot wartet vermutlich auf `PdfStore.ready`). PdfStore selbst hat nur die eine Fremd-Abhängigkeit `U.pdfStatusCache` (pdfstore.js:305).

**Ladereihenfolge-Kopplung:** `PdfStore` ist ein top-level `const` — `U.detectPdf` prüft defensiv `typeof PdfStore !== 'undefined'` (util.js:602-603).

---

## 9. Flutter-Hinweise

1. **3-Spalten-Grid mit Drag-Resize:** `Row` mit fester Rail (220 px), Liste als `Flexible` mit persistiertem Breiten-% (18–60 %), `GestureDetector`+`MouseRegion` als 7-px-Griff (Doppel-Tap = Reset). `--lib-list-w` als Riverpod-State + `SharedPreferences`-Key (Pendant `uiLibPct`). Breakpoints 1199/720 px über `LayoutBuilder` nachbauen (2-spaltig: Detail unter der Liste; einspaltig: Navigation Liste→Detail als eigene Route erwägen — Verhalten dokumentieren, Original stapelt nur).
2. **Sticky+Scroll:** Rail und Detail sind eigenständige Scrollbereiche mit Topbar-Offset — in Flutter je Spalte ein eigener `SingleChildScrollView`/`CustomScrollView`; „sticky" entfällt (Spalten sind ohnehin viewport-hoch).
3. **`<details>`-Sektionen:** `ExpansionTile` bzw. eigenes Widget mit ▸-Rotation (130 ms ease) und den Default-open-Regeln (Anhang nur bei `positionType=='seite'`; Erwähnungen nur bei offenen; Quellentext nur bei `!isDoc && !text`).
4. **IndexedDB → lokale Dateien + Metadaten-DB:** Empfehlung: PDFs/Bilder als Dateien im App-Support-Verzeichnis (`path_provider`), Schlüsselschema 1:1 übernehmen (`<srcId>.pdf`, `inbox/<name>`, `img/<srcId>`, `<srcId>~x…`); alternativ Drift/sqflite-BLOB-Tabelle. `PdfStore.ready` → async Init-Provider (`FutureProvider`), auf den alle Views warten. Das Listener-System mit DOM-Anker entfällt — ChangeNotifier/StreamProvider ersetzt `onChange` inkl. Autocleanup.
5. **File System Access API (Legacy-Ordner)** geht in Flutter NICHT 1:1 (kein persistierbares Handle-Objekt im Web-Sinn). Da das Feature im Original bereits „entfernt, nur Altbestand" ist (views_quellen.js:115-117): weglassen; Ersatz wäre allenfalls ein gemerkter Verzeichnispfad (Desktop: `file_picker` + dart:io-Scan — auf Desktop sogar einfacher, kein Permission-Tanz).
6. **ObjectURL-Cache:** entfällt — PDF-Viewer (z. B. `pdfrx`/`pdfx`) direkt mit `Uint8List` aus `getData` füttern; die HTTP-Fallback-Kette (`sources/<id>.pdf`) nur behalten, wenn die Flutter-App die Assets bundlet (dann `rootBundle`-Fallback statt fetch).
7. **`ts-`Hash-Kompatibilität ist KRITISCH:** `U.srcHash` = CRC32 (ZipUtil-Implementierung, Standard-Polynom) über `norm(titel)|norm(autor)|jahr`, hex 8-stellig, Präfix `ts-`. Die Flutter-Version MUSS bitidentisch rechnen (inkl. NFD-Diakritika-Strip und `[^a-z0-9]`-Filter), sonst brechen bestehende Datei-Aufträge/ZIP-Rückläufe. Ebenso `matchFilename`-Scoring 1:1 portieren (Schwellen 25/60/100).
8. **ZIP:** `archive`-Package für Lesen (Import) und Schreiben (Datei-Auftrag mit `auftrag.json`, Einrückung `JsonEncoder.withIndent(' ')` ≈ `JSON.stringify(...,1)` + `ANLEITUNG.txt` ohne Umlaute beibehalten).
9. **`location.reload()`-Stellen** (Belegstand-Import Z.99, Ergänzungs-Import Z.499, Quelle löschen Z.505): in Flutter durch gezieltes State-Invalidieren ersetzen (Provider-Refresh + Router-Neuaufbau) — es gibt kein „Seite neu laden".
10. **Routing:** `#/quellen`, `#/quellen/<id>`, Links zu `#/studio/<sec>/pruefen[/<para>]` → go_router-Pfade; die Studio-Links aus Zitierstellen/Erwähnungen/Fundstellenregister müssen Abschnitt + Absatz als Parameter tragen.
11. **`confirm`/`alert`:** durch `AlertDialog` ersetzen; die exakten deutschen Texte (§5) übernehmen.
12. **detectPdf-HEAD-Request** pro Listenzeile (bis ~100 Quellen) — in Flutter batchen/cachen (das Original cached in `U.pdfStatusCache`, Reset bei jedem Import); Flag-Progression `·`→`📄`/`—` als async Zustands-Update je Zeile.
13. **gptModal/Magic-Bar** ist ein geteiltes Muster (util.js:779 ff.) — als wiederverwendbares Widget bauen; die Prompt-Builder (`gptErgaenzungsPrompt`, `gptPromptForSource`) sind reine String-Funktionen und 1:1 portierbar (Zeilenumbrüche/JSON-Vorlagen exakt erhalten, GPT-Antworten hängen davon ab).
14. **Fullwidth-Plus ＋ (U+FF0B)** und die Sondersymbole ⭳⭱⌗◌⌖❝❞ müssen in der gewählten Font darstellbar sein — ggf. Fallback-Font (z. B. Noto Sans Symbols) einplanen, sonst Tofu-Boxen.
15. **provisionRegister-Regexes** (Z.670-674) 1:1 in Dart-RegExp übertragen: `§§?\s*(\d+[a-z]?)` (AT), `\bArt(?:ikel)?\.?\s*(\d+[a-z]?)`, `\bErwGr\s*(\d+)` (sortNum 1000+n), `\bAnhang\s*([IVX]+)` (sortNum 2000+Länge); Dedupe pro Fußnote, Sortierung sortNum→key.
