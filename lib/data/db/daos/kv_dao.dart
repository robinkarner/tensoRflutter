/// DAO für die KV-Tabelle — die rohe Lese-/Schreibschicht unter [KvStore]
/// (lib/data/db/kv.dart). Werte sind hier nur Strings; Scoping und
/// JSON-Semantik liegen eine Ebene höher.
library;

import 'package:drift/drift.dart';

import '../database.dart';

part 'kv_dao.g.dart';

@DriftAccessor(tables: [Kv])
class KvDao extends DatabaseAccessor<AppDatabase> with _$KvDaoMixin {
  KvDao(super.db);

  /// Gespeicherter Roh-String oder null.
  Future<String?> read(String projectId, String key) async {
    final row = await (select(kv)
          ..where((t) => t.projectId.equals(projectId) & t.key.equals(key)))
        .getSingleOrNull();
    return row?.jsonValue;
  }

  /// Wert schreiben (Upsert).
  Future<void> write(String projectId, String key, String value) =>
      into(kv).insertOnConflictUpdate(
        KvCompanion.insert(projectId: projectId, key: key, jsonValue: value),
      );

  /// Key entfernen.
  Future<void> remove(String projectId, String key) => (delete(kv)
        ..where((t) => t.projectId.equals(projectId) & t.key.equals(key)))
      .go();

  /// Live-Beobachtung eines Keys (für reaktive Provider späterer Wellen).
  Stream<String?> watch(String projectId, String key) => (select(kv)
        ..where((t) => t.projectId.equals(projectId) & t.key.equals(key)))
      .watchSingleOrNull()
      .map((row) => row?.jsonValue);
}
