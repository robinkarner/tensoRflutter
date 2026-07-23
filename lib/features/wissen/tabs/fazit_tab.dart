/// Connections-Tab (Fazit-Netz) — `analyseFazit` (views_analyse.js:370-391):
/// Kapitelfluss (Klick auf Knoten → Kapitel-Tab), Fazit-Connections
/// (bipartiter Graph mit Hover-Dimming) und die klickbare Befund-Liste.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/bundles/indexes.dart';
import '../../../data/models/models.dart';
import '../charts/fazit_graph.dart';
import '../charts/kapitel_fluss.dart';
import 'finding_modal.dart';
import 'typ_chip.dart';
import 'wissen_card.dart';

class FazitTab extends ConsumerWidget {
  const FazitTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final fz = ref.watch(activeRuntimeProvider)?.meta.fazit;
    final chapters = ref.watch(effectiveThesisProvider)?.chapters ?? const [];
    final unitIndex = ref.watch(unitIndexProvider);

    final findings = fz?.findings ?? const [];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      WissenCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const WissenEyebrow('Kapitelfluss — wie die Arbeit ihr Fazit herleitet'),
          const SizedBox(height: 8),
          KapitelFlussChart(
            [
              for (final c in chapters)
                FlussChapter(num: c.num, title: c.title, tip: 'ab S. ${c.page}'),
            ],
            edges: [
              for (final e in fz?.kapitelFluss ?? const <KapitelFlussKante>[])
                FlussEdge(from: e.from, to: e.to, label: e.label),
            ],
            onClick: (ch) =>
                context.go(Routes.analysePath(tab: 'kapitel', arg: ch)),
          ),
        ]),
      ),
      if (findings.isNotEmpty) ...[
        const SizedBox(height: 16),
        WissenCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const WissenEyebrow('Fazit-Connections — Befunde und ihre Herleitung'),
            const SizedBox(height: 8),
            FazitGraphChart(
              findings,
              onFinding: (id) => showFindingModal(context, ref, id),
              onSection: (s) => context.go(Routes.studioPath(sec: s)),
              sectionTitle: (s) => unitIndex[s]?.unit.title,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Hover hebt Herleitungspfade hervor · Klick auf einen Befund zeigt Details · Klick auf einen Abschnitt öffnet das Studio.',
                style:
                    AppTextStyles.small.copyWith(fontSize: 12.5, color: t.muted),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        WissenCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const WissenEyebrow('Alle Befunde'),
            const SizedBox(height: 8),
            for (final (i, f) in findings.indexed)
              PunktRow(
                icon: TypChip(f.typ),
                last: i == findings.length - 1,
                onTap: () => showFindingModal(context, ref, f.id),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: f.label,
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: t.ink)),
                    TextSpan(
                        text: ' — ${f.beschreibung}',
                        style: TextStyle(color: t.ink2)),
                    for (final x in f.fristen)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: _fristChip(t, x),
                        ),
                      ),
                  ]),
                  style: AppTextStyles.body.copyWith(fontSize: 14),
                ),
              ),
          ]),
        ),
      ],
    ]);
  }

  Widget _fristChip(BookClothTokens t, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9.5, vertical: 4),
        decoration: BoxDecoration(
          color: t.warnSoft,
          borderRadius: BorderRadius.circular(BookClothTokens.radiusPill),
        ),
        child: Text(label,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontFamilyFallback: AppFonts.fallback,
              fontWeight: FontWeight.w500,
              fontSize: 12,
              height: 1,
              color: t.warn,
            )),
      );
}
