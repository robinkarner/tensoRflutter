/// Typisierter KV-Zugriff — Pendant zu `U.storeGet`/`U.storeSet` samt
/// Projekt-Scoping (util.js:195-211).
///
/// Namensschema des Originals: `'ehds.' + (scoped ? '<projektId>.' : '') + key`.
/// In der DB entfällt das `ehds.`-Präfix — das Scoping bildet die Spalte
/// `projectId` ab: `''` = unpräfixiert (globale Keys UND der Prüfstand der
/// Default-Arbeit teilen sich wie im Original denselben Namensraum),
/// `'<id>'` = projekt-gescopter Key einer Instanz-Arbeit.
///
/// Gescoped wird NUR die [KvKeys.projectKeys]-Whitelist (26 Einträge,
/// util.js:200-201 — W1: Dossier 07 hatte sich mit „25" verzählt).
library;

import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'daos/kv_dao.dart';
import 'database.dart';

part 'kv.g.dart';

// ---------------------------------------------------------------------------
// Key-Konstanten
// ---------------------------------------------------------------------------

/// Alle bekannten Store-Keys. Die Namen sind Vertrag (Export-Formate,
/// Migration aus der Web-App) — niemals umbenennen.
abstract final class KvKeys {
  // --- Projekt-gescopte Keys (PROJECT_KEYS-Whitelist, util.js:200-201) ---
  static const belegLevels = 'belegLevels';
  static const annotations = 'annotations';
  static const resolutions = 'resolutions';
  static const pdfManual = 'pdfManual';
  static const linkOverrides = 'linkOverrides';
  static const srcNotes = 'srcNotes';
  static const srcTexts = 'srcTexts';
  static const texEdits = 'texEdits';
  static const pdfMarks = 'pdfMarks';
  static const customSources = 'customSources';
  static const kiConnections = 'kiConnections';
  static const textMentions = 'textMentions';
  static const fileSearch = 'fileSearch';
  static const dlStatus = 'dlStatus';
  static const paraDock = 'paraDock';
  static const paraEdits = 'paraEdits';
  static const dockBySection = 'dockBySection';
  static const marksExtra = 'marksExtra';
  static const notebook = 'notebook';
  static const studioLast = 'studioLast';
  static const assignDismissed = 'assignDismissed';
  static const fnEdits = 'fnEdits';
  static const belegSpans = 'belegSpans';
  static const titleEdits = 'titleEdits';
  static const srcDoc = 'srcDoc';
  static const srcExtras = 'srcExtras';

  /// Die Whitelist in Original-Reihenfolge — exakt 26 Einträge (W1,
  /// verifiziert an util.js:200-201).
  static const List<String> projectKeys = [
    belegLevels, annotations, resolutions, pdfManual, linkOverrides,
    srcNotes, srcTexts, texEdits, pdfMarks, customSources, kiConnections,
    textMentions, fileSearch, dlStatus, paraDock, paraEdits, dockBySection,
    marksExtra, notebook, studioLast, assignDismissed, fnEdits, belegSpans,
    titleEdits, srcDoc, srcExtras,
  ];

  // --- Globale Keys (nie gescoped; Master §6) ---

  /// Aktive Arbeit — RAW-String, KEIN JSON (`ehds.activeProject`).
  static const activeProject = 'activeProject';

  /// Tombstone-Liste gelöschter Builtin-Arbeiten (JSON-Array).
  static const builtinDeleted = 'builtinDeleted';

  /// Einmal-Import-Flag für den Repo-Belegstand (app.js:25).
  static const belegstandImported = 'belegstandImported';

  static const theme = 'theme';
  static const claudeCfg = 'claudeCfg';
  static const enhCfg = 'enhCfg';
  static const instDefs = 'instDefs';
  static const pdfZoomPref = 'pdfZoomPref';
  static const qColl = 'qColl';
  static const qSort = 'qSort';
  static const uiLibPct = 'uiLibPct';

  /// RAW-Keys: Wert ist der nackte String ohne JSON-Hülle. (`gateOk`
  /// existiert nicht mehr — das Passwort-Gate entfällt, E6.)
  static const Set<String> rawKeys = {activeProject};
}

/// Schneller Mitgliedstest der Whitelist.
final Set<String> _projectKeySet = Set.unmodifiable(KvKeys.projectKeys);

// ---------------------------------------------------------------------------
// KvStore
// ---------------------------------------------------------------------------

/// Der Store. [storeProject] ist das Pendant zu `U.storeProject`: `''` für
/// die Default-Arbeit, sonst die Projekt-id — gesetzt vom Boot-Fluss
/// (ProjectRepository.boot), und zwar VOR dem Laufzeitaufbau, damit ein
/// Fehler dort nicht den Prüfstand der Default-Arbeit kontaminiert
/// (projects.js:40-42).
class KvStore {
  KvStore(this._dao);

  final KvDao _dao;

  /// `''` = Default-Arbeit (unpräfixiert), sonst Projekt-id.
  String storeProject = '';

  /// Scope-Regel des Originals (util.js:202-205): gescoped wird nur, wenn
  /// eine Instanz-Arbeit aktiv ist UND der Key auf der Whitelist steht.
  String scopeFor(String key) =>
      (storeProject.isNotEmpty && _projectKeySet.contains(key)) ? storeProject : '';

  // --- JSON-Zugriff (Pendant zu storeGet/storeSet) ---

  /// Wert lesen. Semantik wie `U.storeGet`: fehlender/leerer Eintrag oder
  /// Parse-Fehler → [fallback]; ein gespeichertes `null`/`false` wird
  /// (wie `JSON.parse`) unverändert zurückgegeben.
  Future<Object?> getJson(String key, [Object? fallback]) async {
    final raw = await _dao.read(scopeFor(key), key);
    if (raw == null || raw.isEmpty) return fallback;
    try {
      return json.decode(raw);
    } catch (_) {
      return fallback;
    }
  }

  /// Wert als JSON schreiben (Fehler wären hier echte DB-Fehler, kein
  /// „Speicher voll/privat"-Fall wie bei localStorage — sie propagieren).
  Future<void> setJson(String key, Object? value) =>
      _dao.write(scopeFor(key), key, json.encode(value));

  /// Key im aktuellen Scope entfernen.
  Future<void> remove(String key) => _dao.remove(scopeFor(key), key);

  /// Bequemlichkeit: Objekt-Wert als `Map<String, dynamic>` (Nicht-Objekte
  /// und Fehler → leere Map bzw. [fallback]).
  Future<Map<String, dynamic>> getMap(String key,
      [Map<String, dynamic> fallback = const {}]) async {
    final v = await getJson(key);
    return v is Map<String, dynamic> ? v : fallback;
  }

  /// Bequemlichkeit: Array-Wert als Liste.
  Future<List<Object?>> getList(String key,
      [List<Object?> fallback = const []]) async {
    final v = await getJson(key);
    return v is List ? List<Object?>.from(v) : fallback;
  }

  /// Live-Beobachtung eines Keys im aktuellen Scope (dekodiert).
  Stream<Object?> watchJson(String key) =>
      _dao.watch(scopeFor(key), key).map((raw) {
        if (raw == null || raw.isEmpty) return null;
        try {
          return json.decode(raw);
        } catch (_) {
          return null;
        }
      });

  // --- RAW-Zugriff (globale Keys ohne JSON-Hülle, z. B. activeProject) ---

  Future<String?> getRawGlobal(String key) => _dao.read('', key);

  Future<void> setRawGlobal(String key, String value) => _dao.write('', key, value);

  // --- Boot-Hilfen ---

  /// Gibt es im AKTUELLEN Scope irgendeinen erfassten Fachzustand?
  /// Pendant zur Import-Once-Prüfung (app.js:26-29): alle PROJECT_KEYS außer
  /// `studioLast`; truthy heißt: nicht-leeres Array, nicht-leeres Objekt oder
  /// ein sonstiger truthy Wert.
  Future<bool> hasAnyProjectState() async {
    for (final key in KvKeys.projectKeys) {
      if (key == KvKeys.studioLast) continue;
      final v = await getJson(key);
      if (v == null) continue;
      if (v is List) {
        if (v.isNotEmpty) return true;
      } else if (v is Map) {
        if (v.isNotEmpty) return true;
      } else if (v != false && v != 0 && v != '') {
        return true;
      }
    }
    return false;
  }
}

/// Der Store als Provider — teilt sich die App-Datenbank.
@Riverpod(keepAlive: true)
KvStore kvStore(Ref ref) => KvStore(ref.watch(appDatabaseProvider).kvDao);
