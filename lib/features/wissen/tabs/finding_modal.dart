/// Befund-Detail-Modal — `showFinding` (views_analyse.js:483-496): Titel =
/// Typ-Chip + Label; Body: Beschreibung, Fristen-Chips, „Hergeleitet aus“-
/// Linkliste (Klick schließt das Modal und öffnet das Studio), optional
/// „Zum Fazit-Absatz (6.0-pX) →“.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/modal.dart';
import '../../../data/bundles/indexes.dart';
import 'typ_chip.dart';
import 'wissen_card.dart';

void showFindingModal(BuildContext context, WidgetRef ref, String findingId) {
  final fz = ref.read(activeRuntimeProvider)?.meta.fazit;
  final f = fz?.findings.where((x) => x.id == findingId).firstOrNull;
  if (f == null) return;
  final unitIndex = ref.read(unitIndexProvider);

  showAppModal<void>(
    context,
    title: Row(mainAxisSize: MainAxisSize.min, children: [
      TypChip(f.typ),
      const SizedBox(width: 8),
      Flexible(child: Text(f.label)),
    ]),
    body: Builder(builder: (context) {
      final t = BookClothTokens.of(context);
      void goStudio(String sec) {
        closeAppModal();
        context.go(Routes.studioPath(sec: sec));
      }

      Widget link(String text, VoidCallback onTap) => MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onTap,
              child: Text(text,
                  style: AppTextStyles.body.copyWith(color: t.accentInk)),
            ),
          );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(f.beschreibung,
              style: AppTextStyles.body.copyWith(color: t.ink)),
          if (f.fristen.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final x in f.fristen)
                  AppChip(label: x, variant: AppChipVariant.warn),
              ]),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: WissenEyebrow('Hergeleitet aus'),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in f.abschnitte)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: link(
                      '$s ${unitIndex[s]?.unit.title ?? ''}',
                      () => goStudio(s),
                    ),
                  ),
              ],
            ),
          ),
          if (f.fazitParagraphId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: link('Zum Fazit-Absatz (${f.fazitParagraphId}) →',
                  () => goStudio('6.0')),
            ),
        ],
      );
    }),
  );
}
