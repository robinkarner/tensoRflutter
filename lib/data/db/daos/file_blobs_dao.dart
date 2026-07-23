/// DAO für den Datei-Speicher (PDF-/Bild-Blobs) — Pendant zur
/// IndexedDB `ehds-pdfstore.blobs`. Die Schlüssel-Klassifikation
/// (`inbox:` / `img:` / plain) übernimmt der [FileStore] darüber.
library;

import 'package:drift/drift.dart';

import '../database.dart';

part 'file_blobs_dao.g.dart';

@DriftAccessor(tables: [PdfBlobs])
class FileBlobsDao extends DatabaseAccessor<AppDatabase> with _$FileBlobsDaoMixin {
  FileBlobsDao(super.db);

  /// Alle Schlüssel (Pendant zu getAllKeys beim init).
  Future<List<String>> allKeys() async {
    final query = selectOnly(pdfBlobs)..addColumns([pdfBlobs.key]);
    final rows = await query.get();
    return [for (final r in rows) r.read(pdfBlobs.key)!];
  }

  Future<PdfBlobRow?> read(String key) =>
      (select(pdfBlobs)..where((t) => t.key.equals(key))).getSingleOrNull();

  Future<Uint8List?> readData(String key) async => (await read(key))?.data;

  Future<void> write(String key, Uint8List data, {String? mime}) =>
      into(pdfBlobs).insertOnConflictUpdate(PdfBlobsCompanion.insert(
        key: key,
        data: data,
        mime: Value(mime),
      ));

  Future<void> remove(String key) =>
      (delete(pdfBlobs)..where((t) => t.key.equals(key))).go();

  /// ALLE Blobs löschen (inkl. inbox/img) — Pendant zu `PdfStore.clearAll`.
  Future<void> removeAll() => delete(pdfBlobs).go();
}
