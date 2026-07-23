/// Kapitel-Tab — Kurzfassung je Kapitel mit Fazit-Bezug
/// (`analyseKapitel`, views_analyse.js:320-367). Default-Kapitel: 6.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/richtext/mini_md.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/notice.dart';
import '../../../data/bundles/indexes.dart';
import '../../../data/models/models.dart';
import '../charts/fazit_graph.dart';
import 'finding_modal.dart';
import 'wissen_card.dart';

class KapitelTab extends ConsumerWidget {
  const KapitelTab({super.key, required this.chNum});

  final int chNum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final runtime = ref.watch(activeRuntimeProvider);
    final chapters = ref.watch(effectiveThesisProvider)?.chapters ?? const [];
    final unitIndex = ref.watch(unitIndexProvider);

    final picker = Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Wrap(spacing: 10, runSpacing: 8, children: [
        for (final c in chapters)
          AppButton(
            small: true,
            variant: c.num == chNum
                ? AppButtonVariant.primary
                : AppButtonVariant.solid,
            onPressed: () =>
                context.go(Routes.analysePath(tab: 'kapitel', arg: '${c.num}')),
            child: Text('${c.num} ${c.title}'),
          ),
      ]),
    );

    final k = runtime?.meta.kapitel['$chNum'];
    if (k == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        picker,
        const Notice(child: Text('Kapitel-Zusammenfassung nicht generiert.')),
      ]);
    }

    // Fazit-Bezug: Kapitel 6 = alle Findings, sonst Filter nach Abschnitten.
    final fz = runtime?.meta.fazit;
    final rel = [
      for (final f in fz?.findings ?? const <FazitFinding>[])
        if (chNum == 6 || f.abschnitte.any((s) => s.startsWith('$chNum.'))) f,
    ];

    final grid = <Widget>[];
    if (k.kernaussagen.isNotEmpty) {
      grid.add(WissenCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const WissenEyebrow('Kernaussagen'),
          const SizedBox(height: 8),
          for (final s in k.kernaussagen)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('•  ',
                    style: AppTextStyles.small
                        .copyWith(fontSize: 13.5, color: t.ink)),
                Expanded(
                  child: Text(s,
                      style: AppTextStyles.small
                          .copyWith(fontSize: 13.5, color: t.ink)),
                ),
              ]),
            ),
        ]),
      ));
    }
    if (k.begriffe.isNotEmpty) {
      grid.add(WissenCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const WissenEyebrow('Begriffe in diesem Kapitel'),
          const SizedBox(height: 8),
          for (final b in k.begriffe)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: b.begriff,
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: t.ink)),
                  TextSpan(
                      text: ' — ${b.erklaerung}',
                      style: TextStyle(color: t.ink2)),
                ]),
                style: AppTextStyles.small,
              ),
            ),
        ]),
      ));
    }
    if (k.fristen.isNotEmpty) {
      grid.add(WissenCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const WissenEyebrow('Fristen'),
          const SizedBox(height: 8),
          for (final f in k.fristen)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AppChip(label: f.datum, variant: AppChipVariant.warn),
                  Text(f.was,
                      style: AppTextStyles.small.copyWith(color: t.ink2)),
                ],
              ),
            ),
        ]),
      ));
    }
    if (k.abschnitte.isNotEmpty) {
      grid.add(WissenCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const WissenEyebrow('Abschnitte'),
          const SizedBox(height: 8),
          for (final a in k.abschnitte)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => context.go(Routes.studioPath(sec: a.id)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: a.id,
                            style: AppTextStyles.mono.copyWith(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: t.accentInk,
                            ),
                          ),
                          TextSpan(
                              text: ' ${a.titel}',
                              style: TextStyle(color: t.accentInk)),
                        ]),
                        style: AppTextStyles.body,
                      ),
                      Text(a.einzeiler,
                          style:
                              AppTextStyles.small.copyWith(color: t.muted)),
                    ],
                  ),
                ),
              ),
            ),
        ]),
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      picker,
      WissenCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          WissenEyebrow('Kapitel $chNum kompakt'),
          const SizedBox(height: 6),
          MiniMd(k.kurzfassung,
              baseStyle: AppTextStyles.body.copyWith(color: t.ink)),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 8, children: [
            AppButton(
              small: true,
              onPressed: () => context.go(Routes.studioPath(
                  sec: '$chNum.0', modus: StudioModes.pruefen)),
              child: const Text('Im Studio prüfen ⌖'),
            ),
            AppButton(
              small: true,
              onPressed: () => context.go(Routes.studioPath(
                  sec: '$chNum.0', modus: StudioModes.lesen)),
              child: const Text('Kapitel lesen ☰'),
            ),
          ]),
        ]),
      ),
      if (grid.isNotEmpty) ...[
        const SizedBox(height: 16),
        AutoGrid(minWidth: 300, children: grid),
      ],
      const SizedBox(height: 16),
      WissenCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const WissenEyebrow('Verbindung zum Fazit'),
          if (k.fazitBeitrag.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(k.fazitBeitrag,
                  style: AppTextStyles.small
                      .copyWith(fontSize: 13.5, color: t.ink)),
            ),
          if (rel.isNotEmpty)
            FazitGraphChart(
              rel,
              onFinding: (id) => showFindingModal(context, ref, id),
              onSection: (s) => context.go(Routes.studioPath(sec: s)),
              sectionTitle: (s) => unitIndex[s]?.unit.title,
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Keine direkten Fazit-Befunde aus diesem Kapitel.',
                  style: AppTextStyles.small.copyWith(color: t.muted)),
            ),
        ]),
      ),
    ]);
  }
}
