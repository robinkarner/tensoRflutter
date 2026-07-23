# Inventar-Dossier 02 — Designsystem („Book Cloth" V5)

**Dateien:** `css/theme.css` (585 Z.) · `css/app.css` (2263 Z.) · `assets/fonts/` (12 Dateien)
**Rolle:** Das KOMPLETTE Designsystem der App — Grundlage für das Flutter `ThemeData` + `ThemeExtension`s. Alle Rohwerte sind hier vollständig tabelliert (Light + Dark).

---

## 1. Zweck & Rolle

### css/theme.css (theme.css:1–585)
Definiert das Designsystem „V5 — Book Cloth" (theme.css:1–11): Terracotta (`#b4552d`, „Buchleinen") als EINZIGER Akzent auf fast-schwarzem Ink-Gerüst, warmer Papierton als Fläche, Space Grotesk als Display-Schrift, Serifen nur für Lese-/Zitatflächen. **Design-Konvention (theme.css:9–10): RUND = Belegstatus (Ampel-Punkte), QUADRATISCH = Struktur/Datei/Verbindung.** Enthält: alle `@font-face`-Deklarationen, sämtliche CSS-Custom-Properties für Light (:root) und Dark (`:root[data-theme="dark"]` + Auto-Dark via `prefers-color-scheme`), Reset/Basis-Typografie, Scrollbars, und die generischen Bausteine (card, btn, chip, badge, mark, notice, tbl, modal, md, kbd, grid-Helfer).

### css/app.css (app.css:1–2263)
App-Layout & alle View-spezifischen Komponenten (app.css:1–6): Topbar, Studio-Arbeitsraum (4 parallele, per Drag verziehbare Bereiche), Referenzierungsmodus (Fullscreen-Split), Quellen-Bibliothek (Zotero-artig, 3-spaltig), Analyse-Tabs, Projekt-Seite, PDF-Engine (Markierungs-Renderer über pdf.js), Beleg-Dock, GPT-Magic-System (Block-Buttons im „Retro-Spielmenü"-Stil), Enhance-Panel (rechts einfahrend), Erklärbuch/Mathe-Renderer, Zugangs-Gate, Hilfe-Seite, Druck-Styles, Barrierefreiheit. Baut vollständig auf den Tokens aus theme.css auf; einzige zusätzliche Hardcode-Farben sind unter „Design-Rohwerte" gelistet.

### assets/fonts/ (Verzeichnis)
12 lokale WOFF2-Dateien (kein CDN): `inter-400/500/600/700.woff2`, `space-grotesk-500/700.woff2`, `jetbrains-mono-400/600.woff2`, `nunito-800.woff2`, `baloo2-500/700/800.woff2`. Daneben in `assets/`: `icon-180.png`, `vendor/`.

---

## 2. Öffentliche API

CSS hat keine JS-API; die „API" sind **Klassennamen + Custom Properties**, die JS-Module setzen/lesen:

**Vom JS gesetzte Attribute/Klassen (Konsumenten der CSS):**
- `:root[data-theme="dark"|"light"]` — Theme-Umschaltung (theme.css:160); ohne Attribut greift Auto-Dark (theme.css:243–270).
- `html.gated` (app.css:1625) — Scroll-Sperre solange Zugangs-Gate aktiv.
- `body.resizing` / `body.resizing-y` (app.css:1350, 527) — während Drag-Resize: Cursor global `col-resize`/`row-resize`, `user-select:none`, Transitions am Studio aus (app.css:1100).
- Studio-Zustandsklassen: `.studio.file-off`, `.studio.tree-off` (app.css:184–189), `.sf-dock.sized/.closed`, `.pe.compact`, `.fastread`, `.fastread-on`, `.lesen-doc.kompakt`, `.studio-inner.wide/.dock-on`, `.refmode.side-hidden`, `.wissen-page`.
- **Per JS gesetzte Inline-Custom-Properties (Layout-State):** `--file-w`, `--tree-w` (Studio-Spaltenbreiten, app.css:168–169), `--ref-w` (RefMode-Seitenbreite, app.css:628), `--lib-list-w` (app.css:714), `--ed-w` (Editor-Split, app.css:841), `--sfd-h` (Dock-Höhe, app.css:528), `--ps-w` (Instanz-Fenster-Breite, app.css:1490), `--fc` (farbdot-Farbe, app.css:569), `--sw` (Swatch, app.css:590), `--pc` (Pin-Farbe, app.css:957), `--c` (mark.hl-Kategorie-Farbe, theme.css:419; pc-cat app.css:1363), `--swc` (Suchwort-Mark, app.css:686), `--stc` (Quelltext-Highlight, app.css:1310), `--inst-c` (Instanz-Chip, app.css:1536), `--ps-accent` (getöntes Instanz-Fenster, app.css:1546), `--agc` (Graph-Kanten, app.css:1576), `--vc` (View-Punkt, app.css:2256), `--i` (Stagger-Index Magic-Buttons, app.css:1839).
- CSS Custom Highlight API-Namen (JS registriert `CSS.highlights`): `::highlight(beleg-span)`, `::highlight(gpt-style)` (app.css:1086–1087), `::highlight(src-view)`, `::highlight(src-view-strong)` (app.css:2241–2242).

---

## 3. State & Persistenz

Keine localStorage/IndexedDB-Zugriffe in CSS (reines Styling). Persistenter Layout-State (Spaltenbreiten, Theme) wird von JS-Modulen in die o.g. Custom Properties / `data-theme` geschrieben — Keys siehe Dossiers der JS-Module. CSS-relevanter „State" ist ausschließlich klassenbasiert (Abschnitt 2).

---

## 4. UI-Struktur & Layout

### 4.1 Grundgerüst
- `.topbar` (app.css:9–16): `position:sticky; top:0; z-index:50`, `display:flex; align-items:center; gap:14px`, Höhe `var(--topbar-h)` = **56px**, `padding:0 16px`, `background:var(--surface)`, `border-bottom:1px solid var(--border)`. Enthält `.brand` (Flex, gap 10px) → `.brand-badge` + `.brand-text`/`.brand-sub`, dann `.mainnav` (Flex, gap 1px, `flex:1`, `overflow-x:auto`), rechts `.topbar-actions` (Flex, gap 6px, `position:relative` als Anker für Popovers, app.css:1258).
- `main#app` (app.css:78): `max-width:none; padding: var(--space-3) clamp(14px,2vw,26px) 80px; min-height: calc(100vh - var(--topbar-h) - 60px)`.
- `.footer` (app.css:79–84): Flex `space-between`, wrap, `padding:14px 24px 24px`, Farbe `--muted`, `font-size:12px`, `border-top:1px solid var(--border)`.
- `.page-head` (app.css:85): `margin-bottom:20px`; h1 darin `margin-bottom:4px`.

### 4.2 Responsive-Engine (Konvention, app.css:70–77)
| Tier | Breite | Verhalten |
|---|---|---|
| Stack | ≤ 720px | alle Mehrspalter einspaltig (Handy/iPad hoch) |
| Schmal | ≤ 900px | Splitscreens (RefMode) stapeln |
| Workspace | ≤ 999 / ≥ 1000px | Studio stapelt vs. Spalten |
| Breit | ≥ 1200px | Zusatzspalten (3-spaltige Bibliothek) |

Bauteil-Verhalten via `@container` (Editor-Split `content` max 940px app.css:842; Instanz-Fenster `content` max 880px app.css:1524; Zuordnungspanel `ap` min 560px app.css:1287); Größen via Fluid-Tokens. Weitere @media: 560 (cc-grid 1-spaltig, app.css:1737; gp-Zeilen kompakt app.css:1951), 620 (lg-Zeilen umbruch, app.css:1950), 640 (Enhance vollbreit, Nav horizontal, app.css:2109), 760 (Topbar-Labels weg, app.css:64), 860 (nb-edit 1-spaltig, app.css:1483), 1199 (Lib 2-spaltig, app.css:716).

### 4.3 Studio-Arbeitsraum (app.css:157–210)
`.studio` = CSS-Grid: `grid-template-columns: var(--tree-w-c) 7px minmax(0,1fr) 7px var(--file-w-c)`; Areas `'tree trs content frs file'`; `gap: 0 10px; align-items:start`.
- `--file-w-c: min(var(--file-w, clamp(400px,30vw,640px)), 50vw)` — PDF-Viewer max. 50% Screenbreite (app.css:168).
- `--tree-w-c: min(var(--tree-w, 240px), 26vw)` (app.css:169).
- Die 7px-Spalten sind `.tree-resize`/`.file-resize` (Klasse `.pane-resize`, `cursor:col-resize`).
- `.file-off`: Datei-Spalte + Resizer `display:none`, Grid → `tree 7px content`; `.tree-off`: analog → `content 7px file`; beides → nur `content` (app.css:184–189).
- **≤999px**: alles stapelt (`'tree' 'content' 'file'`), Resizer weg, `.studio-file` `position:static; height:min(78vh,760px); margin-top:14px`, `.studio-tree` `position:relative; max-height:300px` (app.css:192–205).
- `.studio-content`: `min-width:0; container: content / inline-size` (app.css:208). `.studio-inner`: `max-width:980px; margin-inline:auto`; `.wide`: `max-width:none`; `.dock-on`: `max-width:1320px; margin-inline:auto 0` (rechtsbündig, app.css:1489).

### 4.4 Kapitelbaum links `.card.studio-tree` (app.css:216–286)
`position:sticky; top:calc(var(--topbar-h) + 10px); height:calc(100vh - var(--topbar-h) - 22px)`, Flex-Spalte, `padding:0`, `border:1px solid var(--border-strong)`, `border-radius:var(--radius-lg)`. **Kubischer Eck-Marker**: `::before` 8×8px `var(--accent)` bei top/left −1px (app.css:227). Kopfleiste `.st-bar` (min-height 49px, border-bottom), Scrollbereich `.st-body` (`flex:1; overflow-y:auto; padding:6px 8px 16px`). Kapitelgruppen `.tree-ch` mit Hairline-Trennern; Kopf-Button 700 13px, Caret `.tc-caret` dreht bei `.open` um 90° (transition .13s). Unterpunkte `li a` 500 13px, `.active`: `background:var(--accent-soft); color:var(--accent-ink)`; `.l3` eingerückt (padding-left 22px). Kapitelnummern `.tn` in Mono, `--accent-ink`. Umbenennen-Stift `.tree-ren`: `opacity:0`, bei Hover 0.7, `@media (hover:none)` immer 0.55 (app.css:280). Inline-Edit `.tree-edit`: Input mit `border:1px solid var(--accent)`.

### 4.5 Modus-Leiste `.studio-bar` (app.css:291–324)
`position:sticky; top:var(--topbar-h); z-index:40`, Flex mit wrap, `background: color-mix(in srgb, var(--bg) 92%, transparent); backdrop-filter: blur(6px)`, `border-bottom`, `min-height:54px`. `.mode-switch`: Segmented Control — `background:var(--surface-3); border:1px solid var(--border); border-radius:var(--radius-sm); padding:3px`; Links 500 14px `padding:9px 18px; border-radius:7px`; `.active`: `background:var(--surface)`, fett, `box-shadow:0 1px 2px rgb(0 0 0/.08)`. Dark: Track `--bg-deep`, aktiv `--surface-3` ohne Schatten (app.css:319–324). Rechts `.bar-tools` (`margin-left:auto`).

### 4.6 Quellen-Spalte rechts `.studio-file` (app.css:435–504)
Sticky wie tree, gleiche Höhe, Flex-Spalte, `container: filepane / inline-size`, gleicher Eck-Marker (app.css:445). Innen: `.sf-bar` (Kopf, wrap, border-bottom; Label `.sf-bar-lbl` 700 10px Display uppercase; `select` max-width 42cqw), `.sf-iconbtn` (32×32px, font-size 15, `border-radius:8px`), `.sf-host` (`flex:1`, Flex-Spalte, `background:var(--surface-2)`): oben einklappbare Quell-Karte `.sf-card` (nie eigener Scrollbereich, app.css:470–473), darunter `.sf-view` (`flex:1 1 auto; min-height:220px`) mit PDF-Engine. `.sf-host.no-view`: Karte füllt und scrollt, View versteckt. `.sf-empty`: zentrierter Muted-Text `padding:26px 18px`.
**Beleg-Dock unten `.sf-dock`** (app.css:522–561): `border-top:1px solid var(--border-strong)`, Standard `max-height:38%`; Naht `.sfd-resize` 7px hoch, `cursor:row-resize`, `::after`-Streifen (inset 2px 8px) wird bei Hover `--accent`; `.sized`: `height:var(--sfd-h); max-height:72%`; `.closed`: nur Tab-Zeile. `.sfd-tabs` (Flex, border-bottom), Dropdown `.sf-fn` (`flex:1 1 120px`), Farbwahl `.sfd-farb` (Punkt 24×24px), Minimieren-Button `.sfd-min` 30×30px accent-getönt (app.css:547–555). Farbpopover im Slot öffnet **nach oben** (`bottom: calc(100% + 6px)`, app.css:544). `.sfd-body`: scrollbar, `padding:9px 12px 12px`, `gap:7px`.

### 4.7 Rand-Leisten (eingeklappte Spalten, app.css:484–504)
`.file-rail`/`.tree-rail`: nur sichtbar bei `.file-off`/`.tree-off` — `position:fixed; top:calc(var(--topbar-h) + 78px); z-index:30; width:34px; padding:16px 0`, Flex-Spalte zentriert; rechts angeschlagen `border-radius:12px 0 0 12px` (file) bzw. links `0 12px 12px 0` (tree). Text `.fr-tx` vertikal (`writing-mode:vertical-rl`), 600 12px. ≤999px: `top:+12px`, kompakter.

### 4.8 Referenzierungsmodus `.refmode` (app.css:615–711)
`position:fixed; inset:0; z-index:90`, Flex-Spalte, `background:var(--bg)`, fadeIn .14s. `.ref-head` (Kopfzeile, shadow-1). `.ref-body`: Grid `var(--ref-w,360px) 7px minmax(0,1fr)`; `.side-hidden` → `0 0 1fr`. **≤900px**: stapelt vertikal `minmax(120px,34vh)` + Rest (app.css:632–637). `.ref-side`: scrollbar, `background:var(--bg-deep)`. `.ref-src`-Karten mit `header` (Quadrat-Punkt `.dot` 8×8px `border-radius:1.5px`!), `.active`: `border-color:var(--accent-line); box-shadow:0 0 0 1px var(--accent-line)`, Header `--accent-soft`. `.ref-item.focus`: `background:var(--accent-soft); box-shadow: inset 2.5px 0 0 var(--accent)`. `.ref-pdfbar` (Toolbar), `.ref-pdfhost` (`overflow:auto`), `.ref-law` (Gesetzestext-Ansicht), `.prov-row` (Provenienz-Zeilen).

### 4.9 Quellen-Bibliothek `.lib` (app.css:713–793)
Grid: `220px minmax(280px, var(--lib-list-w,34%)) 7px minmax(360px,1fr)`, gap 14px. ≤1199px: `205px 1fr`, Detail über volle Breite; ≤720px: einspaltig. `.lib-rail` + `.lib-detail` sticky (`top: topbar+14px; max-height: calc(100vh - topbar - 30px); overflow-y:auto`). `.lib-coll` (Sammlungs-Buttons, `.active` accent-soft), `.lib-rows` (Rahmen-Liste), `.lib-row.active`: `background:var(--accent-soft); box-shadow: inset 2.5px 0 0 var(--accent)`. `.lvl-bar` in Zeile: 54px. `.src-head .sh-title`: **Serif 19.5px** (compact: 15.5px). `details.libd-sec`: Akkordeons mit `▸`-Caret (rotiert 90°).

### 4.10 PDF-Engine `.pe` (app.css:884–967)
Flex-Spalte, `height:100%`, `container-type:inline-size`. `.pe-bar` Toolbar (wrap, Separatoren `.sep` 1×18px). Suche `.pe-q`: `width:clamp(210px,32cqw,380px)`. `.pe-scroll`: `flex:1; overflow:auto; padding:14px` (Endlos-Scroll aller Seiten); `.pe.compact .pe-scroll`: `max-height:min(62vh,640px)`. `.pe-stack`: Flex-Spalte zentriert, gap 14px, `width:max-content; min-width:100%`. `.pe-page`: **`background:#fff`** (immer, auch Dark), `box-shadow:0 2px 14px rgb(0 0 0/.18)`, `border-radius:3px`. pdf.js-`textLayer` (app.css:917–933): absolut, transparenter Text, selektierbar. Marks-Layer `.pe-marks` (z-3, `pointer-events:none`). Highlights `.pe-hl`: absolut, `mix-blend-mode:multiply`; **Dark: `mix-blend-mode:normal; opacity:.55`** (app.css:948–949). Pins `.pe-pin` (z-4): Mono 700 10px, Pill, `border:1.5px solid var(--pc)`, `cursor:grab`. OCR-Leiste `.pe-ocr`: warn-soft; `.on-page`: absolut auf der Seite (app.css:1660–1664).

### 4.11 Prüfen-Modus / Instanz-Fenster
`.para-card` (app.css:400): Karte `padding:0; overflow:hidden`; `.para-body` klickbar (Hover surface-2); `.open .para-body`: surface-2 + border-bottom. `.para-text` 16px/1.75, max 78ch. `.resolution` (Beleg-Liste, app.css:413). `.beleg`-Zeilen: `border-radius:10px`, Hover accent-line, `.sel` accent-soft.
**Instanz-Fenster `.para-row`** (app.css:1490–1529): Grid `minmax(0,1fr) minmax(0, var(--ps-w, min(300px,34cqw)))`; Karte links ohne rechte Rundung/Border, `.para-side` rechts mit **gestrichelter Naht** (`border-left:1.5px dashed var(--border-strong)`); Resize-Griff `.ps-resize` (10px breit, links überlappend, `cursor:col-resize`). @container content ≤880px: stapelt vertikal, Naht wird `border-top` dashed. `.para-side.tinted`: Farb-Wash `color-mix(in srgb, var(--ps-accent) 4%, var(--surface))`, Farbpunkt 8×8px vor Titel (app.css:1546–1555).

### 4.12 Overlays & Z-Index-Inventar
| z | Element |
|---|---|
| 1 | sp-group sticky, magic-main |
| 2 | textLayer, srctext-bar |
| 3 | pe-marks, edit-hint, ps-resize |
| 4 | pe-pin |
| 5 | Eck-Marker, sfd-resize, pane-resize |
| 30 | file-rail/tree-rail |
| 40 | .studio-bar |
| 50 | .topbar |
| 70 | .farbpop |
| 90 | .refmode, .works-pop |
| 95 | .cmdk-back, .gpt-pop |
| 96 | .lightbox |
| 99 | .viz-tip |
| 110 | .enh-back |
| 120 | .modal-back |
| 200 | .skip-link |
| 9999 | .gate |

- `.modal-back` (theme.css:512–519): fixed, `background: color-mix(in srgb, #000 34%, transparent); backdrop-filter: blur(3px)`, Inhalt oben zentriert `padding:7vh 18px 18px`. `.modal`: `width:min(780px,100%); max-height:84vh`, Flex-Spalte, popIn. Sonderbreite: `.modal:has(.nb-edit-grid) { width:min(1180px,96vw) }` (app.css:1484).
- `.cmdk-back` (app.css:90): `background: color-mix(in srgb, var(--bg-deep) 55%, transparent); blur(5px); padding-top:12vh`. `.cmdk`: `width:min(620px,92vw)`, radius-lg; Input randlos 15px; Liste `max-height:46vh`; `.cmdk-item.sel/:hover`: accent-soft; Hint-Zeile 11px.
- `.works-pop` (app.css:1259): absolut unter Topbar-Actions, `top:calc(100%+8px); right:0; width:min(560px,94vw)`; Karte `max-height:72vh` scrollbar.
- `.gpt-pop` (app.css:1871): absolut unterm GPT-Knopf, `left:0; width:min(540px,94vw)`, `border-radius:12px`.
- `.lightbox` (app.css:153): `background: color-mix(in srgb, var(--bg-deep) 88%, transparent); blur(8px)`; Bild max 94vw/88vh, `cursor:zoom-out`.
- `.enh-back`/`.enh-panel` (app.css:2011–2025): rechts einfahrendes Panel `width:min(580px,97vw)`, `transform:translateX(100%)` → `.in` `translateX(0)`, transition `.42s cubic-bezier(.16,1,.3,1)`; Body-Grid `172px 1fr` (Nav|Main); ≤640px: vollbreit, Nav horizontal oben.
- `.gate` (app.css:1626): fullscreen z-9999; `.gate-card` `width:min(360px,88vw); padding:36px 32px`, zentriert; Logo 44×44px `border-radius:12px` accent.

### 4.13 Splits/Resizer-Pattern (app.css:1341–1351)
`.pane-resize`: `cursor:col-resize; touch-action:none`; `::after`-Streifen `inset:0 2px`, `background:var(--border-strong); opacity:.5`; Hover/`body.resizing`: `background:var(--accent); opacity:.9`. Vertikal identisch: `.sfd-resize`. Während Resize: `body.resizing *{ user-select:none !important }`, Studio-Transitions aus (app.css:1100).

### 4.14 Druck (app.css:1292–1300, 1999–2006)
Versteckt Topbar/Footer/Tree/File/Bar/RefMode/Rails/Resizer; Studio → 1 Spalte `!important`; `body{background:#fff}`. Dokument-Druck: `.page-head h1{font-size:20pt}`, `.lesen-doc{font-size:11pt; line-height:1.5}`, Links `color:inherit`.

---

## 5. Design-Rohwerte

### 5.1 @font-face (theme.css:14–25) — alle lokal, `font-display:swap`
| Familie | Gewichte | Dateien |
|---|---|---|
| Inter | 400, 500, 600, 700 | inter-{400,500,600,700}.woff2 |
| Space Grotesk | 500, 700 | space-grotesk-{500,700}.woff2 |
| JetBrains Mono | 400, 600 | jetbrains-mono-{400,600}.woff2 |
| Nunito | 800 | nunito-800.woff2 |
| Baloo 2 | 500, 700, 800 | baloo2-{500,700,800}.woff2 |

Font-Stacks (theme.css:29–33):
- `--font-ui`: `'Inter', system-ui, -apple-system, 'Segoe UI', sans-serif`
- `--font-display` = `--font-brand`: `'Space Grotesk', 'Inter', system-ui, sans-serif`
- `--font-mono`: `'JetBrains Mono', ui-monospace, 'Cascadia Code', Consolas, monospace`
- `--font-serif`: `'Iowan Old Style', 'Palatino Linotype', Palatino, Georgia, 'Times New Roman', serif` (**keine Webfont-Datei — Systemserifen!**)
- Magic-Buttons: `'Baloo 2', 'Nunito', var(--font-ui)` (app.css:1695, 1777, 1858, 1911, 1921, 2076)

### 5.2 Farbtokens — VOLLSTÄNDIG (Light theme.css:28–155 · Dark theme.css:160–239; Auto-Dark identisch theme.css:243–270)
| Token | Light | Dark | Zweck |
|---|---|---|---|
| --bg | `#f4f2ec` | `#1e1c17` | Seiten-Hintergrund (warmes Papier / Ember-Graphit) |
| --bg-deep | `#ece9e1` | `#161411` | Vertiefungen |
| --surface | `#fefdfb` | `#27231d` | Panels |
| --surface-2 | `#f9f7f1` | `#2e2a24` | Sekundärflächen |
| --surface-3 | `#efece4` | `#39342c` | Hover/aktiv |
| --border | `#ddd8cd` | `#403a30` | Hairline |
| --border-strong | `#c4beb1` | `#575048` | kräftige Kante |
| --ink | `#131316` | `#f0ede5` | Haupttext |
| --ink-2 | `#3a3c43` | `#beb8ac` | Sekundärtext |
| --muted | `#51535c` | `#98917f` | Kleinsttexte (~6.6:1) |
| --accent | `#b4552d` | `#e28a5d` | Terracotta „Book Cloth" |
| --accent-strong | `#9a4423` | `#eb9f74` | Hover-Akzent |
| --accent-ink | `#a04a26` | `#e69670` | Akzent als Textfarbe |
| --accent-soft | `#f7ebe4` | `#3a2a1f` | leiser warmer Wash |
| --accent-line | `#e3c4b2` | `#6e452e` | Akzent-Hairline |
| --accent-contrast | `#ffffff` | `#2b1409` | Text AUF Akzent |
| --good | `#3f7449` | `#8fb87f` | grün |
| --good-soft | `#e8f0e5` | `#253023` | |
| --warn | `#96702c` | `#cfa05e` | gelb/braun |
| --warn-soft | `#f5eeda` | `#332a1a` | |
| --bad | `#a04b3c` | `#d1806f` | rot |
| --bad-soft | `#f5e8e3` | `#37231e` | |
| --ki | `#54687d` | `#94aabf` | KI-Ton (Schieferblau) |
| --ki-soft | `#e9eef3` | `#252a2f` | |
| --lvl1 | `#5d7186` | `#8ba1b6` | Belegstatus 1 (blau-grau) |
| --lvl1-soft | `#e9eef3` | `#272d33` | |
| --lvl2 | `#96702c` | `#cfa05e` | Belegstatus 2 (= warn) |
| --lvl2-soft | `#f5eeda` | `#332a1a` | |
| --lvl3 | `#3f7449` | `#8fb87f` | Belegstatus 3 (= good) |
| --lvl3-soft | `#e8f0e5` | `#253023` | |
| --cat-norm | `#2e6b74` | `#6fb5c0` | Quelle/Rechtsnorm (Petrol) |
| --cat-frist | `#a8721e` | `#d6a44e` | Frist |
| --cat-akteur | `#7d5a96` | `#b291cc` | Akteur |
| --cat-tech | `#34786f` | `#6fbcb0` | Technik |
| --cat-these | `#46679c` | `#85a5d8` | These |
| --cat-luecke | `#ad5151` | `#e07f7f` | Lücke |
| --cat-zahl | `#587f3f` | `#9dc07f` | Zahl |
| --cat-abk | `#8a6d4e` | `#c2a179` | Abkürzung |
| --cat-schlag | `#4e5f8a` | `#8f9fd0` | Schlagwort |
| --tag-venue | `#46679c` | `#46679c` | Venue-Basis (gleich!) |
| --tag-venue-ink | `#33567e` | `#a8c6e8` | Venue-Text |
| --tag-publisher | `#9779c9` | `#9779c9` | Verlag-Basis |
| --tag-publisher-ink | `#5b4487` | `#c3aee7` | |
| --tag-oa | `#7cab54` | `#7cab54` | Open Access |
| --tag-oa-ink | `#44652b` | `#b4d698` | |
| --tag-paywall | `#dd8a3e` | `#dd8a3e` | Paywall |
| --tag-paywall-ink | `#8a5217` | `#edb787` | |
| --fig-bg | `#f5f5f6` | `#ececee` | Abbildungs-Hintergrund (immer hell!) |
| --fig-bg-pop | `#fdfdfd` | `#fdfdfd` | Lightbox-Bildgrund |
| --wissen | `#3f5d8c` | `#8ba7d6` | „Wissen"-Marineblau |
| --wissen-ink | `#38537d` | `#9db5de` | |
| --wissen-soft | `#e8edf5` | `#232a3a` | |
| --wissen-line | `#c2cfe3` | `#3e4c68` | |
| --grid | `#dbd7cc` | `#403a30` | Chart-Gitter |
| --baseline | `#8a8990` | `#938d80` | Chart-Basislinie |
| --warning | `var(--warn)` | (erbt) | Alias |
| --critical | `var(--bad)` | (erbt) | Alias |
| --magic-top | `#f0591a` | `#f2621f` | Magic-CTA oben |
| --magic-bottom | `#d84408` | `#dd4a0c` | Magic-CTA unten |
| --magic-edge | `#a33305` | `#8f2e04` | Magic dunkle Kante |
| --magic-c | `#fb8340` | `#fc8c48` | Magic Fokus-Farbe |
| --magic-glow | `rgba(247,106,32,.40)` | `rgba(250,115,45,.50)` | |
| --magic-grad | `linear-gradient(180deg, var(--magic-top) 0%, var(--magic-bottom) 100%)` | (erbt) | |

Legacy-Aliase (theme.css:120–124): `--bg-0`=--bg, `--bg-1`=--surface-2, `--ink-1`=--ink, `--ink-3`=--muted, `--ok`=--good.
`color-scheme: light` bzw. `dark` (theme.css:154, 238).

### 5.3 Radii, Schatten, Maße (theme.css:126–135)
| Token | Light | Dark |
|---|---|---|
| --radius | 8px | = |
| --radius-sm | 6px | = |
| --radius-xs | 4px | = |
| --radius-lg | 11px | = |
| --shadow-1 | `0 1px 2px rgb(22 23 27/.05)` | `0 1px 2px rgb(0 0 0/.35)` |
| --shadow-2 | `0 1px 3px rgb(22 23 27/.07), 0 8px 24px rgb(22 23 27/.07)` | `0 1px 3px rgb(0 0 0/.4), 0 8px 24px rgb(0 0 0/.3)` |
| --shadow-pop | `0 4px 12px rgb(14 15 19/.12), 0 20px 48px rgb(14 15 19/.16)` | `0 4px 12px rgb(0 0 0/.5), 0 20px 48px rgb(0 0 0/.5)` |
| --topbar-h | 56px | = |

Konvention (theme.css:126): „Eckiger = strukturell — Pills (999px) bleiben Pills."

### 5.4 Fluid-Tokens: Abstände & Typo-Leiter (theme.css:136–152)
- `--space-1..4`: 4 / 8 / 12 / 16px; `--space-5: clamp(18px, 1.5vw + 9px, 26px)`; `--space-6: clamp(26px, 2.3vw + 13px, 40px)`
- `--fs-body: clamp(15px, .3vw + 14px, 16px)`; `--fs-small: 13.5px`; `--fs-lesen: clamp(16px, .4vw + 14.8px, 17.5px)`
- `--fs-h1: clamp(23px, 1vw + 19px, 28px)`; `--fs-h2: clamp(18.5px, .5vw + 17px, 21px)`
- Skala: `--fs-2xs:12px · --fs-xs:13px · --fs-sm:14px · --fs-md:15px · --fs-lg:16px · --fs-xl:18px · --fs-2xl:21px`; `--fs-h3:18px; --fs-h4:16px`
- `--tracking-eyebrow: .09em`; `--lh-tight:1.28; --lh-ui:1.55; --lh-read:1.72`
- **12px ist der Boden für bedeutungstragenden Text** (theme.css:148).

### 5.5 Basis-Typografie (theme.css:276–303)
- body: `--font-ui`, `--fs-body` (Fallback 15.5px), `line-height:1.62`, antialiased.
- h1/h2: `--font-display` 700, `line-height:1.22`, `letter-spacing:-0.015em`; h3/h4: `--font-ui` 600, lh 1.25, ls −0.012em. h1 27px / h2 20px / h3 18px / h4 16px (Fallbacks).
- blockquote: `--font-serif`. a: `--accent-ink`, kein Underline (Hover: underline, offset 3px). code: Mono .9em, `background:var(--surface-3)`, radius 4px, `padding:1px 4.5px`.
- `::selection: color-mix(in srgb, var(--accent) 22%, transparent)`.
- Scrollbars: `scrollbar-width:thin`, WebKit 8px, Thumb `--border-strong` rund.
- `html { scroll-behavior:smooth; scrollbar-gutter:stable }`.

### 5.6 Hardcodierte Farben außerhalb der Tokens (wichtig!)
| Wert | Ort | Verwendung |
|---|---|---|
| `#fff` | app.css:913 | PDF-Seite (immer weiß) |
| `rgba(255,193,7,.6)` + Outline `#e8a800` | app.css:936–937 | Suchtreffer im PDF (`.pe-found`) |
| `#e8c33f` | app.css:1310 | Default-Quelltext-Highlight `--stc` |
| `#efe9dd` | app.css:1685, 1780, 1859 | Magic-Button-Textfarbe |
| `#ffeeda` / `rgba(30,8,2,.34)` / `rgba(0,0,0,.3)` / `rgba(255,255,255,.22)` | app.css:1792–1794 | Preis-Slot im Magic-Button |
| `#fff4e6` / `rgba(30,8,2,.5)` | app.css:1808 | Preis-Slot „live" |
| `#2e7d32` (BG) + `#fff` (Stroke) | app.css:1815, 1818 | ✓-Check-Finale Magic |
| `#6b625c → #453f3a` (linear-gradient 103deg) | app.css:1701 | Magic busy (ai-magic) |
| `#cf6a45` / Kante `#94441f` | app.css:1925 | Brand-Block „Claude" |
| `#10a37f` / Kante `#0a6b53` | app.css:1926 | Brand-Block „OpenAI" |
| `#9df3a1` | app.css:1930 | Brand-Punkt „verbunden" |
| `#ffd166` | app.css:1931 | Brand-Punkt „Demo" |
| `#f1ebe2` | app.css:1921 | Brand-Block Text |
| `#120c07` (44% mix) | app.css:2013 | Enhance-Backdrop |
| Enhance-Kopf: `rgba(214,96,40,.5)`, `rgba(240,145,72,.3)`, `rgba(138,47,29,.34)`, `linear-gradient(165deg,#2a160d,#180d08)`, Topline `rgba(255,214,170,.45)` | app.css:2031–2037 | mehrschichtige Radial-Glut |
| `#9fd48a` / `#f0b45c` | app.css:2053–2054 | enh-status Punkte on/demo |
| `rgba(255,255,255,.13/.15/.2/.24/.28/.45/.5)` | app.css:2040–2052, 1929 | weiße Overlays auf dunklem Kopf |
| `rgba(10,8,22,.55)` | app.css:2021 | enh-panel Schattenwurf `-26px 0 64px -22px` |

### 5.7 Icon-Zeichen in CSS-`content`
- `'▸'` — Akkordeon-Carets (app.css:783, 823)
- `'\0302'` — kombinierender Zirkumflex für `.mhat` (app.css:1470)
- `'→'` — Vektorpfeil `.mvec::before` (app.css:1472)
- Text-Banner: `'VORSCHAU — UNBESTÄTIGT · NICHT ÜBERNOMMEN'` (app.css:1279, `.ai-preview.unconfirmed::before`, 700 10px Display, letter-spacing .08em, warn-soft/warn) — **einziger deutscher UI-Text direkt in CSS**.
- In Kommentaren referenzierte Symbole (Markup kommt aus JS): ⌘K, ☰, ▣, ⇤, ⇥, ⌖, ❝, 📚, ✎, ▾, ×, ⚡, 🤖, ⧉, ⭱, ⓘ, ⚙, ⭳, ↗, Σ, ⎇, 🗂, 🔬, 📓, 🗄, ✦, ◘, 🔑, ⤳, ↺, ▤.

### 5.8 Komponenten-Rohwerte (Auswahl der Kernbausteine)
- `.card` (theme.css:306): surface, border, radius 8, `padding: var(--space-4) var(--space-5)`, shadow-1; `.flat` ohne Schatten. `.well`: surface-2, radius-sm, `padding:11px 13px`.
- `.eyebrow` (theme.css:316): `600 12px/1.3 Display`, uppercase, tracking .09em, muted.
- `.btn` (theme.css:325): inline-flex gap 6px, `500 14px/1 UI`, surface, `border:1px solid var(--border-strong)`, radius-sm, `padding:7.5px 13px`; Hover surface-2 + `border-color: color-mix(in srgb, var(--ink) 26%, transparent)`; Active surface-3. `.btn-primary`: accent-Füllung, 600. `.btn-ghost`: transparent, ink-2. `.btn-sm`: `5px 10px`, 13px, radius-xs. `[disabled]`: opacity .45.
- Kontext-Abschwächung: In Beleg-/QS-Zeilen ist `.btn-primary` accent-soft statt gefüllt (app.css:121–124); in `.lib-tools` nur Outline (app.css:125–126).
- `.chip` (theme.css:347): Pill 999px, `500 12px/1`, surface-3, `padding:4px 9.5px`; Varianten `.ok/.warn/.bad` (Farb+Soft), `.ki` (transparent + Border), `.accent`. `.chip.mini`: 10.5px, `2px 6.5px` (app.css:87).
- `.lvl-badge` (theme.css:365): Pill, `600 11px/1`, `padding:3.5px 8.5px`; `.l1/.l2/.l3` mit lvl-Farben. `.lvl-dot`: 7×7px rund; `.l0`: transparent mit `inset 0 0 0 1.5px var(--border-strong)`.
- `.fn-chip` (theme.css:381): Mono `600 10.5px/1`, surface-2, radius 6px, `padding:2px 5.5px`, `vertical-align:2px`; Status-Punkt `.fnl` 6×6px; `.mini`: nackt, 10px, accent-ink, Punkt 5×5px.
- `mark.hl` (theme.css:418): `background: color-mix(in srgb, var(--c) 9%, transparent)`, `border-bottom:2px solid color-mix(… 55%)`, radius `2px 2px 0 0`; Hover 18%; `.lit`: 26% + volle Farbe + 600. `.mk-src` (theme.css:438): `border-bottom:1.5px dotted color-mix(in srgb, var(--cat-norm) 65%,…)`; `.lit`: 20% Wash + 2px solid + Textfarbe `color-mix(72%, var(--ink))` + 600. `.fastread-on/.fastread`: alle Marks voll (24%/16%, theme.css:456–466).
- Formulare (theme.css:469): `500 14px/1.5 UI`, surface, border-strong, radius-sm, `padding:7px 10px`; Focus: `border-color:var(--accent); box-shadow:0 0 0 3px color-mix(in srgb, var(--accent) 14%, transparent)`. textarea min-height 74px. label 13.5px ink-2.
- `.notice` (theme.css:484): surface-2, `border-left:3px solid var(--warn)`, 13.5px; `.info`→accent, `.ki`→ki.
- `.tbl` (theme.css:497): th `600 11px/1.3 Display` uppercase ls .08em muted, `border-bottom:1px solid var(--border-strong)`; td `8px 10px`; Zeilen-Hover surface-2. `.tbl-wrap { overflow-x:auto }`.
- `.md` (theme.css:550): 15px/1.72, max 76ch; h2 17.5 / h3 16 / h4 15px; blockquote mit `border-left:3px solid var(--accent-line)`.
- `.lvl-bar` (theme.css:560): 5px hoch, Pill, Segmente p1/p2/p3 in lvl-Farben, min-width 60px.
- `kbd` (theme.css:576): Mono `600 10.5px/1`, surface-2, border-strong, `border-bottom-width:2px`, radius 4px.
- `.stat` (app.css:104): Wert `.v` `600 22px/1.1 Display`, `tabular-nums`; Label 11.5px muted.
- `.stag` (app.css:1401): Pill `600 11.5px/1.35`, `padding:4.5px 10px`, umbruchfähig (`white-space:normal; overflow-wrap:anywhere`); Farbrezept: `background: color-mix(in srgb, var(--tag-X) 13–15%, transparent); color: var(--tag-X-ink); border-color: color-mix(… 38–40%)`; `.problem` warn, `.status` neutral, `.link` accent klickbar.
- Magic-CTA `.magic-main` (app.css:1774): `500 13px/1 'Baloo 2'`, Text `#efe9dd`, `background:var(--magic-top)`, `border:2px solid var(--magic-edge)`, radius 6px, `padding:6px 11px`, min-width 121px, **harter Sockel-Schatten `box-shadow:0 3px 0 var(--magic-edge)`** (0 Blur); Active: `translateY(3px)` + Schatten 0 („Block wird gedrückt"). `.magic-top` (Hub-Knopf, app.css:1855): identische Signatur, 13.5px, `padding:7px 12px`. `.ai-magic` (Dialog-Variante, app.css:1682): min-height 54px, `padding:10px 18px`, Hauptlabel `500 15.5px/1.15 Baloo 2`, Sub Mono 11.5px. `.unset`: `filter:grayscale(.55) saturate(.55) brightness(.97)`.
- `.gp-tool` (app.css:1909): gleicher Block-Stil neutral (`border:2px solid var(--border-strong); box-shadow:0 2px 0 var(--border-strong)`).

### 5.9 „Wissen"-Farbwelt (app.css:1235–1243, 806–807)
- `.mainnav a.nav-wissen`: Farbe `--wissen-ink` (auch `.active`).
- `.wissen-chip`: `background:var(--wissen-soft); color:var(--wissen-ink); border:1px solid var(--wissen-line)`.
- `.wissen-head h1 { color:var(--wissen-ink) }`.
- `.wissen-page .a-tabs a.active`: wissen-ink/-Border/-soft. `.wissen-page .eyebrow`: wissen-ink. `.wissen-page .card { border-top:2px solid var(--wissen-line) }`. `.wissen-page .a-tabgroup-l`: wissen-ink.
- Analysemodus-Erklärboxen `.amod-exp` (app.css:1250): `border-left:3px solid var(--wissen); background:var(--wissen-soft)`; `.amod-lens .btn.on` in Wissen-Tönung.

---

## 6. Verhalten & Interaktionen

### 6.1 Transitions/Animationen — vollständige Liste
| Name | Def. | Wert | Einsatz |
|---|---|---|---|
| fadeIn | theme.css:533 | `from{opacity:0}` · .12–.14s ease | modal-back, cmdk-back, lightbox, refmode |
| popIn | theme.css:534 | `from{opacity:0; transform:translateY(6px) scale(.99)}` | modal `.14s cubic-bezier(.2,.9,.3,1.1)`, cmdk `.15s cubic-bezier(.2,.9,.3,1.15)`, farbpop `.12s ease` |
| jump-fade | app.css:1395 | Outline accent → transparent, 2.2s forwards (0–55% voll) | `.para-card.jump-flash` (Sprung-Anker) |
| gateshake | app.css:1650 | translateX ±7px, .3s | Passwort falsch |
| mmCook | app.css:1804 | brightness 1↔1.09, 1.2s infinite | Magic-Button „busy" |
| mmCheckIn | app.css:1822 | scale .6→1 + fade, `.24s cubic-bezier(.34,1.56,.64,1)` | ✓-Overlay |
| mmDraw | app.css:1823 | stroke-dashoffset 26→0, `.38s .14s ease` | ✓-SVG-Haken zeichnet sich |
| maIn | app.css:1841 | opacity 0→1, translateX(−5px)→0, .28s, Delay `calc(var(--i)*50ms + 40ms)` | Mini-Menü-Buttons gestaffelt |
| agpflow | app.css:1589 | translateX(4px), 1.3s linear infinite | gestrichelte Graph-Kanten „fließen" |
| cfBuzz | app.css:2118 | translateX ±1px + rotate ±4deg | (per JS zugewiesen) |
| enh-panel | app.css:2023 | `transform .42s cubic-bezier(.16,1,.3,1)` | Slide-in rechts |
| Standard-Hover | überall | `.1s–.12s ease` auf background/border-color/color/box-shadow | Buttons, Chips, Zeilen |
| Caret-Rotation | app.css:250, 783, 823, 1126 | `transform .13–.15s ease`, rotate(90deg) | Baum, Akkordeons, src-panel |
| farbdot Hover | app.css:574 | `transform:scale(1.12)` (.1s) | Farbpunkte; fp-sw scale(1.2) |
| im-tab Hover | app.css:2200–2202 | `translateY(-1.5px)`, `.14s cubic-bezier(.2,.9,.3,1.2)` | Typ-Tabs Konzept-Fenster |

`@media (prefers-reduced-motion: reduce)`: global alles auf .01ms (app.css:1320–1322) + gezielte Ausnahmen (jump-flash aus app.css:1396, agp-line aus 1590, magic/check/ma statisch 1848–1852, enh-panel ohne Transition 2116, im-tab 2225, ai-magic 1739–1741).

### 6.2 Interaktionsdetails
- **Drag-Resize horizontal**: 7px-Nähte zwischen Studio-Spalten, RefMode, Lib, Editor (`.pane-resize`); Hover färbt Streifen accent; JS schreibt `--file-w`/`--tree-w`/… **Vertikal**: `.sfd-resize` (Dock-Höhe bis 72%). Instanz-Fenster: unsichtbarer 10px-Griff `.ps-resize` auf der Naht.
- **Einklappen**: Spalten klappen an ihren Kanten zu (⇤/⇥ laut Kommentar app.css:327–328, 483); Rückweg über fixierte Rand-Leisten mit Vertikaltext.
- **Hover-Reveal**: `.tree-ren` (Umbenennen-✎) opacity 0→.7 bei Zeilen-Hover; Touch immer .55.
- **Magic-Button-Ablauf** (app.css:1772–1826): Idle → Hover `brightness(1.05)` → Active drückt in Sockel → `.busy`: Breite per JS eingefroren, mmCook-Pulsieren, Preis-Slot `.live` zählt Tokens → `.done` + `.mm-check`-Overlay (grün #2e7d32, Haken zeichnet sich). Klick im busy = Abbruch. `.unset` = ausgegraut, Preis-Slot unterstrichen als Einrichten-Link.
- **Doppelklick-Editing**: `.para-card.editing` / `.para-side.editing` — Ring `outline:2px color-mix(accent 45%/40%)` + Wash `color-mix(accent 6%, surface)`, `contenteditable` mit `caret-color:var(--accent)`, Hinweis-Pill `.edit-hint` oben rechts (app.css:1594–1622).
- **Fußnoten/Marks**: `mark.hl` Klick → `.lit` („angedrückt"); `.mk-src` Klick → `.lit` + öffnet Quelle; ⚡ Schnelllese-Overlay `.fastread` malt alles voll.
- **Erwähnungen** `.mention` (app.css:1354–1359): gepunktete KI-Unterstreichung; `.bestaetigt` solid good; `.merged` solid accent-line; `.lit` = KI-Wash 20% + 600.
- **Kategorie-Filter** `.pc-cat` (app.css:1362–1372): Chip mit Farbpunkt, `.off` = opacity .45, Punkt .3.
- **details/summary-Akkordeons**: `.ref-ctx`, `.libd-sec`, `.acc`, `.src-panel` — native Elemente, Marker versteckt, eigener ▸-Caret.
- **Fokus**: global `outline:2px solid var(--accent); outline-offset:2px` (app.css:1317); Magic: `3px color-mix(var(--magic-c) 60%, #fff)`. Skip-Link erscheint bei Fokus oben links (app.css:1318–1319).
- **Gate**: `html.gated` sperrt Scroll; Fehler → `.gate-card.shake` + `.gate-err` (12px bad, min-height 15px).
- **Lightbox**: Bild-Klick `cursor:zoom-in` → Overlay `cursor:zoom-out`.
- **PDF-Suche**: Treffer `.pe-found` gelb `rgba(255,193,7,.6)` + Outline `#e8a800`.
- **Fehler-/Statuszustände**: `.qs-row.dl-fail` (rote Leiste links + 4% Wash, app.css:135); `.ai-run/.enh-run` in `working`(ki)/`done`(good)/`err`(bad)/`demo`(ki-soft); `.enh-check.ok/.err`; `.ai-preview.unconfirmed` (gestrichelte warn-Outline + Banner); `.sp-file.missing` (gestrichelt) vs. `.has` (good-Wash, good-Eckmarker).

---

## 7. Datenformen

CSS trägt keine Datenstrukturen. Struktur-relevant sind die **Custom-Property-Verträge** (JS → CSS), z. B.:
```json
// Layout-State, den JS als Inline-Styles setzt (Persistenz siehe JS-Dossiers)
{
  "--file-w": "480px",     // Studio: Breite Quellen-Spalte (geklemmt auf ≤50vw)
  "--tree-w": "240px",     // Studio: Breite Kapitelbaum (geklemmt auf ≤26vw)
  "--ref-w": "360px",      // RefMode-Seitenspalte
  "--lib-list-w": "34%",   // Bibliothek Listen-Spalte
  "--ed-w": "1fr",         // Editor-Split
  "--sfd-h": "220px",      // Dock-Höhe (max 72%)
  "--ps-w": "300px",       // Instanz-Fenster-Breite (Default min(300px,34cqw))
  "--ps-accent": "#46679c",// Instanz-Tönung (freie Farbe)
  "--c": "var(--cat-frist)"// Mark-Kategoriefarbe je <mark class=hl>
}
```

---

## 8. Abhängigkeiten

- theme.css ← keine (lädt nur `../assets/fonts/*.woff2`).
- app.css ← baut auf allen Tokens aus theme.css auf; nutzt `fadeIn`/`popIn`-Keyframes aus theme.css.
- Konsumenten: **alle** JS-Module (Views rendern DOM mit diesen Klassen); pdf.js-Vendor (textLayer-Styles app.css:917–938 sind der App-eigene Ersatz für pdf.js-CSS).
- Browser-Features: `color-mix(in srgb, …)` (massiv, >60 Stellen), `@container`/`container-type`, `::highlight()` (Custom Highlight API), `:has()` (app.css:1484), `backdrop-filter`, `mix-blend-mode`, `writing-mode:vertical-rl`, `scrollbar-gutter`, `cqw`-Einheiten, `details/summary`.

---

## 9. Flutter-Hinweise

1. **Token-System**: Alle Tabellen aus §5.2–5.4 als `ThemeExtension<AppTokens>` mit `light()`/`dark()`-Fabriken abbilden; `lerp` für Theme-Wechsel. `--warning/--critical/--ok` etc. als Getter-Aliase.
2. **color-mix-Emulation**: `color-mix(in srgb, C X%, transparent)` ≙ `C.withOpacity(X/100)`; `color-mix(in srgb, A X%, B)` ≙ `Color.lerp(B, A, X/100)`. Am besten Extension `Color.mix(other, pct)` bereitstellen — wird überall gebraucht (Hover, Washes, Stags, Fokus-Ringe).
3. **Fonts**: Inter/Space Grotesk/JetBrains Mono/Nunito/Baloo 2 als Assets bündeln (woff2 → ttf konvertieren, Flutter unterstützt kein woff2 in `pubspec`). **`--font-serif` hat KEINE Datei** — auf iOS/macOS „Iowan Old Style"/Palatino vorhanden, sonst Fallback nötig (z. B. „PT Serif"/„Source Serif" bündeln oder Georgia-ähnliche Systemschrift).
4. **clamp()-Fluid-Typo**: kein CSS-clamp — via `MediaQuery.sizeOf(context).width` berechnen: `fsBody = (15 + 0.003*w).clamp(15,16)` usw.; als Funktionen im Token-Objekt.
5. **Sticky-Layout**: Topbar/Studio-Bar/Sticky-Spalten mit `CustomScrollView`+`SliverPersistentHeader` bzw. festem `Column`-Layout (Spalten sind eh viewport-hoch — in Flutter einfacher als echtes sticky: feste `Row` mit eigenem Scrolling je Spalte).
6. **Drag-Resize**: `GestureDetector`+`MouseRegion(cursor: SystemMouseCursors.resizeColumn/resizeRow)` auf 7px-Handles; Klemmen (50vw/26vw/72%) in Logik übernehmen; während Drag Animationen deaktivieren (Pendant zu `body.resizing`).
7. **Backdrop-Blur** (studio-bar 6px, modal 3px, cmdk 5px, lightbox 8px, enh 2px): `BackdropFilter(ImageFilter.blur)` — teuer, ggf. nur halbtransparente Fläche ohne Blur als Performance-Option.
8. **mix-blend-mode:multiply** der PDF-Highlights: `BlendMode.multiply` im Painter; Dark-Mode-Sonderfall (normal + opacity .55) exakt übernehmen — sonst „verbrennen" Highlights auf dunklen Scans nicht korrekt.
9. **Custom Highlight API** (`::highlight(beleg-span)` usw.) geht nicht 1:1 — in Flutter über `TextSpan`-Segmentierung mit Hintergrundfarbe lösen (Text muss ohnehin selbst gerendert werden).
10. **@container-Queries**: `LayoutBuilder` je Pane (content ≤940/≤880, ap ≥560, cqw-Einheiten → `constraints.maxWidth * x`).
11. **Magic-Block-Stil**: kein Standard-Material — eigener Button: `Container` mit `border: 2px solid magicEdge`, `boxShadow: [BoxShadow(offset: Offset(0,3), blurRadius: 0, color: magicEdge)]`; Pressed-State: Offset (0,0) + `Transform.translate(0,3)`. ✓-Finale: `CustomPaint`-Haken mit `TweenAnimationBuilder` (dashoffset). Busy-Puls: `AnimationController` 1.2s repeat auf Brightness (ColorFiltered/Overlay).
12. **grayscale/saturate/brightness-Filter** (`.unset`, Hover): `ColorFiltered` mit Sättigungs-Matrix bzw. vorab berechnete Farbvarianten (einfacher/performanter).
13. **details/summary-Akkordeons**: `ExpansionTile` mit eigenem ▸-Rotations-Icon (AnimatedRotation .13s).
14. **Scrollbars**: `ScrollbarTheme` — thickness 8, radius, Farbe borderStrong, nur bei Bedarf.
15. **Vertikaltext der Rand-Leisten**: `RotatedBox(quarterTurns: 1)`.
16. **::selection / caret-color**: `TextSelectionThemeData(selectionColor: accent.withOpacity(.22), cursorColor: accent)`.
17. **Print-Styles** entfallen; Export als eigenes PDF-Rendering (pdf-Package) mit den 11pt/20pt-Werten aus app.css:1999–2006 nachbauen.
18. **prefers-reduced-motion**: `MediaQuery.disableAnimations` respektieren (alle o.g. Animationen abschaltbar machen).
19. **Auto-Dark**: `ThemeMode.system` deckt `prefers-color-scheme` ab; explizites `data-theme` ≙ User-Override (ThemeMode.light/dark) — Persistenz siehe Theme-JS-Dossier.
20. **Eck-Marker-Konvention** (8×8/7×7px Quadrat oben links, accent/good): kleines `Positioned`-Quadrat im `Stack` je Panel — unbedingt beibehalten, ist Kern der visuellen Sprache (RUND=Status, ECKIG=Struktur).

---

## Anhang: vollständige Klassenliste je Datei (Kurzreferenz)

**theme.css:** card(.flat), well, eyebrow, page-sub, mut, small, btn(-primary,-ghost,-sm,[disabled]), chip(.ok,.warn,.bad,.ki,.accent), lvl-badge(.l1–l3), lvl-dot(.l0–l3), fn-chip(.lv0–lv3,.mini,.fnl,.fns), a.xref, mark.hl(.lit), mk-src(.lit), fastread(-on), input/select/textarea/label, notice(.info,.ki), tbl(-wrap), modal-back/modal(-h,-b), viz-tip, md, lvl-bar(.p1–p3), grid(-2,-3), row, spread, stack, loading, kbd.

**app.css:** topbar, brand(-badge,-text,-sub), mainnav(.nav-wissen), topbar-actions, ta-btn(.ta-ic,.ta-lb), theme-btn, work-switch(ws-*), footer, page-head, cmdk(-back,-list,-item,-empty,-hint), statgrid/stat, dash-cols, chaprow, qs-rows/qs-row(.ok,.dl-fail,.rich), pre.cmd, fig-card(.fig-img,.fig-cap), fig-missing, lightbox, studio(.file-off,.tree-off), pane-resize/tree-resize/file-resize, studio-content/-inner(.wide,.dock-on), studio-tree(st-bar,st-body,tree-ch,tc-caret,tn,tree-ren,tree-edit,tc-title,ts-title,prog), studio-bar(bar-tools,bar-mid), mode-switch, dichte-switch, dock-switch(inst-dot), ie-list/-row/-move/-fields/-label/-desc, studio-head, sec-head/-meta, lesen-doc(.kompakt)/-sec(.sn,.pg)/-p(.ff)/-inst(li-t,li-b)/lesen-list, kern-list, para-card(.open,.editing,.flash,.jump-flash)/para-body/para-text/ps-kern/para-hint/para-fig/para-list, resolution, belege, beleg(.sel; b-head,num,srcs,acts,claim,ki-line,fund-stelle,b-such,b-ment), studio-file, sf-bar(-lbl,sf-src), sf-iconbtn, sf-host(.no-view), sf-card, sf-view, sf-empty, file-rail/tree-rail(fr-ic,fr-tx), src-strip(ss-id,ss-title,ss-sub), sf-dock(.sized,.closed), sfd-resize, sfd-tabs, sfd-fn-slot, sf-fn, sfd-farb(-lbl), sfd-min, sfd-body(db-claim), farbctl, farbdot(.auto), farbpop(fp-sw(.on),fp-auto), pdf-embed, qd-pdfhost, pdf-drop, refmode(.side-hidden), ref-head/-body/-side/-main, ref-ctx, ref-src(.active), ref-item(.focus; ri-*), sw-chip(.all,.ok), mark.sw, ref-pdfbar/-pdfhost/-iframe/-law, prov-row, lib, lib-rail/-coll(.active)/-tools/-list/-listbar/-rows/-row(.active; ic,bd,ttl,sub,meta,pdfflag)/-detail/-empty, src-head(.compact; sh-title,sh-sub), libd-body, libd-sec(sec-b), cite-list/-row(cite-go), a-tabs, a-tabgroups/-tabgroup(-l), std-card/-grid/-krit(-h), punkt, finding-row, acc(acc-b), faden-step/-col/-n/-body, viz-note, editor-panes, editor-pane textarea.tex, tex-toolbar/-preview(pv-fn)/-lint, pj-row(.active)/pj-pick, qs-assign-host, pe, pe-bar(sep,pe-pagenum,pe-mode,pe-active,pe-grp,pe-zoom), pe-search(pe-q,pe-qinfo), pe-scroll/-stack/-page, textLayer(pe-found), pe-marks, pe-hl, pe-pin, mk-list/-row(mk-q), bcheck(.l3; bc-head,bc-ht,bc-count,bc-row(.ok,.miss),bc-l,bc-lic,bc-okm,bc-d,bc-in), bc-mark, bc-dot, sfd-ki(.l2,.l3), sfd-fnq, sfd-vermutet, br-vermutet, sfd-fnrow/-fnacts, span-ctl, sc-flag/-item, mark-chip, src-panel(sp-bar,sp-caret,sp-lbl,sp-sum,sp-sum-file,sp-body,sp-head,stags,sp-actions), sp-file(.missing,.has,.doc-link,.doc-image), spf-status, mat-switch(ms-tab(.on),ms-state), mat-webrow, ad-lbl/-opts/-opt(.sm; ad-ic,ad-t), sp-mat, mat-list/-row(mr-ic,mr-t)/-addrow, doc-link-a, doc-img, doc-view(.link,.image; dv-*), assign-inline(ai-actions,ai-dl,ai-dl-link,ai-dl-status), ai-candidate/-cand-head/-cand-acts/-preview(.unconfirmed)/-iframe/-ablage, wissen-chip/-head/-page, amod-doc/-p/-list/-exp(ae-t)/-kern/-k/-lens, works-pop, srctext(-bar,-setup), st-hl, skip-link, hilfe, flow(-step(.ki,.ok),-arr), hilfe-tab, mention(.bestaetigt,.merged,.lit), para-cats, pc-cat(.off; dot), mention-row(.offen,.verworfen,.bestaetigt; m-cand), stags, stag(.venue,.publisher,.oa,.paywall,.problem,.status,.link), nb-doc/-md/-chart/-legend/-leg/-table/-latex/-include/-pre/-img/-cell(-h,-out)/-lang/-code/-out/-show/-py/-math, mth(-block,-err), mfrac(mnum,mden), msqrt(mrad,msq-b), mbar, mhat, mvec, mbig(mb-op,mb-hi,mb-lo), mdelim, nb-edit-grid/-prev, para-row, para-side(.empty,.tinted,.editing,.graph; ps-h,ps-t,ps-chips,ps-b), ps-ib(.ps-x), ps-resize, inst-bar, ie-colors, ie-sw(.none,.pick,.sel), agp(agp-t,agp-l,agp-line(.in)), edit-hint, edit-badge, gate(-card(.shake),-logo,-err), pe-ocr(.on-page), inst-row(inst-md), ai-bar, ai-magic(.unset,.busy), aim-body/-main/-sub, ai-tools, ai-chip(.on), ai-prompt, ai-run(.working,.done,.err,.demo), ai-inlink, small.ok/.err, ai-cfg, cc-grid(.cc-full,.cc-check), cc-note, st-inbox, st-file(-name,-acts,st-sel), st-srclist, st-src(-dot(.on),-t,-sub,-tag), magic-dock(.compact), magic-main(.unset,.busy,.done; mm-lb,mm-price(.live)), mm-check, magic-acts(ma), magic-top, gpt-pop, gp-list/-grp(gg-ctx)/-row(.root,.child)/-ic/-tx/-n(.on)/-foot/-tool/-brand(.claude,.openai,.on,.demo; gb-dot)/-hint, stand-log, lg-row(.on)/-dot/-ic/-b/-n/-works/-work(.active), mat-textarea, ve-row(ve-tex,ve-dot,ve-name,ve-desc,ve-n,ve-re,ve-del), ve-list/-new, sf-srcbtn(sfb-*), sp-list/-group/-row(.cur; sp-ic,sp-t,sp-tag), doc-wrap/-actions, enh-back(.in)/-panel/-head/-htitle/-x/-status(.on,.demo)/-body/-nav(-group,-item(.active))/-main/-fhead/-fic/-ft/-fe/-actions/-act(.magic(.off))/-price/-answer/-run(.working,.done,.err,.demo)/-steps(es,es-a)/-view/-ref-sum/-ref-prev/-chips/-prev/-multi/-paket(ep-lb,ep-chip(.gt,.out),ep-arrow)/-check(.ok,.err)/-sys/-access, sys-flow/-node(.gt,.ki,.ok; sn-ic)/-link/-grid/-card(.cur; sc-h,sc-ic,sc-n), pm-ref/-foot, gt-note(gtn-ic), im-tabs/-tab(.on; it-ic)/-body/-pipe(ip(.gt,.ki,.ok),ip-a)/-desc/-int/-live/-cmp, acc-card(.active; ac-h,ac-form,ac-soon).
