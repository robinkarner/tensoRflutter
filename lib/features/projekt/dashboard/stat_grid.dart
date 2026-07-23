/// `.statgrid` + `.stat` — die 6 Status-Kacheln (views_projekt.js:33-40,
/// app.css:103-108): CSS-Grid `repeat(auto-fit, minmax(155px, 1fr))` mit
/// 12px-Gap; Wert 600 22px Display mit tabellarischen Ziffern, der
/// `/M`-Anteil mono 15px muted, Label 11.5px 600 muted.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/bundles/indexes.dart';
import '../../../data/db/kv.dart';
import '../../../data/repos/fig_store.dart';
import '../../quellen/state/quellen_kv.dart';
import 'projekt_state.dart';

class ProjektStatGrid extends ConsumerWidget {
  const ProjektStatGrid({super.key, required this.domain});

  final QuellenDomain domain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levels = domain.levels;
    final sources = domain.sources;

    // Abschnitte GPT-analysiert (views_projekt.js:19-20).
    final ordered = ref.watch(orderedUnitsProvider);
    final secGen = [
      for (final id in ordered)
        if (domain.runtime.sections.containsKey(fileIdOf(id))) id,
    ].length;

    // PDFs (async — Statkachel startet mit „–“, :35/43-49).
    final docSources = projektDocSources(domain);
    final detected = ref.watch(projektDetectedPdfsProvider).value;

    // Links geprüft/übernommen (:32/36).
    final overrides =
        ref.watch(quellenKvProvider.notifier).readMap(KvKeys.linkOverrides);
    final linksOk = [
      for (final s in sources)
        if (srcLinksFromSnapshot(overrides, s).isOverride) s,
    ].length;

    // Belege gesichert (:14-15/37).
    final counts = levels.countsFor(levels.allNums());

    // Quellen-Durchläufe (:16/38).
    final resolutions = domain.resolutions.length;

    // Abbildungen (:17-18/39): Manifest-Datei ODER hochgeladenes Bild.
    final figs = domain.runtime.figures.figuren;
    final figStore = ref.watch(figStoreProvider).value;
    final figsDa = [
      for (final f in figs)
        if ((f.file != null && f.file!.isNotEmpty) ||
            (figStore?.has(f.id) ?? false))
          f,
    ].length;

    final tiles = <_StatTile>[
      _StatTile(v: '$secGen', of: ordered.length, label: 'Abschnitte GPT-analysiert ✦'),
      _StatTile(
          v: detected == null ? '–' : '${detected.length}',
          of: docSources.length,
          label: 'PDFs vorhanden (Artikel/Reports)'),
      _StatTile(v: '$linksOk', of: sources.length, label: 'Links geprüft/übernommen'),
      _StatTile(v: '${counts.l3}', of: counts.total, label: 'Belege gesichert ✓'),
      _StatTile(
          v: '$resolutions', of: sources.length, label: 'Quellen-Durchläufe importiert 🤖'),
      _StatTile(v: '$figsDa', of: figs.length, label: 'Abbildungen hinterlegt'),
    ];

    // auto-fit minmax(155px, 1fr): so viele gleich breite Spalten, wie bei
    // Mindestbreite 155 in die Zeile passen (maximal 6 = Kachelzahl).
    return LayoutBuilder(builder: (context, box) {
      const gap = 12.0;
      const minW = 155.0;
      final w = box.maxWidth;
      var n = ((w + gap) / (minW + gap)).floor();
      if (n < 1) n = 1;
      if (n > tiles.length) n = tiles.length;
      final tileW = (w - gap * (n - 1)) / n;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final tile in tiles) SizedBox(width: tileW, child: tile),
        ],
      );
    });
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.v, required this.of, required this.label});

  final String v;
  final int of;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(BookClothTokens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(text: v),
              TextSpan(
                text: '/$of',
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: 15,
                  color: t.muted,
                ),
              ),
            ]),
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontFamilyFallback: AppFonts.fallback,
              fontWeight: FontWeight.w600,
              fontSize: 22,
              height: 1.1,
              letterSpacing: -.02 * 22,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: t.ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontFamilyFallback: AppFonts.fallback,
              fontWeight: FontWeight.w600,
              fontSize: 11.5,
              height: 1.3,
              letterSpacing: .02 * 11.5,
              color: t.muted,
            ),
          ),
        ],
      ),
    );
  }
}
