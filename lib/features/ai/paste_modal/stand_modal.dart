/// ⎇ Stand — Port von `Enhance.standModal` (enhance.js:710-763): der
/// Speicherstand wie ein Log (GitHub-Schule) — je Datenpaket eine Zeile mit
/// Format, Speicherort, Stand und Herkunft (mitgeliefert / importiert /
/// von Hand). Darunter: BEIDE eingebauten Arbeiten mit ihrem
/// Auslieferungsstand.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/modal.dart';
import '../../../data/bundles/bundle_loader.dart';
import '../../../data/bundles/indexes.dart';
import '../../../data/db/kv.dart';
import '../../../data/models/models.dart';
import '../../../data/repos/project_repository.dart';
import '../../../domain/domain.dart';
import '../../quellen/state/quellen_kv.dart';
import '../flows/registry.dart';

void showAiStandModal(BuildContext context) {
  showAppModal<void>(
    context,
    title: const Text('⎇ Stand — was ist gespeichert (aktive Arbeit)'),
    body: const _StandBody(),
  );
}

/// Eine Log-Zeile (`.lg-row`).
class _LogRow {
  final String ic;
  final String t;
  final String fmt;
  final String ort;
  final String n;
  final String src;
  final bool on;

  const _LogRow({
    required this.ic,
    required this.t,
    required this.fmt,
    required this.ort,
    required this.n,
    required this.src,
    required this.on,
  });
}

class _StandBody extends ConsumerWidget {
  const _StandBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    watchAiSources(ref);
    final runtime = ref.watch(activeRuntimeProvider);
    final quellenSnap = ref.watch(quellenKvProvider).value ?? const <String, Object?>{};
    final boot = ref.watch(projectBootProvider).value;
    final bundle = ref.watch(thesisBundleProvider).value;

    Map<String, Object?> mapOf(String key) {
      final v = quellenSnap[key];
      return v is Map ? v.map((k, val) => MapEntry('$k', val)) : const {};
    }

    final meta = runtime?.thesis.meta;
    final secN = runtime?.sections.length ?? 0;
    final shipConn = runtime?.meta.connections?.connections.length ?? 0;
    final kiRaw = mapOf(KvKeys.kiConnections)['connections'];
    final kiConn = kiRaw is List ? kiRaw.length : 0;
    int allConn;
    try {
      final qd = ref.watch(quellenDomainProvider);
      allConn = qd == null
          ? shipConn + kiConn
          : Connections(
              qd.ctx,
              QuellenDomainStore(quellenSnap, ref.read(quellenKvProvider.notifier)),
            ).all().length;
    } catch (_) {
      allConn = shipConn + kiConn;
    }

    final dock = mapOf(KvKeys.paraDock);
    var dockN = 0;
    for (final m in dock.values) {
      if (m is Map) dockN += m.length;
    }
    var shipInst = 0;
    for (final items in (runtime?.instanzen?.items ?? const {}).values) {
      shipInst += items.length;
    }
    final marks = mapOf(KvKeys.marksExtra);
    var marksN = 0;
    for (final l in marks.values) {
      if (l is List) marksN += l.length;
    }
    final res = mapOf(KvKeys.resolutions);
    var stellenN = 0;
    for (final r in res.values) {
      final st = r is Map ? r['stellen'] : null;
      if (st is List) stellenN += st.length;
    }
    final nbRaw = quellenSnap[KvKeys.notebook];
    final nb = nbRaw is String && nbRaw.trim().isNotEmpty;
    final hasBuiltinBuch = runtime?.erklaerbuch != null;
    final levelN = mapOf(KvKeys.belegLevels).length;

    final rows = <_LogRow>[
      _LogRow(
        ic: '⚡',
        t: 'Voranalyse (Abschnitte)',
        fmt: 'JSON je Abschnitt (paragraphs, belege, sentences)',
        ort: 'Bundle der Arbeit',
        n: '$secN Abschnitte',
        src: 'mitgeliefert',
        on: secN > 0,
      ),
      _LogRow(
        ic: '⤳',
        t: 'Connections',
        fmt: 'connections.json {connections:[von→nach, typ]}',
        ort: 'Bundle + kiConnections + live abgeleitet',
        n: '$allConn sichtbar ($shipConn Bundle · $kiConn importiert)',
        src: allConn > shipConn + kiConn
            ? 'abgeleitet + Daten'
            : kiConn > 0
                ? 'beide'
                : 'mitgeliefert',
        on: allConn > 0,
      ),
      _LogRow(
        ic: '🎛',
        t: 'Views / Instanzen',
        fmt: 'instanzen.json + Markdown je Absatz',
        ort: 'Bundle + paraDock (+ auto aus Voranalyse)',
        n: shipInst > 0
            ? '$shipInst mitgeliefert · $dockN eigene'
            : 'auto aus Voranalyse · $dockN eigene',
        src: dockN > 0
            ? 'beide'
            : shipInst > 0
                ? 'mitgeliefert'
                : 'auto',
        on: shipInst + dockN + secN > 0,
      ),
      _LogRow(
        ic: '🖍',
        t: 'Extra-Markierungen',
        fmt: 'JSON {snippet, kategorie} je Absatz',
        ort: 'marksExtra',
        n: marksN > 0 ? '$marksN Marks' : '—',
        src: marksN > 0 ? 'importiert' : '—',
        on: marksN > 0,
      ),
      _LogRow(
        ic: '📓',
        t: 'Erklärbuch',
        fmt: 'Markdown (Charts/Tabellen als Zellen)',
        ort: nb ? 'notebook (eigenes)' : 'Bundle (eingebaut)',
        n: nb
            ? 'eigenes'
            : hasBuiltinBuch
                ? 'eingebaut'
                : '—',
        src: nb ? 'importiert' : 'mitgeliefert',
        on: nb || hasBuiltinBuch,
      ),
      _LogRow(
        ic: '📚',
        t: 'Quellen-Durchläufe',
        fmt: 'resolution.json je Quelle {stellen:[…]}',
        ort: 'resolutions',
        n: '${res.length} Quellen · $stellenN Stellen',
        src: res.isNotEmpty ? 'importiert' : '—',
        on: res.isNotEmpty,
      ),
      _LogRow(
        ic: '✓',
        t: 'Beleg-Stufen (von Hand)',
        fmt: 'JSON je Fußnote {seite, zitat, stufe}',
        ort: 'belegLevels',
        n: levelN > 0 ? '$levelN Fußnoten' : '—',
        src: levelN > 0 ? 'von Hand' : '—',
        on: levelN > 0,
      ),
    ];

    // Beide eingebauten Arbeiten: Auslieferungsstand (enhance.js:741-751).
    ProjectRecord? sens;
    for (final p in bundle?.builtinProjects ?? const <ProjectRecord>[]) {
      if (p.id == 'sensors-paper') {
        sens = p;
        break;
      }
    }
    final sg = sens?.generated;
    final sensSum = sens == null
        ? '—'
        : '${sg?.sections.length ?? 0} Abschnitte · ${sg?.connections?.connections.length ?? 0} Connections · ${sg?.instanzen?.defs.length ?? 0} Views · Erklärbuch ${sg?.erklaerbuch is String ? '✓' : '—'} · ${sg?.sources.length ?? 0} Dossiers';
    final activeId = boot?.activeId ?? ProjectRecord.defaultId;
    final isDefault = activeId == ProjectRecord.defaultId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(children: [
            const TextSpan(
                text: 'Wie ein Log: jedes Datenpaket mit Format, Speicherort und Herkunft. Alles liegt '),
            TextSpan(
                text: 'lokal im Browser',
                style: TextStyle(fontWeight: FontWeight.w700, color: t.ink)),
            const TextSpan(text: ', pro Arbeit getrennt ('),
            TextSpan(
              text: 'ehds.<arbeit>.…',
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontFamilyFallback: AppFonts.fallback,
                fontSize: 12,
                color: t.ink2,
                backgroundColor: t.surface3,
              ),
            ),
            const TextSpan(text: ') — der Original-LaTeX wird nie verändert.'),
          ]),
          style: AppTextStyles.small.copyWith(color: t.muted),
        ),
        const SizedBox(height: 10),
        // `.stand-log` — Zeilen mit Commit-Punkten an einer Linie.
        Stack(
          children: [
            Positioned(
              left: 5,
              top: 12,
              bottom: 12,
              child: Container(width: 2, color: t.border),
            ),
            Column(
              children: [for (final r in rows) _logRow(t, r)],
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Eyebrow('Beide Arbeiten — Auslieferungsstand'),
        const SizedBox(height: 6),
        _work(
          t,
          name: 'EHDS-Bachelorarbeit (eingebaut)',
          sub: 'Voranalyse vollständig mitgeliefert: Abschnitte · Connections · Instanzen · Erklärbuch · Dossiers (statisches Bundle)',
          active: isDefault,
          ok: true,
        ),
        const SizedBox(height: 6),
        _work(
          t,
          name: sens?.name ?? 'Mobile Sensors (Paper)',
          sub: 'Voranalyse vollständig mitgeliefert: $sensSum (v${sens?.builtinVersion ?? '?'})',
          active: !isDefault && activeId == 'sensors-paper',
          ok: sens != null,
        ),
        const SizedBox(height: 10),
        Text(
          'Arbeit wechseln über 🗂 oben rechts — die Zähler oben zeigen immer die AKTIVE Arbeit („${meta?.title ?? ''}“).',
          style: AppTextStyles.small.copyWith(color: t.muted),
        ),
      ],
    );
  }

  Widget _logRow(BookClothTokens t, _LogRow r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // `.lg-dot` — Commit-Punkt (12×12, on = good).
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: r.on ? t.good : t.surface3,
              border: Border.all(color: r.on ? t.good : t.borderStrong, width: 2),
            ),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 20,
            child: Text(r.ic,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, height: 1)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.t,
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontFamilyFallback: AppFonts.fallback,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.25,
                      color: t.ink,
                    )),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${r.fmt} · '),
                    TextSpan(
                      text: r.ort,
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontFamilyFallback: AppFonts.fallback,
                        fontSize: 10,
                        backgroundColor: t.surface3,
                      ),
                    ),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontFamilyFallback: AppFonts.fallback,
                    fontSize: 11,
                    height: 1.35,
                    color: t.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            r.n,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontFamilyFallback: AppFonts.fallback,
              fontWeight: FontWeight.w600,
              fontSize: 10.5,
              height: 1.3,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: t.ink2,
            ),
          ),
          const SizedBox(width: 8),
          AppChip(
            label: r.src,
            mini: true,
            variant: r.on ? AppChipVariant.ok : AppChipVariant.neutral,
          ),
        ],
      ),
    );
  }

  Widget _work(BookClothTokens t,
      {required String name,
      required String sub,
      required bool active,
      required bool ok}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: active ? t.accentSoft : t.surface2,
        border: Border.all(color: active ? t.accentLine : t.border),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(name,
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontFamilyFallback: AppFonts.fallback,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.25,
                    color: t.ink,
                  )),
              if (active)
                const AppChip(label: 'aktiv', mini: true, variant: AppChipVariant.ok),
              AppChip(
                label: ok ? '✓ aktuell' : 'unvollständig',
                mini: true,
                variant: ok ? AppChipVariant.ok : AppChipVariant.warn,
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(sub,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontFamilyFallback: AppFonts.fallback,
                fontSize: 11.5,
                height: 1.4,
                color: t.muted,
              )),
        ],
      ),
    );
  }
}
