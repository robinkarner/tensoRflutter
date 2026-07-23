/// „Referenzierungsdurchläufe — je Quelle“ — Port der Durchläufe-Karte
/// (views_projekt.js:201-224): Quellen absteigend nach Zitierstellen,
/// je Quelle ✓/·-Status („done“ = Resolution importiert), „Durchlauf“
/// öffnet DENSELBEN GPT-Dialog wie überall — hier das ⧉/⭱-Pendant
/// [showDurchlaufModal] (S-4; der Magic-Knopf dockt in K-3 dort an).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../domain/js_compat.dart';
import '../../quellen/detail/durchlauf_modal.dart';
import '../../quellen/state/quellen_kv.dart';
import '../dashboard/dash_card.dart';

class ReferenzRunsCard extends ConsumerWidget {
  const ReferenzRunsCard({super.key, required this.domain});

  final QuellenDomain domain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final resAll = domain.resolutions;
    // Sortierung: citations DESC — stabil wie JS-sort (views_projekt.js:210).
    final sorted = stableSorted(domain.sources,
        (a, b) => b.citations.length.compareTo(a.citations.length));

    return ProjektCard(
      eyebrow: 'Referenzierungsdurchläufe — je Quelle',
      children: [
        const SizedBox(height: 6),
        Text(
          'Ein Durchlauf schlägt für jede Zitierstelle einer Quelle die '
          'konkrete Fundstelle vor (Seite/Art/§ + Suchbegriffe + Zitat). '
          '„Durchlauf" öffnet das Einfüge-Fenster: Prompt kopieren, Antwort '
          'direkt hier importieren — direkt kochen geht über den GPT-Knopf '
          'oben.',
          style: AppTextStyles.small.copyWith(color: t.muted),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, s) in sorted.indexed)
                  Builder(builder: (context) {
                    final doneRaw = resAll[s.id];
                    final done = doneRaw is Map ? doneRaw : null;
                    final stellen = done?['stellen'];
                    final title = s.title.length > 54
                        ? '${s.title.substring(0, 54)}…'
                        : s.title;
                    return Container(
                      padding: const EdgeInsets.fromLTRB(4, 7, 4, 7),
                      decoration: BoxDecoration(
                        border: i == sorted.length - 1
                            ? null
                            : Border(bottom: BorderSide(color: t.border)),
                      ),
                      child: Row(
                        spacing: 9,
                        children: [
                          SizedBox(
                            width: 16,
                            child: Text(
                              done != null ? '✓' : '·',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                height: 1,
                                color: done != null ? t.good : t.ki,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text.rich(
                              TextSpan(children: [
                                TextSpan(
                                    text: domain.ctx.srcShort(s.id),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                TextSpan(
                                  text: ' $title · ${s.citations.length} '
                                      'Stellen'
                                      '${done != null ? ' · ${stellen is List ? stellen.length : 0} importiert' : ''}',
                                  style: AppTextStyles.small
                                      .copyWith(color: t.muted),
                                ),
                              ]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: AppFonts.ui,
                                fontFamilyFallback: AppFonts.fallback,
                                fontSize: 14,
                                height: 1.3,
                                color: t.ink,
                              ),
                            ),
                          ),
                          Row(
                            spacing: 4,
                            children: [
                              AppButton(
                                small: true,
                                tooltip: 'Quellen-Durchlauf: Prompt kopieren, '
                                    'Antwort einfügen — Fundstelle + Zitat je '
                                    'Zitierstelle',
                                onPressed: () => showDurchlaufModal(
                                    context, ref, source: s),
                                child: const Text('Durchlauf'),
                              ),
                              AppButton(
                                small: true,
                                tooltip: 'Quellenseite',
                                onPressed: () =>
                                    context.go(Routes.quellenPath(s.id)),
                                child: const Text('✎'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
