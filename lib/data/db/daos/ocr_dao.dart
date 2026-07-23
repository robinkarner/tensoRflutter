/// DAO für OCR-Texte je Quelle+Seite — Pendant zu `U.getOcr`/`U.setOcr`
/// (util.js:281-286). Global über alle Arbeiten (die PDFs sind geteilt).
///
/// OCR selbst entfällt in V1 (E3) — die Tabelle bleibt trotzdem Teil des
/// Schemas: der Cache ist Datenbestand (kann aus der Web-App migriert
/// werden) und die Ausbaustufe braucht keinen Schema-Bruch.
library;

import 'package:drift/drift.dart';

import '../database.dart';

part 'ocr_dao.g.dart';

@DriftAccessor(tables: [OcrTexts])
class OcrDao extends DatabaseAccessor<AppDatabase> with _$OcrDaoMixin {
  OcrDao(super.db);

  /// OCR-Text einer Seite oder null.
  Future<String?> read(String srcId, int page) async {
    final row = await (select(ocrTexts)
          ..where((t) => t.srcId.equals(srcId) & t.page.equals(page)))
        .getSingleOrNull();
    return row?.content;
  }

  Future<void> write(String srcId, int page, String text) =>
      into(ocrTexts).insertOnConflictUpdate(
        OcrTextsCompanion.insert(srcId: srcId, page: page, content: text),
      );

  /// Alle OCR-Seiten einer Quelle (page → text) — z. B. für die Volltextsuche.
  Future<Map<int, String>> allForSource(String srcId) async {
    final rows =
        await (select(ocrTexts)..where((t) => t.srcId.equals(srcId))).get();
    return {for (final r in rows) r.page: r.content};
  }
}
