/// Flow-Registry — Port von `Enhance.flows(ctx)` (enhance.js:60-185) samt
/// der Import-Kernlogik `_importMarks`/`_importInst` (enhance.js:187-213)
/// und der Referenz-Bausteine `_ref*` (enhance.js:320-366).
///
/// Alle 7 Flows als typisierte [AiFlow]-Objekte; Meta-Texte (kurz, erzeugt,
/// how, basis, wieder, paket) WORTWÖRTLICH aus dem Original. Die UIs (Hub,
/// Panel, Magic-Dock, Modals) sind reine Projektionen dieser Liste.
///
/// Speicherorte (KV, alle projekt-gescoped):
///  * marksExtra / paraDock → über den Studio-Schnappschuss ([StudioKv]) —
///    die Studio-Ansichten lesen synchron daraus, der Import wird sofort
///    sichtbar (routeRefresh-Pendant); die Quellen-Welt zieht über ihre
///    KV-Streams nach.
///  * kiConnections / resolutions → über den Quellen-Schnappschuss
///    ([QuellenKv], hält ALLE 26 PROJECT_KEYS live).
///  * notebook → [NotebookStore] (K-1).
///
/// W8/E9-Fix: Der Quellen-Prompt ist projektabhängig (Titel der aktiven
/// Arbeit) statt des hart codierten EHDS-Texts — umgesetzt in
/// `gptPromptForSource` (S-4, features/quellen/import/gpt_prompts.dart).
library;

import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/richtext/categories.dart';
import '../../../core/router/routes.dart';
import '../../../data/bundles/indexes.dart';
import '../../../data/db/kv.dart';
import '../../../data/models/models.dart';
import '../../../data/repos/project_repository.dart';
import '../../../domain/domain.dart';
import '../../projekt/arbeiten/master_prompt.dart';
import '../../quellen/import/gpt_prompts.dart';
import '../../quellen/state/quellen_kv.dart';
import '../../studio/layout/dock_state.dart';
import '../../studio/layout/studio_state.dart';
import '../../studio/views/instanz_prompt.dart';
import '../../wissen/notebook/notebook_prompt.dart';
import '../../wissen/notebook/notebook_state.dart';
import '../client/claude_cfg.dart';
import 'ai_flow.dart';
import 'checkers.dart';
import 'marks_prompt.dart';

// ---------------------------------------------------------------------------
// Prompt inkl. Zusatz-Instruktion (`Enhance.prompt`, enhance.js:50-54)
// ---------------------------------------------------------------------------

/// Prompt einer Stelle inkl. optionaler ⚙-Zusatz-Instruktion.
String aiPromptFor(ProviderContainer c, AiFlow flow) {
  final base = flow.build?.call() ?? '';
  final add = c.read(enhCfgStoreProvider.notifier).cfgFor(flow.id).instruction.trim();
  return add.isNotEmpty ? '$base\n\nZUSÄTZLICHE ANWEISUNG:\n$add' : base;
}

// ---------------------------------------------------------------------------
// Import-Kernlogik (enhance.js:187-213)
// ---------------------------------------------------------------------------

/// 🖍 `_importMarks`: je Absatz nur Einträge mit Snippet + bekannter
/// Kategorie; **ersetzt `marksExtra[pid]` komplett**.
String aiImportMarks(ProviderContainer c, String text) {
  final d = jsonDecode(text);
  final items = d is Map ? d['items'] : null;
  if (items is! Map) throw const FormatException('Feld "items" fehlt.');
  final kv = c.read(studioKvProvider.notifier);
  final all = {...kv.readMap(KvKeys.marksExtra)};
  var n = 0;
  for (final e in items.entries) {
    final list = e.value;
    if (list is! List) continue;
    final ok = <Map<String, Object?>>[
      for (final m in list)
        if (m is Map &&
            m['snippet'] is String &&
            (m['snippet'] as String).trim().isNotEmpty &&
            catLabels.containsKey(m['kategorie']))
          {'snippet': (m['snippet'] as String).trim(), 'kategorie': m['kategorie']},
    ];
    if (ok.isNotEmpty) {
      all['${e.key}'] = ok;
      n += ok.length;
    }
  }
  kv.put(KvKeys.marksExtra, all);
  return '$n Markierungen übernommen';
}

/// 🎛 `_importInst`: nur bekannte, nicht-spezielle Instanz-IDs; Werte =
/// Markdown-Strings; Teil-Antworten ERGÄNZEN (dockSet je Absatz).
/// Wird auch extern vom ↻-Recompile der Views genutzt (views_studio.js:2473).
String aiImportInst(ProviderContainer c, String text) {
  final d = jsonDecode(text);
  final known = {
    for (final x in c.read(dockDefsProvider))
      if (!x.special) x.id,
  };
  var n = 0;
  final skipped = <String>{};
  final kv = c.read(studioKvProvider.notifier);
  void take(String instId, Object? items) {
    if (!known.contains(instId)) {
      skipped.add(instId);
      return;
    }
    if (items is! Map) return;
    for (final e in items.entries) {
      final md = e.value;
      if (md is String && md.trim().isNotEmpty) {
        dockSetIn(kv, instId, '${e.key}', md);
        n++;
      }
    }
  }

  final inst = d is Map ? d['instanzen'] : null;
  if (inst is Map) {
    for (final e in inst.entries) {
      take('${e.key}', e.value);
    }
  } else if (d is Map && d['items'] != null && (d['mode'] != null || d['instanz'] != null)) {
    take('${d['mode'] ?? d['instanz']}', d['items']);
  } else {
    throw const FormatException('Feld "instanzen" fehlt.');
  }
  return '$n Absatz-Instanzen übernommen'
      '${skipped.isNotEmpty ? ' · übersprungen: ${skipped.join(', ')}' : ''}';
}

// ---------------------------------------------------------------------------
// Die Registry
// ---------------------------------------------------------------------------

/// Alle 7 Flows für den Kontext [ctx]. Die Closures lesen zum AUFRUFZEIT-
/// Punkt aus dem [ProviderContainer] (Registry wird — wie im Original —
/// bei jedem Render frisch gebaut; die Widgets watchen die Quellen selbst).
List<AiFlow> buildAiFlows(ProviderContainer c, AiFlowCtx ctx) {
  final ordered = c.read(orderedUnitsProvider);
  final sectionId =
      ctx.sectionId ?? (ordered.isNotEmpty ? ordered.first : null);

  StudioDomain? domain() => c.read(studioDomainProvider);
  Map<String, Object?> studioSnap() =>
      c.read(studioKvProvider).value ?? const {};
  Map<String, Object?> quellenSnap() =>
      c.read(quellenKvProvider).value ?? const {};
  ThesisRuntime? runtime() => c.read(activeRuntimeProvider);

  Map<String, Object?> mapOf(Map<String, Object?> snap, String key) {
    final v = snap[key];
    return v is Map ? v.map((k, val) => MapEntry('$k', val)) : const {};
  }

  /// Connections-Instanz über dem Quellen-Schnappschuss (hält
  /// `kiConnections` live; seit Gate 2 kennt auch der Studio-Schnappschuss
  /// den Key und zieht Fremd-Writes per KV-Stream nach).
  Connections? connections() {
    final d = c.read(quellenDomainProvider);
    if (d == null) return null;
    return Connections(
      d.ctx,
      QuellenDomainStore(quellenSnap(), c.read(quellenKvProvider.notifier)),
    );
  }

  String? quellenSrc() => aiQuellenSrcFor(c, ctx, sectionId: sectionId);

  // ---- Referenzen (enhance.js:320-366) ------------------------------------

  AiReference refAll() {
    final sec = runtime()?.sections.length ?? 0;
    final src = runtime()?.sources.length ?? 0;
    final connsRaw = mapOf(quellenSnap(), KvKeys.kiConnections)['connections'];
    final conn = connsRaw is List ? connsRaw.length : 0;
    return AiReference(
      summary: [
        const RichBit('Aktueller Stand der Arbeit: '),
        RichBit('$sec', bold: true),
        const RichBit(' Abschnitte analysiert · '),
        RichBit('$src', bold: true),
        const RichBit(' Quellen · '),
        RichBit('$conn', bold: true),
        const RichBit(' KI-Connections importiert.'),
      ],
      hint: '„⚡ Voranalyse (alles)“ erzeugt/ersetzt diesen ganzen Bestand auf einmal.',
    );
  }

  AiReference refBuch() {
    final stored = c.read(notebookStoreProvider).value;
    final builtin = runtime()?.erklaerbuch;
    final src = stored ?? builtin ?? '';
    final head =
        RegExp(r'^#\s+(.+)$', multiLine: true).firstMatch(src)?.group(1) ?? '—';
    final cells = RegExp('```').allMatches(src).length ~/ 2;
    return AiReference(
      summary: [
        RichBit(stored != null
            ? 'Eigenes'
            : builtin != null
                ? 'Eingebautes'
                : 'Starter-'),
        const RichBit(' Erklärbuch · Titel „'),
        RichBit(head, bold: true),
        RichBit('“ · ~$cells Code-/Chart-Zellen.'),
      ],
      mdPreview: src.isEmpty
          ? null
          : src.substring(0, src.length > 700 ? 700 : src.length),
      mdTruncated: src.length > 700,
    );
  }

  AiReference refMarks() {
    final extra = mapOf(studioSnap(), KvKeys.marksExtra);
    final paras =
        c.read(unitIndexProvider)[sectionId ?? '']?.unit.paragraphs ??
            const <Paragraph>[];
    var n = 0;
    final chips = <AiRefChip>[];
    for (final p in paras) {
      final list = extra[p.id];
      if (list is! List) continue;
      for (final m in list) {
        if (m is! Map) continue;
        n++;
        if (chips.length < 12) {
          final snippet = '${m['snippet'] ?? ''}';
          chips.add(AiRefChip(
            snippet.length > 22 ? snippet.substring(0, 22) : snippet,
            catKey: '${m['kategorie'] ?? ''}',
          ));
        }
      }
    }
    return AiReference(
      summary: [
        RichBit('Abschnitt ${sectionId ?? ''}: '),
        RichBit('$n', bold: true),
        const RichBit(' zusätzliche KI-Markierungen (plus die mitgelieferten aus der Voranalyse).'),
      ],
      chips: n > 0 ? chips : const [],
      hint: n > 0
          ? null
          : 'Noch keine zusätzlichen Markierungen — „Mit Claude“ oder „⧉ Prompt“.',
    );
  }

  AiReference refConn() {
    List<ConnectionEdge> all;
    try {
      all = connections()?.all() ?? const [];
    } catch (_) {
      all = const [];
    }
    final ship = runtime()?.meta.connections?.connections.length ?? 0;
    final kiRaw = mapOf(quellenSnap(), KvKeys.kiConnections)['connections'];
    final ki = kiRaw is List ? kiRaw.length : 0;
    final by = <String, int>{};
    for (final e in all) {
      by[e.typ] = (by[e.typ] ?? 0) + 1;
    }
    return AiReference(
      summary: [
        RichBit('${all.length}', bold: true),
        RichBit(' Connections sichtbar — $ship mitgeliefert · $ki importiert · Rest live abgeleitet (geteilte Quellen, Querverweise).'),
      ],
      chips: [
        if (all.isNotEmpty)
          for (final e in by.entries) AiRefChip('${e.key}: ${e.value}'),
      ],
      hint: all.isEmpty ? 'Noch keine Connections vorhanden.' : null,
    );
  }

  AiReference refInst() {
    final dock = mapOf(studioSnap(), KvKeys.paraDock);
    // Zähllogik exakt wie das Original (enhance.js:356-361): Top-Level-Keys
    // (= Instanz-Modi) zählen, `split('|')[0]` gruppiert.
    var n = 0;
    final byMode = <String, int>{};
    for (final k in dock.keys) {
      n++;
      final mode = k.split('|').first;
      byMode[mode] = (byMode[mode] ?? 0) + 1;
    }
    return AiReference(
      summary: [
        RichBit('$n', bold: true),
        const RichBit(' gefüllte Absatz-Instanzen.'),
      ],
      chips: [
        if (n > 0)
          for (final e in byMode.entries) AiRefChip('${e.key}: ${e.value}'),
      ],
      hint: n > 0
          ? null
          : 'Noch keine — Übersetzung/Erklärung/Analyse je Absatz werden hier erzeugt.',
    );
  }

  AiReference refQuellen() {
    final id = quellenSrc();
    if (id == null) {
      return const AiReference(summary: [
        RichBit('Keine Quelle gewählt — im Studio rechts eine Quelle öffnen, dann hierher.'),
      ]);
    }
    final res = mapOf(quellenSnap(), KvKeys.resolutions)[id];
    final stellen = res is Map ? res['stellen'] : null;
    final short = domain()?.ctx.srcShort(id) ?? id;
    return AiReference(summary: [
      const RichBit('Aktive Quelle: '),
      RichBit(short, bold: true),
      RichBit(res != null
          ? ' · ${stellen is List ? stellen.length : 0} Fundstellen importiert.'
          : ' · noch keine Fundstellen.'),
    ]);
  }

  AiReference refStyle() {
    final on =
        (c.read(studioPrefsCtlProvider).value ?? StudioPrefs.defaults).styleCheck;
    return AiReference(
      summary: [
        const RichBit('Stil-Check ist aktuell '),
        RichBit(on ? 'an' : 'aus', bold: true),
        const RichBit('.'),
      ],
      hint: 'Sofort-Heuristik ohne KI — markiert auffällige Sätze direkt im Text.',
    );
  }

  // ---- Stats --------------------------------------------------------------

  String statMarks() {
    final extra = mapOf(studioSnap(), KvKeys.marksExtra);
    final paras =
        c.read(unitIndexProvider)[sectionId ?? '']?.unit.paragraphs ??
            const <Paragraph>[];
    var n = 0;
    for (final p in paras) {
      final list = extra[p.id];
      if (list is List) n += list.length;
    }
    return n > 0 ? '$n' : '—';
  }

  String statConn() {
    try {
      final n = connections()?.all().length ?? 0;
      return n > 0 ? '$n' : '—';
    } catch (_) {
      return '—';
    }
  }

  String statInst() {
    final n = mapOf(studioSnap(), KvKeys.paraDock).length;
    return n > 0 ? '$n' : '—';
  }

  String statQuellen() {
    final id = quellenSrc();
    final res = id != null ? mapOf(quellenSnap(), KvKeys.resolutions)[id] : null;
    final stellen = res is Map ? res['stellen'] : null;
    final n = stellen is List ? stellen.length : 0;
    return n > 0 ? '$n' : '—';
  }

  bool hasBuch() =>
      c.read(notebookStoreProvider).value != null || runtime()?.erklaerbuch != null;

  // ---- Die 7 Flows --------------------------------------------------------

  return [
    AiFlow(
      id: 'all',
      icon: '⚡',
      title: 'Voranalyse (alles)',
      aktion: 'Analyze',
      scope: 'Ganze Arbeit',
      multi: true,
      kurz: 'Erzeugt den kompletten Prüfstand in EINEM Lauf',
      erzeugt: 'Markierungen · Kernaussagen · Belege · Dossiers · Connections · Instanzen',
      how: 'Der Gesamt-Prompt kombiniert die Formatvorgabe (welche Dateien in welcher Struktur), die Notation für Belege/Markierungen und den KOMPLETTEN LaTeX-Quelltext der Arbeit. Das Modell erzeugt daraus die ganze Voranalyse — als mehrere Dateien, die über „⭱ Analysen importieren“ eingelesen werden.',
      paket: const AiPaket(
        input: ['Formatvorgabe', 'Notation', 'LaTeX (komplett)'],
        out: 'alle Analyse-Dateien',
        ziel: 'kompletter Prüfstand',
      ),
      basis: 'komplettes LaTeX + Notation',
      wieder: 'Ein neuer Lauf setzt/ersetzt den kompletten Prüfstand (alle Pakete). Eigene manuelle Belege und der Originaltext bleiben unberührt.',
      // masterPrompt + LaTeX-Rekonstruktion (Editor.fullDocument — inkl.
      // texEdits, enhance.js:71). masterPromptWithTex baut exakt den
      // Original-Umschlag (60×'=' + Zwischenzeile).
      build: () => masterPromptWithTex(domain()?.editor.fullDocument() ?? ''),
      run: (_) => throw const FormatException(
          'Die Voranalyse-Antwort umfasst mehrere Dateien — als einzelne Dateien sichern und über „⭱ Analysen importieren“ einlesen.'),
      reference: refAll,
      stat: () => '${runtime()?.sections.length ?? 0} Abschn.',
      statOn: () => (runtime()?.sections.length ?? 0) > 0,
    ),
    AiFlow(
      id: 'buch',
      icon: '📓',
      title: 'Erklärbuch',
      aktion: 'Explain',
      scope: 'Ganze Arbeit',
      kurz: 'Interaktives Erklärbuch der ganzen Arbeit',
      erzeugt: 'das interaktive Erklärbuch (Markdown)',
      how: 'Der Prompt enthält die Anleitung zum Erklärbuch-Format, die Baustein-Referenz (Charts, Tabellen, Rechenzellen) und das ECHTE Datenpaket der aktiven Arbeit (Kennzahlen, Quellen, Belegstatus). Die Antwort ist Markdown und ersetzt das Erklärbuch.',
      paket: const AiPaket(
        input: ['Baustein-Referenz', 'Datenpaket (live)'],
        out: 'Markdown-Buch',
        ziel: 'Wissen → Erklärbuch',
      ),
      basis: 'Live-Datenpaket der Arbeit',
      wieder: 'Ein neuer Lauf ersetzt dein Erklärbuch — ↺ bringt jederzeit das eingebaute Buch zurück.',
      placeholder: '# Erklärbuch …',
      // Notebook.prompt() ist in Flutter async (K-1-Provider) — die UIs
      // warmen ihn per watch; bis dahin ist der Prompt leer.
      build: () => c.read(notebookPromptProvider).value ?? '',
      run: (t) {
        if (t.trim().isEmpty) throw const FormatException('Leeres Markdown.');
        c.read(notebookStoreProvider.notifier).set(t);
        return 'Erklärbuch übernommen';
      },
      check: aiCheckBuch,
      reference: refBuch,
      done: (context) => context.go(Routes.analysePath(tab: 'buch')),
      stat: () => hasBuch() ? '✓' : '—',
      statOn: hasBuch,
    ),
    AiFlow(
      id: 'marks',
      icon: '🖍',
      title: 'Markierungen',
      aktion: 'Marks',
      scope: 'Dieser Abschnitt',
      section: sectionId,
      kurz: 'Farbige Schlüsselstellen im Text nachschärfen',
      erzeugt: 'farbige Schlüsselstellen im Abschnitt',
      how: 'Der Prompt enthält alle Absätze des Abschnitts ${sectionId != null ? '($sectionId) ' : ''}und die Kategorien (Quelle, Frist, Akteur, Technik, These, Lücke, Zahl, Abkürzung, Schlagwort). Das Modell liefert wörtliche Snippets je Absatz mit Kategorie — sie werden als farbige Marks über den Text gelegt.',
      paket: const AiPaket(
        input: ['Absätze des Abschnitts', 'Kategorien-Notation'],
        out: 'Snippets + Kategorie (JSON)',
        ziel: 'Marks im Text',
      ),
      basis: 'Absätze dieses Abschnitts',
      wieder: 'Ein neuer Lauf ersetzt die zusätzlichen KI-Markierungen dieses Abschnitts — die mitgelieferten aus der Voranalyse bleiben.',
      placeholder: '{"sectionId":"…","items":{"<absatz-id>":[{"snippet":"…","kategorie":"frist"}]}}',
      build: () {
        final d = domain();
        return d != null && sectionId != null ? marksPromptFor(d.ctx, sectionId) : '';
      },
      run: (t) => aiImportMarks(c, t),
      check: aiCheckMarks,
      reference: refMarks,
      // done = routeRefresh → in Flutter reaktiv (die Ansichten watchen den
      // KV-Schnappschuss); gesetzt bleibt es fürs Schließ-Verhalten.
      done: _noopDone,
      stat: statMarks,
      statOn: () => statMarks() != '—',
    ),
    AiFlow(
      id: 'conn',
      icon: '⤳',
      title: 'Connections',
      aktion: 'Connect',
      scope: 'Ganze Arbeit',
      kurz: 'Verbindungen zwischen den Absätzen',
      erzeugt: 'inhaltliche Verbindungen zwischen den Absätzen',
      how: 'Der Prompt enthält die Gliederung und die Kernaussagen je Absatz. Das Modell liefert Verbindungen (Folgerung, Grundlage, Aufgriff, Vergleich) zwischen Absätzen — sichtbar in der ⤳ Connections-Instanz und in der Analyse.',
      paket: const AiPaket(
        input: ['Gliederung', 'Kernaussagen je Absatz'],
        out: 'Verbindungen (JSON)',
        ziel: '⤳ Instanz + Analyse',
      ),
      basis: 'Gliederung + Kernaussagen',
      wieder: 'Ein neuer Lauf ersetzt die importierten KI-Connections — die mitgelieferten aus der Voranalyse bleiben.',
      placeholder: '{"connections":[…]}',
      build: () => connections()?.regeneratePrompt() ?? '',
      run: (t) {
        final conn = connections();
        if (conn == null) {
          throw const FormatException('Arbeit noch nicht geladen.');
        }
        return '${conn.importKi(t)} Connections übernommen';
      },
      check: aiCheckConn,
      reference: refConn,
      done: _noopDone,
      stat: statConn,
      statOn: () => statConn() != '—',
    ),
    AiFlow(
      id: 'inst',
      icon: '🎛',
      title: 'Instanzen',
      aktion: 'Views',
      scope: 'Ganze Arbeit',
      kurz: 'Füllt alle Text-Views je Absatz',
      erzeugt: 'Übersetzung · Erklärung · Analyse je Absatz',
      how: 'Der Prompt enthält die Beschreibungen aller Text-Instanzen und den kompletten Text der Arbeit. Views mit Σ-Verknüpfung (View-Manager ✎) bekommen zusätzlich das LaTeX-Material der verknüpften Quelle als übergeordnete Textbasis. Das Modell liefert je Instanz und Absatz Markdown — es füllt die Instanz-Fenster neben den Absätzen.',
      paket: const AiPaket(
        input: ['Instanz-Beschreibungen', 'LaTeX (komplett)'],
        out: 'Markdown je Absatz (JSON)',
        ziel: 'Instanz-Fenster',
      ),
      basis: 'kompletter Text + Instanz-Aufträge (+ Σ Quell-LaTeX)',
      wieder: 'Je Absatz-Instanz wird überschrieben — Teil-Antworten (einzelne Instanzen/Abschnitte) ergänzen nur.',
      placeholder: '{"instanzen": {"<instanz-id>": {"<absatz-id>": "<markdown>"}}}',
      build: () {
        final d = domain();
        if (d == null) return '';
        return instanzPrompt(
          d.ctx,
          c.read(dockDefsProvider),
          materials: texMaterialsFrom(quellenSnap()[KvKeys.srcExtras]),
        );
      },
      run: (t) => aiImportInst(c, t),
      check: (raw) => aiCheckInst(raw, {
        for (final x in c.read(dockDefsProvider))
          if (!x.special) x.id,
      }),
      reference: refInst,
      done: _noopDone,
      stat: statInst,
      statOn: () => mapOf(studioSnap(), KvKeys.paraDock).isNotEmpty,
    ),
    AiFlow(
      id: 'quellen',
      icon: '📚',
      title: 'Quellen-Durchlauf',
      aktion: 'Sources',
      scope: 'Dieser Abschnitt',
      kurz: 'Prüft Fundstellen & Zitate je Zitierstelle',
      erzeugt: 'geprüfte Fundstellen je Zitierstelle einer Quelle',
      how: 'Der Prompt enthält alle Zitierstellen der AKTIVEN Quelle (rechts im Studio gewählt): je Fußnote Claim + vermutete Fundstelle + Suchbegriffe. Das Modell liefert die geprüfte Fundstelle/Seite + Zitat — sie fließen als Belege an die Fußnoten (früher „🤖 GPT-Durchlauf“).',
      paket: const AiPaket(
        input: ['Zitierstellen der Quelle', 'Claims + Suchbegriffe'],
        out: 'Fundstellen + Zitate (JSON)',
        ziel: 'Belege der Fußnoten',
      ),
      basis: 'Zitierstellen der aktiven Quelle',
      wieder: 'Ein neuer Lauf ersetzt den Durchlauf dieser Quelle — von Hand erfasste Belege (Seite/Zitat) gewinnen immer.',
      placeholder: '{"formatVersion":"1.0","sourceId":"…","stellen":[…]}',
      build: () {
        final id = quellenSrc();
        final rt = runtime();
        if (id == null || rt == null) return '';
        final source = c.read(srcByIdProvider)[id];
        final qd = c.read(quellenDomainProvider);
        if (source == null || qd == null) return '';
        final ovRaw = mapOf(quellenSnap(), KvKeys.linkOverrides)[id];
        return gptPromptForSource(
          source,
          positionType: qd.levels.positionType(id),
          links: effectiveSrcLinks(
            source,
            ovRaw is Map ? ovRaw.map((k, v) => MapEntry('$k', v)) : const {},
          ),
          arbeitTitel: rt.thesis.meta.title,
        );
      },
      run: (t) {
        final id = quellenSrc();
        if (id == null) {
          throw const FormatException('Keine Quelle gewählt — im Studio rechts eine Quelle öffnen.');
        }
        final r = jsonDecode(t);
        if (r is! Map || r['stellen'] == null) {
          throw const FormatException('Feld "stellen" fehlt.');
        }
        final res = r.map((k, v) => MapEntry('$k', v));
        // sourceId/generatedBy defaulten, dann roh ablegen (U.setResolution:
        // `resolutions[res.sourceId] = res` — von Hand erfasste Belege
        // gewinnen ohnehin über die Levels-Kaskade).
        final srcId = res['sourceId'];
        if (srcId == null || '$srcId'.isEmpty) res['sourceId'] = id;
        final gen = res['generatedBy'];
        if (gen == null || '$gen'.isEmpty) res['generatedBy'] = 'gpt';
        final kv = c.read(quellenKvProvider.notifier);
        final all = {...kv.readMap(KvKeys.resolutions)};
        all['${res['sourceId']}'] = res;
        kv.put(KvKeys.resolutions, all);
        final stellen = res['stellen'];
        return '${stellen is List ? stellen.length : 0} Stelle(n) übernommen';
      },
      check: (raw) => aiCheckQuellen(raw, quellenSrc()),
      reference: refQuellen,
      done: _noopDone,
      stat: statQuellen,
      statOn: () => statQuellen() != '—',
    ),
    AiFlow(
      id: 'style',
      icon: '🤖',
      title: 'Stil-Check',
      scope: 'Dieser Abschnitt',
      toggle: true,
      erzeugt: 'GPT-lastige / schwache Sätze — sofort, ohne KI',
      how: 'Rein deterministische Heuristik (keine KI, kein Prompt): markiert Floskeln, vage Einordnungen, Konnektor-Ketten und wertende Sätze ohne Konkretes direkt im Text. Ein-/Ausschalter.',
      paket: const AiPaket(
        input: ['Text des Abschnitts (lokal)'],
        out: 'Hinweise (ohne KI)',
        ziel: 'Highlights im Text',
      ),
      reference: refStyle,
      stat: () =>
          (c.read(studioPrefsCtlProvider).value ?? StudioPrefs.defaults).styleCheck
              ? 'an'
              : 'aus',
      statOn: () =>
          (c.read(studioPrefsCtlProvider).value ?? StudioPrefs.defaults).styleCheck,
    ),
  ];
}

/// 📚 `_src()` (enhance.js:154): ctx.srcId ∥ Studio.file.srcId ∥ erste
/// Quelle des Abschnitts — auch der Hub braucht sie für den Kontext-Chip.
String? aiQuellenSrcFor(ProviderContainer c, AiFlowCtx ctx, {String? sectionId}) {
  if (ctx.srcId != null && ctx.srcId!.isNotEmpty) return ctx.srcId;
  final fileSrc = c.read(studioFileProvider).srcId;
  if (fileSrc != null && fileSrc.isNotEmpty) return fileSrc;
  final sec = sectionId ??
      ctx.sectionId ??
      (c.read(orderedUnitsProvider).isNotEmpty
          ? c.read(orderedUnitsProvider).first
          : null);
  if (sec != null) {
    final bySrc = c.read(studioDomainProvider)?.sectionSources(sec);
    if (bySrc != null && bySrc.isNotEmpty) return bySrc.keys.first;
  }
  return null;
}

/// `done: () => routeRefresh()`-Pendant — die Flutter-Ansichten ziehen
/// reaktiv nach; das Feld bleibt gesetzt, damit Panel/Dock ihr
/// Original-Schließverhalten zeigen.
void _noopDone(BuildContext context) {}

/// Flow per id (`flows.find(f => f.id === id)` — Fallback erster Flow).
AiFlow aiFlowById(List<AiFlow> flows, String? id) {
  for (final f in flows) {
    if (f.id == id) return f;
  }
  return flows.first;
}

/// Alle Quellen der Registry beobachten — die KI-Widgets rufen das in
/// `build()`, damit Stats/Referenzen/Preise live nachziehen (das Original
/// rendert bei jedem Öffnen frisch aus localStorage).
void watchAiSources(WidgetRef ref) {
  ref.watch(activeRuntimeProvider);
  ref.watch(studioKvProvider);
  ref.watch(quellenKvProvider);
  ref.watch(studioPrefsCtlProvider);
  ref.watch(dockDefsProvider);
  ref.watch(studioFileProvider);
  ref.watch(notebookStoreProvider);
  // Erklärbuch-Prompt warm halten (async — build() liest ihn synchron).
  ref.watch(notebookPromptProvider);
  ref.watch(claudeCfgStoreProvider);
  ref.watch(enhCfgStoreProvider);
}
