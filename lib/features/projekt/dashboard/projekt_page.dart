/// `#/projekt` — das Status-Dashboard der aktiven Arbeit (Port von
/// `renderProjekt`, views_projekt.js:11-268): Seitenkopf mit Arbeits-Chip,
/// Boot-Warnungen, 6 Status-Kacheln, darunter zwei Spalten 1.55fr/1fr
/// (Breakpoint 999px → einspaltig): links Kapitel-Fortschritt,
/// Quellen-Setup und Referenzierungsdurchläufe, rechts Connections und
/// Anleitung. Die Arbeiten-Verwaltung lebt im 🗂-Menü der Topbar (K-2,
/// works_menu.dart) — wie im Original nicht mehr auf dieser Seite.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/notice.dart';
import '../../../data/repos/project_repository.dart';
import '../../quellen/state/quellen_kv.dart';
import '../setup/quellen_setup_card.dart';
import '../setup/referenz_runs_card.dart';
import 'chapter_progress_card.dart';
import 'info_cards.dart';
import 'stat_grid.dart';

class ProjektPage extends ConsumerWidget {
  const ProjektPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final domain = ref.watch(quellenDomainProvider);
    final boot = ref.watch(projectBootProvider).value;
    if (domain == null || boot == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child:
              Text('Lade …', style: AppTextStyles.small.copyWith(color: t.muted)),
        ),
      );
    }

    final meta = domain.runtime.thesis.meta;
    final metaSub = [
      if (meta.author.isNotEmpty) meta.author,
      if (meta.university.isNotEmpty) meta.university,
      if (meta.date.isNotEmpty) meta.date,
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // .page-head: h1 „Status“ + Chip mit dem Namen der aktiven Arbeit.
        Row(
          spacing: 10,
          children: [
            Text('Status', style: AppTextStyles.h1.copyWith(color: t.ink)),
            Tooltip(
              message: 'Aktive Arbeit — wechseln über 🗂 oben rechts',
              child: AppChip(
                  label: boot.activeName, variant: AppChipVariant.accent),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${meta.title} — $metaSub. Fortschritt, Setup und die GPT-Pipeline '
          '— Arbeiten wechseln/anlegen über das 🗂-Menü oben rechts.',
          style: AppTextStyles.body.copyWith(color: t.ink2),
        ),
        const SizedBox(height: 20),
        // Boot-Warnungen (Projects.bootWarnings, views_projekt.js:28).
        for (final w in boot.warnings)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Notice(child: Text('⚠ $w')),
          ),
        ProjektStatGrid(domain: domain),
        const SizedBox(height: 16),
        // .dash-cols: 1.55fr/1fr, gap 16, ab ≤999px eine Spalte.
        LayoutBuilder(builder: (context, box) {
          final left = <Widget>[
            ChapterProgressCard(domain: domain),
            QuellenSetupCard(domain: domain),
            ReferenzRunsCard(domain: domain),
          ];
          final right = <Widget>[
            ConnectionsCard(domain: domain),
            const AnleitungCard(),
          ];
          if (box.maxWidth <= BookClothTokens.bpWorkspace) {
            return _Stack(children: [...left, ...right]);
          }
          const gap = 16.0;
          final leftW = (box.maxWidth - gap) * (1.55 / 2.55);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: leftW, child: _Stack(children: left)),
              const SizedBox(width: gap),
              Expanded(child: _Stack(children: right)),
            ],
          );
        }),
      ],
    );
  }
}

/// `.stack` — vertikaler Karten-Stapel mit 10px-Gap (theme.css:574).
class _Stack extends StatelessWidget {
  const _Stack({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: children,
    );
  }
}
