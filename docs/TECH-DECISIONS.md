# Technologie-Entscheidungen Flutter-Konvertierung (Stand 2026-07-23)

## Umgebung (verifiziert installiert)
- Flutter **3.44.7** stable (2026-07-17), Dart **3.12.2** — Pfad: /home/user/flutter/bin
- Verifikation je Welle: `flutter analyze` + finaler `flutter build web --release`

## Paket-Matrix (Versionen live von pub.dev API abgefragt, 2026-07-23)

| Zweck | Paket | Version | Entscheidung/Begründung |
|---|---|---|---|
| State | flutter_riverpod | 3.3.2 | Riverpod v3-Linie |
| State-Codegen | riverpod_annotation / riverpod_generator | 4.0.3 / 4.0.4 | @riverpod-Codegen: Notifier, AsyncNotifier, family, autoDispose |
| Lint | riverpod_lint + custom_lint | 3.1.4 / 0.8.1 | Riverpod-Best-Practices erzwingen |
| Router | go_router | 17.3.0 | StatefulShellRoute (Topbar-Shell), Redirects für Alt-Routen, Pfad-Parameter |
| Router-Codegen | go_router_builder | 4.4.0 | OPTIONAL — nur wenn es lesbar bleibt; sonst handgeschriebener, sauber kategorisierter Routenbaum |
| DB | drift / drift_flutter / drift_dev | 2.34.2 / 0.3.1 / 2.34.5 | SQLite relational; Web via WASM/OPFS kommt mit drift_flutter; sqlite3_flutter_libs (+eol) wird von drift_flutter selbst korrekt aufgelöst — NICHT direkt pinnen |
| PDF-Viewer | pdfrx | 2.4.7 | pdfium-basiert, ALLE Plattformen inkl. Web/WASM; Text-Selektion (PdfTextSelectionParams), Suche, pageOverlaysBuilder/pagePaintCallbacks für Highlights+Pins |
| Dateien | file_picker | 11.0.2 | PDF/ZIP/TEX-Import auf allen Plattformen |
| ZIP | archive | 4.0.9 | Datei-Auftrag-Export, ZIP-Import |
| Markdown | flutter_markdown_plus | 1.0.12 | Nachfolger des eingestellten flutter_markdown (NICHT flutter_markdown verwenden!) + markdown 7.3.1 als Parser |
| Mathe | flutter_math_fork | 0.7.4 | LaTeX-Mathe im Erklärbuch; Kompatibilität beim ersten Build prüfen (Risiko mittel) |
| Charts | fl_chart | 1.2.0 | Balken/Linien/Donut des Erklärbuchs + Kennzahlen |
| PDF-Export | printing + pdf | 5.15.0 / 3.13.0 | #/doc "ganze Arbeit als PDF drucken" |
| Links | url_launcher | 6.3.2 | offizielle Seiten, DOI-Links |
| Prefs | shared_preferences | 2.5.5 | nur Kleinkram (Theme, letzte Route); ALLES Fachliche liegt in Drift |
| Code-Highlight | flutter_highlight | 0.7.0 | LaTeX-/Code-Ansicht im Editor (funktioniert dank Dart-3-Kompat-Regel für >=2.12) |
| Split-Layout | multi_split_view | 3.6.2 | Studio-3-Spalten mit Drag-Resize + Einklappen; Breiten persistieren |
| Listen | scrollable_positioned_list | 0.3.8 | Absatz-Anker-Sprünge im Lesen/Prüfen-Modus |
| Immutable Models | freezed + json_serializable | 3.2.5 / 6.14.0 | Datenmodelle aus JSON-Bundles |
| HTTP | (dart:io HttpClient / http) | — | Download-Engine, Claude/OpenAI-API |

## Bewusste Abweichungen vom Original (werden in getmedoc.md dokumentiert)
1. **OCR (Tesseract deu+eng)**: kein tragfähiges Cross-Plattform-Flutter-Plugin (Web+Desktop). → V1: nicht umgesetzt, UI-Platz mit erklärendem Hinweis. Dokumentierte Erweiterungsoption: tesseract via FFI (Desktop) / ML Kit (Mobile).
2. **Erklärbuch JS-/Python-Zellen (Pyodide)**: Zellen werden gerendert (Code + gespeicherte Ausgabe), aber nicht ausgeführt. Charts/Tabellen/Mathe/include/figure laufen nativ.
3. **localStorage/IndexedDB → Drift (SQLite)**: der gesamte Fachzustand (Belegstand, Instanzen, Notizen, Markierungen, Projekte, Dateien/PDF-Blobs) wandert in ein relationales Schema mit Projekt-Namespacing als Spalte statt Key-Präfix. JSON-Export/-Import (belegstand.json, Resolution-Format) bleibt 100% format-kompatibel.
4. **Zugangs-Gate (gate.js, SHA-256)**: entfällt in der App (kein statisches Hosting-Szenario); dokumentiert.
5. **Fonts**: woff2 → ttf konvertiert (Flutter lädt kein woff2 als Asset-Font).

## Architektur-Eckpfeiler
- `flutter_conversion/` als eigenständiges Flutter-Projekt im Repo, Original bleibt unberührt.
- Feature-First-Struktur: `lib/features/<studio|quellen|analyse|projekt|hilfe|doc>/`, `lib/core/<theme|router|db|data|ai|pdf|widgets>/`
- Routenbaum: eigene Datei, deklarativ, mit Legacy-Redirects (#/lesen → /studio/... etc.), StatefulShellRoute für Topbar+Footer-Shell.
- Seed: JSON-Bundles (data/parsed + data/generated) als Assets, Erst-Start-Import in Drift, danach DB-first.
