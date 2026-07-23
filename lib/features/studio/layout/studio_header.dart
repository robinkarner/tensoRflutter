/// Abschnittskopf + Vor/Zurück-Navigation — Pendant zu `studioHeader`
/// (:188-206) und `sectionNav` (:310-317).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../data/bundles/indexes.dart';

/// Titelzeile (nicht sticky): h2 mit „Kapitel n“ bzw. Abschnitts-ID + Titel,
/// darunter die Meta-Zeile mit Kapitel und Original-PDF-Link.
class StudioHeader extends ConsumerWidget {
  const StudioHeader({super.key, required this.sectionId});

  final String sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final info = ref.watch(unitIndexProvider)[sectionId];
    if (info == null) return const SizedBox.shrink();
    final u = info.unit;
    final ch = info.chapter;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${u.isIntro ? 'Kapitel ${ch.num}' : sectionId} '
            '${(u.isIntro ? ch.title : u.title)}',
            style: AppTextStyles.h2.copyWith(color: t.ink),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Kapitel ${ch.num} · ${ch.title}',
                style: AppTextStyles.small.copyWith(color: t.muted),
              ),
              if (u.pdfPage != null)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    // Original: sources/thesis.pdf#page=n in neuem Tab — im
                    // Asset-Bundle nicht verlinkbar; der Link bleibt für
                    // Web-Hosting-Fälle mit relativem Pfad bestehen.
                    onTap: () => launcher.launchUrl(
                      Uri.parse('sources/thesis.pdf#page=${u.pdfPage}'),
                      mode: launcher.LaunchMode.externalApplication,
                    ),
                    child: Text(
                      'Original-PDF S. ${u.page} ↗',
                      style: AppTextStyles.small.copyWith(color: t.accentInk),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ← / →-Navigation zwischen Abschnitten (nur Abschnitte mit Absätzen).
class SectionNav extends ConsumerWidget {
  const SectionNav({super.key, required this.sectionId, required this.mode});

  final String sectionId;
  final String mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderedUnitsProvider);
    final idx = order.indexOf(sectionId);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (idx > 0)
            AppButton(
              child: Text('← ${order[idx - 1]}'),
              onPressed: () => context
                  .go(Routes.studioPath(sec: order[idx - 1], modus: mode)),
            )
          else
            const SizedBox.shrink(),
          if (idx >= 0 && idx < order.length - 1)
            AppButton(
              child: Text('${order[idx + 1]} →'),
              onPressed: () => context
                  .go(Routes.studioPath(sec: order[idx + 1], modus: mode)),
            ),
        ],
      ),
    );
  }
}
