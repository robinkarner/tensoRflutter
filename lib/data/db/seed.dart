/// Erst-Start-Seeding — zwei getrennte Einmal-Vorgänge:
///
///  1. **Builtin-Arbeiten** (sensors-paper aus dem Bundle) in die Projekt-
///     Tabelle einspielen — exakt die Original-Logik (projects.js:66-79):
///     Tombstones gewinnen immer, Nutzer-veränderte Stände werden bei
///     Versionssprüngen nie überschrieben.
///  2. **Belegstand aus dem Repo** (app.js:23-41): der mitgelieferte
///     Prüfstand der Default-Arbeit wird genau EINMAL importiert — und nur,
///     wenn lokal noch in KEINEM Fach-Store etwas erfasst wurde (Lokales
///     gewinnt immer; importState überschreibt alle Bereiche, deshalb reicht
///     der Blick auf belegLevels allein nicht).
///
/// Die Bundle-Daten der Default-Arbeit selbst (thesis/sections/…) bleiben
/// Assets — sie sind read-only Material und brauchen keine DB-Kopie
/// (Dossier 10 §9.12; die Runtime lädt sie über den Bundle-Loader).
library;

import 'package:flutter/services.dart';

import '../export/belegstand.dart';
import '../models/models.dart';
import 'daos/projects_dao.dart';
import 'kv.dart';

/// Asset-Pfad des optionalen Repo-Belegstands (Original: data/belegstand.json,
/// per fetch geladen — Datei optional, Fehlen ist kein Fehler).
const String belegstandAsset = 'assets/data/belegstand.json';

/// Builtin-Arbeiten einspielen (Pendant zu `Projects.seedBuiltins`):
/// Tombstone → nie; nicht vorhanden → rein; vorhanden → nur ersetzen, wenn
/// `builtinVersion` größer UND der Bestand nicht `userModified` ist.
/// Fehler je Record werden geschluckt (wie das leere catch des Originals) —
/// ein kaputter Builtin darf den Boot nicht reißen.
Future<void> seedBuiltinProjects({
  required ProjectsDao dao,
  required KvStore kv,
  required List<ProjectRecord> builtins,
}) async {
  if (builtins.isEmpty) return;
  final deleted = (await kv.getList(KvKeys.builtinDeleted)).whereType<String>().toSet();
  for (final bp in builtins) {
    if (bp.id.isEmpty || deleted.contains(bp.id)) continue;
    try {
      final ex = await dao.getById(bp.id);
      if (ex == null) {
        await dao.upsert(bp);
      } else if (ex.builtinVersion < bp.builtinVersion && !ex.userModified) {
        await dao.upsert(bp);
      }
    } catch (_) {
      // Einzelner Builtin nicht seedbar — still weiter (Original ebenso).
    }
  }
}

/// Einmal-Import des Repo-Belegstands (Pendant zu app.js:23-41).
/// Voraussetzungen prüft die Funktion selbst: Import-Flag noch nicht
/// gesetzt UND kein lokaler Fachzustand (alle PROJECT_KEYS außer
/// `studioLast` leer). Der Aufrufer stellt sicher, dass die DEFAULT-Arbeit
/// aktiv ist ([KvStore.storeProject] == '').
///
/// Rückgabe: true, wenn tatsächlich importiert wurde.
Future<bool> importRepoBelegstandOnce(
  KvStore kv, {
  AssetBundle? bundle,
  String asset = belegstandAsset,
}) async {
  final already = await kv.getJson(KvKeys.belegstandImported, false);
  if (already == true) return false;
  if (await kv.hasAnyProjectState()) return false;

  final String text;
  try {
    text = await (bundle ?? rootBundle).loadString(asset);
  } catch (_) {
    return false; // Datei optional — gehostet ohne Belegstand ist normal.
  }

  try {
    await Belegstand.importState(kv, text);
    await kv.setJson(KvKeys.belegstandImported, true);
    return true;
  } catch (_) {
    return false; // kaputte Datei: still ignorieren (Original: try/catch)
  }
}
