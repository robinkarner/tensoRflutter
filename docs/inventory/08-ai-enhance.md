# Dossier 08 — KI-/GPT-Schicht: `js/enhance.js` (1019 Z.) + `js/claude.js` (237 Z.)

> Fokus: „GPT Magic"-Werkbank, Generate-GPT-Hub (Topbar), Magic-Dock, Instanz-System (Absatz-Views),
> Gesamtprompt (Voranalyse) + alle Antwort-Import-Formate (exakte Notation), 🖍 Markierungen,
> Claude-API-Anbindung (Endpunkte, Auth, Streaming, Kosten, Demo-Modus).
> Querbezüge (weil die Prompts/Instanz-Defs dort leben): `js/views_studio.js:2127-2522`, `js/views_projekt.js:437-563`, `js/views_quellen.js:686-710`, `js/util.js:721-908,919-924`, `tools/sensors_instanzen.js`.

---

## 1. Zweck & Rolle

### `js/enhance.js` — Objekt `Enhance` (window-global, enhance.js:26/1019)
Die zentrale KI-Werkbank der App. EIN Konzept: Jede KI-Funktion ist ein **„Datenpaket"** — definierte Eingaben → Prompt → Modell → Format-Checker → definierter Speicherort (Kommentar enhance.js:1-23). Ground Truth ist immer das LaTeX der Arbeit; KI-Ergebnisse sind Ebenen darüber (ersetzbar, entfernbar). Das Modul liefert vier UI-Oberflächen für dieselben 7 „Flows": (a) das rechts einfahrende **Werkbank-Panel** (`Enhance.open`, enhance.js:370), (b) den **Generate-GPT-Hub** als Topbar-Popover (`Enhance.hub`, enhance.js:657), (c) das kompakte **✦ Magic-Dock** als wiederverwendbares Bedien-Modul je Stelle (`Enhance.dock`, enhance.js:775), (d) drei zentrale Modals: ⭱ Einfüge-Fenster (`pasteModal`, enhance.js:887), ⓘ Konzept (`infoModal`, enhance.js:960), ⎇ Stand/Log (`standModal`, enhance.js:710). Dazu die komplette Import- und Format-Checker-Logik für alle Antwortformate (enhance.js:187-318).

### `js/claude.js` — Objekt `ClaudeAI` (window-global, claude.js:17/237)
Die „KI-Magie" hinter jedem ✦-Knopf: einheitlicher Browser-Client für die Anthropic Messages API. Reine Fetch-Integration ohne SDK (App ist statisch/serverlos). Verantwortlich für: Konfiguration (Key/Basis-URL/Modell/maxTokens/deepThink/demo), Zugangs-Status (`hasAccess`/`isDemo`/`ready`), Token-/Kosten-Schätzung (lokal + `count_tokens`-Endpunkt), **SSE-Streaming** des `/v1/messages`-Endpunkts mit Text-/Thinking-/Usage-Callbacks, ehrlicher **Demo-Modus** (simuliert Streaming Wort für Wort, importiert nie Daten), Fehler-Mapping (401/403/404/429/529) und `clean()` (entfernt umschließende ```-Codeblöcke vor dem Import).

---

## 2. Öffentliche API

### Exportiert (window-Scope)

| Symbol | Signatur | Zweck | Genutzt von |
|---|---|---|---|
| `window.Enhance` | Objekt | gesamte KI-Werkbank | `app.js:125` (Topbar-Hub), `views_projekt.js:221` (pasteModal für Quellen-Flow), `views_studio.js:2473` (`Enhance._importInst` beim View-Recompile) |
| `Enhance.accessInfo()` | `() → {mode:'extern'\|'space'\|'key'\|'demo', label, dot:'on'\|'off'\|'demo'}` | Zugangs-Status auf einen Blick (enhance.js:29-40). Labels wörtlich: `'nur ⧉ extern'`, `'AI-Space verbunden'`, `` `verbunden · ${model.label}` ``, `'Demo-Modus'` | Panel-Kopf, Hub-Footer, infoModal |
| `Enhance.cfg(id)` / `setCfg(id, patch)` | pro-Flow-Config `{model?, instruction?}` aus Store-Key `enhCfg` (enhance.js:42-47) | ⚙ je Stelle | `_show`, `dock`, `_cook` |
| `Enhance.prompt(flow)` | `flow → string`; `flow.build()` + optional `\n\nZUSÄTZLICHE ANWEISUNG:\n<instruction>` (enhance.js:50-54) | finaler Prompt je Stelle | überall |
| `Enhance.flows(ctx)` | `({sectionId?, srcId?}) → Flow[]` — die 7 Flow-Definitionen (enhance.js:60-185) | Datenquelle aller UIs | intern + Hub |
| `Enhance.open(ctx, activeId?)` | öffnet Werkbank-Panel rechts; `activeId` auch `'_system'`/`'_access'` (enhance.js:370-414) | Vollansicht | Hub „⧈ Werkbank", infoModal |
| `Enhance.close()` | Panel schließen + laufenden Claude-Run abbrechen (`_ctl.abort()`) (enhance.js:415-421) | | Esc, ✕, Backdrop |
| `Enhance.hubCtx()` | `() → {sectionId?, srcId?}` aus `location.hash` + `Studio` (enhance.js:649-656) | Kontext des Hubs | `hub` |
| `Enhance.hub(pop)` | rendert das Generate-GPT-Menü in ein gegebenes Popover-Element (enhance.js:657-704) | Topbar-Menü | `app.js:125` |
| `Enhance.dock(ctx, flowId, opts={compact?})` | `→ HTMLElement` `.magic-dock` — fixes Bedien-Modul `[✦ Aktion · Preis][⧉][⭱][ⓘ]` (enhance.js:775-813) | in Hub-Zeilen + an Stellen in Views | Hub (compact), Studio/Quellen-Views |
| `Enhance.pasteModal(ctx, flowId, opts)` | zentrales Einfüge-Fenster; `opts={prefill?, autocheck?, note?, onDone?}` (enhance.js:887-954) | Antwort einfügen/prüfen/übernehmen | Dock ⭱, Fehlerpfad von `_cook`, views_projekt.js:221 |
| `Enhance.infoModal(ctx, currentId)` | ⓘ Konzept-Modal mit Tabs je Typ + Vergleichstabelle (enhance.js:960-1016) | | Hub „ⓘ Konzept", Dock ⓘ |
| `Enhance.standModal()` | ⎇ Speicherstand-Log-Modal (enhance.js:710-763) | | Hub „⎇ Stand" |
| `Enhance._importMarks(text)` / `_importInst(text)` | Import-Kernlogik (enhance.js:188-213) | `_importInst` wird extern von `viewGenerate` (views_studio.js:2473) aufgerufen | |
| `Enhance._check(flow,text)` + `_checkMarks/_checkConn/_checkInst/_checkQuellen/_checkBuch/_checkJson` | Format-Checker `→ {ok, html}` (enhance.js:218-318) | ✓ Prüfen | |
| `window.ClaudeAI` | Objekt | API-Client (claude.js:237) | Enhance, `U._claudeCfgForm`, `U.gptModal`, `viewGenerate` |
| `ClaudeAI.DEFAULTS` | `{baseUrl:'https://api.anthropic.com', model:'claude-opus-4-8', maxTokens:6000, deepThink:false, demo:true}` (claude.js:20) | | |
| `ClaudeAI.MODELS` | Preisliste, s. §5 (claude.js:24-30) | | Selects in ⚙-Formularen |
| `ClaudeAI.cfg()` / `setCfg(patch)` | Config aus Store-Key `claudeCfg` (merge mit DEFAULTS) (claude.js:32-41) | | |
| `ClaudeAI.model(id?)` | Modell-Objekt (Fallback MODELS[0]) (claude.js:42) | | |
| `ClaudeAI.hasAccess()` | Key gesetzt ODER baseUrl ≠ Default (Proxy) (claude.js:45-48) | | |
| `ClaudeAI.isDemo()` / `ready()` | Demo = kein Zugang & `demo!==false`; ready = Zugang ∨ Demo (claude.js:52-55) | | |
| `ClaudeAI.estTokens(text)` | `ceil(len/3.7)` (claude.js:59) | lokale Schätzung | |
| `ClaudeAI.estOutTokens(inTok)` | `min(4000, max(500, round(inTok*0.5)))` (claude.js:61) | | |
| `ClaudeAI.costOf(inTok,outTok,modelId)` | `(in/1e6)*m.in + (out/1e6)*m.out` (claude.js:62-65) | | |
| `ClaudeAI.fmtUsd(v)` | `<0.1→4 Dez., <1→3 Dez., sonst 2`; `'–'` bei null (claude.js:66-71) | | |
| `ClaudeAI.fmtTok(n)` | `≥1000 → 'x.xk'` (≥10000 ohne Dez.) (claude.js:72) | | |
| `ClaudeAI.fmtEur(v)` | `<0.005→'<0.01 €'`, sonst `'x.xx €'` (claude.js:74-78) | Magic-Knöpfe | |
| `ClaudeAI.estimate(prompt, modelId?)` | `→ {inTok,outTok,cost,model}` (claude.js:81-85) | | |
| `ClaudeAI.countTokens(prompt, modelId?)` | async, POST `/v1/messages/count_tokens` → `input_tokens` oder `null` (claude.js:105-116) | Verfeinerung der Preisanzeige | enhance.js:497-505 |
| `ClaudeAI.run(prompt, {onText,onThink,onUsage,signal})` | async Streaming-Kern `→ {text, usage:{input,output}, cost, demo?}` (claude.js:121-182) | | `_cook`, `gptModal`, `viewGenerate` |
| `ClaudeAI.clean(text)` | ```-Codeblock-Entferner (claude.js:226-234) | vor jedem Import | |

### Konsumierte fremde Globals (durch enhance.js)
`U` (storeGet/storeSet/esc/md/el/copy/download/modal/closeModal/claudeConfigModal/_claudeCfgForm/srcShort/setResolution/getResolutions), `ClaudeAI`, `Editor.fullDocument()` (enhance.js:71), `Notebook.prompt()/set()` (enhance.js:86-87), `Connections.regeneratePrompt()/importKi()/all()` (enhance.js:120-125), `Studio` (`.styleCheck`, `.sectionId`, `.file.srcId`), `Projects` (`.activeId`, `.DEFAULT`, `.get`), `renderAnalyse` (enhance.js:90), `routeRefresh`, `orderedUnits`, `UNIT_INDEX`, `CAT_LABELS`, `sectionSources`, `masterPrompt`, `marksPromptFor`, `instanzPrompt`, `gptPromptForSource`, `dockDefs`, `dockSet`, `importAnalysenModal`, Daten-Globals `window.DATA_SECTIONS / DATA_SOURCES / DATA_META / DATA_THESIS / PROJECT_ERKLAERBUCH / PROJECT_INSTANZEN / BUILTIN_PROJECTS`, `navigator.vibrate`.

---

## 3. State & Persistenz

Alle Keys via `U.storeGet/storeSet` → localStorage mit Präfix `ehds.` bzw. `ehds.<projektId>.` wenn der Key in `U.PROJECT_KEYS` steht (util.js:200-211). **Wichtig:** `claudeCfg`, `enhCfg` und `instDefs` sind NICHT projekt-gescoped (global über alle Arbeiten); `marksExtra`, `paraDock`, `kiConnections`, `notebook`, `belegLevels`, `dockBySection`, `resolutions`, `srcExtras` SIND projekt-gescoped.

| localStorage-Key (effektiv) | Form (reales Beispiel) | gelesen / geschrieben |
|---|---|---|
| `ehds.claudeCfg` | `{"baseUrl":"https://api.anthropic.com","model":"claude-opus-4-8","maxTokens":6000,"deepThink":false,"demo":true,"apiKey":"sk-ant-…"}` | R: `ClaudeAI.cfg()` überall; W: `setCfg` aus `U._claudeCfgForm` (util.js:743-751) und temporär in `_cook` (Modell-Override, enhance.js:827/879). **API-Key liegt im Klartext im localStorage!** |
| `ehds.enhCfg` | `{"marks":{"model":"claude-haiku-4-5","instruction":"nur die wichtigsten 3 pro Absatz"}}` | R: `Enhance.cfg` (enhance.js:42); W: ⚙-Formular (`_wireCfg`, enhance.js:637-641) |
| `ehds.<proj>.marksExtra` | `{"3.2.1-p1":[{"snippet":"binnen 24 Monaten","kategorie":"frist"}]}` | R: `stat()`/`_refMarks`/`paraMarks` (views_studio.js:684); W: `_importMarks` (enhance.js:198) — **ersetzt je Absatz komplett** |
| `ehds.<proj>.paraDock` | `{"erklaerung":{"3.2.1-p1":"Der Absatz erklärt …"},"sensorblick":{"1.1-p1":"🟦 …"}}` | R: `dockGet`/`stat`/`_refInst`/`standModal`; W: `dockSet(instId,pid,md)` via `_importInst` (enhance.js:207) und Inline-Edit (views_studio.js:2278) |
| `ehds.instDefs` | `[{"id":"kritik","label":"Kritik","desc":"Je Absatz eine kritische Rückfrage","color":"","srcTex":""}]` | R: `dockDefs()` (views_studio.js:2149); W: `instanzEditModal` `save` (views_studio.js:2390); `null` = Reset auf Default |
| `ehds.<proj>.kiConnections` | `{"connections":[{"id":"c1","typ":"folgerung","von":{"sectionId":"5.3.3","paraId":"5.3.3-p2"},"nach":{"sectionId":"6.0","paraId":"6.0-p5"},"label":"…","text":"…"}]}` | R: `_refAll`/`_refConn`/`standModal`; W: `Connections.importKi` (Flow `conn.run`) |
| `ehds.<proj>.notebook` | Markdown-String `"# Erklärbuch …"` | R: `stat`/`_refBuch`/`standModal`; W: `Notebook.set` (Flow `buch.run`) |
| `ehds.<proj>.resolutions` | `{"cobrado2024":{"formatVersion":"1.0","sourceId":"cobrado2024","generatedBy":"gpt","stellen":[{"footnote":12,"seite":4,"zitat":"…","status":"bestaetigt","kommentar":"…"}]}}` | R: `U.getResolutions` (Flow `quellen`); W: `U.setResolution(r)` (enhance.js:162) |
| `ehds.<proj>.belegLevels` | `{"12":{"seite":4,"zitat":"…","stufe":"belegt"}}` | R: nur `standModal` (enhance.js:724) |
| `ehds.uiStyleCheck` | `true/false` | W: Stil-Check-Toggle (enhance.js:451) |
| `ehds.<proj>.dockBySection` / `ehds.uiDockMode` | `{"3.2":"erklaerung"}` / `"connections"` | Instanz-Auswahl (views_studio.js:2177-2179, 669-676) |
| `ehds.uiPsW` | `312` (px) | Drag-Resize der Instanz-Fenster (views_studio.js:2227) |
| `ehds.<proj>.srcExtras` | `{"cobrado2024":[{"kind":"tex","name":"LaTeX","text":"\\section…"}]}` | R: `texMaterials()` für Σ-Verknüpfung (views_studio.js:2351-2358) |

In-Memory: `Enhance._ctl` (aktueller AbortController, enhance.js:369), `Studio.styleCheck`, `Studio.dock`, DOM-Zustand der Panels. `ClaudeAI` hält keinen In-Memory-State (Config immer frisch aus Store).

---

## 4. UI-Struktur & Layout

### 4.1 Topbar-Knopf + Generate-GPT-Hub (Popover)
- Topbar: `<button class="magic-top" id="gptBtn">` mit Label **„Generate GPT"** (index.html:36); Popover-Container `<div id="gptPop" class="gpt-pop" hidden>` (index.html:47). `app.js:120-138`: Klick toggelt, `Enhance.hub(gptPop)` rendert, Position `left = gptBtn.offsetLeft`, wird bei Überstand rechts eingerückt; Klick außerhalb und `hashchange` schließen.
- Hub-DOM (enhance.js:663-703):
```
.gp-list
  .gp-grp  "Ganze Arbeit"
  .gp-row.root   (⚡ Voranalyse)   → .gp-ic | .gp-tx>b+small | .gp-n[.on] | <magic-dock compact>
  .gp-row.child  (⤳ Connections)
  .gp-row.child  (🎛 Instanzen)
  .gp-row        (📓 Erklärbuch)
  .gp-grp  "Im Studio-Kontext" + .gg-ctx (z.B. "Abschnitt 3.2 · Cobrado 2024"
           oder Fallback "im Studio öffnen — Abschnitt & Quelle")
  .gp-row        (🖍 Markierungen)
  .gp-row        (📚 Quellen-Durchlauf)
.gp-foot
  .gp-tool[data-gp=konzept] "ⓘ Konzept" · [bench] "⧈ Werkbank" · [stand] "⎇ Stand"
  <flex-spacer>
  .gp-brand.claude.(on|off|demo) "Claude" (mit <i class="gb-dot">)
  .gp-brand.openai "OpenAI"
```
Hierarchie-Klassen `root`/`child` visualisieren: ⚡ Voranalyse ist Wurzel, ⤳/🎛 schärfen nach (Kommentar enhance.js:674-675). Jede Zeile enthält ein kompaktes Magic-Dock. Der `stat()`-Badge (`.gp-n`) bekommt `.on` wenn `statOn()`.

### 4.2 Werkbank-Panel (rechts einfahrend)
Mount in `#enhRoot` (index.html:55). DOM (enhance.js:376-386):
```
.enh-back                                ← Backdrop (mousedown auf Backdrop = close)
  aside.enh-panel[role=dialog][aria-modal=true][aria-label="GPT Magic — KI-Werkbank"]
    .enh-head
      .enh-htitle  "GPT Magic" + <small>"KI-Werkbank · LaTeX ist Ground Truth"</small>
      button.enh-status.(on|off|demo)[data-goto=_access]  <i></i> + accessInfo().label
      button.enh-x "✕"
    .enh-body
      nav.enh-nav                        ← linke Navigation
      section.enh-main                   ← Inhalt
```
- Einfahren: `requestAnimationFrame(() => back.classList.add('in'))` (enhance.js:413) — CSS-Transition.
- Nav gruppiert nach Scope: `.enh-nav-group` „Ganze Arbeit" / „Dieser Abschnitt", je Flow `button.enh-nav-item[data-id]` mit `.enh-ni-ic` (Icon) + `.enh-ni-t` (Titel), `style="--i:.02s"` (Stagger-Var); darunter Gruppe „System" mit `⧈ Datenflüsse` (`_system`) und `🔑 Zugang` (`_access`) (enhance.js:392-398).
- Escape schließt NUR, wenn `#modalRoot` leer ist (kein Modal darüber, enhance.js:423).

### 4.3 Flow-Ansicht im Panel (`_show`, enhance.js:443-544)
```
.enh-fhead   → .enh-fic (Icon) | .enh-ft (Titel + span.chip.mini Scope) | .enh-fe ("erzeugt: …")
.enh-paket   → "Paket"-Strip: span.ep-lb + ep-chip[.gt bei LaTeX-Eingabe] … → ep-arrow "→" →
               ep-chip "GPT / Claude" (bzw. "Heuristik (lokal)") → ep-chip out → ep-chip.out Ziel
.enh-actions → .enh-act "⧉ Kopieren" | .enh-act.magic[.off] "Mit Claude" + span.enh-price
               | .enh-act "ⓘ Info" | .enh-act "⚙"
.enh-steps   (nur ohne Zugang, nicht multi): 3 Schritte mit <i>1</i>…"⧉ kopieren" → "extern
               ausführen (ChatGPT/Claude/…)" → "einfügen · ✓ prüfen · ⭱ übernehmen"
#enhRun.enh-run[hidden] · #enhCheck.enh-check[hidden] · #enhCfg.enh-view[hidden]
textarea.enh-answer#enhAns[placeholder=flow.placeholder]
.row → btn "✓ Prüfen" | btn-primary "⭱ Übernehmen" | label.btn "Datei laden"+input[file,
       accept=".json,.md,.txt,application/json"] | span#enhMsg
```
Multi-Flow (`all`): statt Textarea `.enh-multi` mit Hinweis + `#enhMulti` „⭱ Analysen importieren (mehrere Dateien)" (enhance.js:484-486). Toggle-Flow (`style`): nur Referenz + `#enhToggle` („Stil-Check einschalten/ausschalten") + `ⓘ Wie funktioniert das?` (enhance.js:445-453).
Preis-Label: zunächst `≈ $… · <Modell>` aus lokaler Schätzung; bei echtem Zugang ersetzt `countTokens` still das Label durch `"<n>k Tok · ≈ $… · <Modell>"` (enhance.js:497-505).

### 4.4 ⧈ System-Ansicht (`_showSystem`, enhance.js:548-580)
`.enh-sys` mit `.sys-flow` (vertikale Kette): `.sys-node.gt` (Σ Ground Truth) → `.sys-link` (Text) → `.sys-node` (⧉ Prompt je Datenpaket) → `.sys-link` → `.sys-node.ki` (◆ Modell) → `.sys-link` („✓ Format-Checker prüft VOR dem Übernehmen") → `.sys-node.ok` (⭱ Import). Darunter `.sys-grid` aus klickbaren `.sys-card`-Buttons (Icon+Titel+`sc-n`-Stat + `<small>` „in → ziel"), Klick öffnet den Flow.

### 4.5 🔑 Zugang-Ansicht (`_showAccess`, enhance.js:584-610)
`.enh-access` mit 3 `.acc-card` (aktive per `.active`): „⧉ Extern kopieren" (`chip mini` **gratis**, ggf. `chip ok mini` **aktiv nutzbar**), „🔑 Eigener Claude-Zugang" (chip **verbunden**; enthält `#accForm` → `U._claudeCfgForm`), „☁ Thesis-Studio AI-Space" (`span.ac-soon` **„in Vorbereitung"**/**„verbunden"**, `chip mini` **„≈ 1 € / Durchlauf"**).

### 4.6 ✦ Magic-Dock (enhance.js:775-813)
```
.magic-dock[.compact][role=group]
  button.magic-main[.unset wenn kein Zugang]  → .mm-lb (flow.aktion) + .mm-price
  span.magic-acts → button.ma "⧉" (--i:0) | "⭱" (--i:1) | "ⓘ" (--i:2)
```
Preis auf dem Hauptknopf: `ClaudeAI.fmtEur(est.cost)` („0.33 €"), ohne Zugang **„einrichten →"**. Während des Kochens (`_cook`): Breite eingefroren (`main.style.width = px`), `.busy`, `.mm-price.live` zählt `"<n> Tok"`; am Ende `.done` + eingespielter `span.mm-check` mit Inline-SVG-Haken `<svg viewBox="0 0 24 24"><path d="M4.5 12.8 9.5 17.8 19.5 6.8"/></svg>` (enhance.js:830-839).

### 4.7 Modals (alle über `U.modal` in `#modalRoot`)
- **⭱ pasteModal** (enhance.js:891-916): optional `.notice.info.small` (note) → `.pm-ref` („Aktueller Speicherstand dieser Stelle" + `flow.reference()`) → Eyebrow „Externe GPT-Antwort einfügen" → `#pmAns.enh-answer` → `#pmCheck.enh-check` (auto) → Buttons „⭱ Übernehmen" / „Datei laden" / `#pmMsg` → Fußzeile `.pm-foot` mit `#pmSys` „⧈ Alle Stellen &amp; Datenflüsse" + Hinweis „Format-Checker läuft automatisch beim Einfügen". Multi-Variante: readonly-Textarea der gekochten Antwort + „⧉ Antwort kopieren" / „⭳ Antwort speichern (.txt)" (Download `voranalyse-antwort.txt`) + „⧉ Gesamt-Prompt kopieren (inkl. LaTeX)" + „⭱ Analysen importieren (mehrere Dateien)".
- **ⓘ infoModal** (enhance.js:964-1015): `.gt-note` (Σ „Der Originaltext wird nie angegriffen. …") → `.im-tabs[role=tablist]` (je Flow `.im-tab[.on]` mit `.it-ic`+aktion) → `#imBody` mit `.im-pipe` (Basis → „GPT / Claude" → out → ziel als `.ip[.gt|.ki|.ok]`-Chips), `.im-desc`, `.im-int` (`chip warn mini` „beim erneuten Lauf" + `flow.wieder`), `.im-live` (Stand + „⧉ Prompt kopieren" + „⭱ Einfüge-Fenster") → Vergleichstabelle `.tbl.im-cmp` (Spalten: Typ / Textbasis / erzeugt / landet in; aktive Zeile `.cur`) → Fuß: „🔑 Zugang" (+Label-Chip) und „⧈ Werkbank öffnen".
- **⎇ standModal** (enhance.js:752-761): `.stand-log` aus `.lg-row[.on]` (lg-dot, lg-ic, lg-b mit `<b>Titel</b><small>Format · <code>Ort</code></small>`, lg-n Zähler, `chip mini[.ok]` Herkunft „mitgeliefert/importiert/von Hand/beide/auto/abgeleitet + Daten") → `.lg-works` mit 2 `.lg-work[.active]`-Karten (EHDS-Bachelorarbeit / Mobile Sensors) inkl. `chip mini ok` „aktiv" / „✓ aktuell" bzw. `chip warn` „unvollständig".
- **⚙ Zugangs-Formular** (`U._claudeCfgForm`, util.js:724-758): `.cc-grid` mit Passwortfeld „Eigener API-Key" (placeholder `sk-ant-… (bleibt in diesem Browser)`), Modell-Select (`Label · Tier ($in/$out)`), „max. Antwort-Tokens" (number, min 1024, step 512), „Basis-URL (eigener Proxy — hält den Key serverseitig)", Checkbox „Tiefes Denken (adaptiv — nur Opus/Sonnet/Fable, etwas teurer & besser)", Checkbox „Demo-Modus, solange kein Zugang gesetzt ist …"; speichert bei jedem input/change, zeigt kurz „✓ gespeichert".

### 4.8 Instanz-Fenster (Views) — Layout (views_studio.js:2232-2337)
Je Absatzkarte ein `aside.para-side[data-mode]` rechts daneben; Instanz-Farbe via CSS-Var `--ps-accent` + Klasse `.tinted` (färbt Kopf + Naht). Kopf `.ps-h` mit `.ps-t` (Label) + `.ps-chips` (`chip ki mini` „✦ auto" wenn nur Auto-Inhalt; `chip ok mini` „✎" wenn eigener) + einziges `button.ps-x` „×" (schließt Fenster des Abschnitts). Breiten-Drag über `.ps-resize[role=separator]` (Titel „Fenster-Breite ziehen · Doppelklick = Standard"), gespeichert in `uiPsW`, min 200 / max 560 px, `dir:-1`, angewendet als `--ps-w` auf dem Root (views_studio.js:2221-2229). Leertext: „— leer — Doppelklick und einfach losschreiben (oder 🤖 Prompt in der Instanz-Leiste)". Graph-Instanz (⤳): `.para-side.graph` mit `.ps-kern` (Kernaussage) + `a.agp`-Zeilen (Kantenlinie `.agp-line[.in]`, Farbe `--agc`), max 6 eigene + bis 8 Abschnitts-Kanten unter Eyebrow „Abschnitt gesamt".

---

## 5. Design-Rohwerte

### Icons/Zeichen (exakt)
- Flows: `⚡` Voranalyse · `📓` Erklärbuch · `🖍` Markierungen · `⤳` Connections · `🎛` Instanzen · `📚` Quellen-Durchlauf · `🤖` Stil-Check (enhance.js:64-183).
- Aktionen: `⧉` Kopieren · `✓` Prüfen · `⭱` Übernehmen/Einfügen · `✦` Mit Claude/Magic · `◱` Referenz (nur im Kopf-Kommentar) · `ⓘ` Info · `⚙` Config · `✕`/`×` Schließen · `⭳` Download · `↺` Standard · `↻` Recompile · `🗑` Löschen · `➕` Neu · `⧈` Datenflüsse/Werkbank · `🔑` Zugang · `☁` AI-Space · `⎇` Stand · `Σ` Ground-Truth/LaTeX-Verknüpfung · `◆` Modell-Node · `✔` kopiert-Feedback · `⏳` busy · `🗂` Arbeit-Menü.
- Status-Kette: `✦ vermutet → ❝ Original → ✓ belegt` (enhance.js:565).
- Topbar: „Generate GPT" (`.magic-top #gptBtn`, index.html:36).
- Instanz-Defaults: `⚡ Schnelllesen` · `⤳ Connections` · `◘ Quelle` · `🌐 Übersetzung` · `✎ Erklärung` · `✦ Analyse` · `◻ Ohne` (views_studio.js:2127-2135). Sensors-Projekt: `📡 Sensor-Brille` · `🎓 Prüfungsfrage` mit Kategorie-Chips `🟦 🟥 🟩 🟨` (tools/sensors_instanzen.js:11-19).

### Farben (nur Token, keine Inline-Hex in diesen Modulen)
Instanz-Farben: `schnell: var(--cat-frist)`, `connections: var(--accent-ink)`, `srcview/uebersetzung: var(--cat-norm)`, `erklaerung: var(--good)`, `analyse: var(--cat-akteur)`; Sensors: `sensorblick: var(--cat-tech)`, `pruefungsfrage: var(--cat-these)`. Graph-Kantenfarben (views_studio.js:2299): `folgerung: var(--accent-ink)` · `grundlage: var(--good)` · `aufgriff: var(--cat-frist)` · `vergleich: var(--cat-akteur)` · `fazit: var(--cat-tech)` · `quellen: var(--cat-norm)` · `xref: var(--muted)`. Mark-Chips: `style="--c:var(--cat-<kategorie>)"` (enhance.js:345). masterPrompt erlaubt in instanzen.json `"color":"var(--cat-tech)|#hex"` (views_projekt.js:555).

### Modelle & Preise (claude.js:24-30, $/1 Mio Tokens)
| id | label | tier | in | out | adaptive |
|---|---|---|---|---|---|
| `claude-opus-4-8` | Opus 4.8 | Höchste Qualität | 5 | 25 | ja |
| `claude-sonnet-5` | Sonnet 5 | Schnell & günstig | 3 | 15 | ja |
| `claude-haiku-4-5` | Haiku 4.5 | Am günstigsten | 1 | 5 | nein |
| `claude-opus-4-7` | Opus 4.7 | Vorgänger | 5 | 25 | ja |
| `claude-fable-5` | Fable 5 | Maximal | 10 | 50 | ja |

### Wichtige UI-Texte wortwörtlich (Auswahl, Zeilenverweise)
- Panel-Kopf: „GPT Magic" / „KI-Werkbank · LaTeX ist Ground Truth" (enhance.js:378).
- Zugang-Labels: „nur ⧉ extern" · „AI-Space verbunden" · „verbunden · <Modell>" · „Demo-Modus" (enhance.js:30-39).
- 3-Schritte-Zeile: „1 ⧉ kopieren → 2 extern ausführen (ChatGPT/Claude/…) → 3 einfügen · ✓ prüfen · ⭱ übernehmen" (enhance.js:467-470).
- Voranalyse-Fehlertext: „Die Voranalyse-Antwort umfasst mehrere Dateien — als einzelne Dateien sichern und über „⭱ Analysen importieren" einlesen." (enhance.js:72).
- Eingebaute-Arbeit-Alert: „Diese Arbeit ist eingebaut — ihre Voranalyse wird mitgeliefert. Für eine neue Voranalyse eine eigene .tex-Arbeit importieren (Status → Arbeiten)." (enhance.js:532; Variante „(🗂-Menü)" enhance.js:924).
- Demo-Abschluss-Modal: Titel „<Aktion> — Demo abgeschlossen"; „Es wurden keine Daten übernommen — der Demo-Modus erfindet nichts."; Buttons „🔑 Echten Zugang einrichten" / „⧉ Stattdessen extern (gratis)" (enhance.js:851-857).
- Fehler-Modal: „GPT Magic — Fehler" + „Zugang prüfen (🔑) oder den Weg über ⧉ Kopieren + externes GPT nehmen — der ist immer frei." (enhance.js:877).
- Demo-Stream-Text (claude.js:189-195): „✦ Demo-Modus — so liefe die Anfrage mit echtem Zugang: …" (5 Zeilen, exakt im Code).
- Fehler-Map (claude.js:213-219): „Zugang abgelehnt (401) — API-Key falsch oder fehlt." · „Kein Zugriff (403) — Key/Endpunkt prüfen." · „Endpunkt nicht gefunden (404) — Basis-URL prüfen." · „Zu viele Anfragen / Kontingent erschöpft (429)." · „Claude überlastet (529) — gleich erneut versuchen."; Netzwerk: „Netzwerkfehler — Adresse/Verbindung prüfen (…)"; ohne Zugang: „Kein Claude-Zugang hinterlegt — erst einrichten (⚙)." (claude.js:122).
- ⚙-Placeholder Zusatz-Anweisung: „z. B. „Sei knapper" oder „nur die wichtigsten 3 pro Absatz"" (enhance.js:635).
- Views-Editor (views_studio.js:2367-2386): Titel „✎ Views verwalten"; „➕ Neue View — die KI füllt sie aus dem LaTeX"; Placeholders „Name (z. B. „Kritik", „Beispiele")" / „Auftrag je Absatz (z. B. „Nenne je Absatz ein konkretes Praxisbeispiel, 1–2 Sätze")"; „Erlaubte Syntax: einfacher Markdown (fett/kursiv/Listen), kein LaTeX. Ohne Zugang wird die View leer angelegt — Inhalte dann über den GPT-Hub oben (🎛 Instanzen: ⧉ kopieren / ⭱ einfügen)."; Buttons „➕ Erstellen & Generieren" / „↺ Standard" / „Fertig"; Confirms „View „<Label>" löschen? Ihre generierten Inhalte (<n> Absätze) werden mit entfernt." und „Alle Views auf den Standard zurücksetzen? Eigene Views (samt Inhalten) werden entfernt.".
- `CAT_LABELS` (util.js:919-923): norm „Quelle/Rechtsnorm" · frist „Frist/Datum" · akteur „Akteur/Institution" · tech „Technik/Standard" · these „These/Wertung" · luecke „Lücke/Problem" · zahl „Zahl/Menge" · abk „Abkürzung" · schlag „Schlagwort". `CAT_ORDER = ['norm','frist','akteur','tech','these','luecke','zahl','abk','schlag']`.

---

## 6. Verhalten & Interaktionen

### 6.1 Die 7 Flows (enhance.js:60-185) — Kerndaten
| id | Icon/Titel | aktion | scope | build (Prompt) | run (Import) | stat() |
|---|---|---|---|---|---|---|
| `all` | ⚡ Voranalyse (alles) | Analyze | Ganze Arbeit, `multi:true` | `masterPrompt() + '='.repeat(60) + 'HIER DER LATEX-QUELLTEXT DER ARBEIT:' + Editor.fullDocument()` (enhance.js:71) | wirft immer Fehler → Multi-Datei-Import via `importAnalysenModal` | `"<n> Abschn."` |
| `buch` | 📓 Erklärbuch | Explain | Ganze Arbeit | `Notebook.prompt()` | `Notebook.set(t)`; danach `location.hash='#/analyse/buch'` + rerender (enhance.js:87-90) | `'✓'`/`'—'` |
| `marks` | 🖍 Markierungen | Marks | Dieser Abschnitt (`section: sectionId`) | `marksPromptFor(sectionId)` | `_importMarks` | Anzahl Extra-Marks des Abschnitts |
| `conn` | ⤳ Connections | Connect | Ganze Arbeit | `Connections.regeneratePrompt()` | `Connections.importKi(t)` | `Connections.all().length` |
| `inst` | 🎛 Instanzen | Views | Ganze Arbeit | `instanzPrompt()` | `_importInst` | Keys von `paraDock` |
| `quellen` | 📚 Quellen-Durchlauf | Sources | Dieser Abschnitt | `gptPromptForSource(this._src())`; `_src()` = ctx.srcId ∥ Studio.file.srcId ∥ erste Quelle des Abschnitts (enhance.js:154) | JSON parsen, `stellen` Pflicht, `sourceId`/`generatedBy:'gpt'` defaulten, `U.setResolution(r)` (enhance.js:156-164) | Stellen-Zahl der aktiven Quelle |
| `style` | 🤖 Stil-Check | — (`toggle:true`) | Dieser Abschnitt | — (lokale Heuristik, kein Prompt) | — | `'an'`/`'aus'` |

Jeder Flow trägt zusätzlich wörtliche Meta-Texte `kurz`, `erzeugt`, `how`, `basis`, `wieder` (Ersetzen-Semantik) und `paket {in[], out, ziel}` — alle 1:1 im Code (enhance.js:64-183), sie speisen Paket-Strip, infoModal und Vergleichstabelle.

### 6.2 Interaktionen im Detail
- **⧉ Kopieren**: `U.copy(Enhance.prompt(flow))`; Button-Feedback „✔ kopiert" für 1400 ms (Dock: „✔" 1200 ms) (enhance.js:517, 799-803).
- **✓ Prüfen**: `_check` → `ClaudeAI.clean` → `flow.check` in try/catch; Ergebnis-Box `.enh-check.ok|.err`, Präfix „✓ " bei ok (enhance.js:519-524). Leer: „Nichts zu prüfen — die Antwort (z. B. aus dem externen GPT) oben einfügen."
- **⭱ Übernehmen**: `doApply` → `flow.run(ClaudeAI.clean(text))`; Erfolg `#enhMsg` „✓ <out>" (Klasse `small ok`), nach 700 ms `Enhance.close()` + `flow.done()`; Fehler „✗ <msg>" (`small err`) (enhance.js:511-515). Leere Textarea → Fokus + Hinweis „Antwort oben einfügen, dann „⭱ Übernehmen"." (enhance.js:526).
- **Datei laden**: File-Input, `await f.text()` → `doApply` (enhance.js:529).
- **✦ Mit Claude (Panel)**: ohne ready → `U.claudeConfigModal`; sonst `_runMagic` (Panel-Variante) (enhance.js:538-541).
- **✦ Ein-Klick-Kochen (Dock, `_cook`, enhance.js:820-882)**: Ablauf-Reihenfolge: (1) erneuter Klick während `.busy` = Abbruch via `Enhance._ctl.abort()`; (2) per-Flow-Modell wird temporär als globales Modell gesetzt und im `finally` zurückgesetzt (enhance.js:827/879); (3) `navigator.vibrate(12)`; (4) Breite einfrieren, `.busy`, Preis-Slot `live` zeigt „0 Tok" und zählt Output-Tokens live; (5) `ClaudeAI.run` streamt; (6a) Demo → `finalize` (✓-Haken, `vibrate([10,40,10])`, 1250 ms) → Demo-Modal; (6b) echt → `flow.run(clean)`; Erfolg: Preis = `fmtEur(cost)`, ✓-Animation, dann `flow.done()`; (6c) **Import-Fehler → nahtlos `pasteModal` mit `prefill` + `autocheck` + Note „✗ Automatischer Import scheiterte: <msg> — Antwort unten prüfen/korrigieren."**; (7) sonstige Fehler → Fehler-Modal (außer AbortError).
- **pasteModal**: Format-Checker debounced 350 ms bei `input`; Datei-Laden befüllt Textarea + Check; Übernehmen wie oben mit 700-ms-Close; `#pmSys` wechselt zum infoModal (enhance.js:929-952).
- **Stil-Check-Toggle**: setzt `Studio.styleCheck`, speichert `uiStyleCheck`, schließt Panel, `routeRefresh()` (enhance.js:451).
- **Instanz-Inline-Edit** (views_studio.js:2254-2289): Doppelklick auf `.para-side` (nicht auf Buttons/Naht) → `contentEditable='plaintext-only'` (Fallback `'true'`), Chips zeigen „✎ · Esc fertig"; Esc oder Blur beendet (idempotent via `done`-Flag); unverändertes Auto wird als leer gespeichert (kein Edit).
- **View-Recompile ↻** (`viewGenerate`, views_studio.js:2458-2480): Button ⏳ + Token-Zähler; `ClaudeAI.run(instanzPromptFor([def]))`; Demo → Info-Modal; echt → `Enhance._importInst(clean)`, Button „✓" 900 ms. Neue View: id = `name.toLowerCase().replace(/[^a-z0-9äöüß]+/gi,'-')…slice(0,40)` (views_studio.js:2433); bei `ClaudeAI.ready()` wird direkt generiert.
- **gptModal** (`U.gptModal`, util.js:779-908; von anderen Views genutztes Muster): ✦-Knopf streamt in die Antwort-Textarea (`onText` mit Auto-Scroll), `onThink` → „Claude denkt …", `onUsage` → „Claude schreibt … <n> Tokens"; bei Erfolg **automatischer Import**; ✎ Bearbeiten erlaubt Prompt-Override (gilt für Kopieren UND Senden); erneuter Klick = Abbrechen.
- **Randfälle**: `Enhance.close()` bricht laufende Runs ab (enhance.js:419); Hub `reopen` nur wenn `pop.isConnected && !pop.hidden`; `countTokens` scheitert leise (null); `_checkQuellen` toleriert fehlende `formatVersion` und meldet sourceId-Mismatch nur als Hinweis (enhance.js:298-299); `_importMarks` filtert Einträge ohne Snippet/mit unbekannter Kategorie; `_importInst` überspringt unbekannte Instanz-IDs und meldet sie („übersprungen: …").

### 6.3 ClaudeAI.run — exakter Netz-Ablauf (claude.js:121-182)
1. `ready()`-Check, Demo-Weiche (claude.js:125).
2. Request: `POST {baseUrl}/v1/messages`, Header: `content-type: application/json`, `anthropic-version: 2023-06-01`, `anthropic-dangerous-direct-browser-access: true`, `x-api-key: <key>` (nur wenn gesetzt; beim Proxy entfällt er) (claude.js:87-97). Body: `{model, max_tokens: max(1024, cfg.maxTokens||6000), stream:true, messages:[{role:'user', content: prompt}]}`; bei `deepThink && model.adaptive` zusätzlich `thinking:{type:'adaptive'}` (claude.js:128-134). **Kein System-Prompt, keine History — immer Single-Turn.**
3. SSE-Parsing per `res.body.getReader()` + TextDecoder; Blöcke an `\n\n` getrennt, nur `data:`-Zeilen; `[DONE]` ignoriert. Events: `message_start` → `usage.input`; `content_block_delta` mit `text_delta` → Text sammeln + `onText`; `thinking_delta` → `onThink`; `message_delta.usage` → `usage.output`; `error` → throw (claude.js:151-179).
4. Rückgabe `{text, usage, cost}`; Kosten aus echten Usage-Zahlen.
5. `countTokens`: `POST /v1/messages/count_tokens` gleicher Header-Satz, Antwortfeld `input_tokens` (claude.js:105-116).
6. Demo (`_runDemo`, claude.js:186-208): streamt den festen Demo-Text wortweise mit 14 ms Delay, zählt Usage hoch, respektiert `signal`, Rückgabe mit `demo:true`.

---

## 7. Datenformen — Antwort-/Import-Formate (exakte Notation)

### 7.1 🖍 Markierungen (Flow `marks`)
```jsonc
// Placeholder (enhance.js:102) und Prompt-Vorgabe (views_studio.js:701):
{"sectionId": "3.2.1",
 "items": { "3.2.1-p1": [ {"snippet": "binnen 24 Monaten",   // MUSS wörtlich im Absatz stehen, 1–6 Wörter
                            "kategorie": "frist"} ] }}        // Schlüssel aus CAT_LABELS
```
Import (enhance.js:188-200): validiert `items`-Objekt; je Absatz nur Einträge mit nicht-leerem `snippet` und bekannter `kategorie`; **ersetzt `marksExtra[pid]` komplett**. Anzeige: Extra-Marks werden an die Voranalyse-Marks angehängt (`paraMarks`, views_studio.js:681-686) und als farbige Spans über den Text gelegt.

### 7.2 🎛 Instanzen (Flow `inst`) — zwei akzeptierte Formen (enhance.js:209-211)
```jsonc
// Hauptform (Placeholder enhance.js:136):
{"instanzen": { "erklaerung": { "3.2.1-p1": "**fett** Markdown …" },
                "sensorblick": { "1.1-p1": "🟦 …" } }}
// Alternative Teil-Form (eine Instanz):
{"mode": "erklaerung", "items": { "3.2.1-p1": "…" }}   // statt "mode" auch "instanz"
```
Nur bekannte, nicht-spezielle Instanz-IDs (`dockDefs().filter(x=>!x.special)`); Werte = Markdown-Strings; leere/Nicht-Strings übersprungen. Teil-Antworten ERGÄNZEN (per `dockSet` je Absatz), Voll-Läufe überschreiben je Absatz.

### 7.3 ⤳ Connections (Flow `conn`)
```jsonc
{"connections": [ { "id": "c1", "typ": "folgerung",   // folgerung|grundlage|aufgriff|vergleich
    "von": {"sectionId": "5.3.3", "paraId": "5.3.3-p2"},
    "nach": {"sectionId": "6.0",  "paraId": "6.0-p5"},
    "label": "<Kurzname>", "text": "<warum die Stellen zusammenhängen>" } ]}
```
Checker-Pflicht: `von.sectionId`, `nach.sectionId`, `typ` (enhance.js:254-268); Import via `Connections.importKi` → Store `kiConnections`.

### 7.4 📚 Quellen-Durchlauf (Flow `quellen`; Prompt views_quellen.js:702-708)
```jsonc
{ "formatVersion": "1.0", "sourceId": "cobrado2024", "generatedBy": "gpt",
  "stellen": [ { "footnote": 12,                       // Pflicht (Alias "num" toleriert der Checker)
      "seite": 4,                                       // ODER "fundstelle": "<Art/§/Abschnitt>" (je posType)
      "zitat": "<wörtliche Originalpassage>",
      "status": "bestaetigt",                           // bestaetigt|teilweise|nicht_gefunden
      "kommentar": "<kurz>" } ] }
```
Import: gesamtes Objekt → `U.setResolution` (ersetzt Durchlauf der Quelle); von Hand erfasste Belege gewinnen immer (enhance.js:152).

### 7.5 📓 Erklärbuch (Flow `buch`)
Reines Markdown, muss mit `# Titel` beginnen; Checker zählt ```-Zäune (ungerade = Fehler), lehnt JSON-Anfang ab (enhance.js:306-318).

### 7.6 ⚡ Voranalyse — Multi-Datei-Antwort (masterPrompt, s. §7.8)
Dateien werden einzeln gespeichert und über `importAnalysenModal` (views_projekt.js:437-490) eingelesen. Erkannte Dateinamen (wörtlich, views_projekt.js:440-443): `<abschnitt>.json` (z. B. `3_2_1.json`), `kapitel-N.json`, `gesamt.json`, `fazit-connections.json`, `connections.json`, `struktur/quellen/inhalt/standards.json`, `instanzen.json`, `erklaerbuch.md`, `figures.json`, `registry.json`, Quellen-Dossiers per sourceId (`<id>-dossier.json`). `.md` → direkt `rec.generated.erklaerbuch`; JSON → `Projects.applyGeneratedFile(rec, f.name, obj)`; `registry.json` → zweistufig `Projects.applyRegistry`.

### 7.7 Flow-Objekt (interne Struktur, enhance.js:63-76)
```jsonc
{ "id": "marks", "icon": "🖍", "title": "Markierungen", "aktion": "Marks",
  "scope": "Dieser Abschnitt", "section": "3.2.1", "multi": false, "toggle": false,
  "kurz": "…", "erzeugt": "…", "how": "…", "basis": "…", "wieder": "…",
  "paket": {"in": ["Absätze des Abschnitts","Kategorien-Notation"],
            "out": "Snippets + Kategorie (JSON)", "ziel": "Marks im Text"},
  "placeholder": "{…}",
  // Funktionen: build() → Prompt, run(text) → Erfolgs-String (wirft),
  // check(raw) → {ok, html}, reference() → HTML, done() → Navigation,
  // stat() → Kurzstatus-String, statOn() → bool }
```

### 7.8 Prompt-Vorlagen (wortwörtlich, Fundstellen)
1. **Gesamt-/Master-Prompt** `masterPrompt()` (views_projekt.js:493-563): beginnt „Du bist die Setup-Pipeline für „Thesis Studio" …"; verlangt 11 Dateien als ```json-Blöcke mit vorangestelltem Dateinamen; enthält die vollständigen Schemata für `registry.json` (inkl. `kind: "artikel|konferenz|norm|report|online|recht-eu|recht-at"`, `links.official/file`, `aliases` als Regex-Strings), `<abschnitt>.json` (sentences mit `text/einfach/kategorien/marks`, `belege` mit `num/quellen/claim/fundstelle/suchHinweis` — suchHinweis: „2-4 WOERTLICH im Original vorkommende Zeichenketten (je 2-6 Woerter …), mit | getrennt"), Dossiers, `kapitel-<n>.json`, `gesamt.json`, `fazit-connections.json`, `connections.json` (mit Typ-Erklärungen + „15–40 Stück, Qualität vor Menge"), Würdigung, `standards.json` (`note: "stark|solide|ausbaufaehig|schwach"`), `instanzen.json`, `erklaerbuch.md`. Schluss: „Arbeite Kapitel für Kapitel. Die vollständige Spezifikation liegt in docs/PROJEKT-FORMAT.md." Flow `all` hängt an: `\n\n` + 60×`=` + `\nHIER DER LATEX-QUELLTEXT DER ARBEIT:\n` + 60×`=` + `\n\n` + `Editor.fullDocument()`.
2. **Marks-Prompt** `marksPromptFor(sectionId)` (views_studio.js:688-706): „Du markierst in „Thesis Studio" Schluesselstellen …"; listet die 9 Kategorien mit Kurzerklärung; Regeln (wörtliches Snippet 1–6 Wörter, keine `[^n]`-Marker, 2–8 pro Absatz, keine Überlappungen); „ANTWORTE NUR mit diesem JSON:" + Schema; dann „ABSÄTZE (Abschnitt <id> · <Titel>):" mit `[<p.id>]`-Blöcken (Fußnoten-Marker `[\^\d+]` entfernt, Listen als `\n· `-Items).
3. **Instanzen-Prompt** `instanzPromptFor(defs)` (views_studio.js:2485-2522): „Du füllst in „Thesis Studio" die Absatz-Instanzen der GANZEN Arbeit („<Titel>")."; je Text-View eine Zeile `- "<id>" (<label>): <desc>` (Default-Auftrag: „kurzer, hilfreicher Text je Absatz."; Σ-Zusatz „[Σ übergeordnet verknüpft mit Quelle <srcTex> — Material unten]"); „Einfacher Markdown-Text (fett/kursiv/Listen erlaubt), KEIN LaTeX. Das Original bleibt unverändert (Ground Truth)."; JSON-Schema; optional Σ-Blöcke „ÜBERGEORDNET VERKNÜPFTES MATERIAL für die View "<id>" — LaTeX der Quelle <srcId>:" mit `--- <name> ---` + Volltext; dann „ABSÄTZE (gesamte Arbeit):" mit `== Abschnitt <id> · <Titel> ==`-Blöcken und `[<p.id>]`-Absätzen.
4. **Quellen-Prompt** `gptPromptForSource(srcId)` (views_quellen.js:686-710): „Du hilfst bei der Literaturprüfung einer Bachelorarbeit über den EHDS. …"; QUELLE-Zeile (Autor — Titel (Container) · DOI), OFFIZIELLER LINK / DATEI-LINK, „ZITIERSTELLEN (<n>):" als `- Fußnote <n> (Abschnitt <id>): Aussage: „…" · vermutet: … · Suche: …`; „ANTWORTE NUR mit folgendem JSON (eine "stellen"-Zeile je Fußnote):" — `"seite"` vs. `"fundstelle"` abhängig von `Levels.positionType(srcId)`. **Achtung: „EHDS" ist hier hart codiert, nicht projektabhängig.**
5. **Zusatz-Instruktion** (⚙, enhance.js:53): Suffix `\n\nZUSÄTZLICHE ANWEISUNG:\n<text>`.

### 7.9 Instanz-System (Views) — Definitionen
`DOCK_DEFAULTS` (views_studio.js:2127-2135): 3 Spezial (`schnell`, `connections`, `srcview` — festes Verhalten, nur Name/Position) + 3 Text-Views mit `desc` = GPT-Auftrag (wörtlich in §5/oben) + Spezial `clear` (◻ Ohne). `dockDefs()` mischt: Defaults + Projekt-Instanzen (`window.PROJECT_INSTANZEN.defs`, vor „◻ Ohne" eingereiht, Flag `project:true`) + Nutzer-Overrides aus `instDefs` (Reihenfolge/Labels/desc/color/srcTex), Spezial-/Projekt-Instanzen werden abgesichert nachgereicht (views_studio.js:2143-2162). Neue Views: id = slugifizierter Name (a-z0-9äöüß, max 40), `label`, `desc` (= Auftrag), optional `srcTex` (Σ-Quelle), optional `color`. Auto-Inhalte (`dockAuto`, views_studio.js:2184-2198): `uebersetzung` ← `gp.uebersetzung`; `erklaerung` ← Join der `sentences[].einfach`; `analyse` ← `**Kernaussage:** …` + `**Belegt wird:** claim · claim`; sonst ← `PROJECT_INSTANZEN.items[mode][p.id]`. Beispiel mitgelieferter Projekt-Instanzen (tools/sensors_instanzen.js:11-19): `sensorblick` „📡 Sensor-Brille" (`var(--cat-tech)`) und `pruefungsfrage` „🎓 Prüfungsfrage" (`var(--cat-these)`) mit den wörtlichen `desc`-Aufträgen (s. §5).

---

## 8. Abhängigkeiten

- **enhance.js → claude.js**: durchgängig (Status, Schätzung, run, clean); defensiv via `typeof ClaudeAI === 'undefined'`-Guards (funktioniert theoretisch auch ohne claude.js im „nur extern"-Modus).
- **enhance.js → util.js**: `U.*` (Store, Modal, esc, md, el, copy, download, setResolution/getResolutions, claudeConfigModal, _claudeCfgForm), `CAT_LABELS`, `UNIT_INDEX`.
- **enhance.js → views_studio.js**: `marksPromptFor`, `instanzPrompt`, `dockDefs`, `dockSet`, `Studio` (sectionId, file.srcId, styleCheck, genPara indirekt).
- **enhance.js → views_projekt.js**: `masterPrompt`, `importAnalysenModal`, `Projects`.
- **enhance.js → views_quellen.js**: `gptPromptForSource`, `sectionSources`.
- **enhance.js → connections.js / notebook.js / editor.js / app.js**: `Connections.*`, `Notebook.*`, `Editor.fullDocument`, `routeRefresh`, `renderAnalyse`, `orderedUnits`.
- **Wer ruft enhance.js**: `app.js:125` (Topbar → `Enhance.hub`), `views_projekt.js:221` (`Enhance.pasteModal({srcId},'quellen')`), `views_studio.js:2473` (`Enhance._importInst`), sowie überall, wo `Enhance.dock(…)` platziert wird.
- **Wer ruft claude.js**: `Enhance` (alle ✦-Pfade), `U._claudeCfgForm`/`U.gptModal` (util.js), `viewGenerate` (views_studio.js).
- **Netz**: ausschließlich `fetch` auf `{baseUrl}/v1/messages` und `{baseUrl}/v1/messages/count_tokens`.

---

## 9. Flutter-Hinweise

1. **`Enhance.flows` als typisiertes Registry-Pattern** übernehmen: `class AiFlow { id, icon, title, aktion, scope, multi, toggle, paket, buildPrompt(), runImport(), check(), reference(), done(), stat() }` — die gesamte UI (Hub, Panel, Dock, Modals) ist nur eine Projektion dieser Liste. Das 1:1 nachzubauen ist der Schlüssel für Verhaltensgleichheit.
2. **Claude-Client**: `package:http` reicht nicht bequem für SSE — `http.Client().send()` mit `StreamedResponse` + eigener Zeilen-/`data:`-Parser (identisch zur JS-Logik: Blöcke an `\n\n`, Events message_start/content_block_delta(text_delta|thinking_delta)/message_delta/error) oder Paket `eventflux`/`fetch_client` (Web). Header exakt übernehmen; `anthropic-dangerous-direct-browser-access` nur für Web-Target nötig, im nativen Flutter-Client harmlos/überflüssig — für 1:1-Web-Parität trotzdem senden. AbortController → `StreamSubscription.cancel()` bzw. `http.Client().close()`.
3. **Key-Speicherung**: Original legt den API-Key im Klartext in localStorage. In Flutter `flutter_secure_storage` verwenden (bewusste, dokumentierte Abweichung) — Verhalten (global, projektübergreifend, sofortiges Speichern bei Eingabe) beibehalten.
4. **Storage-Scoping nachbauen**: Präfixlogik `ehds.` vs. `ehds.<projekt>.` (util.js:200-211) muss exakt repliziert werden, sonst brechen Import/Export-Kompatibilität und die Trennung pro Arbeit. `claudeCfg`, `enhCfg`, `instDefs` global; `marksExtra`, `paraDock`, `kiConnections`, `notebook`, `resolutions` projekt-gescoped.
5. **Panel-Einfahren**: `.enh-back.in`-Transition → `SlideTransition`/`showGeneralDialog` mit rechtsseitigem `Align` + `AnimationController`; Backdrop-Tap schließt; Escape-Sonderregel (nur wenn kein Modal darüber) → in Flutter über Navigator-Stack natürlich gelöst.
6. **Magic-Dock-Animation**: Breiten-Einfrieren beim Kochen (Label bleibt, nur Preis-Slot tickt) → `AnimatedSize` deaktivieren bzw. feste `BoxConstraints` während busy; ✓-Haken als animiertes SVG → `CustomPainter` mit Pfad-Animation oder `Icons.check` mit Scale-Pop; `navigator.vibrate` → `HapticFeedback.lightImpact()` (12 ms) bzw. Muster `[10,40,10]` → `HapticFeedback.mediumImpact()` (kein exaktes Pattern-API auf iOS — akzeptierte Abweichung).
7. **Format-Checker-HTML**: `check()` liefert HTML-Strings (fett, `<ul>`, Chips). In Flutter als `InlineSpan`-Builder oder kleines RichText-Modell (`ok`, `summary`, `problems[]`) neu modellieren statt HTML zu rendern — Wortlaut der Meldungen exakt übernehmen.
8. **contentEditable-Inline-Edit** der Instanz-Fenster → `TextField` mit `maxLines:null` an gleicher Stelle (Markdown-Rohform), Esc/Fokusverlust committen; „unverändertes Auto zählt nicht als Edit"-Regel übernehmen (views_studio.js:2278).
9. **Drag-Resize** der Instanz-Fenster (`--ps-w`, 200–560 px, Doppelklick = Reset, persistiert `uiPsW`) → `GestureDetector` + gespeicherte Breite; Doppelklick → `GestureDetector.onDoubleTap`.
10. **Multi-Datei-Import** (Voranalyse) → `file_picker` mit `allowMultiple`, Dateiname-Dispatch identisch (`3_2_1.json` etc.); `.md` vs. JSON-Weiche beibehalten.
11. **Clipboard/Download**: `U.copy` → `Clipboard.setData`; `U.download('voranalyse-antwort.txt')` → `file_saver`/Share-Sheet.
12. **Nicht 1:1 möglich**: (a) direkte Browser-CORS-Semantik entfällt — nativ ist der Anthropic-Call unproblematisch; (b) `location.hash`-basierter `hubCtx` → Router-State (GoRouter) injizieren; (c) `count_tokens`-Stillschweigen (null bei Fehler) beibehalten; (d) Demo-Wortstreaming mit 14 ms Timer exakt nachbaubar (`Stream.periodic`).
13. **Preisformate exakt übernehmen** (`fmtUsd`/`fmtEur`/`fmtTok`-Schwellen), da sie sichtbarer Teil der UI sind; Modell-Liste + Preise als Konstanten spiegeln.
14. **Konzept-Modal-Tabs + Vergleichstabelle**: `DefaultTabController` bzw. eigener Chip-Tabbar; Tabellen-Zeile `.cur`-Highlight synchron zum Tab.
