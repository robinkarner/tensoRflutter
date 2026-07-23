/// DAO für Projekt-Records — Pendant zu `Projects._idb`/list/get/save/remove
/// (projects.js:81-93). Records gehen als rohes JSON rein und raus; die
/// typisierte Sicht liefert [ProjectRecord] aus den F-B-Modellen.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../models/models.dart';
import '../database.dart';

part 'projects_dao.g.dart';

@DriftAccessor(tables: [Projects])
class ProjectsDao extends DatabaseAccessor<AppDatabase> with _$ProjectsDaoMixin {
  ProjectsDao(super.db);

  /// Alle Records (unsortiert, wie IndexedDB getAll).
  Future<List<ProjectRecord>> getAll() async {
    final rows = await select(projects).get();
    return [for (final r in rows) _decode(r)];
  }

  /// Record per id oder null.
  Future<ProjectRecord?> getById(String id) async {
    final row = await (select(projects)..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _decode(row);
  }

  /// Upsert (Pendant zu IndexedDB put mit keyPath id).
  Future<void> upsert(ProjectRecord rec) => into(projects).insertOnConflictUpdate(
        ProjectsCompanion.insert(id: rec.id, jsonValue: json.encode(rec.toJson())),
      );

  Future<void> deleteById(String id) =>
      (delete(projects)..where((t) => t.id.equals(id))).go();

  ProjectRecord _decode(ProjectRow row) =>
      ProjectRecord.fromJson(json.decode(row.jsonValue) as Map<String, dynamic>);
}
