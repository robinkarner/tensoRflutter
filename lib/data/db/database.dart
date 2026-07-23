/// Drift-Schema — die EINE lokale Datenbank der App (E7: gesamter
/// Fachzustand in SQLite statt localStorage + 3 IndexedDB-Datenbanken).
///
/// Abbildung der Original-Speicher:
///
/// | Original                              | Tabelle    |
/// |---------------------------------------|------------|
/// | IndexedDB `ehds-projects.projects`    | [Projects] |
/// | localStorage `ehds.[<proj>.]<key>`    | [Kv]       |
/// | IndexedDB `ehds-pdfstore.blobs`       | [PdfBlobs] |
/// | IndexedDB `ehds-figstore.imgs`        | [FigImgs]  |
/// | localStorage `ehds.ocrText` (global)  | [OcrTexts] |
///
/// Grundsätze:
///  * Projekt-Records und KV-Werte bleiben ROHES JSON (Text-Spalte) — die
///    Export-Formate sind bit-kompatibel, unbekannte Fremd-Felder überleben
///    jeden Roundtrip (Dossier 07 §9.3).
///  * Die virtuelle Default-Arbeit `'default'` steht NIE in [Projects] —
///    exakt wie im Original (projects.js: nur Instanzen in IndexedDB).
///  * Datei-/Bild-Blobs sind arbeitsübergreifend (Zwei-Ebenen-Modell,
///    Master §6): keine projectId an [PdfBlobs]/[FigImgs]/[OcrTexts].
library;

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'daos/fig_imgs_dao.dart';
import 'daos/file_blobs_dao.dart';
import 'daos/kv_dao.dart';
import 'daos/ocr_dao.dart';
import 'daos/projects_dao.dart';

part 'database.g.dart';

// ---------------------------------------------------------------------------
// Tabellen
// ---------------------------------------------------------------------------

/// Projekt-Records (Arbeiten/Instanzen) — Pendant zu IndexedDB
/// `ehds-projects` (keyPath `id`). Der komplette Record inkl. LaTeX-Quelltext
/// liegt als JSON-String in [jsonValue] (nicht normalisiert — Export/Import
/// erwartet 1:1 dieselbe Struktur, `thesis-studio-projekt` v1).
@DataClassName('ProjectRow')
class Projects extends Table {
  TextColumn get id => text()();

  /// Der rohe ProjectRecord als JSON.
  TextColumn get jsonValue => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Key-Value-Zustand — Pendant zum localStorage-Schema
/// `'ehds.' + (key ∈ PROJECT_KEYS ? '<projektId>.' : '') + key`:
///
///  * [projectId] `''` = unpräfixiert — trägt sowohl die globalen Keys
///    (theme, activeProject, …) als auch den Prüfstand der Default-Arbeit
///    (genau wie im Original beide ohne Projekt-Segment liegen).
///  * [projectId] `'<id>'` = projekt-gescopter Key einer Instanz-Arbeit.
///
/// [jsonValue] ist der JSON-serialisierte Wert; RAW-Keys (activeProject)
/// speichern den nackten String (Typ-Mix wie im Original, Master §6).
@DataClassName('KvRow')
class Kv extends Table {
  TextColumn get projectId => text()();
  TextColumn get key => text()();
  TextColumn get jsonValue => text()();

  @override
  Set<Column> get primaryKey => {projectId, key};
}

/// PDF-/Bild-Blobs — Pendant zu IndexedDB `ehds-pdfstore.blobs` mit dem
/// Schlüsselschema 1:1 (pdfstore.js:44-51):
///
///  * `<srcId>`               Haupt-PDF einer Quelle
///  * `inbox:<Dateiname>`     Ablage (importiert, unzugewiesen)
///  * `img:<srcId>`           Quelle als Bild definiert
///  * `<srcId>~x<ts36><rand>` weiteres Material (U.extraKey)
///
/// Arbeitsübergreifend — PDFs werden über die Quellen-id geteilt.
@DataClassName('PdfBlobRow')
class PdfBlobs extends Table {
  TextColumn get key => text()();
  BlobColumn get data => blob()();

  /// MIME-Typ (Original speichert Blob/File samt type) — für Bilder relevant.
  TextColumn get mime => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Hochgeladene Abbildungs-Blobs — Pendant zu IndexedDB `ehds-figstore.imgs`
/// (Key = figId). Ebenfalls arbeitsübergreifend.
@DataClassName('FigImgRow')
class FigImgs extends Table {
  TextColumn get figId => text()();
  BlobColumn get data => blob()();
  TextColumn get mime => text().nullable()();

  @override
  Set<Column> get primaryKey => {figId};
}

/// OCR-Texte je Quelle+Seite — Pendant zum globalen localStorage-Key
/// `ehds.ocrText` (`{srcId: {page: text}}`). Bewusst arbeitsübergreifend
/// (die PDFs teilen sich alle Arbeiten, util.js:280). Als eigene Tabelle
/// statt KV-Blob, weil einzelne Seiten gelesen/geschrieben werden.
@DataClassName('OcrRow')
class OcrTexts extends Table {
  TextColumn get srcId => text()();
  IntColumn get page => integer()();
  TextColumn get content => text()();

  @override
  Set<Column> get primaryKey => {srcId, page};
}

// ---------------------------------------------------------------------------
// Datenbank
// ---------------------------------------------------------------------------

/// Die App-Datenbank. Plattform-Anbindung über drift_flutter
/// (nativ: SQLite-Datei im App-Support-Verzeichnis; Web: WASM/OPFS über
/// `web/sqlite3.wasm` + `web/drift_worker.js`). Tests injizieren einen
/// eigenen Executor (`NativeDatabase.memory()`).
@DriftDatabase(
  tables: [Projects, Kv, PdfBlobs, FigImgs, OcrTexts],
  daos: [ProjectsDao, KvDao, FileBlobsDao, FigImgsDao, OcrDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() => driftDatabase(
        name: 'thesis_studio',
        web: DriftWebOptions(
          sqlite3Wasm: Uri.parse('sqlite3.wasm'),
          driftWorker: Uri.parse('drift_worker.js'),
        ),
      );
}

/// Die Datenbank als App-weiter Singleton-Provider; der explizite Reboot
/// (E8) invalidiert diesen Knoten NICHT — die DB überlebt Projektwechsel,
/// nur die Daten-Sichten darüber werden neu aufgebaut.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
