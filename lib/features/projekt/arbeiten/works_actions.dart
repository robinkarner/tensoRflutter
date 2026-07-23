/// Arbeiten-Aktionen ohne UI — Ports von `Projects.createFromTex` und
/// `Projects.applyRegistry` (projects.js:102-127). Beide bauen NUR den
/// Datensatz und speichern ihn; der eigentliche Neustart (E8-Reboot statt
/// `location.reload()`) läuft beim Aufrufer über
/// `projectBootProvider.notifier.activateProject(...)` bzw. `.reboot()`.
library;

import '../../../data/export/projekt_format.dart';
import '../../../data/models/models.dart';
import '../../../data/repos/project_repository.dart';
import '../../../domain/texparse.dart';

/// Ergebnis von [createFromTex]: das Parse-Ergebnis plus (bei Erfolg)
/// id und gespeicherter Record — `{...r, id, rec}` des Originals.
class CreateFromTexResult {
  final TexParseResult parse;
  final String? id;
  final ProjectRecord? rec;

  const CreateFromTexResult(this.parse, {this.id, this.rec});

  bool get ok => parse.ok;
  List<String> get errors => parse.errors;
}

/// JS `new Date().toISOString()` — UTC mit Millisekunden und `Z`-Suffix
/// (Darts `toIso8601String()` hängt sonst Mikrosekunden an).
String isoNowUtc([DateTime? now]) {
  final d = (now ?? DateTime.now()).toUtc();
  String p2(int n) => n.toString().padLeft(2, '0');
  String p3(int n) => n.toString().padLeft(3, '0');
  return '${d.year.toString().padLeft(4, '0')}-${p2(d.month)}-${p2(d.day)}'
      'T${p2(d.hour)}:${p2(d.minute)}:${p2(d.second)}.${p3(d.millisecond)}Z';
}

/// Neue Arbeit aus LaTeX (projects.js:102-116): parsen → Datensatz mit
/// id `p-<slug30>-<rand4>` anlegen → speichern. Bei Parse-Fehler kommt nur
/// das Ergebnis zurück (nichts gespeichert).
Future<CreateFromTexResult> createFromTex(
  ProjectRepository repo,
  String name,
  String tex, {
  List<Map<String, dynamic>>? registry,
  DateTime? now,
}) async {
  final r = TexParse.parse(tex, registry: registry ?? const []);
  if (!r.ok) return CreateFromTexResult(r);
  final id = newProjectId(name.isEmpty ? 'arbeit' : name);
  // Datensatz-Form exakt wie projects.js:107-113 (rohes JSON = Wahrheit).
  final metaTitle = (r.thesis?['meta'] is Map)
      ? ((r.thesis!['meta'] as Map)['title']?.toString() ?? '')
      : '';
  final rec = ProjectRecord.fromJson({
    'id': id,
    'name': name.isNotEmpty ? name : metaTitle,
    'created': isoNowUtc(now),
    'tex': tex,
    'registry': registry ?? const [],
    'parsed': {
      'thesis': r.thesis,
      'footnotes': r.footnotes,
      'sources': r.sources,
    },
    'generated': {
      'sections': <String, Object?>{},
      'sources': <String, Object?>{},
      'chapters': <String, Object?>{},
      'gesamt': null,
      'fazit': null,
      'analyse': <String, Object?>{},
      'connections': null,
    },
    'figures': {'figuren': <Object?>[], 'tabellen': <Object?>[]},
  });
  await repo.save(rec);
  return CreateFromTexResult(r, id: id, rec: rec);
}

/// Registry nachreichen (projects.js:119-127): Re-Parse mit Registry;
/// bei Erfolg wird der Record aktualisiert (`userModified = true`) und
/// gespeichert. Liefert Parse-Ergebnis + (ggf.) aktualisierten Record.
Future<(TexParseResult, ProjectRecord)> applyRegistry(
  ProjectRepository repo,
  ProjectRecord rec,
  List<Object?> registry,
) async {
  final regMaps = [
    for (final e in registry)
      if (e is Map) e.map((k, v) => MapEntry('$k', v)),
  ];
  final r = TexParse.parse(rec.tex, registry: regMaps);
  if (!r.ok) return (r, rec);
  final raw = Map<String, dynamic>.from(rec.raw);
  raw['userModified'] = true;
  raw['registry'] = registry;
  raw['parsed'] = {
    'thesis': r.thesis,
    'footnotes': r.footnotes,
    'sources': r.sources,
  };
  final updated = ProjectRecord.fromJson(raw);
  await repo.save(updated);
  return (r, updated);
}
