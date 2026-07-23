/// 🤖 Stil-Check-UI — Port von `appendScFlag` (:859-867) und
/// `styleCheckModal` (:625-633): Zähler-Chip am Absatz-Fuß, Klick öffnet
/// das Modal mit den auffälligen Sätzen + Treffer-Chips.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/modal.dart';
import '../../../data/models/models.dart';
import '../../../domain/stylecheck.dart';

/// `.sc-flag`: „🤖 N“.
class ScFlag extends StatelessWidget {
  const ScFlag({super.key, required this.paragraph, required this.flagged});

  final Paragraph paragraph;
  final List<FlaggedSentence> flagged;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Tooltip(
      message:
          'GPT-Stil-Check: ${flagged.length == 1 ? '1 auffälliger Satz' : '${flagged.length} auffällige Sätze'} — klicken für Begründungen',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => showStyleCheckModal(context, paragraph, flagged),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: t.warnSoft,
              border: Border.all(color: t.warn),
              borderRadius: BorderRadius.circular(BookClothTokens.radiusPill),
            ),
            child: Text(
              '🤖 ${flagged.length}',
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontFamilyFallback: AppFonts.fallback,
                fontWeight: FontWeight.w600,
                fontSize: 10.5,
                height: 1.3,
                color: t.warn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showStyleCheckModal(
  BuildContext context,
  Paragraph p,
  List<FlaggedSentence> flagged,
) {
  return showAppModal<void>(
    context,
    title: Text('🤖 Stil-Check — Absatz ${p.id}'),
    body: _StyleCheckBody(flagged: flagged),
  );
}

class _StyleCheckBody extends StatelessWidget {
  const _StyleCheckBody({required this.flagged});

  final List<FlaggedSentence> flagged;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Deterministische Heuristik (ohne KI): Floskeln, vage Einordnungen, '
          'Konnektor-Ketten, wertende Sätze ohne Beleg oder Konkretes. '
          'Ein Hinweis zum Selbst-Redigieren — kein Urteil.',
          style: AppTextStyles.small.copyWith(color: t.muted),
        ),
        for (final (i, f) in flagged.indexed)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: i > 0
                ? BoxDecoration(
                    border: Border(top: BorderSide(color: t.border)))
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '„${f.text.replaceAll(RegExp(r'\[\^\d+\]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim()}“',
                  style: AppTextStyles.small.copyWith(color: t.ink),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final h in f.hits)
                      AppChip(label: h, variant: AppChipVariant.warn, mini: true),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
