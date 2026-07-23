/// Überblick — Executive Summary, Ergebnisse-Grid, Roter Faden,
/// Fristen-Timeline (`analyseUeberblick`, views_analyse.js:275-317).
///
/// Zwei-Spalten-Grid `minmax(0, 1.6fr) minmax(280px, 1fr)`; ≤900px eine
/// Spalte. Das Original wertet den Breakpoint nur EINMAL beim Render aus
/// (L7) — der LayoutBuilder macht das hier automatisch live (dokumentierte
/// Verbesserung, Dossier 06 Hinweis 12).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/richtext/mini_md.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/util/format.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/notice.dart';
import '../../../data/bundles/indexes.dart';
import '../../../data/models/models.dart';
import '../charts/timeline.dart';
import 'typ_chip.dart';
import 'wissen_card.dart';

class UeberblickTab extends ConsumerWidget {
  const UeberblickTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(activeRuntimeProvider)?.meta.gesamt;
    if (g == null) {
      return const Notice(child: Text('Gesamtzusammenfassung nicht generiert.'));
    }

    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth <= 900;
      final left = _LeftColumn(g: g);
      final right = _RightColumn(g: g);
      if (narrow) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          left,
          const SizedBox(height: 14),
          right,
        ]);
      }
      final total = constraints.maxWidth - 14;
      // 1.6fr : 1fr — die rechte Spalte hält min. 280px.
      var rightW = total / 2.6;
      if (rightW < 280) rightW = 280;
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: left),
        const SizedBox(width: 14),
        SizedBox(width: rightW, child: right),
      ]);
    });
  }
}

class _LeftColumn extends StatelessWidget {
  const _LeftColumn({required this.g});

  final GesamtMeta g;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final erg = g.ergebnisse;

    Widget ergCard(String typ, List<ErgebnisEintrag> items) => WissenCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(alignment: Alignment.centerLeft, child: TypChip(typ)),
              const SizedBox(height: 10),
              for (final i in items)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i.titel,
                          style: AppTextStyles.small.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: t.ink)),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        children: [
                          Text(i.text,
                              style: AppTextStyles.small
                                  .copyWith(color: t.ink2)),
                          if (i.frist != null)
                            AppChip(label: i.frist!, mini: false),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      WissenCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const WissenEyebrow('Executive Summary'),
          const SizedBox(height: 6),
          MiniMd(g.executiveSummary,
              baseStyle: AppTextStyles.body.copyWith(color: t.ink)),
        ]),
      ),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('Ergebnisse auf einen Blick',
            style: AppTextStyles.h2.copyWith(color: t.ink)),
      ),
      const SizedBox(height: 10),
      AutoGrid(minWidth: 230, children: [
        ergCard('positiv', erg.positiv),
        ergCard('luecke', erg.luecken),
        ergCard('spannung', erg.spannungen),
      ]),
    ]);
  }
}

class _RightColumn extends StatelessWidget {
  const _RightColumn({required this.g});

  final GesamtMeta g;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (g.roterFaden.isNotEmpty)
        WissenCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const WissenEyebrow('Roter Faden'),
            const SizedBox(height: 10),
            for (final (i, s) in g.roterFaden.indexed)
              _FadenStep(
                schritt: s,
                last: i == g.roterFaden.length - 1,
              ),
          ]),
        ),
      if (g.roterFaden.isNotEmpty && g.timeline.isNotEmpty)
        const SizedBox(height: 10),
      if (g.timeline.isNotEmpty)
        WissenCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const WissenEyebrow('Fristen-Timeline'),
            const SizedBox(height: 6),
            TimelineList(g.timeline, datumLabelOf: (it) => fmtDate(it.datum)),
          ]),
        ),
    ]);
  }
}

/// `.faden-step` (app.css:829-834): Nummern-Kachel 26×26 (mono 700 12,
/// accent-ink auf accent-soft) + 2px-Verbindungsbalken; Body mit Label (13.5
/// fett) und Text (14, ink-2).
class _FadenStep extends StatelessWidget {
  const _FadenStep({required this.schritt, required this.last});

  final RoterFadenSchritt schritt;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final n = schritt.kapitel ?? schritt.schritt;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Column(children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.accentSoft,
              border: Border.all(color: t.accentLine),
              borderRadius: BorderRadius.circular(BookClothTokens.radiusXs),
            ),
            child: Text(
              '${n ?? ''}',
              style: AppTextStyles.mono.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: t.accentInk,
              ),
            ),
          ),
          if (!last)
            Expanded(
              child: Container(
                width: 2,
                margin: const EdgeInsets.symmetric(vertical: 3),
                constraints: const BoxConstraints(minHeight: 14),
                color: t.accentLine.withValues(alpha: .5),
              ),
            ),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(schritt.label,
                    style: AppTextStyles.small.copyWith(
                        fontWeight: FontWeight.w700, color: t.ink)),
                Text(schritt.text,
                    style: AppTextStyles.small
                        .copyWith(fontSize: 14, color: t.ink2)),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
