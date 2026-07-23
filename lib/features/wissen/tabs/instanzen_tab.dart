/// 🌐 Übersetzung & Instanzen — die Absatz-Instanzen der ganzen Arbeit als
/// fortlaufendes Dokument (`analyseInstanzen`, views_analyse.js:223-272).
///
/// Dieselben Daten wie die Instanz-Fenster im Prüftab (dort erstell-/
/// editier-/generierbar): je Abschnitt eine Karte mit `.inst-row`-Zeilen
/// (44px-Mono-Spalte mit der Absatz-Kurz-id + Markdown-Inhalt).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/richtext/mini_md.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/notice.dart';
import '../../../data/bundles/indexes.dart';
import '../../../data/models/models.dart';
import '../../studio/layout/dock_state.dart';
import '../../studio/layout/studio_state.dart';
import 'wissen_card.dart';

class InstanzenTab extends ConsumerWidget {
  const InstanzenTab({super.key, this.modeArg});

  final String? modeArg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);

    // Text-Instanzen aus den Instanz-Definitionen (inkl. selbst definierter).
    final modes = [
      for (final d in ref.watch(dockDefsProvider))
        if (!d.special) d,
    ];
    final mode = modes.any((d) => d.id == modeArg)
        ? modeArg!
        : (modes.firstOrNull?.id ?? '');
    if (mode.isEmpty) {
      return const Notice(
        variant: NoticeVariant.info,
        child: Text(
            'Keine Text-Instanzen definiert — im Studio über ✎ in der Instanz-Leiste anlegen.'),
      );
    }
    final modeLabel = modes.firstWhere((d) => d.id == mode).label;

    final domain = ref.watch(studioDomainProvider);
    final snapshot =
        ref.watch(studioKvProvider).value ?? const <String, Object?>{};
    final unitIndex = ref.watch(unitIndexProvider);
    final ordered = ref.watch(orderedUnitsProvider);

    // Abdeckung zählen + Abschnitts-Daten sammeln.
    var covered = 0, totalParas = 0;
    final secData = <({String id, Unit unit, List<(Paragraph, String)> rows, int has})>[];
    for (final id in ordered) {
      final entry = unitIndex[id];
      if (entry == null) continue;
      final paras = [
        for (final p in entry.unit.paragraphs)
          if (p.typeEnum == ParagraphType.text || p.typeEnum == ParagraphType.list) p,
      ];
      final rows = <(Paragraph, String)>[];
      var has = 0;
      for (final p in paras) {
        var text = dockGetFrom(snapshot, mode, p.id);
        if (text.isEmpty && domain != null) {
          text = dockAutoFor(domain, mode, id, p);
        }
        rows.add((p, text));
        if (text.isNotEmpty) has++;
      }
      covered += has;
      totalParas += paras.length;
      secData.add((id: id, unit: entry.unit, rows: rows, has: has));
    }

    final children = <Widget>[
      // Mode-Picker-Zeile.
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final d in modes)
              AppButton(
                small: true,
                variant: d.id == mode
                    ? AppButtonVariant.primary
                    : AppButtonVariant.solid,
                onPressed: () => context
                    .go(Routes.analysePath(tab: 'instanzen', arg: d.id)),
                child: Text(d.label),
              ),
            Text('$covered von $totalParas Absätzen vorhanden',
                style: AppTextStyles.small.copyWith(color: t.muted)),
            Text(
              'erstellen/ändern: GPT-Knopf oben in der Kopfleiste generiert global; direkt in den Fenstern schreibbar'
              '${mode == 'analyse' ? ' · generell (ohne Kapitel): 📓 Erklärbuch' : ''}',
              style: AppTextStyles.small.copyWith(color: t.muted),
            ),
          ],
        ),
      ),
    ];

    if (covered == 0) {
      children.add(Notice(
        variant: NoticeVariant.info,
        child: Text('Noch keine $modeLabel-Instanzen vorhanden. '
            'Über den GPT-Knopf oben in der Kopfleiste global generieren '
            '— oder direkt in den Instanz-Fenstern schreiben.'),
      ));
      return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    }

    for (final sd in secData) {
      if (sd.has == 0) continue;
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: WissenCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                // Abschnitts-id in accent-ink (hier NICHT wissen-ink!).
                Text(sd.id,
                    style: AppTextStyles.mono
                        .copyWith(fontSize: 12, color: t.accentInk)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    sd.unit.isIntro
                        ? (unitIndex[sd.id]?.chapter.title ?? sd.unit.title)
                        : sd.unit.title,
                    style: AppTextStyles.h3.copyWith(color: t.ink),
                  ),
                ),
                AppButton(
                  small: true,
                  onPressed: () => context.go(Routes.studioPath(
                      sec: sd.id, modus: StudioModes.pruefen)),
                  child: const Text('⌖ Studio'),
                ),
              ]),
              const SizedBox(height: 10),
              for (final (p, text) in sd.rows)
                if (text.isNotEmpty)
                  // `.inst-row`: 44px-Spalte + Inhalt, gestrichelte Trennlinie.
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                            color: t.border.withValues(alpha: .7)),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 44,
                          child: Text(
                            p.id.replaceFirst('${sd.id}-', ''),
                            style: AppTextStyles.mono.copyWith(
                                fontSize: 12.5, color: t.muted),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MiniMd(text,
                              baseStyle: AppTextStyles.body.copyWith(
                                  fontSize: 14, height: 1.7, color: t.ink)),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ));
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}
