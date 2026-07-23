/// „Beleg-Fortschritt je Kapitel“ — Port der Kapitel-Karte
/// (views_projekt.js:61-74, app.css:113-118): Legende mit den drei
/// Stufen-Punkten, je Kapitel eine `.chaprow` mit Nummer, Titel,
/// `Levels.bar` (130px), Zähler „x/y ✓“ und ⌖-Sprung ins Studio
/// (`#/studio/<num>.0/pruefen`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/chips.dart';
import '../../quellen/state/quellen_kv.dart';
import 'dash_card.dart';

class ChapterProgressCard extends ConsumerWidget {
  const ChapterProgressCard({super.key, required this.domain});

  final QuellenDomain domain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final levels = domain.levels;
    // Kapitel aus der effektiven Struktur (titleEdits sind angewandt —
    // das Original patcht DATA_THESIS in rebuildDataIndexes genauso).
    final chapters = domain.ctx.thesis?.chapters ?? const [];

    return ProjektCard(
      eyebrow: 'Beleg-Fortschritt je Kapitel',
      children: [
        const SizedBox(height: 6),
        // Legende: „<dot l1> vermutet → <dot l2> Original → <dot l3> belegt“
        Text.rich(
          TextSpan(children: [
            const WidgetSpan(
                alignment: PlaceholderAlignment.middle, child: LevelDot(1)),
            const TextSpan(text: ' vermutet → '),
            const WidgetSpan(
                alignment: PlaceholderAlignment.middle, child: LevelDot(2)),
            const TextSpan(text: ' Original → '),
            const WidgetSpan(
                alignment: PlaceholderAlignment.middle, child: LevelDot(3)),
            const TextSpan(text: ' belegt'),
          ]),
          style: AppTextStyles.small.copyWith(color: t.muted),
        ),
        const SizedBox(height: 4),
        for (final (i, ch) in chapters.indexed)
          Container(
            padding: const EdgeInsets.fromLTRB(4, 9, 4, 9),
            decoration: BoxDecoration(
              border: i == chapters.length - 1
                  ? null
                  : Border(bottom: BorderSide(color: t.border)),
            ),
            child: Row(
              spacing: 12,
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    '${ch.num}',
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontFamilyFallback: AppFonts.fallback,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 1,
                      color: t.accentInk,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    ch.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontFamilyFallback: AppFonts.fallback,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      height: 1.3,
                      color: t.ink,
                    ),
                  ),
                ),
                Builder(builder: (context) {
                  final nums = levels.numsForChapter(ch.num);
                  final cc = levels.countsFor(nums);
                  return Row(
                    spacing: 12,
                    children: [
                      SizedBox(
                        width: 130,
                        child: LvlBar(
                            l1: cc.l1, l2: cc.l2, l3: cc.l3, total: cc.total),
                      ),
                      SizedBox(
                        width: 70,
                        child: Text(
                          '${cc.l3}/${cc.total} ✓',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontFamily: AppFonts.mono,
                            fontFamilyFallback: AppFonts.fallback,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                            height: 1,
                            color: t.muted,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                AppButton(
                  small: true,
                  onPressed: () => context.go(Routes.studioPath(
                      sec: '${ch.num}.0', modus: StudioModes.pruefen)),
                  child: const Text('⌖'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
