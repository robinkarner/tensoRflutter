# BAUPLAN — Flutter-Konvertierung „Thesis Studio" (thesoR)

Stand: 2026-07-23 · Grundlage: `docs/inventory/00-MASTER.md` (+ Dossiers 01–10) und `docs/TECH-DECISIONS.md`.
Arbeitsweise: Wellen wie auf einer Baustelle — jede Welle hat Arbeitspakete mit klarer Verzeichnis-Eignerschaft
(keine zwei Agenten in derselben Datei), am Wellenende ein hartes Gate: `flutter analyze` sauber, `flutter test` grün,
`flutter build web --release` erfolgreich.

## Fixierte Produktentscheidungen (aus den offenen Punkten des Masters)

| # | Entscheidung | Begründung |
|---|---|---|
| E1 | **Serif = PT Serif** (gebündelt, 400/400i/700) | Original nutzt System-Serif (Iowan/Palatino/Georgia) ohne Datei; PT Serif ist die kanonische, plattformstabile Wahl |
| E2 | **Noto Sans Symbols 2** als Fallback-Font | ⭳⭱⌖⌗⇤⇥∅⤳◐ etc. rendern sonst nicht überall |
| E3 | **OCR entfällt in V1** (UI-Platz mit Hinweis) | kein tragfähiges Cross-Plattform-Plugin für Web+Desktop+Mobil |
| E4 | **js-/py-Zellen im Erklärbuch: rendern, nicht ausführen** | Pyodide/`new Function` nicht portierbar; alle anderen Blocktypen (chart/table/math/latex/figure/include) laufen nativ |
| E5 | **pdfToTex (Beta) wird zurückgestellt** | Beta im Original; braucht per-Fragment-Fontgrößen; Neue-Arbeit-aus-`.tex` ist der Hauptpfad |
| E6 | **Passwort-Gate entfällt** | Türsteher fürs statische Hosting, in einer App ohne Funktion |
| E7 | **Gesamter Fachzustand → Drift/SQLite** (statt localStorage/IndexedDB), Export-Formate bleiben **bit-kompatibel** (`ehds-belegstand` v2 inkl. `notes`↔`srcNotes`, `thesis-studio-projekt` v1, Datei-Auftrag-ZIP v1, Resolution 1.0, CRC32-srcHash) | Datenmitnahme aus der Web-App garantiert |
| E8 | **`location.reload()`-Muster → expliziter Provider-Reboot** (Invalidierung des gesamten Graphen); Stale-Cache-Bugs des Originals (L2) dabei bewusst gefixt | architektonisch klar besser, dokumentiert |
| E9 | Original-Bugs W8 (EHDS-hartcodierter Quellen-Prompt) und W9 (`\cite`-Lint) werden **gefixt**, nicht nachgebaut | vom Nutzer freigegebene Kategorie „100 % sicher besser" |
| E10 | API-Key-Ablage in der lokalen DB, klar dokumentiert | Parität zum Original (Klartext-localStorage); secure-storage als dokumentierte Ausbaustufe |
| E11 | Charts als **CustomPainter** (Nachbau der 7 SVG-Typen inkl. nice-Ticks/de-AT), fl_chart nur falls deckungsgleich | Pixel-Nähe geht vor Bibliothekskomfort |
| E12 | Kommentare im Code auf Deutsch, Bezeichner Dart-konventionell — derselbe erklärende Stil wie im Original | Stil-Parität |

## Ziel-Struktur `lib/`

```
lib/
  main.dart                    Boot-Sequenz (Projekt laden → DB ready → Indizes → Einmal-Import) + ProviderScope
  core/
    theme/                     tokens.dart (alle CSS-Custom-Properties Light+Dark als ThemeExtension),
                               typography.dart, theme.dart, color_mix.dart
    router/                    routes.dart (deklarativer Routenbaum + Alt-Routen-Redirects), router.dart
    shell/                     app_shell.dart, topbar.dart, mainnav.dart, footer.dart, works_menu.dart,
                               gpt_hub_button.dart, cmdk.dart
    widgets/                   modal.dart, resizable.dart (U.resizer-Pendant), tooltip.dart, chips.dart,
                               buttons.dart, notice.dart, accordion.dart, lightbox.dart
    richtext/                  richtext_builder.dart (Fußnoten-Chips, Marks, Mentions, Xrefs, Satzspannen
                               als TextSpan/WidgetSpan — Ersatz für U+0001-Sentinel-Pipeline + Custom Highlights)
    util/                      crc32.dart (0xedb88320 + NFD-Strip), sentences.dart, format.dart (de-AT)
  data/
    models/                    freezed-Modelle: Meta, Kapitel, Unit, Paragraph, Sentence, Mark, Beleg,
                               Fußnote, Quelle, Dossier, Figur/Tabelle, Connection, Instanz, Projekt …
    bundles/                   bundle_loader.dart (Assets→Modelle), indexes.dart (UNIT_INDEX, FN_INDEX,
                               SRC_BY_ID, orderedUnits — als Riverpod-Provider)
    db/                        database.dart (Drift-Schema), daos/, seed.dart (Erst-Import), kv.dart
                               (projekt-gescopte Zustands-Tabelle, PROJECT_KEYS-Semantik 1:1)
    export/                    belegstand.dart, projekt_format.dart, dateiauftrag.dart, resolution.dart
    repos/                     project_repository.dart, file_store.dart (PDF/Bild-Blobs), fig_store.dart
  domain/                      reine Dart-Ports mit Golden-Tests gegen die JS-Originale (Node-Fixtures):
                               levels.dart, connections.dart, mentions.dart, stylecheck.dart,
                               texparse.dart, editor_logic.dart (LaTeX-Interpreter/Lint/Preview-Modell)
  features/
    studio/                    layout/ (3 Spalten + Rails), lesen/, pruefen/, editor/, refmode/,
                               dock/ (Beleg-Dock), views/ (Instanz-Fenster + Leiste)
    quellen/                   library/, detail/, import/ (PDF/ZIP/Auftrag), store_modal/
    pdf/                       viewer/ (pdfrx, Endlos-Scroll), marks/ (0..1-Rects, Pins, Chooser),
                               search/, assign_panel/, figures/
    wissen/                    tabs/, notebook/ (Erklärbuch-Renderer), charts/ (CustomPainter),
                               math/ (MathRender-Subset via flutter_math_fork), analysemodus/
    projekt/                   dashboard/, setup/, arbeiten/ (Instanzen, Neue-Arbeit-aus-.tex, Import)
    hilfe/
    doc/                       Gesamtdokument-Ansicht + LaTeX-Export + printing
    ai/                        flows/ (7-Flow-Registry), hub/, panel/ (Werkbank), dock/ (Magic),
                               client/ (Claude-SSE + Demo-Modus), paste_modal/
test/
  domain/                      Golden-Tests (Fixtures aus tools/golden_gen.mjs, mit Node erzeugt)
  data/                        Export-Roundtrip-Tests (belegstand v2, CRC32-Testvektoren)
```

## Wellen

### Welle 0 — Fundament (parallel A+B, dann C+D, dann E)
| Paket | Inhalt | Eigner-Verzeichnisse | braucht |
|---|---|---|---|
| F-A Theme+Widgets | tokens/typography/theme (Dossier 02 vollständig!), modal, resizable, tooltip, chips, buttons, notice, accordion, lightbox | `core/theme`, `core/widgets`, `core/util` | — |
| F-B Modelle+Bundles | freezed-Modelle aller Entitäten, Bundle-Loader, Indizes-Provider | `data/models`, `data/bundles` | — |
| F-C DB+Export | Drift-Schema, DAOs, Seed, KV (PROJECT_KEYS), Export-Formate, Repos, CRC32-Roundtrip-Tests | `data/db`, `data/export`, `data/repos`, `test/data` | F-B |
| F-D Domänen-Ports | levels/connections/mentions/stylecheck/texparse/editor_logic + Golden-Fixtures via Node | `domain/`, `test/domain`, `tools/golden_gen.mjs` | F-B |
| F-E Router+Shell+Boot | go_router-Baum, Shell (Topbar/Nav/Footer/Theme/cmdk-Gerüst), Boot-Sequenz, Platzhalter-Screens je Route | `core/router`, `core/shell`, `main.dart` | F-A, F-B |
| **Gate 0** | analyze + test + build web + CONTRACTS.md (Provider-/Repo-Schnittstellen für Welle 1/2) | | |

### Welle 1 — Kernfeatures (4 Pakete, disjunkt)
| Paket | Inhalt | Eigner |
|---|---|---|
| S-1 PDF-Engine | pdfrx-Viewer (Endlos-Scroll, Zoom fit/0.3–4, Tastatur), Selektion→max 40 normierte Rects, Highlights (multiply, Dark .55), Pins (Drag+Clamp), Suche (zirkulär, Flash), assignPanel (4 Datei-Zustände, 5-Tab-Material, Kandidaten, Download-Engine), FigStore | `features/pdf` |
| S-2 RichText+Studio-Lesen/Prüfen | richtext_builder (core), Lesen (Dichte, ⚡/🖍), Prüfen (Absatzkarten, Belege, Erwähnungs-Workflow, jump-flash), Kapitelbaum, Modus-Leiste, 3-Spalten-Layout mit Rails | `core/richtext`, `features/studio/{layout,lesen,pruefen}` |
| S-3 Studio-Editor/Dock/RefMode/Views | LaTeX-Editor (Split, Lint, Live-Preview, Snippets), Beleg-Dock (Höhe ziehbar, Auto-Zuklapp <110px), Instanz-Fenster/-Leiste (+ ✎-Verwaltung), Referenzierungs-Vollbild, Absatz-Doppelklick-Edit, #/doc-Grundansicht | `features/studio/{editor,dock,refmode,views}`, `features/doc` |
| S-4 Quellen-Welt | Bibliothek (4-Spur-Grid, Sammlungen/Filter/Sortierung), Detailpanel (Akkordeons, Zitierstellen, Erwähnungen, Fundstellen-Register), Import PDF/ZIP (Matching-Kaskade), Datei-Auftrag-ZIP, storeModal, ＋ Quelle / aus Datei / 🤖 Ergänzung, Belegstand Sichern/Laden (UI) | `features/quellen` |
| **Gate 1** | analyze + test + build web | |

### Welle 2 — Welten & KI (4 Pakete, disjunkt)
| Paket | Inhalt | Eigner |
|---|---|---|
| K-1 Wissen | 8 Tabs in 3 Clustern (Farbwelt!), Erklärbuch-Renderer (alle Blocktypen, E4), Notebook-Editor, Chart-Engine (7 Typen, CustomPainter), MathRender, Analysemodus, Überblick/Kapitel/Connections (Bézier+bipartit)/Würdigung/Kennzahlen | `features/wissen` |
| K-2 Projekt+Hilfe | Dashboard (6 Statkacheln), Kapitel-Fortschritt, Quellen-Setup (Link-Vorschläge, ⭳ Alle laden), Referenzierungsdurchläufe, Arbeiten-Verwaltung (🗂, Reboot statt reload, Tombstones), Neue Arbeit aus .tex (Live-Parse), Analysen-Import (11-stufiges Mapping), Hilfe-Seiten | `features/projekt`, `features/hilfe` |
| K-3 AI-Schicht | Flow-Registry (7 Flows: build/run/check/reference/stat/done), GPT-Hub, Werkbank-Panel (einfahrend), Magic-Dock (Token-Zähler, Haken, Fehler→pasteModal), pasteModal/infoModal/standModal, Format-Checker, Claude-SSE-Client + Demo-Modus, Modelle/Preise | `features/ai` |
| K-4 Doc/Print+cmdk-Finish | printing-Export des Gesamtdokuments, LaTeX-Gesamt-Export, Command-Palette komplett (Abschnitte+Quellen+Ansichten) | `features/doc`, `core/shell/cmdk.dart` |
| **Gate 2** | analyze + test + build web | |

### Welle 3 — Integration, Review, Doku
1. Verdrahtungs-Sweep (Studio↔AI↔Quellen↔PDF Querbezüge, Fußnoten-Modal global, Deep-Links)
2. **Adversarial-Review-Workflow**: Finder-Agenten (Layout-Treue je Dossier, Verhaltens-Parität, Riverpod-Hygiene, toter Code) → Verifizierer → Fixes
3. README.md (Startanleitung alle Plattformen) + **getmedoc.md** (Architektur, alle Designentscheidungen, DB-Schema mit Testdaten, Mappings Original→Flutter, Riverpod-Konzept, Schnittstellen)
4. Finale: analyze 0 Issues, alle Tests grün, build web release, Commit + Push

## Verifikation & Regeln für alle Agenten
- `export PATH="/home/user/flutter/bin:$PATH"` — analyze/test nur aufs eigene Paket fokussiert, Fehler selbst beheben.
- `dart run build_runner build --delete-conflicting-outputs` bei Codegen-Änderungen; bei Lock-Konflikt kurz warten und wiederholen.
- Dossiers unter `docs/inventory/` sind die Wahrheit — bei Widersprüchen gilt: Realcode/Realdaten > Dossier > Doku (und Masters §8 beachten).
- UI-Texte wortwörtlich Deutsch aus den Dossiers übernehmen; Unicode-Symbole exakt.
- Keine Platzhalter-TODOs in ausgelieferten Pfaden — lieber Funktionsumfang klein schneiden als Stummel zeigen.
