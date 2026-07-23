# Inventar-Dossier 09 — Domänenlogik

Dateien: `js/levels.js` (248 Z.), `js/connections.js` (195 Z.), `js/mentions.js` (202 Z.), `js/stylecheck.js` (88 Z.), `js/editor.js` (268 Z.), `js/texparse.js` (548 Z.), `js/ziputil.js` (114 Z.)

Alle Module sind klassische Skript-Globals (kein ES-Module-System): jede Datei definiert mit `const` ein Objekt im globalen Scope (`Levels`, `Connections`, `Mentions`, `StyleCheck`, `Editor`, `TexParse`, `ZipUtil`) plus die freie Funktion `renderEditorPane` (editor.js:164). Alle Dateien beginnen mit `'use strict';`.

**Persistenz-Grundlage (Kontext aus util.js):** `U.storeGet(key, fallback)` / `U.storeSet(key, val)` (util.js:206-211) mappen den logischen Key auf den realen localStorage-Key `'ehds.' + (projektScoped ? projektId + '.' : '') + key` (util.js:202-204). Projekt-Scoping gilt für alle Keys in `U.PROJECT_KEYS` (util.js:200-201); die eingebaute Arbeit nutzt die unpräfixierten Alt-Schlüssel (z. B. `ehds.belegLevels`), Zusatzprojekte z. B. `ehds.<projId>.belegLevels`. Werte sind JSON-serialisiert; Lesefehler liefern still den Fallback.

---

# 1. js/levels.js — Beleg-Status-Modell

## 1.1 Zweck & Rolle

Kernmodell des „Belegstands“: Jede Fußnote der Arbeit ist ein Beleg-Vorgang mit einem **dynamisch abgeleiteten** Status (nicht manuell geschaltet, levels.js:1-12). Drei Stufen: **1 = ✦ vermutet** (nur KI-Rohdaten), **2 = ❝ Original** (Originalpassage/Zitat liegt vor), **3 = ✓ belegt** (Position gesichert: PDF-Seite bzw. Fundstelle bei Rechtstexten/Websites). Zusätzlich verwaltet das Modul je Beleg eine Markierungsfarbe für den PDF-Referenzierungsmodus (automatisch rotierende 8er-Palette, manuell übersteuerbar). Es liefert HTML-Renderer für Badge/Statuspunkt/Fortschrittsbalken, Aggregationen (Fußnoten-Nummern je Quelle/Abschnitt/Kapitel, Zählungen) sowie den **Gesamt-Export/Import des Prüfstands** als JSON-Format `"ehds-belegstand"` Version 2 — das ist das zentrale Backup-/Austauschformat der ganzen App.

## 1.2 Öffentliche API (alles auf `Levels`)

| Member | Signatur / Form | Zweck | Referenz |
|---|---|---|---|
| `Levels.L` | `{1:{key:'l1',label:'vermutet',desc,icon:'✦'}, 2:{key:'l2',label:'Original',icon:'❝'}, 3:{key:'l3',label:'belegt',icon:'✓'}}` | Stufen-Definition inkl. Icon/Beschreibung | levels.js:16-20 |
| `Levels.FARBEN` | Array aus 8 `{key, hex}` | Markierungsfarb-Palette | levels.js:25-30 |
| `farbHex(key)` | `→ hex \| null` | Key→Hex | levels.js:31 |
| `autoFarbe(srcId, fnNum)` | `→ farbKey` | deterministischer Farbvorschlag: Index der Fußnote in `numsForSource(srcId)` modulo 8 (`indexOf` −1 wird zu 0 geklemmt) | levels.js:36-40 |
| `farbeFor(srcId, fnNum)` | `→ farbKey` | manuell gespeicherte Farbe > autoFarbe | levels.js:42-45 |
| `entry(num)` | `→ Objekt \| null` | roher gespeicherter Zustand einer Fußnote | levels.js:51 |
| `save(num, data)` | `data:{zitat,seite,fundstelle,kommentar,herkunft,farbe}` `→ level (0/2/3)` | dynamisches Speichern, Level-Ableitung, Aufräumen leerer Felder | levels.js:56-68 |
| `set(num, data)` | merge ohne Level-Logik (`ts` wird gesetzt) — Kompatibilität/Import | levels.js:71-75 |
| `clear(num)` | Eintrag löschen | levels.js:76-80 |
| `positionType(sourceId)` | `→ 'seite' \| 'fundstelle'` | `fundstelle` wenn Quell-`kind` ∈ {`recht-eu`,`recht-at`,`online`,`norm`}, sonst `seite`; unbekannte Quelle → `'seite'` | levels.js:83-87 |
| `positionLabel(sourceId)` | `→ 'Fundstelle (Art/§/Abschnitt)' \| 'Seite im PDF'` | UI-Label | levels.js:88-90 |
| `info(num)` | `→ {level, zitat?, seite?, fundstelle?, kommentar?, herkunft?, farbe?, derived?}` | **effektiver Status** (Kaskade, s. 1.6) | levels.js:94-130 |
| `badge(level, opts)` | `→ HTML-String` | Status-Badge | levels.js:133-137 |
| `dot(num, srcId)` | `→ HTML-String` | Statuspunkt mit Farb-Ring | levels.js:140-145 |
| `bar(nums, opts)` | `→ HTML-String` | Mini-Fortschrittsbalken (Segmente p3/p2/p1) | levels.js:148-153 |
| `countsFor(nums)` | `→ {l0,l1,l2,l3,total}` | Zählung über `info(n).level` | levels.js:155-163 |
| `allNums()` | alle Fußnotennummern (`Object.keys(FN_INDEX).map(Number)`) | levels.js:166 |
| `numsForSource(srcId)` | Fußnotennummern aus `SRC_BY_ID[srcId].citations[].footnote` | levels.js:167-170 |
| `numsForSection(sectionId)` | über `UNIT_INDEX[sectionId].unit.paragraphs[].footnotes[].num` | levels.js:171-176 |
| `numsForChapter(chNum)` | rekursiv über `DATA_THESIS.chapters[].sections` | levels.js:177-189 |
| `exportState()` | `→ JSON-String` (pretty, indent 1) | Gesamt-Prüfstand exportieren | levels.js:192-220 |
| `importState(json)` | `→ Anzahl belegLevels-Einträge`; wirft bei fremdem Format | levels.js:221-247 |

Interne Helfer: `_all()` / `_saveAll(m)` (levels.js:47-48) auf Store-Key `belegLevels`.

**Konsumierte Globals:** `U.storeGet/storeSet/esc/getResolutions/getAnnotations/getPdfManual/findBeleg`, `SRC_BY_ID`, `FN_INDEX`, `UNIT_INDEX`, `window.DATA_THESIS`, optional `PdfEngine.marksForFn` (Existenz-geprüft via `typeof`, levels.js:117).
**Nutzer:** praktisch alle Views — `views_studio.js` (Badges/Dots/Bars in Absatz- und Fußnotenkarten), `views_quellen.js` (Export-Button `qExport` lädt `ehds-belegstand.json` herunter, Z. 95; Import Z. 99 mit `location.reload()`), `app.js:33` (Auto-Import beim Start), `connections.js:88` (`numsForSection`).

## 1.3 State & Persistenz

**Store-Key `belegLevels`** (realer localStorage-Key `ehds.belegLevels` bzw. `ehds.<proj>.belegLevels`) — gelesen bei jedem `entry/info/save`, geschrieben bei `save/set/clear/importState`. Form: Map Fußnotennummer → Eintrag:

```json
{
  "17": {
    "zitat": "The processing of personal electronic health data …",
    "seite": 14,
    "fundstelle": "",            // alternativ zu seite (Rechtstexte: "Art 34 Abs 1")
    "kommentar": "Wortlaut leicht gekürzt",
    "herkunft": "manuell",       // oder "import" | "markierung" | generatedBy-Wert
    "farbe": "blau",             // Farb-Key aus FARBEN (optional, manuelle Übersteuerung)
    "level": 3,                  // von save() abgeleitet: seite|fundstelle→3, zitat→2
    "ts": 1753222000000          // Date.now() beim letzten Schreiben
  },
  "23": { "farbe": "gelb", "level": 0, "ts": 1753222000001 }
}
```

`save()`-Regeln (levels.js:56-68): leere Felder (`''`/`null`/`undefined`) aus {zitat, seite, fundstelle, kommentar, farbe} werden gelöscht; `level = (seite||fundstelle) ? 3 : (zitat ? 2 : 0)`; ist `level===0` und weder `farbe` noch `kommentar` vorhanden → Eintrag komplett entfernt, Rückgabe 0.

**Export-Format `ehds-belegstand` v2** (levels.js:192-220) — bündelt **21 Store-Bereiche**:

```json
{
  "format": "ehds-belegstand",
  "version": 2,
  "exportiert": "2026-07-23T10:00:00.000Z",
  "belegLevels": { "17": { "…": "s. o." } },
  "annotations": {},      "resolutions": {},   "pdfManual": {},
  "linkOverrides": {},    "notes": {},         "srcTexts": {},
  "pdfMarks": {},         "kiConnections": null, "customSources": [],
  "textMentions": {},     "fileSearch": {},    "dlStatus": {},
  "paraDock": {},         "paraEdits": {},     "dockBySection": {},
  "marksExtra": {},       "notebook": null,    "texEdits": {},
  "fnEdits": {},          "belegSpans": {},    "titleEdits": {}
}
```

**Achtung Feld-Umbenennung:** Das Export-Feld `notes` speist sich aus Store-Key `srcNotes` (levels.js:203) und wird beim Import wieder nach `srcNotes` geschrieben (levels.js:229). Alle anderen Feldnamen = Store-Key-Namen. `importState` prüft nur `format === 'ehds-belegstand'` (nicht die Version!) und überschreibt jeden vorhandenen Abschnitt einzeln (`if (d.x) …` — leere Objekte `{}` sind falsy-sicher nicht: `{}` ist truthy und überschreibt; `null`/fehlend lässt Bestand stehen). Fehlertext: `'Unbekanntes Format — erwartet "ehds-belegstand".'` (levels.js:223).

## 1.4 UI-Struktur (HTML-Renderer)

- **Badge** (levels.js:133-137): `<span class="lvl-badge l1|l2|l3" title="{desc}">{icon} {label}</span>`; Fallback level 0: `<span class="lvl-badge" style="opacity:.6"><span class="lvl-dot l0"></span>offen</span>`.
- **Dot** (levels.js:140-145): `<span class="lvl-dot l0..l3" style="box-shadow:0 0 0 2.5px {farbHex}55" title="{label|'offen'}"></span>` — Farb-Ring als Box-Shadow mit Alpha-Suffix `55` (~33 % Deckkraft), Ringbreite 2.5px.
- **Bar** (levels.js:148-153): `<span class="lvl-bar" title="belegt: X · Original: Y · vermutet: Z · offen: W">` mit bis zu 3 Segment-Spans `class="p3|p2|p1"` und `width:NN.N%` (1 Dezimale, Anteil an total, min total=1). Level-0-Anteil bekommt **kein** Segment (bleibt Hintergrund).

Die konkreten Farben der Klassen `lvl-badge`, `lvl-dot l0..l3`, `p1..p3` stehen im CSS (nicht in diesem Modul).

## 1.5 Design-Rohwerte

Farb-Palette (levels.js:25-30), exakt:

| key | hex |
|---|---|
| `gelb` | `#e8c33f` |
| `blau` | `#5f8fc7` |
| `gruen` | `#7cab54` |
| `rosa` | `#d77aa4` |
| `orange` | `#dd8a3e` |
| `violett` | `#9779c9` |
| `tuerkis` | `#4fb3a5` |
| `rot` | `#cf6d5c` |

Icons: `✦` (U+2726), `❝` (U+275D), `✓` (U+2713). Labels wörtlich: `vermutet`, `Original`, `belegt`, `offen`. Beschreibungen wörtlich (levels.js:17-19): „Nur KI-Analyse — Fundstelle vermutet, nichts nachgewiesen“, „Originalpassage (Zitat) liegt vor — Position noch offen“, „Position gesichert: Seite im PDF bzw. Fundstelle bestätigt“. Positions-Labels: „Fundstelle (Art/§/Abschnitt)“, „Seite im PDF“ (levels.js:89).

## 1.6 Verhalten: die `info(num)`-Kaskade (levels.js:94-130)

Reihenfolge der Statusermittlung (erste Stufe, die greift, gewinnt):
1. **Gespeicherter Eintrag mit `level > 0`** → `{level, ...stored}` zurück (levels.js:95-96).
2. **Abgeleitet aus Resolutions/Annotationen** (levels.js:99-113): für jede Quelle der Fußnote (`FN_INDEX[num].sources`) werden `U.getResolutions()[srcId].stellen` (herkunft = `res.generatedBy || 'import'`) und `U.getAnnotations()[srcId]` (herkunft = `'manuell'`) zusammengelegt, gefiltert auf `Number(s.footnote) === Number(num)`. Stelle mit `status === 'bestaetigt'` **und** (`seite` oder `fundstelle`) → Level 3; sonst Stelle mit `zitat` → Level 2. Immer `derived: true`, `farbe` aus dem stored-Eintrag übernommen (`stored?.farbe`).
3. **PDF-Markierung** (levels.js:117-125, nur wenn `PdfEngine` definiert): erste Markierung mit `zitat` aus `PdfEngine.marksForFn(srcId, num)`; Level = 3 wenn `m.page` gesetzt **und** `positionType(srcId) === 'seite'`, sonst 2; `herkunft: 'markierung'`; `farbe` = stored-Farbe, sonst Markierungsfarbe `m.farbe`.
4. **KI-Beleg** (levels.js:128-129): `U.findBeleg(num)` vorhanden → Level 1, sonst Level 0. Rückgabe `{level, farbe: stored?.farbe, derived: true}`.

Randfälle: Ein Eintrag nur mit Farbe/Kommentar (level 0) blockiert die Kaskade nicht (Bedingung `stored.level` truthy). `countsFor`/`bar` laufen komplett über `info` — also inkl. aller Ableitungen.

## 1.7 Datenformen (Zusammenfassung)

Siehe 1.3; zusätzlich das `info()`-Ergebnis:

```json
{
  "level": 3,                    // 0..3
  "zitat": "…", "seite": 14, "fundstelle": "", "kommentar": "",
  "herkunft": "markierung",      // 'manuell'|'import'|'markierung'|generatedBy|undefined
  "farbe": "blau",
  "derived": true                 // fehlt bei direkt gespeicherten Einträgen
}
```

## 1.8 Abhängigkeiten

Eingehend: praktisch alle Views (Studio, Quellen, Projekt, App-Start). Ausgehend: `U.*`-Store-Helfer, Indizes `FN_INDEX`/`SRC_BY_ID`/`UNIT_INDEX`, `DATA_THESIS`, `PdfEngine` (optional), `U.findBeleg`.

## 1.9 Flutter-Hinweise

- `badge/dot/bar` liefern HTML-Strings → in Flutter je ein Widget (`LevelBadge`, `LevelDot` mit `BoxShadow`-Ring Farbe+Alpha 0x55, `LevelBar` als `Row` mit `Flexible`-Segmenten oder `FractionallySizedBox`).
- Das Modell (`save`-Ableitung, `info`-Kaskade) ist reine Logik → 1:1 in eine Dart-Klasse `BelegLevels` portierbar; `ts: Date.now()` → `DateTime.now().millisecondsSinceEpoch`.
- **Export/Import-Kompatibilität ist Pflicht**: exakt dieselben Feldnamen inkl. `notes`↔`srcNotes`-Mapping und `format:'ehds-belegstand', version:2`, damit bestehende Backups geladen werden können. JSON-Ausgabe mit Indent 1 (`JSON.stringify(…, null, 1)`) — Dart: `JsonEncoder.withIndent(' ')`.
- localStorage → z. B. `shared_preferences` oder SQLite/Hive; Key-Schema `ehds.` + optionales Projekt-Präfix beibehalten oder sauber auf Projekt-Tabellen abbilden (dann Migrations-/Importpfad für Alt-Keys).
- Fußnoten-Keys sind im JSON Strings („17“), im Code Numbers — in Dart konsequent `int` + String-Konvertierung an der JSON-Grenze.

---

# 2. js/connections.js — Verbindungs-Framework

## 2.1 Zweck & Rolle

Führt inhaltliche Verweise zwischen Abschnitten aus **vier** Quellen zusammen (Kommentar nennt drei, Code hat vier, connections.js:1-12, 80-116): (1) deterministische Querverweise im Text („siehe Abschnitt 3.2“ / „Kapitel 5“), (2) Fazit-Befunde aus `DATA_META.fazit`, (3) KI-erkannte Verbindungen (Bundle `DATA_META.connections` + Import in localStorage), (4) automatisch erkannte Paare mit gemeinsamen **seltenen** Quellen. Ergebnis ist eine deduplizierte, gecachte Kantenliste; dazu ein Importer für KI-JSON und ein Prompt-Generator, mit dem der Nutzer die KI-Verbindungen (nach)generieren lassen kann.

## 2.2 Öffentliche API

- `Connections.TYPES` (connections.js:18-26) — Typdefinitionen, **exakt**:

| typ | icon | out-Label | in-Label |
|---|---|---|---|
| `folgerung` | `⇒` (U+21D2) | „daraus gefolgert in“ | „Folgerung aus“ |
| `aufgriff` | `↻` (U+21BB) | „wieder aufgegriffen in“ | „greift zurück auf“ |
| `grundlage` | `▤` (U+25A4) | „Grundlage für“ | „stützt sich auf“ |
| `vergleich` | `⇄` (U+21C4) | „Vergleich mit“ | „Vergleich mit“ |
| `fazit` | `◎` (U+25CE) | „fließt ins Fazit ein“ | „hergeleitet aus“ |
| `xref` | `→` (U+2192) | „verweist auf“ | „referenziert von“ |
| `quellen` | `⌗` (U+2317) | „teilt Quellen mit“ | „teilt Quellen mit“ |

- `Connections.all()` → Kantenliste (gecacht in `_cache`; connections.js:31-119).
- `Connections.invalidate()` — Cache leeren (connections.js:28); wird nach Importen gerufen.
- `Connections.forSection(sectionId)` → `{out: [...], in: [...]}` sortiert nach Rang `{folgerung:0, grundlage:1, aufgriff:2, vergleich:3, fazit:4, quellen:5, xref:6}` (unbekannt: 9) (connections.js:122-130).
- `Connections.importKi(json)` → Statusstring; wirft `'Feld "connections" (Array) fehlt.'` bzw. ``Keine gültigen Einträge (N übersprungen — von/nach.sectionId müssen existierende Abschnitte sein).`` (connections.js:133-151). Merge per `id` in Store-Key `kiConnections`; Einträge ohne id bekommen `ki-${byId.size}-${Date.now()}`. Rückgabe: `"N übernommen, M übersprungen (ungültige/unbekannte Abschnitte)"` oder nur `"N"`.
- `Connections.regeneratePrompt()` → mehrzeiliger deutscher KI-Prompt (connections.js:154-194) mit Gliederung + Kernaussagen je Absatz (aus `DATA_SECTIONS[fileIdOf(u.id)].paragraphs[].kernaussage`) und dem geforderten Antwort-JSON-Schema (wörtlich im Prompt, inkl. „Qualität vor Menge: 15–40 Verbindungen“ und „ANTWORTE NUR mit diesem JSON (importierbar unter Projekt → Connections)“).

**Konsumiert:** `UNIT_INDEX`, `orderedUnits()`, `FN_INDEX`, `Levels.numsForSection`, `U.storeGet/storeSet/srcShort`, `window.DATA_META`, `window.DATA_THESIS`, `window.DATA_SECTIONS`, `fileIdOf`. **Nutzer:** `views_studio.js` (Abschnitts-Verbindungen), `enhance.js:121` (Import-UI: `Connections.importKi(t) + ' Connections übernommen'`).

## 2.3 State & Persistenz

- In-Memory: `_cache` (Kantenliste; invalidierbar).
- Store-Key **`kiConnections`** (projekt-scoped): `{ "connections": [ … ] }` — geschrieben von `importKi`, gelesen in `all()` (connections.js:46) und im Belegstand-Export enthalten.

## 2.4 Erzeugungslogik von `all()` im Detail

Gemeinsamer `push`-Filter (connections.js:35-43): verwirft Kanten ohne `von.sectionId`/`nach.sectionId`, mit unbekannten Abschnitten (`UNIT_INDEX`-Check) oder Selbstbezug; Dedupe-Key `` `${typ}|${von.sectionId}|${von.paraId||''}|${nach.sectionId}|${nach.paraId||''}` ``.

1. **KI** (connections.js:46-50): aus `DATA_META.connections.connections` und Store `kiConnections.connections`; unbekannter `typ` → `'aufgriff'`; `herkunft:'ki'`.
2. **Fazit** (connections.js:53-64): Fazit-Kapitel = erstes Kapitel mit `/fazit|zusammenfassung|conclusio/i` im Titel, sonst letztes Kapitel; Ziel-Section `${chNum}.0`. Je Finding `f` aus `DATA_META.fazit.findings` und je `s` aus `f.abschnitte`: Kante `{id:'fz-'+f.id+'-'+s, typ:'fazit', herkunft:'auto', von:{sectionId:s}, nach:{sectionId:fazitSec, paraId:f.fazitParagraphId||null}, label:f.label, text:f.beschreibung||'', findingId:f.id, findingTyp:f.typ}`.
3. **Text-Querverweise** (connections.js:67-78): Regex `/\b(Abschnitt|Kapitel)\s+(\d+(?:\.\d+)*)\b/g` über alle Absatztexte (bei `type:'list'` über `items`); „Kapitel N“ → Ziel `N.0`; Kante `{id:'xr-'+p.id+'-'+target, typ:'xref', herkunft:'auto', von:{sectionId, paraId:p.id}, nach:{sectionId:target}}`.
4. **Gemeinsame seltene Quellen** (connections.js:85-116): je Abschnitt Quellen-Set (über `Levels.numsForSection` → `FN_INDEX[n].sources`); `srcSpread` = in wie vielen Abschnitten eine Quelle vorkommt. Kandidaten nur **kapitelübergreifend** (`a.split('.')[0] !== b.split('.')[0]`); `rare` = gemeinsame Quellen mit spread ≤ 3, `veryRare` ≤ 2; Bedingung `rare.length>=2 || veryRare.length>=1`; `score = rare.length*2 + veryRare.length`; absteigend sortiert, **Top 40**; Label `gemeinsame Quellen: {bis zu 3 U.srcShort(...)-Namen, komma-getrennt}` + `' …'` falls >3; Text `Beide Abschnitte stützen sich auf N gemeinsame, selten zitierte Quelle(n).`; `id: 'qs-'+a+'-'+b`.

## 2.5 Datenform Kante

```json
{
  "id": "c1",                      // bzw. "fz-…", "xr-…", "qs-…", "ki-…"
  "typ": "folgerung",              // folgerung|grundlage|aufgriff|vergleich|fazit|xref|quellen
  "herkunft": "ki",                // "ki" | "auto"
  "von":  { "sectionId": "5.3.3", "paraId": "5.3.3-p2" },   // paraId optional
  "nach": { "sectionId": "6.0",   "paraId": "6.0-p5" },
  "label": "Kurzname der Verbindung",
  "text": "1 Satz Begründung",
  "findingId": "f3", "findingTyp": "…"   // nur bei typ 'fazit'
}
```

## 2.6 Flutter-Hinweise

- Reine Logik, 1:1 portierbar. Cache als nullable Feld + `invalidate()`.
- JS-`sort` ist stabil (moderne Engines); Darts `List.sort` ist **nicht** stabil — bei `forSection` (Rang-Sortierung) und den Score-Ties in Schritt 4 ggf. `mergeSort` aus `package:collection` verwenden, um identische Reihenfolgen zu erhalten.
- Icons sind reine Unicode-Zeichen → als `Text` mit passendem Font darstellbar; alternativ Material-Icons zuordnen (dann bewusst dokumentierte Abweichung).
- `regeneratePrompt()` erzeugt Text für Copy&Paste in eine KI — in Flutter identisch als String-Builder + `Clipboard.setData`.

---

# 3. js/mentions.js — deterministische Autor/Jahr-Erkennung

## 3.1 Zweck & Rolle

Erkennt **ohne KI**, wo eine Quelle im Fließtext nur per Autorennennung referenziert wird („Abowd and Dey (1999) defined …“), ohne dass dort eine Fußnote derselben Quelle steht (mentions.js:1-15). Treffer sind Vorschläge; erst Nutzer-Bestätigung macht sie zu Erwähnungen der bestehenden Quellen-Instanz. Bei Mehrdeutigkeit (mehrere Quellen passen auf dieselbe Jahres-Klammer) entsteht **eine** Erwähnung mit `candidates[]` (nach Score sortiert); die Auswahl trifft der Nutzer. Persistenz im Store-Key `textMentions` mit Alt-Format-Migration.

## 3.2 Öffentliche API

- `Mentions._patterns()` → `[{srcId, year:Number, names:[Nachname,…]}]`, gecacht (mentions.js:23-39).
- `Mentions.invalidate()` — Pattern- und Absatz-Cache leeren (mentions.js:40).
- `Mentions.detect(text, footnoteSources)` → Roh-Treffer (Algorithmus s. 3.4) (mentions.js:47-107).
- `Mentions.key(paraId, f)` → `` `${paraId}|${f.start}` `` (mentions.js:111).
- `Mentions.statusEntry(paraId, f)` → `{status, srcId, fn?} | null`; migriert Alt-Keys `"paraId|srcId|start": "status"` verlustfrei ins neue Format (in-place, mit Store-Write; mentions.js:114-132).
- `Mentions.setStatus(key, status, srcId, fn)` — `status: 'bestaetigt'|'verworfen'|'beleg'|'offen'`; `'offen'` löscht den Eintrag; `'beleg'` speichert zusätzlich `fn: Number(fn)` (mentions.js:135-140).
- `Mentions.mergeTarget(p, mt)` → Fußnotennummer | null: nächste Fußnote **derselben** Quelle nach `mt.end` im Absatz; gibt es keine dahinter, irgendeine der Quelle im Absatz (mentions.js:145-157).
- `Mentions.forPara(sectionId, p)` → angereicherte Erwähnungen des Absatzes, pro Sitzung gecacht (`_paraCache` nach `p.id`); `figure`/`table`-Absätze → `[]` (mentions.js:162-181).
- `Mentions.scanAll()` → alle Erwähnungen der Arbeit (Rekursion über `DATA_THESIS`) (mentions.js:184-195).
- `Mentions.forSource(srcId)` → Erwähnungen der Quelle inkl. offener Stellen, bei denen sie nur Kandidat ist (mentions.js:198-201).

**Konsumiert:** `window.DATA_SOURCES`, `FN_INDEX`, `U.storeGet/storeSet`, `window.DATA_THESIS`. **Nutzer:** `views_studio.js` (Z. 435, 729, 886, 952-961, 1103, 1138 — Anzeige, Filterung nach Status, Beleg-Merging), Belegstand-Export.

## 3.3 State & Persistenz

Store-Key **`textMentions`** (projekt-scoped, im Belegstand enthalten):

```json
{
  "3.2.1-p4|127": { "status": "bestaetigt", "srcId": "abowd1999" },
  "3.2.1-p6|489": { "status": "beleg", "srcId": "panadero2017", "fn": 42 },
  "4.1-p2|55":    { "status": "verworfen", "srcId": "vallejo2021a" }
}
```

Alt-Format (wird bei `statusEntry` gelesen und migriert): `"3.2.1-p4|abowd1999|127": "bestaetigt"`. Ebenso wird ein reiner String-Wert unter neuem Key als `{status: v, srcId: f.srcId}` interpretiert (mentions.js:130).
In-Memory: `_patCache` (Quellen-Muster), `_paraCache` (Map paraId → detect-Ergebnis).

## 3.4 Algorithmus `detect` (exakt, mentions.js:47-107)

1. **Muster-Aufbau** (mentions.js:26-38): je Quelle mit `year` **und** `author`; `author` an `;` gesplittet; pro Teil `\bu.\s?a\.` und `\bet al\.?` (case-insensitive) entfernt; enthält der Rest ein Komma → Nachname = Teil vor dem Komma, sonst (Institution) ganzer Name; nur Namen mit Länge ≥ 3.
2. **Jahres-Klammern** finden: `/\(\s*((?:19|20)\d{2})[a-z]?\s*\)/g` — also `(1999)`, `( 2021a )` etc.; `end` = Ende der Klammer.
3. **Namensfenster**: 55 Zeichen vor der Klammer (`windowStart = max(0, m.index-55)`). Für jede Quelle mit passendem Jahr: jeder Name als Regex `(^|[^\wÄÖÜäöü])(NAME)(?=[^\wÄÖÜäöü]|$)` (Name regex-escaped, `gi`) im Fenster gesucht; **das späteste Vorkommen** (größte absolute Position) gewinnt (`best`, `bestName`).
4. **Nähe-Unterdrückung** (Treffer verwerfen, wenn die Stelle ohnehin belegt ist): a) im Bereich bis **320 Zeichen nach** der Klammer ein Marker `[^N]`, dessen Fußnote (`FN_INDEX[N].sources`) die Quelle enthält; b) sonst im Bereich **90 Zeichen vor** dem Namensbeginn ebenso (mentions.js:68-84).
5. **Score**: `(quelle bereits per Fußnote im Absatz zitiert ? 100 : 0) + bestName.length` (mentions.js:86).
6. **Gruppierung**: Treffer mit gleichem `end` (gleiche Jahres-Klammer) = **eine** Erwähnung; Duplikat-srcIds innerhalb der Gruppe unterdrückt; Gruppe absteigend nach Score sortiert; `srcId` = Top-Kandidat, `start` = min der Gruppen-Starts, `snippet = raw.slice(start, end)`, `candidates = [{srcId, score, start}, …]`. Endergebnis aufsteigend nach `start` (mentions.js:90-106).

`forPara` reichert an: `status` aus Store (Default `'offen'`), `srcId` = gespeicherte Wahl, falls unter den Kandidaten, sonst Top-Kandidat; `fn` = gemergte Fußnote oder null (mentions.js:170-180).

## 3.5 Datenform Erwähnung (Ergebnis `forPara`)

```json
{
  "srcId": "abowd1999",            // gewählte bzw. wahrscheinlichste Quelle
  "start": 112, "end": 152,        // Zeichen-Offsets im Absatz-Rohtext (inkl. [^N]-Marker!)
  "snippet": "Abowd and Dey (1999)",
  "candidates": [ { "srcId": "abowd1999", "score": 105, "start": 112 } ],
  "paraId": "3.2.1-p4", "sectionId": "3.2.1",
  "key": "3.2.1-p4|112",
  "status": "offen",               // offen|bestaetigt|verworfen|beleg
  "fn": null                        // Fußnotennummer bei status 'beleg'
}
```

## 3.6 Flutter-Hinweise

- Dart-`RegExp` unterstützt alles Nötige (`allMatches` statt `matchAll`); Zeichenklasse `[^\wÄÖÜäöü]` funktioniert identisch, `\w` ist in Dart ASCII-basiert wie in JS.
- **Offsets beziehen sich auf den Rohtext mit `[^N]`-Markern** — die UI muss beim Highlighten dieselbe Textbasis verwenden. Bei UTF-16-Codeunits (JS) vs. Dart-Strings (auch UTF-16) sind die Indizes kompatibel.
- Score-Ties: Kandidaten-Sortierung stabil halten (s. Hinweis 2.6).
- Session-Cache (`_paraCache`) → einfach `Map<String, List<Mention>>` im Provider/Service; bei Textänderung `invalidate()`.
- Migrationslogik des Alt-Formats muss mitkommen, sonst gehen alte Bestätigungen verloren.

---

# 4. js/stylecheck.js — GPT-Stil-Check

## 4.1 Zweck & Rolle

Deterministischer Heuristik-Checker (ohne KI), der Sätze markiert, die nach generischem KI-Schreibstil klingen: Floskeln, vage Mengenwörter, Konnektor-Ketten und wertende Sätze ohne Beleg/Konkretes (stylecheck.js:1-6). Pro Satz ein Score mit Begründungstexten — ausdrücklich „ein HINWEIS zum Selbst-Redigieren, kein Urteil“.

## 4.2 Öffentliche API

- `StyleCheck.FILLER` — 31 Regexes (EN+DE), je Treffer **+1** (stylecheck.js:11-41). Beispiele exakt: `/\bplays? an? (?:key|central|crucial|vital|significant|pivotal|important|essential) role\b/i`, `/\bcrucial\b/i`, `/\bdelv(?:e|es|ing)\b/i`, `/\bleverag(?:e|es|ing)\b/i`, `/\bnot only\b[\s\S]{0,80}\bbut also\b/i`, `/\bspielt eine (?:zentrale|wichtige|entscheidende|bedeutende|immer größere) Rolle\b/i`, `/\bzusammenfassend lässt sich (?:sagen|festhalten)\b/i` (vollständige Liste in Datei).
- `StyleCheck.VAGUE` — 12 Regexes (`various`, `numerous`, `a variety of`, `several aspects`, `different aspects`, `overall`, `essentially`, `broadly`, `verschiedenste[nr]?`, `zahlreiche[nr]?`, `vielfältig(e[nr]?)?`, `grundsätzlich`), Score gedeckelt: `score += Math.min(1, vague*0.5)`; höchstens 2 „vage“-Hits werden gelistet (stylecheck.js:43-47, 61-65).
- `StyleCheck.CONNECT` — Satzanfangs-Regex: `Furthermore|Moreover|Additionally|In addition|Overall|In conclusion|Notably|Importantly|Consequently|Darüber hinaus|Des Weiteren|Zudem|Außerdem|Insgesamt|Abschließend|Folglich|Somit` (stylecheck.js:49).
- `StyleCheck.analyzeSentence(text, prevConnector)` → `{score, hits:[String], connector:Bool}` (stylecheck.js:51-75). Ablauf: Fußnoten-Marker `[^N]` und Mehrfach-Whitespace entfernen → FILLER (+1 je Treffer, Hit `Floskel: „…“`) → VAGUE (Hit `vage: „…“`) → Konnektor-Kette: nur wenn **dieser und der vorige Satz** mit Konnektor beginnen, +1, Hit `Konnektor-Kette (Furthermore/Moreover/Zudem …)` → „seichter Einordnungssatz“: wertendes Muster (`is/are/ist/sind/wird/bleibt … key/central/wichtig/zentral/entscheidend/wesentlich …`, stylecheck.js:70) **ohne** Zitat (`[^N]`-Marker im Rohtext oder Jahres-Klammer) **und ohne** Konkretes (Ziffer, `%`, `Fig.`, `Tab`/`Tabelle`, `Abb.`) → +1, Hit `Einordnung ohne Beleg/Konkretes („ist wichtig/zentral“)`.
- `StyleCheck.analyzePara(text)` → nur auffällige Sätze `[{start, end, text, score, hits}]` mit `score >= 1`; nutzt `U.splitSentences` und trägt den Konnektor-Zustand über Sätze weiter (stylecheck.js:78-87).

**Konsumiert:** `U.splitSentences`. **Nutzer:** `views_studio.js:617` und `:861` (Markierung auffälliger Sätze im Absatz).

## 4.3 State

Keiner (vollständig zustandslos, keine Persistenz).

## 4.4 Flutter-Hinweise

- Reine Funktionslogik, direkt portierbar. Die Regex-Listen wörtlich übernehmen (auch Umlaute in `größere`).
- Achtung: `hasCite` prüft den **Rohtext** (`raw`) auf `[^N]`, die anderen Prüfungen den bereinigten Text `t` — Reihenfolge beibehalten.
- `U.splitSentences` (util.js) liefert `{start, end, text}` — Vertrag mit dem Util-Dossier abgleichen; die Offsets werden fürs Highlighten gebraucht.

---

# 5. js/editor.js — LaTeX-Subset-Editor

## 5.1 Zweck & Rolle

Studio-Modus „Editor“: abschnittsweises Bearbeiten des aus den geparsten Daten **rekonstruierten** LaTeX-Quelltexts mit Live-Vorschau, Prüfbericht (erlaubte Befehle, Klammern, Umgebungen) und `.tex`-Export (editor.js:1-7). Änderungen liegen ausschließlich im localStorage (`texEdits`) — die Originaldaten bleiben unberührte „Ground Truth“. Zwei Teile: das logische Objekt `Editor` (Rekonstruktion, Lint, Preview, Export) und die freie Render-Funktion `renderEditorPane(root, sectionId)`.

## 5.2 Öffentliche API

- `Editor.ALLOWED` (editor.js:11-12): erlaubte Befehle exakt `['chapter','section','subsection','subsubsection','textbf','textit','emph','enquote','footnote','item','begin','end','S','%','&','_',',','dots']`; `Editor.ALLOWED_ENVS = ['itemize','enumerate']` (editor.js:13).
- `Editor.edits()` / `saveEdit(id, tex)` / `clearEdit(id)` — Store-Key `texEdits` (Map sectionId→tex) (editor.js:15-17).
- `Editor.reconstruct(sectionId)` → LaTeX-String (editor.js:20-36): Kopf `\chapter{ch.title}` bei `isIntro`, sonst nach Tiefe (`sectionId.split('.').length-1`): 1→`\section`, 2→`\subsection`, sonst `\subsubsection`. Absätze: `list` → `\begin{itemize}\n  \item …\n\end{itemize}`; `figure`/`table` → Kommentarzeile `% {text | [FIGURE]/[TABLE]}`; sonst `inlineToTex(p.text)`.
- `Editor.inlineToTex(text)` (editor.js:42-47): `[^N]` → `\footnote{Originaltext}` — **immer** `fn._origText ?? fn.text` (Anzeige-Overrides aus `fnEdits` dürfen nicht in texEdits einsickern, editor.js:39-41); unbekannte Nummer → `Fußnote N`.
- `Editor.lint(tex)` → `{errs:[String], warns:[String]}` (editor.js:53-81). Fehlermeldungen exakt:
  - ``Zeile N: Unbekannter/nicht erlaubter Befehl \x — erlaubt sind: \chapter, \section, … .`` (nur mit Buchstaben beginnende ALLOWED gelistet)
  - ``Zeile N: Nicht erlaubte Umgebung „env“ — erlaubt: itemize, enumerate.``
  - ``Zeile N: Schließende } ohne öffnende {.`` (Tiefe wird auf 0 zurückgesetzt)
  - ``Zeile N: K geschweifte Klammer(n) nicht geschlossen.`` (N = Zeile der ersten offenen Klammer)
  - ``\begin/\end nicht balanciert (X begin / Y end).``
  - Hinweis (warns): ``Zeile N: $…$-Mathematik wird im Studio nur als [Formel]-Marker übernommen.`` (Trigger: `/[^\\]\$\S/` auf `' '+Zeile`).
- `Editor.replaceCmd(str, cmd, fn)` — brace-bewusstes Ersetzen `\cmd{...}` → `fn(inhalt)` (editor.js:84-97).
- `Editor.preview(tex)` → HTML (editor.js:100-129):
  - Inline: `\footnote{…}` → `<sup class="pv-fn" title="{Inhalt ohne \befehle}">{laufende Nr.}</sup>`; `\textbf`→`<b>`, `\textit`/`\emph`→`<em>`, `\enquote{x}`→`„x“`; `\S`→`§`, `\,`→`&thinsp;`, `\%`→`%`, `\&`→`&amp;`, `\_`→`_`, `\dots`→`…`, `--`→`–`.
  - Blöcke zeilenweise: Überschriften `\chapter`→`<h2>`, `\section`→`<h3>`, `\subsection`/`\subsubsection`→`<h4>`; `\begin{itemize}`→`<ul class="lesen-list">`, `enumerate`→`<ol>`; `\item x`→`<li>`; Zeilen mit `%`-Anfang → `<div class="fig-missing small"><span class="eyebrow">Platzhalter</span>{Rest}</div>`; Leerzeile flusht den Absatz-Puffer zu `<p class="lesen-p ff">…</p>` (Zeilen mit Leerzeichen gejoint). Eingabe wird vorher komplett `U.esc`-escaped.
- `Editor.exportAll()` → `U.download('thesis-export.tex', fullDocument(), 'text/x-tex')` (editor.js:132-134).
- `Editor.fullDocument()` → komplettes kompilierbares Dokument (editor.js:139-160): Kommentarkopf mit Titel, `% Generiert aus Thesis Studio (lokale Änderungen eingerechnet)`, `\documentclass[11pt,a4paper]{report}`, Pakete `inputenc(utf8)/fontenc(T1)/hyperref/graphicx`; `\title{…\\[0.4em]\large subtitle}`, `\author{…\\ university}`, `\date{meta.date | \today}`, `\maketitle`, optional `abstract`-Umgebung; Body = `orderedUnits().map(id => edits[id] ?? reconstruct(id))` mit `\n\n` gejoint; Abschluss `\bibliographystyle{plain}`, `% \bibliography{lit}`, `\end{document}`.
- `renderEditorPane(root, sectionId)` (editor.js:164-268) — s. 5.4/5.6.

**Konsumiert:** `U.storeGet/storeSet/el/esc/download/resizer`, `UNIT_INDEX`, `FN_INDEX`, `orderedUnits()`, `window.DATA_THESIS.meta`, optional `sourcePickerModal` (typeof-geprüft, editor.js:246). **Nutzer:** `views_studio.js:129` (`Studio.mode === 'editor'` → `renderEditorPane(inner, sectionId)` + `sectionNav(inner, sectionId, 'editor')`).

## 5.3 State & Persistenz

- Store-Key **`texEdits`** (projekt-scoped, im Belegstand-Export): `{ "3.2.1": "\\subsection{…}\n\n…" }` — pro Abschnitt der komplette editierte LaTeX-Text.
- Store-Key **`uiEdPct`** (global, **nicht** projekt-scoped): Spaltenverhältnis links in Prozent, Number, Default 50, geklemmt 25–70 (editor.js:203, 211).

## 5.4 UI-Struktur & Layout (renderEditorPane)

DOM-Hierarchie (alles in `root`):

```
div.editor-pane
├─ div.row.spread (margin-bottom:10px)
│  ├─ span.small.mut   Hinweistext (+ optional span.chip.warn „✎ lokal bearbeitet")
│  └─ span.row (gap:6px)
│     ├─ button.btn.btn-sm.btn-primary#edSave  „Speichern"
│     ├─ button.btn.btn-sm#edReset             „Zurücksetzen" (disabled ohne Edit)
│     ├─ button.btn.btn-sm#edExportSec         „⭳ Abschnitt.tex"
│     └─ button.btn.btn-sm#edExportAll         „⭳ Gesamt.tex"
├─ div.tex-toolbar
│  ├─ 8× button.btn[data-ins]  (Einfüge-Snippets, s. 5.5)
│  ├─ button.btn#edCite  „＋ Quelle"
│  └─ span.small.mut (margin-left:auto)  „Auswahl wird in <code>$</code> eingesetzt"
└─ div.editor-panes            (CSS-Var --ed-w = linke Spaltenbreite in %)
   ├─ div.ed-left
   │  ├─ textarea.tex#edTex (spellcheck=false)  Quelltext
   │  └─ div.tex-lint#edLint                    Prüfbericht
   ├─ div.pane-resize (role="separator", aria-orientation="vertical",
   │                   title="Breite ziehen · Doppelklick = Standard")
   └─ div.ed-right
      ├─ div.eyebrow „Live-Vorschau" (margin-bottom:8px)
      └─ div.card.tex-preview#edPrev
```

Layout: Zweispalter mit Drag-Resizer; Spaltenverhältnis als **Prozent** in `--ed-w` (25–70 %), persistiert in `uiEdPct`; `U.resizer` mit `min: 260` px, `max: innerWidth - 380` px; Doppelklick (apply mit `px === null`) → Reset auf 50 % (editor.js:201-214).

## 5.5 Design-Rohwerte & Texte (wörtlich)

- Hinweis oben: „Eingeschränkter Befehlssatz — Änderungen bleiben lokal im Browser; das PDF der Quellen steht rechts in der Quellen-Spalte.“ (editor.js:173); Chip: „✎ lokal bearbeitet“.
- Button-Titles: „Diesen Abschnitt als .tex herunterladen“, „Gesamte Arbeit als .tex (mit allen lokalen Änderungen)“, „Quelle als \cite einfügen — die ganze Quellenauswahl durchsuchbar“, Toolbar-Buttons „einfügen“.
- Toolbar-Snippets (Label → Einfügetext, `$` = Selektions-Platzhalter; editor.js:182-184): `\textbf{…}`→`\textbf{$}` · `\textit{…}`→`\textit{$}` · `\enquote{…}`→`\enquote{$}` · `\footnote{…}`→`\footnote{$}` · `\S`→`\S $` · `itemize`→`\begin{itemize}\n  \item $\n\end{itemize}` · `\item`→`\item $` · `–`→`--`.
- Lint-Ausgabe: Fehler-Header `✗ LaTeX-Code nicht kompilierbar — Ausgabe des Prüfers:` (div.err.lint-head), je Fehler `· {msg}` (div.err); OK-Zeile `✓ Kompilierbar: nur erlaubte Befehle, Klammern und Umgebungen balanciert.` (div.ok); Warnungen `⚠ {msg}` (div.warn) (editor.js:223-227).
- Icons/Zeichen: `⭳` (U+2B73), `＋` (U+FF0B, vollbreites Plus), `✎` (U+270E), `✗`, `✓`, `⚠`, `„“` (deutsche Anführungszeichen in enquote-Preview), `–` (Halbgeviertstrich), `§`.
- Export-Dateinamen: `thesis-export.tex`, `abschnitt-{sectionId mit . → _}.tex` (editor.js:266).

## 5.6 Verhalten & Interaktionen

1. **Initialisierung**: `current = edits[sectionId] ?? reconstruct(sectionId)`; sofortiger `refresh()` (Preview + Lint) (editor.js:165-231).
2. **Tippen** im Textarea: debounced 220 ms → `refresh()` (editor.js:229-230).
3. **Toolbar-Klick**: Snippet einfügen; enthält es `$`, ersetzt `$` die aktuelle Selektion und der Cursor landet hinter der eingesetzten Selektion (`a + ins.indexOf('$') + sel.length`), sonst Cursor ans Snippet-Ende; danach Fokus + `refresh()` (editor.js:233-242).
4. **„＋ Quelle“**: öffnet `sourcePickerModal(sectionId, null, cb)`; Callback fügt `\cite{id}` an der (beim Klick gemerkten) Selektionsposition ein, Cursor dahinter (editor.js:245-255). No-op, wenn das Modal nicht existiert.
5. **Speichern**: `saveEdit` + kompletter Re-Render des Panes (`root.innerHTML=''`); **Zurücksetzen**: `clearEdit` + Re-Render (editor.js:257-264).
6. **Resizer**: Drag ändert `--ed-w` live in Prozent (25–70, 1 Dezimale), speichert gerundet in `uiEdPct`; Doppelklick reset 50 % (editor.js:205-214).
7. Randfall: `\cite` ist **nicht** in `ALLOWED` — nach dem Einfügen einer Quelle meldet der Lint einen Fehler („Unbekannter/nicht erlaubter Befehl \cite …“). Das ist Ist-Verhalten des Originals.

## 5.7 Flutter-Hinweise

- Textarea + Selektion → `TextField`/`TextEditingController` mit `selection`; Snippet-Einfügung über Controller-Manipulation identisch abbildbar.
- Preview: statt HTML-String ein Widget-Renderer für das Mini-LaTeX (eigener Parser identisch zur `preview`-Logik; `RichText`/`Text.rich` für Inline, `sup`-Fußnote als `WidgetSpan` mit Tooltip).
- Debounce 220 ms → `Timer`; Resizer → `GestureDetector` + `LayoutBuilder`, Prozent-Klemmen 25–70 und Pixel-Grenzen (260 / breite−380) übernehmen; Doppelklick-Reset (`GestureDetector.onDoubleTap`).
- `U.esc`-Escaping entfällt in Flutter (kein HTML-Injection-Risiko), aber die Ersetzungsreihenfolge der Inline-Regeln beibehalten (footnote zuerst, dann textbf/textit/emph/enquote, dann Zeichenersetzungen).
- Lint-Meldungen wörtlich übernehmen (deutsche Texte oben).

---

# 6. js/texparse.js — LaTeX→Struktur-Parser

## 6.1 Zweck & Rolle

Browser-Portierung von `tools/parse_thesis.js`: parst kompletten `.tex`-Quelltext neuer Arbeiten zu `{meta, chapters, footnotes, sources}` in denselben Datenformen wie `data/parsed/` (texparse.js:1-8). Zusätzlich robuste Vorverarbeitung für rohes LaTeX (Präambel, `\mainmatter`, figure/table→Marker, Mathematik→Marker, \cite-Modus für Paper) und eine ausführliche **deutsche** Fehler-/Warnungsliste, warum etwas nicht ladbar/darstellbar ist. Quellen werden über eine Registry (Regex-`aliases`) den Fußnotentexten zugeordnet; ohne Registry bleiben Fußnoten quellenlos (Warnung).

## 6.2 Öffentliche API

- `TexParse.parse(tex, opts = {registry: [...]})` → `{ok, errors, warnings, stats:{kapitel, abschnitte, fussnoten, quellen}, thesis:{meta, chapters}, footnotes, sources}` (texparse.js:14-343). `ok === errors.length === 0`.
- `TexParse.PKG_OK` — Set von ~52 still abgedeckten Paketen (texparse.js:346-352): u. a. `fontenc, inputenc, babel, csquotes, graphicx, hyperref, url, array, booktabs, tabularx, longtable, geometry, microtype, xcolor, color, biblatex, natbib, cite, enumitem, caption, subcaption, float, setspace, parskip, amssymb, amsfonts, lmodern, mathptmx, times, helvet, courier, textcomp, ifthen, calc, etoolbox, llncs, vutinfth, fancyhdr, titlesec, tocloft, appendix, breakurl, xurl, doi, orcidlink, multirow, multicol, wrapfig, placeins, rotating, pdflscape, lscape, threeparttable, makecell, verbatim, quoting`.
- `TexParse.PKG_NOTES` — Map Paket → präzise deutsche Warnung (texparse.js:355-377), z. B. `tikz: 'Zeichnungen (TikZ) werden als [GRAFIK]-Marker ersetzt.'`, `glossaries: 'Glossar-Kurzformen (\\gls u. a.) werden entfernt — ausgeschriebene Begriffe gehen verloren.'`, `chemfig: 'Chemische Strukturformeln sind nicht darstellbar — der Inhalt geht verloren.'` (17 Einträge: tikz, pgfplots, listings, minted, fancyvrb, amsmath, mathtools, amsthm, algorithm, algorithm2e, algorithmicx, algpseudocode, siunitx, glossaries, glossaries-extra, acronym, chemfig, musixtex, pdfpages, todonotes, tcolorbox).
- `TexParse.scanPackages(tex, warnings)` (texparse.js:380-393): meldet je unbekanntem/nicht abgedecktem `\usepackage`: `Nicht abgedeckt: Paket „p“ — {note | 'unbekanntes Paket; zugehörige Befehle können als Rest im Text verbleiben (siehe Restbefehl-Bericht).'}`.
- `TexParse.residualScan(chapters, footnotes, warnings)` (texparse.js:397-421): sammelt alle nach `cleanTex` verbliebenen `\befehle` mit Zählung und Erstfundort; Warnung: ``LaTeX nicht vollständig übersetzbar — verbleibende Befehle im Text: \cmd (N×, z. B. Abschnitt 3.2) · … . Diese Stellen erscheinen roh; oben stehen die nicht abgedeckten Pakete dazu.``
- `TexParse.extractMeta(tex, warnings)` (texparse.js:424-439): Titel aus `\settitle{..}{T}` (vutinfth) | `\title{T}` | `\newcommand{\thesistitle}{T}`; `subtitle` aus `\setsubtitle`; `author` aus `\newcommand{\authorname}` | `\author`; `university` aus `\institute` oder Erkennung `TU Wien|vutinfth|Technische Universität Wien` → `'Technische Universität Wien'`; `date` aus `\setdate{D}{M}{Y}` → `"Y-M-D"`; Konstanten `thesisPdf:'sources/thesis.pdf'`, `pageOffset:0`; ohne Titel → Warnung `Kein Titel gefunden (\settitle/\title) — „Unbenannte Arbeit“ verwendet.` und Titel `'Unbenannte Arbeit'`.
- `TexParse.sourceFromKey(key)` (texparse.js:444-461): Quellen-Stub aus Bib-Key (z. B. `abu-rasheed_context_2023`): `id` = lowercase, Nicht-`[a-z0-9_-]`→`-`; `year` = erstes `(19|20)\d{2}` im Key; `author` = erster `_`-Teil, Bindestrich-Teile kapitalisiert; `title` = restliche Teile ohne Jahreszahlen, kapitalisiert; `kind:'artikel'`, `keyGuessed:true`, `aliases:[regex-escapeter Key]`.
- `TexParse.cleanTex(s)` (texparse.js:464-500): LaTeX-Bereinigung — Kommentare (Lookbehind `(?<!\\)%.*$`), `\href{u}{t}`→t, `\url{u}`→u, `\textit/sl/sc/bf/tt{x}`→x, `\emph{x}`→x, `\enquote{x}`→„x“, `\glqq`→„, `\grqq`→“, `\ref/\label/\cite/\index/\gls/\acrshort/\acrlong{..}`→'' (entfernt), `\footnotemark`→'', `\footnotetext{..}`→'', `~`→Space, `\,`→Space, `\\`→Space, `\&`→&, `\%`→%, `\_`→_, `\#`→#, `\S`→§, `\dots`→…, `\$`→$, Akzentmakros via `ACCENTS`, `\ss`→ß, `\ae/\AE/\oe/\OE/\aa/\AA/\o/\O`→æÆœŒåÅøØ, `\c{c|C}`→ç/Ç, Layout-Befehle (`newpage`, `centering`, `vspace{..}` etc.) und Tabellen-Rules entfernt, **alle** `{`/`}` entfernt, Whitespace kollabiert, getrimmt.
- `TexParse.ACCENTS` (texparse.js:503-511): Map `"a`→ä … `=o`→ō (vollständig in Datei; deckt `\" \' \` \^ \~ \=` ab).
- `TexParse.parseParagraphs(raw, unitId)` (texparse.js:514-547): splittet an `itemize/enumerate/description`-Blöcken; Listen → `{id:'{unitId}-pN', type:'list', items:[…]}` (description-Items: `[Label] Text` → `Label: Text`); übrige Teile an Leerzeilen **oder** `\\` am Zeilenende getrennt; Marker `[ABBILDUNG: …]`/`[TABELLE: …]` → `type:'figure'/'table'` mit `text` = Caption; sonst `{type:'text', text}`.

**Konsumiert:** nichts App-Spezifisches (autark, nur eigenes Objekt). **Nutzer:** `views_projekt.js:410` (interaktive Analyse mit Fehlerbericht) und `projects.js:103,120` (Projekt-Anlage/-Neuladen mit Registry).

## 6.3 Parse-Pipeline (Reihenfolge exakt, texparse.js:14-343)

0. **Validierung:** leer/&lt;40 Zeichen → Fehler `'Leere oder viel zu kurze Eingabe — bitte den vollständigen LaTeX-Quelltext übergeben.'`; beginnt mit `%PDF-` → `'Das ist eine PDF-Datei, kein LaTeX-Quelltext (.tex). Bitte den Quelltext der Arbeit laden.'` (Z. 16-21).
1. Zeilenenden normalisieren; `extractMeta`; `scanPackages` **vor** dem Zuschnitt (Z. 24-27).
2. **Hauptteil-Zuschnitt:** `\mainmatter…\backmatter`, sonst `\begin{document}…\end{document}`, sonst Warnung `'Kein \begin{document} gefunden — die Datei wird als reiner Hauptteil interpretiert.'` (Z. 30-38).
3. **Abstract/Kurzfassung sichern** (`frontMatter`, erste passende Umgebung) + `\keywords{…}` merken (Z. 43-47); dann `filecontents*/abstract/kurzfassung/danksagung*/acknowledgements*/kitools`-Umgebungen aus dem Body löschen (Z. 50-52).
4. **Code-Blöcke** (`verbatim|Verbatim|lstlisting|minted|algorithm|algorithmic` inkl. `*`-Varianten, optionale `[..]`/`{..}`-Argumente) und `\lstinputlisting` → `[CODE: Quelltext-Auszug]`; Zähl-Warnung `'N Code-/Algorithmus-Block… durch [CODE]-Marker ersetzt — Listings sind im Studio nicht darstellbar.'`; `\verb|x|` → Inhalt (Z. 56-60).
5. **Kommentare:** ganze `%`-Zeilen filtern und Zeilenrest-Kommentare (Lookbehind) kappen — **vor** Zitat-/Fußnotenextraktion, damit `\cite`/`\footnote` in Kommentaren keine verwaisten Fußnoten erzeugen (Z. 62-68).
6. **\cite-Modus** (Z. 70-90): `\nocite{keys}` → nur registrieren; `\citeauthor*` → Autorname(n) als Fließtext; `\citeyear(par)` → Jahr(e), bei `par` in Klammern; `CITE_RE` = `\cite|citep|citet|autocite|Autocite|parencite|Parencite|footcite|footfullcite|fullcite|smartcite|Smartcite|textcite|Textcite` (mit optionalem `[..]`) → `\footnote{key1, key2}`. Gibt es Keys: Warnung ``\cite-basierte Arbeit erkannt: N Quellen aus den Bib-Keys übernommen — Metadaten sind daraus geraten und per registry.json (Gesamt-Prompt) ersetzbar.``; ohne übergebene Registry wird sie automatisch aus `sourceFromKey` je Key gebaut.
7. **Figuren/Tabellen** → `[ABBILDUNG: caption]` / `[TABELLE: caption]` (Caption-Regex erlaubt eine Klammer-Verschachtelung, entfernt `\footnotemark`; Default `ohne Titel`); freistehende `tikzpicture` → `[GRAFIK: TikZ-Zeichnung]`; freistehende `tabularx?/longtable` → `[TABELLE: Tabelle im Fließtext]` (Z. 92-100).
8. **Mathematik** (Z. 102-111): `\$` per `\u0001` schützen; Display-Umgebungen (`equation|align|gather|multline|eqnarray|alignat|flalign|displaymath` + `*`), `\[..\]`, `$$..$$` → Block `[FORMEL]`; `\(..\)` und `$..$` → inline `[Formel]`; Warnung `'N Formel(n) durch [Formel]-Marker ersetzt — Mathematik ist im Studio nicht darstellbar.'`
9. `\input/\include` → je Datei Warnung ``\input{f} kann im Browser nicht nachgeladen werden — der Inhalt von „f.tex“ fehlt in dieser Analyse. Bitte den Quelltext zu einer Datei zusammenführen.`` (Z. 113-115); Struktur-/Paper-Restbefehle entfernen (Z. 116-118); `quote/quotation/verse` auspacken (Z. 120); ab `\chapter*{`/`\section*{`/`\begin{thebibliography}` abschneiden (Literaturverzeichnis, Z. 122-123).
10. **Fußnoten-Extraktion** brace-aware (Z. 126-150): jedes `\footnote{…}` wird durch `[^N]` (fortlaufend ab 1) ersetzt, Text via `cleanTex`; unbalancierte Klammer → Fehler ``Nicht geschlossene \footnote{…} ab Zeile ~N — geschweifte Klammern prüfen.`` (parst 10 Zeichen weiter).
11. **Struktur** (Z. 152-251): `\paragraph{T}` → Absatzanfang `T. ` + Warnung; Tokenizer über `\chapter|section|subsection|subsubsection{..}`; **Fehler** wenn weder chapter noch section: `'Kein \chapter{…} oder \section{…} im Hauptteil gefunden — ohne Gliederung kann die Arbeit nicht aufgebaut werden.'` (→ `ok:false`); ohne chapter-Ebene: Warnung + **Level-Shift** (section→chapter usw., genau einmal am Token, Z. 185-192). `unitFor` baut IDs: Kapitel `N` (Intro-Einheit `N.0` mit `isIntro`), Abschnitte `N.M` (level 2), `N.M.K` (level 3), `N.M.K.L` (level 4); Text vor der ersten Section eines Kapitels wird zur vorangestellten Intro-Section `{id:'N.0', title:'Überblick', level:2, isIntro:true}` (Z. 240-247). Fehlende Zwischenebenen werden **sticky** promotet (WeakSet `promoted`, Z. 209-233): aufeinanderfolgende gleichrangige Überschriften bleiben Geschwister. Text ohne vorherige Überschrift wird verworfen (`pending` null, Z. 238).
12. **Front-Kapitel „0“** (Z. 256-283): gesicherter Abstract → Kapitel `{id:'0', num:0, title:'Abstract'|'Kurzfassung', sections:[{id:'0.0', …}]}` per `unshift` vor Kapitel 1; Zitate/Fußnoten darin werden entfernt (zählen nicht); Keywords als eigener Absatz `Keywords: a · b` (`\and`→` · `).
13. **Registry-Matching** (Z. 286-315): Registry-Einträge brauchen `id`; `aliases` werden als case-insensitive Regexes kompiliert (ungültige → Warnung `Registry {id}: ungültiges alias-Muster "{a}"`); jede Fußnote erhält `sources` = alle Registry-IDs, deren Alias auf den Fußnotentext matcht; Absätze bekommen `p.footnotes = [{num, text, sources}]` (aus `[^N]`-Markern); Fußnoten bekommen `sectionId`/`paragraphId`. `sources`-Ausgabe je Registry-Eintrag: alle Felder außer `aliases`/`_res`, plus `expectedFile: 'sources/{id}.pdf'` und `citations: [{footnote, sectionId, paragraphId, footnoteText}]`.
14. **residualScan** + **Diagnose** (Z. 318-328): Warnungen `'Keine \footnote{…} gefunden — ohne Fußnoten gibt es keine Belege zum Prüfen.'`, `'Keine Quellen-Registry übergeben — Fußnoten bleiben ohne Quellenzuordnung (per Registry-Import nachholbar).'`, ``N von M Fußnoten ohne Quellen-Match (Registry-aliases prüfen).``; Fehler `'Gliederung gefunden, aber keine Abschnitte mit Text — ist der Hauptteil leer?'` wenn keine Einheit Absätze hat.

## 6.4 Datenformen (Ausgabe)

```json
{
  "ok": true,
  "errors": [], "warnings": ["Nicht abgedeckt: Paket „tikz“ — …"],
  "stats": { "kapitel": 6, "abschnitte": 42, "fussnoten": 180, "quellen": 55 },
  "thesis": {
    "meta": { "title": "…", "subtitle": "", "author": "…", "university": "…",
              "date": "2024-05-01", "thesisPdf": "sources/thesis.pdf", "pageOffset": 0 },
    "chapters": [{
      "id": "1", "num": 1, "title": "Einleitung",
      "sections": [{
        "id": "1.0", "title": "Überblick", "level": 2, "isIntro": true,
        "paragraphs": [{ "id": "1.0-p1", "type": "text", "text": "… [^1] …",
                         "footnotes": [{ "num": 1, "text": "Vgl. …", "sources": ["ehds-vo"] }] }],
        "children": []
      }, {
        "id": "1.1", "title": "Motivation", "level": 2,
        "paragraphs": [
          { "id": "1.1-p1", "type": "text", "text": "…" },
          { "id": "1.1-p2", "type": "list", "items": ["Label: Text", "…"] },
          { "id": "1.1-p3", "type": "figure", "text": "Architekturübersicht" }
        ],
        "children": [ { "id": "1.1.1", "level": 3, "…": "…" } ]
      }]
    }]
  },
  "footnotes": [{ "num": 1, "text": "Vgl. …", "sectionId": "1.0", "paragraphId": "1.0-p1" }],
  "sources": [{
    "id": "abu-rasheed-context-2023", "kind": "artikel", "author": "Abu-Rasheed",
    "year": 2023, "title": "Context", "keyGuessed": true,
    "expectedFile": "sources/abu-rasheed-context-2023.pdf",
    "citations": [{ "footnote": 1, "sectionId": "1.0", "paragraphId": "1.0-p1", "footnoteText": "…" }]
  }]
}
```

Registry-Eingabeform (opts.registry): `[{id, kind?, author?, year?, title?, aliases:["Regex-String", …], …beliebige Metafelder}]`.

## 6.5 Flutter-Hinweise

- Größtes Portierungsstück, aber vollständig UI-frei → reine Dart-Klasse, gut testbar (Golden-Tests: identische Eingabe muss identisches JSON liefern wie das JS-Original).
- Dart-`RegExp` unterstützt Lookbehind `(?<!\\)` (ab Dart 2.19 überall); `matchAll`→`allMatches`; `String.replace(re, fn)`→`replaceAllMapped`. Achtung bei `$`-Zeichen in Ersetzungsstrings (Dart interpoliert nicht in Ersatzfunktionen — bevorzugt Funktionen nutzen).
- `WeakSet promoted` → normales `Set<Object>` (Identity-Semantik: `Set.identity()`), Lebensdauer ist eh nur der Parse-Lauf.
- Schutzzeichen `\u0001` für `\$` beibehalten.
- Alle deutschen Fehler-/Warnungstexte wörtlich übernehmen — sie sind Teil der UI (Prüfbericht in views_projekt).
- Fußnoten-Nummern entstehen in Dokumentreihenfolge der `\footnote`-Vorkommen — Reihenfolge der Pipeline (erst \cite→\footnote-Ersetzung, dann Extraktion) ist dafür kritisch.

---

# 7. js/ziputil.js — ZIP lesen/schreiben

## 7.1 Zweck & Rolle

**Eigene, abhängigkeitsfreie Implementierung** (keine Lib!) des ZIP-Formats (ziputil.js:1-5). Schreiben: ausschließlich unkomprimiert (STORE) — Begründung im Code: „PDFs sind ohnehin komprimiert“. Lesen: STORE direkt, DEFLATE via Browser-`DecompressionStream` (`'deflate-raw'`; Chrome/Edge/Safari 16.4+). Einsatz: Quellen-Workflow — alle Datei-Links als ZIP sichern und ZIP-Archive (auch mehrfach) importieren.

## 7.2 Öffentliche API

- `ZipUtil.crc32(buf: Uint8Array) → Number` — CRC-32 (Polynom `0xedb88320`, Tabelle vorbereitet in `_crcTable`, ziputil.js:9-22).
- `ZipUtil.create(entries: [{name: String, data: Uint8Array}]) → Blob('application/zip')` (ziputil.js:25-58): je Eintrag Local File Header (Signatur `0x04034b50`, Version 20, Flags `0x0800` = UTF-8-Dateinamen, Methode 0 = STORE, feste Zeit `0`/Datum `0x21` — Kommentar „unwichtig“), CRC + Größe (×2, da unkomprimiert); dann Central Directory (`0x02014b50`, 18 Teile pro Eintrag) und End-of-Central-Directory (`0x06054b50`). Kein ZIP64, keine Extra-Fields, keine Kommentare.
- `ZipUtil.read(blob) → Promise<[{name, data: Uint8Array} | {name, error: String}]>` (ziputil.js:61-113): sucht EOCD-Signatur rückwärts in den letzten 65 558 Bytes; wirft `'Kein ZIP-Archiv (End-Signatur fehlt.)'` → exakt: `'Kein ZIP-Archiv (End-Signatur fehlt).'`; liest Eintragszahl (EOCD+10) und CD-Offset (EOCD+16); iteriert Central-Directory-Einträge (bricht bei falscher Signatur ab), überspringt Ordner (`name.endsWith('/')`); Datenoffset über den **lokalen** Header neu berechnet (Name-/Extra-Längen können abweichen, ziputil.js:87-91); Methode 0 → Kopie (`raw.slice()`); Methode 8 → `DecompressionStream('deflate-raw')`, bei fehlender Browser-Unterstützung Fehlereintrag `'komprimiert (DEFLATE) — dieser Browser kann das nicht entpacken'`, bei Entpackfehler `'nicht entpackbar: {msg}'`; andere Methoden → `'Kompressionsmethode {N} nicht unterstützt'`. CRC wird beim Lesen **nicht** verifiziert.

**Konsumiert:** nur Web-APIs (`TextEncoder/TextDecoder`, `DataView`, `Blob`, `DecompressionStream`, `Response`). **Nutzer:** `views_quellen.js:817` (`ZipUtil.read(f)` beim Import) und `views_quellen.js:894` (`ZipUtil.create([...])` beim Export).

## 7.3 Datenformen

Eingabe create / Ausgabe read: `[{ name: 'id.pdf', data: Uint8Array }]`; Fehlereinträge beim Lesen ersetzen `data` durch `error` (String) — Aufrufer müssen `entry.error` prüfen.

## 7.4 Randfälle / bekannte Grenzen (für 1:1-Nachbau relevant)

- `csize` stammt aus dem Central Directory → auch Streams mit Data-Descriptor lesbar. Kein ZIP64 (>4 GB / >65535 Einträge), keine Verschlüsselung, keine UTF-8-Fallback-Erkennung (dekodiert immer UTF-8).
- `create`: `cdSize`-Berechnung nimmt die letzten `central.length * 18` Parts (ziputil.js:55) — funktioniert nur, weil pro CD-Eintrag exakt 18 Array-Teile gepusht werden. Beim Portieren einfach mitzählen statt diese fragile Slice-Logik nachzubauen.
- Zeitstempel aller Einträge fest: DOS-Time 0, DOS-Date `0x21` (1980-01-01).

## 7.5 Flutter-Hinweise

- **Empfehlung: `package:archive`** (pub.dev) statt Eigenbau — deckt STORE+DEFLATE, ZIP64 und CRC ab. Beim Schreiben STORE erzwingen, um Byte-Verhalten (schnell, PDFs unkomprimiert) beizubehalten; UTF-8-Namen setzt archive automatisch.
- Fehlerverhalten nachbilden: Eintrags-Liste mit `error`-Feld statt Exception pro Datei; Gesamtfehler „Kein ZIP-Archiv …“ als Exception.
- `DecompressionStream` entfällt — `archive` dekomprimiert nativ, damit verschwindet die Browser-Kompatibilitätswarnung (im UI-Text ggf. anpassen/streichen).

---

# 8. Modulübergreifende Abhängigkeitsmatrix

| Modul | ruft auf | wird gerufen von |
|---|---|---|
| Levels | U.store*/esc/getResolutions/getAnnotations/getPdfManual/findBeleg, SRC_BY_ID, FN_INDEX, UNIT_INDEX, DATA_THESIS, PdfEngine? | views_studio, views_quellen (Export/Import), app.js (Auto-Import), connections, enhance |
| Connections | UNIT_INDEX, orderedUnits, FN_INDEX, Levels.numsForSection, U.store*/srcShort, DATA_META, DATA_THESIS, DATA_SECTIONS, fileIdOf | views_studio, enhance (importKi) |
| Mentions | DATA_SOURCES, FN_INDEX, U.store*, DATA_THESIS | views_studio (Anzeige/Merge), Belegstand-Export |
| StyleCheck | U.splitSentences | views_studio (617, 861) |
| Editor | U.store*/el/esc/download/resizer, UNIT_INDEX, FN_INDEX, orderedUnits, DATA_THESIS.meta, sourcePickerModal? | views_studio:129 (Modus 'editor') |
| TexParse | — (autark) | views_projekt:410, projects:103/120 |
| ZipUtil | Web-APIs | views_quellen:817/894 |

---

# 9. Offene Punkte für andere Dossiers

- Genaue Formen von `U.getResolutions()` (`stellen[]`, `generatedBy`), `U.getAnnotations()`, `U.findBeleg(num)` und `U.splitSentences` → Util-Dossier.
- `PdfEngine.marksForFn(srcId, num)` → PDF-Dossier (Felder `zitat`, `page`, `farbe` werden hier konsumiert).
- CSS-Farben der Klassen `lvl-badge l1..l3`, `lvl-dot l0..l3`, `lvl-bar p1..p3`, `.editor-panes`/`--ed-w`-Grid, `.tex-toolbar`, `.tex-lint .err/.ok/.warn`, `.pv-fn`, `.fig-missing`, `.chip.warn` → CSS-Dossier.
- `sourcePickerModal(sectionId, null, cb)` (Quellen-Auswahl-Modal) → Views-Dossier.
