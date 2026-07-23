# Drift-Web-Artefakte (sqlite3.wasm + drift_worker.js)

`AppDatabase` (lib/data/db/database.dart) öffnet die Datenbank im Web über
`DriftWebOptions(sqlite3Wasm: 'sqlite3.wasm', driftWorker: 'drift_worker.js')` —
beide Dateien müssen deshalb hier in `web/` liegen (werden von `flutter build web`
unverändert nach `build/web/` kopiert).

Herkunft (Gate 0, 2026-07-23 — GitHub-Releases waren vom Sandbox-Proxy blockiert,
darum aus dem Pub-Cache bezogen statt von den offiziellen Release-Seiten):

| Datei | Quelle | Stand |
|---|---|---|
| `drift_worker.js` | `drift-2.34.2/drift_worker.js` (vom drift-Team vorkompiliert, identische Paketversion wie im Lockfile) | drift 2.34.2 |
| `sqlite3.wasm` | `drift-2.34.2/extension/devtools/build/sqlite3.wasm` (sqlite3.dart-Build, SQLite 3.53.3) | maschinell verifiziert: alle 78 von `package:sqlite3` 3.5.0 (`wasm_interop.dart`) erwarteten Exporte vorhanden |

Bei einem Upgrade von `drift`/`sqlite3` in pubspec.yaml diese beiden Dateien
mit aktualisieren — kanonische Quellen:
* https://github.com/simolus3/sqlite3.dart/releases (sqlite3.wasm)
* https://github.com/simolus3/drift/releases bzw. `dart compile js -O4
  web/drift_worker.dart` aus dem drift-Paket (drift_worker.js)
