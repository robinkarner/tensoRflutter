# Thesis Studio — Flutter-Konvertierung

Vollständige Flutter-Neuimplementierung der thesoR-Web-App **„Thesis Studio"** (KI-gestützte
Quellen- und Belegarbeit für wissenschaftliche Arbeiten). Das Original (Vanilla JS, im
Repo-Root) bleibt unberührt — dieses Verzeichnis ist eine eigenständige App mit nahezu
identischem Aussehen und Verhalten.

**Referenzdokument:** [`getmedoc.md`](getmedoc.md) — Architektur, alle Designentscheidungen,
Datenbankschema mit Testdaten, Mappings Original→Flutter, Riverpod-/State-Konzept,
Schnittstellen. Die Bestandsaufnahme des Originals liegt in [`docs/inventory/`](docs/inventory/),
der Bau-Fahrplan in [`docs/BAUPLAN.md`](docs/BAUPLAN.md), der Schnittstellen-Vertrag in
[`docs/CONTRACTS.md`](docs/CONTRACTS.md).

## Was drin ist

- **Studio** — 3-Spalten-Arbeitsraum (Kapitelbaum · Inhalt · Quellen-Spalte) mit Drag-Resize
  und Einklapp-Rails; Modi ☰ Lesen / ◉ Analyse / ✎ LaTeX; Beleg-Workflow ✦ → ❝ → ✓ mit
  Beleg-Dock, Instanz-Fenstern und Referenzierungs-Vollbild
- **PDF-Engine** — Endlos-Scroll-Viewer (pdfrx/pdfium), Text markieren → Zitat + Seite landen
  im aktiven Beleg (zoominvariante Markierungen, Kommentar-Pins), Volltextsuche, Quell-Karte
  mit Download-Engine und Datei-Zuordnung
- **Quellen** — Bibliothek im Zotero-Layout, Dossiers, Zitierstellen, Erwähnungen,
  Fundstellen-Register, Import (PDF/ZIP), Datei-Auftrag-Export, Belegstand Sichern/Laden
  (bit-kompatibel zur Web-App)
- **Wissen** — Erklärbuch (Markdown-Notebook mit Charts, Tabellen, Mathe, Figuren),
  Analysemodus, Überblick, Kapitel, Connections-Visualisierung, Würdigung, Kennzahlen
- **Status/Projekt** — Dashboard, Quellen-Setup, Referenzierungsdurchläufe, Mehrfach-Arbeiten
  (neue Arbeit aus `.tex` mit Live-Parse), Analysen-Import
- **KI-Schicht** — Generate-GPT-Hub, 7 Flows mit Prompt→Format-Checker→Import,
  ✦ Magic-Dock, Claude-API-Client (SSE) mit Demo-Modus — alles auch ohne API-Key per
  ⧉ Kopieren / ⭱ Einfügen nutzbar

Alle Fachdaten liegen in einer **SQLite-Datenbank (Drift)** — auf dem Web über WASM/OPFS,
nativ als Datei. Die beiden eingebauten Arbeiten (EHDS-Bachelorarbeit, Sensors-Paper) werden
beim ersten Start aus den gebündelten Assets eingespielt.

## Voraussetzungen

- **Flutter ≥ 3.44** (Dart ≥ 3.12) — entwickelt und getestet mit Flutter 3.44.7 / Dart 3.12.2
- Für Desktop-Targets zusätzlich die üblichen Plattform-Toolchains (siehe `flutter doctor`)

## Starten

```bash
cd flutter_conversion
flutter pub get

# Codegen-Artefakte (freezed/riverpod/drift) sind eingecheckt.
# Nur nach Modell-/Provider-/Schema-Änderungen nötig:
dart run build_runner build --delete-conflicting-outputs

# Web (empfohlen zum Ausprobieren):
flutter run -d chrome
# → web/sqlite3.wasm und web/drift_worker.js liegen bei (siehe web/DRIFT-WEB-ARTEFAKTE.md)

# Desktop:
flutter run -d linux    # bzw. -d windows / -d macos
# Android / iOS:
flutter run -d <gerät>
```

Tests und Release-Build:

```bash
flutter test                     # komplette Suite (Golden-, Roundtrip-, Widget-Tests)
flutter build web --release      # Ergebnis in build/web/
```

## Deployment (GitHub Pages)

Die App wird als **eigenständige Web-Instanz** über GitHub Pages veröffentlicht.
Der Workflow [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml) baut
`flutter build web` und deployt das Ergebnis.

**Einmalige Einrichtung:** In den Repo-Einstellungen unter **Settings → Pages**
die Quelle auf **„GitHub Actions"** stellen.

Danach gilt:

- **Push auf `main`** → Build **und** Deploy. Die Live-Instanz liegt unter
  `https://<owner>.github.io/<repo>/` (hier
  `https://robinkarner.github.io/tensoRflutter/`).
- **Push auf jeden anderen Branch / Pull Request** → nur **Build-Check**
  (kein Deploy), damit Kompilierfehler früh auffallen.
- **Actions → „Deploy Web to GitHub Pages" → Run workflow** deployt manuell.

Der Basis-Pfad wird automatisch aus dem Repo-Namen gesetzt
(`--base-href "/<repo>/"`), die Groß-/Kleinschreibung stimmt dadurch immer.
Die App nutzt **Hash-Routing** (`…/#/studio/…`), deshalb funktionieren tiefe
Links auf Pages ohne Server-Rewrite; eine `404.html` (Kopie der `index.html`)
liegt als zusätzliche Absicherung bei. Getestet mit **Flutter 3.44.7**.

> Hinweis: Für den Web-Build ist der `hooks:`-Block im `pubspec.yaml`
> irrelevant (Web nutzt `sqlite3.wasm`/OPFS statt der nativen sqlite3-Binaries).

### Hinweis zum `hooks:`-Block im pubspec.yaml

`sqlite3` und `pdfrx` laden beim ersten nativen Build vorkompilierte Binaries herunter
(GitHub Releases). Der Block

```yaml
hooks:
  user_defines:
    sqlite3:
      source: system
```

existiert nur, weil die Build-Umgebung dieser Konvertierung solche Downloads blockiert —
er bindet stattdessen das System-`libsqlite3` ein. **Auf einem normalen Entwickler-Rechner
kann der Block entfernt werden** (dann wird das gebündelte SQLite verwendet, empfohlen für
Android/iOS/Windows). Details in `web/DRIFT-WEB-ARTEFAKTE.md` und `getmedoc.md`.

## Projektstruktur (Kurzfassung)

```
lib/
  core/        Theme (Book-Cloth-Tokens), Router, App-Shell, Basis-Widgets, RichText-Builder
  data/        Modelle (freezed), Bundle-Loader, Drift-DB + KV, Export-Formate, Repositories
  domain/      Reine Logik-Ports: Levels, Connections, Mentions, StyleCheck, TexParse, Editor
  features/    studio · quellen · pdf · wissen · projekt · hilfe · doc · ai
  app_wiring.dart   Zentrale Slot-/Hook-Verdrahtung zwischen den Features
assets/        Daten der eingebauten Arbeiten, Abbildungen, Fonts, Original-Thesis-PDF
test/          Golden-Tests gegen das Original-JS, Export-Roundtrips, Widget-Tests
docs/          Bestandsaufnahme (inventory/), BAUPLAN, CONTRACTS, TECH-DECISIONS
```

Vollständige Erklärung aller Schichten, Schemata und Entscheidungen: **[`getmedoc.md`](getmedoc.md)**.
