/// DAO für hochgeladene Abbildungs-Blobs — Pendant zur IndexedDB
/// `ehds-figstore.imgs` (figures.js:13-32).
library;

import 'package:drift/drift.dart';

import '../database.dart';

part 'fig_imgs_dao.g.dart';

@DriftAccessor(tables: [FigImgs])
class FigImgsDao extends DatabaseAccessor<AppDatabase> with _$FigImgsDaoMixin {
  FigImgsDao(super.db);

  /// Alle fig-ids mit hochgeladenem Bild (Pendant zu getAllKeys beim init).
  Future<List<String>> allIds() async {
    final query = selectOnly(figImgs)..addColumns([figImgs.figId]);
    final rows = await query.get();
    return [for (final r in rows) r.read(figImgs.figId)!];
  }

  Future<FigImgRow?> read(String figId) =>
      (select(figImgs)..where((t) => t.figId.equals(figId))).getSingleOrNull();

  Future<void> write(String figId, Uint8List data, {String? mime}) =>
      into(figImgs).insertOnConflictUpdate(FigImgsCompanion.insert(
        figId: figId,
        data: data,
        mime: Value(mime),
      ));

  Future<void> remove(String figId) =>
      (delete(figImgs)..where((t) => t.figId.equals(figId))).go();
}
