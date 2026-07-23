/// Projekt-Repository — Pendant zu `Projects` (projects.js) + Boot-Teilen
/// von app.js. Liefert die effektiven Daten der aktiven Arbeit als
/// [ThesisRuntime] und bereitet den Reboot-Flow (E8) als Provider-
/// Invalidierung vor: statt `location.reload()` wird [ProjectBoot]
/// invalidiert — der komplette Daten-Graph (Runtime → Indizes → Views)
/// baut sich reaktiv neu, inklusive der Caches, die das Original vergaß
/// (Stale-Cache-Bug L2, bewusst gefixt).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../bundles/bundle_loader.dart';
import '../bundles/indexes.dart';
import '../db/daos/projects_dao.dart';
import '../db/database.dart';
import '../db/kv.dart';
import '../db/seed.dart';
import '../export/dateiauftrag.dart';
import '../export/projekt_format.dart';
import '../models/models.dart';
import 'file_store.dart';

part 'project_repository.g.dart';

// ---------------------------------------------------------------------------
// Effektive Quell-Links (U.srcLinks-Pendant)
// ---------------------------------------------------------------------------

/// Aufgelöste Links einer Quelle: Vorschläge + manuelle Overrides.
class EffectiveSrcLinks {
  final String? official;
  final String? file;

  /// true, wenn ein manueller Override existiert (`_override` im Original).
  final bool isOverride;

  const EffectiveSrcLinks({this.official, this.file, this.isOverride = false});
}

/// Link-Kaskade exakt wie util.js:236-245: Basis sind die vorgeschlagenen
/// Links der Quelle; fehlt `official`, ergibt DOI (bzw. URL) IMMER eine
/// offizielle Seite; manuelle Overrides gewinnen zuletzt.
EffectiveSrcLinks effectiveSrcLinks(Source s, Map<String, dynamic> override) {
  var official = s.links.official;
  if (official == null || official.isEmpty) {
    official = s.doi != null ? 'https://doi.org/${s.doi}' : s.url;
  }
  var file = s.links.file;
  final ovOfficial = override['official'];
  final ovFile = override['file'];
  if (ovOfficial is String && ovOfficial.isNotEmpty) official = ovOfficial;
  if (ovFile is String && ovFile.isNotEmpty) file = ovFile;
  return EffectiveSrcLinks(
    official: official,
    file: file,
    isOverride: (ovOfficial is String && ovOfficial.isNotEmpty) ||
        (ovFile is String && ovFile.isNotEmpty),
  );
}

// ---------------------------------------------------------------------------
// applyGeneratedFile (Analysen-Import-Routing)
// ---------------------------------------------------------------------------

/// Ergebnis von [ProjectRepository.applyGeneratedFile] — die vier
/// Ergebnisklassen des Originals (String | {registry} | {registryError} |
/// null) als ein Objekt. [rec] ist immer der (ggf. aktualisierte) Record.
class GeneratedApplyResult {
  final ProjectRecord rec;

  /// Erfolgsmeldung („Abschnitt 3_2_1.json", „Gesamtzusammenfassung", …).
  final String? label;

  /// registry.json erkannt — Anwendung erfolgt separat (ZULETZT!).
  final List<Object?>? registry;

  /// registry.json mit falscher Struktur.
  final String? registryError;

  const GeneratedApplyResult(this.rec, {this.label, this.registry, this.registryError});

  /// Datei war zuordenbar und wurde eingebaut.
  bool get applied => label != null;

  /// Weder zuordenbar noch Registry (⚠-Zeile im Import-Log).
  bool get unknown => label == null && registry == null && registryError == null;
}

// ---------------------------------------------------------------------------
// Boot-Ergebnis
// ---------------------------------------------------------------------------

/// Ergebnis des Boot-Flusses (Pendant zu Projects.boot + app.js:23-41).
class BootResult {
  /// Effektive Daten der aktiven Arbeit (Custom-Quellen bereits gemerged).
  final ThesisRuntime runtime;

  /// Text-Overrides des Prüfstands (paraEdits/fnEdits/titleEdits) — für
  /// den TextOverrides-Provider der Index-Schicht.
  final TextOverrideState overrides;

  /// 'default' oder Projekt-id.
  final String activeId;

  /// Anzeigename (Topbar/Status-Chip).
  final String activeName;

  /// Boot-Warnungen — werden auf #/projekt als Notices gezeigt.
  final List<String> warnings;

  /// true, wenn der Repo-Belegstand in diesem Boot erstmalig importiert wurde.
  final bool importedBelegstand;

  const BootResult({
    required this.runtime,
    required this.overrides,
    required this.activeId,
    required this.activeName,
    required this.warnings,
    this.importedBelegstand = false,
  });
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class ProjectRepository {
  ProjectRepository({required AppDatabase db, required this.kv})
      : _projects = db.projectsDao;

  final ProjectsDao _projects;
  final KvStore kv;

  /// Anzeigename der eingebauten Arbeit (projects.js:16).
  static const defaultActiveName = 'EHDS-Bachelorarbeit (eingebaut)';

  // --- CRUD (Pendant zu Projects.list/get/save/remove) ---

  Future<List<ProjectRecord>> list() => _projects.getAll();

  Future<ProjectRecord?> get(String id) => _projects.getById(id);

  Future<void> save(ProjectRecord rec) => _projects.upsert(rec);

  Future<void> remove(String id) => _projects.deleteById(id);

  /// Aktive Arbeit umschalten — schreibt nur den RAW-Key; der eigentliche
  /// Neustart läuft über [ProjectBoot.activateProject] (E8: Invalidierung
  /// statt `location.reload()`); die Navigation nach `#/projekt` übernimmt
  /// der Aufrufer (Original: `location.hash = '#/projekt'`).
  Future<void> setActive(String id) => kv.setRawGlobal(KvKeys.activeProject, id);

  /// Builtin-Arbeit löschen heißt: Record weg + Tombstone, sonst spielt
  /// das Seeding sie beim nächsten Start wieder ein (views_projekt.js:306-313).
  Future<void> removeWithTombstone(ProjectRecord rec) async {
    await remove(rec.id);
    if (rec.builtin) {
      final deleted = (await kv.getList(KvKeys.builtinDeleted)).whereType<String>().toSet()
        ..add(rec.id);
      await kv.setJson(KvKeys.builtinDeleted, deleted.toList());
    }
  }

  // --- Manuelle Quellen (Pendant zu Projects.customSources/save/remove) ---

  Future<List<Map<String, dynamic>>> customSources() async =>
      (await kv.getList(KvKeys.customSources)).whereType<Map<String, dynamic>>().toList();

  /// Upsert per id (projects.js:256-261): vorhandener Eintrag wird gemerged.
  Future<void> saveCustomSource(Map<String, dynamic> src) async {
    final all = await customSources();
    final i = all.indexWhere((s) => s['id'] == src['id']);
    if (i >= 0) {
      all[i] = {...all[i], ...src};
    } else {
      all.add(src);
    }
    await kv.setJson(KvKeys.customSources, all);
  }

  Future<void> removeCustomSource(String id) async {
    final all = await customSources();
    await kv.setJson(KvKeys.customSources, all.where((s) => s['id'] != id).toList());
  }

  // --- Import/Export einer Arbeit ---

  /// Import mit Kollisions-Dialog (projects.js:270-284). [confirmOverwrite]
  /// ist das confirm()-Pendant: true = überschreiben, false = als Kopie
  /// (id-Suffix `-kopie-<rand3>`, Name „ (Kopie)").
  Future<ProjectRecord> importProject(
    String jsonText, {
    required Future<bool> Function(String id, String existingName) confirmOverwrite,
  }) async {
    var rec = parseProjectImport(jsonText);
    final existing = await get(rec.id);
    if (existing != null && !await confirmOverwrite(rec.id, existing.name)) {
      final raw = Map<String, dynamic>.from(rec.raw);
      raw['id'] = copyProjectId(rec.id);
      raw['name'] = copyProjectName(raw['name'] as String?);
      rec = ProjectRecord.fromJson(raw);
    }
    await save(rec);
    return rec;
  }

  // --- Analysen-Import (Pendant zu Projects.applyGeneratedFile) ---

  /// Generierte Analyse-Datei einsortieren — 11-stufiges Dateiname-Mapping
  /// (projects.js:130-151). Arbeitet auf einer tiefen Kopie des rohen JSON
  /// (der übergebene Record bleibt unverändert — Riverpod-freundlich);
  /// `userModified` wird wie im Original IMMER gesetzt, auch wenn die Datei
  /// am Ende nicht zuordenbar war.
  GeneratedApplyResult applyGeneratedFile(ProjectRecord rec, String filename, Object? obj) {
    final raw = json.decode(json.encode(rec.raw)) as Map<String, dynamic>;
    raw['userModified'] = true;
    final existing = raw['generated'];
    final Map<String, dynamic> g = existing is Map<String, dynamic>
        ? existing
        : <String, dynamic>{
            'sections': <String, dynamic>{},
            'sources': <String, dynamic>{},
            'chapters': <String, dynamic>{},
            'gesamt': null,
            'fazit': null,
            'analyse': <String, dynamic>{},
            'connections': null,
          };
    raw['generated'] = g;
    Map<String, dynamic> sub(String key) {
      final v = g[key];
      if (v is Map<String, dynamic>) return v;
      final fresh = <String, dynamic>{};
      g[key] = fresh;
      return fresh;
    }

    final updated = ProjectRecord.fromJson(raw);
    GeneratedApplyResult ok(String label) => GeneratedApplyResult(updated, label: label);
    final unknown = GeneratedApplyResult(updated);

    final base = filename.replaceAll(RegExp(r'^.*[\\/]'), '');
    final isObj = obj is Map<String, dynamic>;
    final map = isObj ? obj : const <String, dynamic>{};

    if (RegExp(r'^\d+(_\d+)*\.json$').hasMatch(base)) {
      if (!isObj || map['paragraphs'] is! List) return unknown;
      sub('sections')[base.replaceAll('.json', '')] = map;
      return ok('Abschnitt $base');
    }
    final kapitel = RegExp(r'^kapitel-(\d+)\.json$').firstMatch(base);
    if (kapitel != null) {
      if (!isObj) return unknown;
      sub('chapters')[kapitel.group(1)!] = map;
      return ok(base);
    }
    if (base == 'gesamt.json') {
      if (!isObj) return unknown;
      g['gesamt'] = map;
      return ok('Gesamtzusammenfassung');
    }
    if (base == 'fazit-connections.json') {
      if (!isObj || map['findings'] is! List) return unknown;
      g['fazit'] = map;
      return ok('Fazit-Connections');
    }
    if (base == 'connections.json') {
      if (!isObj || map['connections'] is! List) return unknown;
      g['connections'] = map;
      return ok('Connections');
    }
    if (RegExp(r'^(struktur|quellen|inhalt|standards)\.json$').hasMatch(base)) {
      if (!isObj) return unknown;
      sub('analyse')[base.replaceAll('.json', '')] = map;
      return ok('Analyse: $base');
    }
    if (base == 'instanzen.json') {
      if (!isObj || map['defs'] is! List) return unknown;
      g['instanzen'] = map;
      return ok('Instanz-Set (${(map['defs'] as List).length} Instanzen)');
    }
    if (base == 'figures.json') {
      if (!isObj) return unknown;
      raw['figures'] = map;
      return ok('Abbildungs-Manifest');
    }
    if (base == 'registry.json') {
      if (obj is! List) {
        return GeneratedApplyResult(updated,
            registryError: 'registry.json muss ein ARRAY von Quellen sein');
      }
      return GeneratedApplyResult(updated, registry: List<Object?>.from(obj));
    }
    // Inhaltsbasiert: Dossier bzw. Abschnitt ohne passenden Dateinamen.
    if (isObj && map['sourceId'] != null && map['dossier'] != null) {
      sub('sources')[map['sourceId'].toString()] = map;
      return ok('Dossier ${map['sourceId']}');
    }
    if (isObj && map['sectionId'] != null && map['paragraphs'] is List) {
      sub('sections')[map['sectionId'].toString().replaceAll('.', '_')] = map;
      return ok('Abschnitt ${map['sectionId']}');
    }
    return unknown;
  }

  // --- Links + Datei-Auftrag ---

  /// Effektive Links einer Quelle (Vorschlag + Override), util.js:236-245.
  Future<EffectiveSrcLinks> srcLinks(Source s) async {
    final overrides = await kv.getMap(KvKeys.linkOverrides);
    final ov = overrides[s.id];
    return effectiveSrcLinks(s, ov is Map<String, dynamic> ? ov : const {});
  }

  /// Datei-Auftrag-ZIP für alle Quellen ohne Datei
  /// (Pendant zu exportDateiAuftrag, views_quellen.js:867-903).
  Future<Uint8List> exportDateiauftrag({
    required Iterable<Source> sources,
    required bool Function(String id) hasFile,
  }) async {
    final overrides = await kv.getMap(KvKeys.linkOverrides);
    final fileSearch = await kv.getMap(KvKeys.fileSearch);
    final eintraege = <DateiauftragEintrag>[];
    for (final s in sources) {
      if (hasFile(s.id)) continue;
      final ov = overrides[s.id];
      final links = effectiveSrcLinks(s, ov is Map<String, dynamic> ? ov : const {});
      final fsr = fileSearch[s.id];
      final venue = (fsr is Map && fsr['venue'] is String) ? fsr['venue'] as String : null;
      eintraege.add(Dateiauftrag.eintragFor(
        s,
        linkOffiziell: links.official,
        linkDatei: links.file,
        venue: venue,
      ));
    }
    return Dateiauftrag.buildZip(eintraege);
  }

  // --- Boot (Pendant zu Projects.boot + Einmal-Import aus app.js) ---

  Future<BootResult> boot(ThesisBundle bundle) async {
    final warnings = <String>[];
    var activeId = await kv.getRawGlobal(KvKeys.activeProject) ?? ProjectRecord.defaultId;
    if (activeId.isEmpty) activeId = ProjectRecord.defaultId;

    await seedBuiltinProjects(dao: _projects, kv: kv, builtins: bundle.builtinProjects);

    ThesisRuntime? runtime;
    var activeName = defaultActiveName;

    if (activeId != ProjectRecord.defaultId) {
      final rec = await get(activeId);
      if (rec == null) {
        warnings.add('Aktive Arbeit „$activeId“ nicht gefunden — zurück zur eingebauten Arbeit.');
        activeId = ProjectRecord.defaultId;
        await kv.setRawGlobal(KvKeys.activeProject, ProjectRecord.defaultId);
      } else {
        // Key-Scopierung IMMER vor dem Laufzeitaufbau — sonst könnte ein
        // Fehler hier den Prüfstand der eingebauten Arbeit kontaminieren
        // (projects.js:40-42).
        kv.storeProject = activeId;
        try {
          activeName = rec.name;
          runtime = ThesisRuntime.fromProjectRecord(rec);
        } catch (e) {
          warnings.add('Arbeit „${rec.name}“ ist nicht ladbar (${_errMsg(e)}) — '
              'zurück zur eingebauten Arbeit. Fehlerhafte Analyse-Dateien über '
              '„⭱ Analysen“ erneut importieren.');
          activeId = ProjectRecord.defaultId;
          activeName = defaultActiveName;
          await kv.setRawGlobal(KvKeys.activeProject, ProjectRecord.defaultId);
        }
      }
    }

    // Scope final setzen: '' für die Default-Arbeit (projects.js:53).
    kv.storeProject = activeId == ProjectRecord.defaultId ? '' : activeId;
    runtime ??= ThesisRuntime.fromBundle(bundle);

    // Repo-Belegstand genau einmal übernehmen — nur für die Default-Arbeit
    // und nur ohne lokalen Fachzustand (app.js:23-41).
    var importedBelegstand = false;
    if (activeId == ProjectRecord.defaultId) {
      importedBelegstand = await importRepoBelegstandOnce(kv);
    }

    // Manuelle Quellen einmischen (bereits projekt-gescoped gelesen).
    runtime = runtime.withMergedCustomSources(await customSources());

    return BootResult(
      runtime: runtime,
      overrides: await _loadTextOverrides(),
      activeId: activeId,
      activeName: activeName,
      warnings: warnings,
      importedBelegstand: importedBelegstand,
    );
  }

  /// Text-Overrides des Prüfstands laden (Futter für den
  /// TextOverrides-Provider der Index-Schicht).
  Future<TextOverrideState> _loadTextOverrides() async {
    Map<String, String> strMap(Map<String, dynamic> m) => {
          for (final e in m.entries)
            if (e.value case final String v) e.key: v,
        };
    final para = strMap(await kv.getMap(KvKeys.paraEdits));
    final title = strMap(await kv.getMap(KvKeys.titleEdits));
    final fnRaw = await kv.getMap(KvKeys.fnEdits);
    final fn = <int, String>{};
    for (final e in fnRaw.entries) {
      final num = int.tryParse(e.key);
      if (num != null && e.value is String) fn[num] = e.value;
    }
    if (para.isEmpty && title.isEmpty && fn.isEmpty) return TextOverrideState.empty;
    return TextOverrideState(paraEdits: para, fnEdits: fn, titleEdits: title);
  }

  static String _errMsg(Object e) =>
      e is FormatException ? e.message : e.toString();
}

/// Das Repository als Provider.
@Riverpod(keepAlive: true)
ProjectRepository projectRepository(Ref ref) => ProjectRepository(
      db: ref.watch(appDatabaseProvider),
      kv: ref.watch(kvStoreProvider),
    );

// ---------------------------------------------------------------------------
// Boot + Reboot (E8)
// ---------------------------------------------------------------------------

/// Der Boot-Fluss als Provider: Bundle laden → Repository booten →
/// Runtime + Overrides in die Daten-Notifier der Index-Schicht einspielen.
/// main.dart (F-E) wartet auf `projectBootProvider.future`, bevor die
/// Shell rendert.
///
/// **Reboot statt reload (E8):** [reboot] invalidiert diesen Knoten —
/// build() läuft komplett neu (liest den frischen activeProject-Key,
/// scoped den KV-Store um, baut die Runtime) und ersetzt die ActiveRuntime;
/// alle abgeleiteten Indizes/Provider bauen sich reaktiv neu auf.
@Riverpod(keepAlive: true)
class ProjectBoot extends _$ProjectBoot {
  @override
  Future<BootResult> build() async {
    final bundle = await ref.watch(thesisBundleProvider.future);
    final repo = ref.watch(projectRepositoryProvider);
    final result = await repo.boot(bundle);
    // Bewusster Seiteneffekt: die Index-Schicht (F-B) hält Runtime und
    // Overrides als eigene Notifier — der Boot ist die eine Stelle, die
    // sie füttert (Pendant zum Überschreiben der DATA_*-Globals).
    ref.read(activeRuntimeProvider.notifier).activate(result.runtime);
    ref.read(textOverridesProvider.notifier).set(result.overrides);
    return result;
  }

  /// Kompletter Neustart des Daten-Graphen (Ersatz für location.reload()).
  Future<BootResult> reboot() async {
    // Den PDF-Status-Cache mit verwerfen — das Original ließ ihn beim
    // Projektwechsel stehen (Stale-Cache-Bug L2); hier bewusst gefixt.
    ref.read(fileStoreProvider).value?.resetStatusCache();
    ref.invalidateSelf();
    return future;
  }

  /// Arbeitswechsel (Pendant zu Projects.setActive): Key schreiben, dann
  /// Reboot. Die Navigation nach #/projekt übernimmt der Aufrufer.
  Future<BootResult> activateProject(String id) async {
    await ref.read(projectRepositoryProvider).setActive(id);
    return reboot();
  }
}
