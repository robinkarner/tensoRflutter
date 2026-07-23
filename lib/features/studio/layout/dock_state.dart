/// Views-/Instanz-Zustand — Port der Dock-Logik (views_studio.js:2127-2207):
/// effektive View-Definitionen, Abschnitts-Overrides, gespeicherte Inhalte
/// und automatische Vorbefüllung.
///
/// S-2 konsumiert das für die Lesen-/Analyse-Darstellung (Text-View-Blöcke,
/// `dock-on`/`fastread-on`/`srcview-on`, „clear“ unterdrückt Marks);
/// S-3 (views/) baut darauf die Instanz-Fenster, die Leiste und die
/// ✎-Verwaltung.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/bundles/indexes.dart';
import '../../../data/db/kv.dart';
import '../../../data/models/models.dart';
import 'studio_state.dart';

part 'dock_state.g.dart';

/// Eine View-Definition (`DOCK_DEFAULTS`-Form). [color] bleibt der
/// CSS-String des Originals (Persistenz-Format; Auflösung via
/// `resolveCssColor`).
class DockDef {
  final String id;
  final String label;
  final String color;

  /// GPT-Auftrag der Text-Views (Generierung, S-3/K-3).
  final String desc;

  /// Spezial-Views (⚡/⤳/◘/◻) mit festem Verhalten.
  final bool special;

  /// Von der aktiven Arbeit mitgeliefert (`PROJECT_INSTANZEN.defs`).
  final bool project;

  /// Quellen-Bezug eigener Views (`srcTex`, S-3-Verwaltung).
  final String srcTex;

  const DockDef({
    required this.id,
    required this.label,
    this.color = '',
    this.desc = '',
    this.special = false,
    this.project = false,
    this.srcTex = '',
  });

  DockDef copyWith({String? color, bool? special, bool? project}) => DockDef(
        id: id,
        label: label,
        color: color ?? this.color,
        desc: desc,
        special: special ?? this.special,
        project: project ?? this.project,
        srcTex: srcTex,
      );
}

/// `DOCK_DEFAULTS` (views_studio.js:2127-2135) — Texte/Farben wörtlich.
const List<DockDef> dockDefaults = [
  DockDef(id: 'schnell', label: '⚡ Schnelllesen', special: true, color: 'var(--cat-frist)'),
  DockDef(id: 'connections', label: '⤳ Connections', special: true, color: 'var(--accent-ink)'),
  DockDef(id: 'srcview', label: '◘ Quelle', special: true, color: 'var(--cat-norm)'),
  DockDef(
    id: 'uebersetzung',
    label: '🌐 Übersetzung',
    color: 'var(--cat-norm)',
    desc: 'Eine präzise ÜBERSETZUNG (englisches Original → Deutsch; deutsches Original → Englisch). Fachbegriffe korrekt, keine Auslassungen.',
  ),
  DockDef(
    id: 'erklaerung',
    label: '✎ Erklärung',
    color: 'var(--good)',
    desc: 'Eine EINFACHE ERKLÄRUNG (2–4 Sätze, deutsch): was sagt der Absatz, warum ist er wichtig. Kein Fachjargon ohne Auflösung.',
  ),
  DockDef(
    id: 'analyse',
    label: '✦ Analyse',
    color: 'var(--cat-akteur)',
    desc: 'Analysiere je Absatz: Argumentationsschritt, Rolle im Kapitel, Stärke der Belegung, offene Fragen. 2–4 prägnante Sätze, gern mit **fett** für das Wichtigste.',
  ),
  DockDef(id: 'clear', label: '◻ Ohne', special: true),
];

/// Effektive View-Definitionen: Defaults + Projekt-Instanzen (vor „◻ Ohne“)
/// + gespeicherte `instDefs`-Overrides (Reihenfolge/Namen), mit Absicherung
/// der Spezial-/Projekt-Views — Port von `dockDefs()` (:2143-2162).
@Riverpod(keepAlive: true)
List<DockDef> dockDefs(Ref ref) {
  final runtime = ref.watch(activeRuntimeProvider);
  final snapshot = ref.watch(studioKvProvider).value ?? const <String, Object?>{};

  final projectDefs = <DockDef>[
    for (final d in runtime?.instanzen?.defs ?? const <InstanzDef>[])
      if (d.id.isNotEmpty && d.label.isNotEmpty)
        DockDef(id: d.id, label: d.label, color: d.color, desc: d.desc, project: true),
  ];

  final base = [...dockDefaults];
  for (final pd in projectDefs) {
    if (!base.any((d) => d.id == pd.id)) {
      base.insert(base.length - 1, pd); // vor „◻ Ohne“ einreihen
    }
  }

  final stored = snapshot[StudioUiKeys.instDefs];
  if (stored is! List || stored.isEmpty) return base;

  DockDef? baseOf(String id) {
    for (final d in base) {
      if (d.id == id) return d;
    }
    return null;
  }

  final out = <DockDef>[];
  for (final raw in stored) {
    if (raw is! Map) continue;
    final id = '${raw['id'] ?? ''}';
    final label = '${raw['label'] ?? ''}';
    if (id.isEmpty || label.isEmpty) continue;
    final color = '${raw['color'] ?? ''}';
    out.add(DockDef(
      id: id,
      label: label,
      color: color.isNotEmpty ? color : (baseOf(id)?.color ?? ''),
      desc: '${raw['desc'] ?? ''}',
      special: dockDefaults.any((x) => x.special && x.id == id),
      project: projectDefs.any((x) => x.id == id),
      srcTex: '${raw['srcTex'] ?? ''}',
    ));
  }
  // Spezial- und Projekt-Views absichern (Alt-Stand kennt sie evtl. nicht)
  for (final def in base.where((d) => d.special || d.project)) {
    if (out.any((d) => d.id == def.id)) continue;
    if (def.id == 'clear') {
      out.add(def);
    } else if (def.special) {
      out.insert(0, def);
    } else {
      final clearIdx = out.indexWhere((x) => x.id == 'clear');
      out.insert(clearIdx >= 0 ? out.length - 1 : out.length, def);
    }
  }
  return out;
}

/// View-Definition zu einer id (`dockDef`).
DockDef? dockDefOf(List<DockDef> defs, String? id) {
  for (final d in defs) {
    if (d.id == id) return d;
  }
  return null;
}

/// Label einer View (`dockLabel`).
String dockLabelOf(List<DockDef> defs, String id) =>
    dockDefOf(defs, id)?.label ?? id;

/// Text-View? (existiert und ist nicht special — `dockIsText`.)
bool dockIsTextOf(List<DockDef> defs, String? id) {
  final d = dockDefOf(defs, id);
  return d != null && !d.special;
}

/// Effektive View eines Abschnitts: Abschnitts-Override (auch explizites
/// `null` = geschlossen!) > globaler Standard — Port von `dockModeFor`
/// (:2177-2180).
@Riverpod(keepAlive: true)
String? dockModeFor(Ref ref, String sectionId) {
  final snapshot = ref.watch(studioKvProvider).value ?? const <String, Object?>{};
  final bySection = snapshot[KvKeys.dockBySection];
  if (bySection is Map && bySection.containsKey(sectionId)) {
    final ov = bySection[sectionId];
    return ov is String && ov.isNotEmpty ? ov : null;
  }
  final prefs = ref.watch(studioPrefsCtlProvider).value ?? StudioPrefs.defaults;
  return prefs.dock;
}

/// Gespeicherter View-Inhalt eines Absatzes (`dockGet`, :2168).
String dockGetFrom(Map<String, Object?> snapshot, String mode, String paraId) {
  final all = snapshot[KvKeys.paraDock];
  if (all is Map) {
    final perMode = all[mode];
    if (perMode is Map) {
      final v = perMode[paraId];
      if (v is String) return v;
    }
  }
  return '';
}

/// View-Inhalt setzen (`dockSet`, :2169-2174) — leer löscht den Eintrag.
void dockSetIn(StudioKv kv, String mode, String paraId, String md) {
  final all = kv.readMap(KvKeys.paraDock);
  final perMode = <String, Object?>{
    ...(all[mode] is Map ? (all[mode] as Map).map((k, v) => MapEntry('$k', v)) : const {}),
  };
  if (md.trim().isNotEmpty) {
    perMode[paraId] = md;
  } else {
    perMode.remove(paraId);
  }
  kv.put(KvKeys.paraDock, {...all, mode: perMode});
}

/// Automatische Vorbefüllung (`dockAuto`, :2184-2198): Übersetzung aus der
/// Voranalyse, Erklärung aus den Einfach-Sätzen, Analyse aus Kernaussage +
/// Beleg-Claims; eigene/mitgelieferte Views aus `PROJECT_INSTANZEN.items`.
String dockAutoFor(StudioDomain domain, String mode, String sectionId, Paragraph p) {
  final gp = domain.genPara(sectionId, p.id);
  if (mode == 'uebersetzung') return gp?.uebersetzung ?? '';
  if (mode == 'erklaerung') {
    return [
      for (final x in gp?.sentences ?? const <SentenceAnalyse>[])
        if (x.einfach.isNotEmpty) x.einfach,
    ].join(' ');
  }
  if (mode == 'analyse') {
    final teile = <String>[];
    if ((gp?.kernaussage ?? '').isNotEmpty) {
      teile.add('**Kernaussage:** ${gp!.kernaussage}');
    }
    final claims = [
      for (final b in gp?.belege ?? const <Beleg>[])
        if (b.claim.isNotEmpty) b.claim,
    ];
    if (claims.isNotEmpty) teile.add('**Belegt wird:** ${claims.join(' · ')}');
    return teile.join('\n\n');
  }
  return domain.runtime.instanzen?.item(mode, p.id) ?? '';
}

/// Instanz-Fenster NUR für diesen Abschnitt schließen (`dockClose`,
/// :2201-2207): globale Auswahl null → Eintrag löschen, sonst `null`-Override.
void dockCloseSection(StudioKv kv, String? globalDock, String sectionId) {
  final all = kv.readMap(KvKeys.dockBySection);
  final next = {...all};
  if (globalDock == null) {
    next.remove(sectionId);
  } else {
    next[sectionId] = null;
  }
  kv.put(KvKeys.dockBySection, next);
}
