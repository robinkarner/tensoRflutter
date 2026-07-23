/// Globales Fußnoten-Detail — Pendant zu `showFootnoteModal` (app.js:252-271).
///
/// Wird von überall aufgerufen (jeder Fußnoten-Chip im Text delegiert
/// hierher). Zeigt in fester Reihenfolge: Fußnotentext als Blockquote →
/// „Was hier belegt wird“ (Claim) → KI-Vermutung (✦ Fundstelle + Suche) →
/// bei Stufe ≥ 2 den Nachweis (❝ Zitat/Seite/Fundstelle) → Quellenliste
/// mit Links → Fundort-Fußzeile (Abschnitt/Absatz + Lesemodus-Link).
///
/// Der Belegstatus kommt aus der Levels-Kaskade (F-D): wie im Original wird
/// er beim Öffnen EINMAL aus dem aktuellen Stand berechnet (das Modal ist
/// eine Momentaufnahme, kein Live-View). Die PDF-Markierungs-Stufe der
/// Kaskade kommt aus der PDF-Engine (S-1, `levelsMarksForFnProvider`) —
/// solange deren Marks-Store noch lädt, bleibt sie leer (identisch zum
/// Original ohne geladenes PdfEngine-Modul).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/bundles/indexes.dart';
import '../../data/db/kv.dart';
import '../../features/pdf/marks/pdf_marks_store.dart';
import '../../data/models/models.dart';
import '../../domain/domain_context.dart';
import '../../domain/domain_store.dart';
import '../../domain/levels.dart';
import '../router/routes.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/chips.dart';
import '../widgets/eyebrow.dart';
import '../widgets/modal.dart';

/// Öffnet das Fußnoten-Modal für die Fußnote [num]; ohne Index-Eintrag
/// passiert nichts (app.js:254).
Future<void> showFootnoteModal(BuildContext context, int num) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final fn = container.read(fnIndexProvider)[num];
  if (fn == null) return;

  final beleg = container.read(findBelegProvider(num));
  final info = (await _buildLevels(container)).info(num);
  if (!context.mounted) return;

  // Quellenliste: beleg.quellen gewinnt, sonst fn.sources (app.js:257).
  final srcIds = beleg != null && beleg.quellen.isNotEmpty
      ? beleg.quellen
      : fn.sources;

  await showAppModal<void>(
    context,
    title: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text('Fußnote $num')),
        const SizedBox(width: 8),
        LevelBadge(info.level),
      ],
    ),
    body: _FootnoteBody(fn: fn, beleg: beleg, info: info, srcIds: srcIds),
  );
}

/// Levels-Instanz aus dem aktuellen Provider-Stand + einem KV-Schnappschuss
/// der drei Kaskaden-Stores (belegLevels/resolutions/annotations) bauen.
Future<Levels> _buildLevels(ProviderContainer container) async {
  final runtime = container.read(activeRuntimeProvider);
  final ctx = DomainContext(
    thesis: container.read(effectiveThesisProvider),
    unitIndex: container.read(unitIndexProvider),
    fnIndex: container.read(fnIndexProvider),
    sources: runtime?.sources ?? const [],
    srcById: container.read(srcByIdProvider),
    orderedUnitIds: container.read(orderedUnitsProvider),
    sections: runtime?.sections ?? const {},
    meta: runtime?.meta ?? const DataMeta(),
  );

  final kv = container.read(kvStoreProvider);
  final store = MemoryDomainStore({
    for (final key in const [
      KvKeys.belegLevels,
      KvKeys.resolutions,
      KvKeys.annotations,
    ])
      key: await kv.getJson(key),
  }..removeWhere((_, v) => v == null));

  return Levels(
    ctx,
    store,
    // PDF-Markierungs-Stufe der Kaskade (S-1) — null, solange der
    // Marks-Store noch lädt.
    marksForFn: container.read(levelsMarksForFnProvider),
  );
}

// ---------------------------------------------------------------------------
// Modal-Inhalt
// ---------------------------------------------------------------------------

class _FootnoteBody extends StatelessWidget {
  const _FootnoteBody({
    required this.fn,
    required this.beleg,
    required this.info,
    required this.srcIds,
  });

  final FnIndexEntry fn;
  final Beleg? beleg;
  final LevelInfo info;
  final List<String> srcIds;

  /// Modal schließen, dann navigieren — Pendant zu den
  /// `onclick="U.closeModal()"`-Links des Originals.
  void _goAndClose(BuildContext context, String path) {
    final router = GoRouter.of(context);
    closeAppModal();
    router.go(path);
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final seite = info.seite;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fußnotentext als Blockquote (3px accent-line links, ink-2).
        Container(
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: t.accentLine, width: 3)),
          ),
          child: Text(fn.text, style: AppTextStyles.body.copyWith(color: t.ink2)),
        ),

        if (beleg != null && beleg!.claim.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Eyebrow('Was hier belegt wird'),
          const SizedBox(height: 4),
          Text(beleg!.claim, style: AppTextStyles.body.copyWith(color: t.ink)),
        ],

        if (beleg != null && beleg!.fundstelle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _KiChip(fundstelle: beleg!.fundstelle),
              if (beleg!.suchHinweis.isNotEmpty)
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Suche: '),
                    TextSpan(
                      text: beleg!.suchHinweis,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ]),
                  style: AppTextStyles.small.copyWith(color: t.muted),
                ),
            ],
          ),
        ],

        if (info.level >= 2 && (info.zitat ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          const Eyebrow('Nachgewiesen'),
          const SizedBox(height: 4),
          Text(
            '❝ „${info.zitat}“'
            '${seite != null && '$seite'.isNotEmpty ? ' — S. $seite' : ''}'
            '${(info.fundstelle ?? '').isNotEmpty ? ' — ${info.fundstelle}' : ''}',
            style: AppTextStyles.small.copyWith(color: t.ink2),
          ),
        ],

        const SizedBox(height: 12),
        const Eyebrow('Quelle(n)'),
        const SizedBox(height: 6),
        if (srcIds.isEmpty)
          Text('—', style: AppTextStyles.body.copyWith(color: t.muted))
        else
          for (final id in srcIds)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _SourceRow(
                srcId: id,
                onOpen: () => _goAndClose(context, Routes.quellenPath(id)),
              ),
            ),

        const SizedBox(height: 12),
        // Fundort-Zeile: Abschnitt (→ Prüfen) · Absatz · Lesemodus ☰.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Abschnitt ',
                style: AppTextStyles.small.copyWith(color: t.muted)),
            _InlineLink(
              fn.sectionId,
              onTap: () => _goAndClose(
                context,
                Routes.studioPath(sec: fn.sectionId, modus: StudioModes.pruefen),
              ),
            ),
            Text(' · Absatz ${fn.paragraphId} · ',
                style: AppTextStyles.small.copyWith(color: t.muted)),
            _InlineLink(
              'im Lesemodus ☰',
              onTap: () => _goAndClose(
                context,
                Routes.studioPath(sec: fn.sectionId, modus: StudioModes.lesen),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// `.chip.ki` mit „✦ vermutet: **{fundstelle}**“ — die Fundstelle fett,
/// deshalb kein einfacher [AppChip].
class _KiChip extends StatelessWidget {
  const _KiChip({required this.fundstelle});

  final String fundstelle;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9.5, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(BookClothTokens.radiusPill),
      ),
      child: Text.rich(
        TextSpan(children: [
          const TextSpan(text: '✦ vermutet: '),
          TextSpan(
            text: fundstelle,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ]),
        style: TextStyle(
          fontFamily: AppFonts.ui,
          fontFamilyFallback: AppFonts.fallback,
          fontWeight: FontWeight.w500,
          fontSize: 12,
          height: 1.35,
          color: t.ki,
        ),
      ),
    );
  }
}

/// Eine Quellen-Zeile: Titel-Link (→ Quellenseite) + Art-Chip (KIND_LABELS).
class _SourceRow extends ConsumerWidget {
  const _SourceRow({required this.srcId, required this.onOpen});

  final String srcId;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(srcByIdProvider)[srcId];
    final kindLabel = s == null ? '' : (kindLabels[s.kind] ?? s.kind);
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _InlineLink(s?.title ?? srcId, onTap: onOpen),
        if (kindLabel.isNotEmpty) AppChip(label: kindLabel),
      ],
    );
  }
}

/// Inline-Link im globalen `a`-Stil (accent-ink, ohne Unterstreichung).
class _InlineLink extends StatelessWidget {
  const _InlineLink(this.label, {required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          label,
          style: AppTextStyles.small.copyWith(color: t.accentInk),
        ),
      ),
    );
  }
}
