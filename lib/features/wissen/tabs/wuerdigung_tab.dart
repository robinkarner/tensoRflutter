/// ⚖ Würdigung — Bewertung nach Standards + drei Akkordeons
/// (`analyseWuerdigung`, views_analyse.js:394-438).
///
/// Sterne-Noten: „★★★ stark“ / „★★☆ solide“ / „★☆☆ ausbaufähig“ /
/// „☆☆☆ schwach“ (letzteres kommt in Realdaten nie vor — L5). Akkordeons
/// struktur (initial offen) / quellen / inhalt als `details.acc`-Pendant.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/richtext/mini_md.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/accordion.dart';
import '../../../core/widgets/chips.dart';
import '../../../data/bundles/indexes.dart';
import '../../../data/models/models.dart';
import 'typ_chip.dart';
import 'wissen_card.dart';

/// note → Chip-Variante (`NOTE`, views_analyse.js:408).
const Map<String, AppChipVariant> _noteVariant = {
  'stark': AppChipVariant.ok,
  'solide': AppChipVariant.ok,
  'ausbaufaehig': AppChipVariant.warn,
  'schwach': AppChipVariant.bad,
};

/// note → Sterne-Label (`NLAB`, views_analyse.js:409).
const Map<String, String> _noteLabel = {
  'stark': '★★★ stark',
  'solide': '★★☆ solide',
  'ausbaufaehig': '★☆☆ ausbaufähig',
  'schwach': '☆☆☆ schwach',
};

class WuerdigungTab extends ConsumerWidget {
  const WuerdigungTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final ana = ref.watch(activeRuntimeProvider)?.meta.analyse ??
        const AnalyseDocs();

    final std = ana.standards;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Intro-Absatz mit den fetten Passagen (wortwörtlich).
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Die '),
            const TextSpan(
                text: 'Bewertung',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const TextSpan(
                text:
                    ' der Arbeit — kritische Einordnung gegen wissenschaftliche Standards, mit Stärken und '),
            const TextSpan(
                text: 'verbesserungswürdigen',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const TextSpan(
                text:
                    ' Stellen. Basis, Zusammenhänge und schnelles Verständnis stehen in den anderen Tab-Gruppen.'),
          ]),
          style: AppTextStyles.small.copyWith(color: t.muted),
        ),
      ),
      if (std != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: WissenCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              WissenEyebrow(
                  std.titel.isNotEmpty ? std.titel : 'Bewertung nach Standards'),
              if (std.verdikt != null && std.verdikt!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 10),
                  child: MiniMd(std.verdikt!,
                      baseStyle: AppTextStyles.body
                          .copyWith(fontSize: 15, height: 1.6, color: t.ink)),
                ),
              if (std.markdown.isNotEmpty)
                MiniMd(std.markdown,
                    baseStyle:
                        AppTextStyles.small.copyWith(color: t.ink2)),
              if (std.kriterien.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: AutoGrid(
                    minWidth: 240,
                    gap: 10,
                    children: [
                      for (final k in std.kriterien) _KritTile(k: k),
                    ],
                  ),
                ),
              if (std.verbesserung.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const WissenEyebrow('▲ Verbesserungswürdig'),
                      for (final (i, text) in std.verbesserung.indexed)
                        PunktRow(
                          icon: const TypChip('schwaeche'),
                          last: i == std.verbesserung.length - 1,
                          child: Text(text,
                              style: AppTextStyles.body
                                  .copyWith(fontSize: 14, color: t.ink)),
                        ),
                    ],
                  ),
                ),
            ]),
          ),
        ),
      for (final (key, open) in const [
        ('struktur', true),
        ('quellen', false),
        ('inhalt', false),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _AccSection(
            doc: switch (key) {
              'struktur' => ana.struktur,
              'quellen' => ana.quellen,
              _ => ana.inhalt,
            },
            fallbackTitle: key,
            initiallyOpen: open,
          ),
        ),
    ]);
  }
}

/// `.std-krit`-Kachel: Name + Noten-Chip + Text.
class _KritTile extends StatelessWidget {
  const _KritTile({required this.k});

  final AnalyseKriterium k;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      decoration: BoxDecoration(
        color: t.surface2,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(k.name,
                style: AppTextStyles.small.copyWith(
                    fontSize: 13, fontWeight: FontWeight.w700, color: t.ink)),
          ),
          const SizedBox(width: 8),
          AppChip(
            label: _noteLabel[k.note] ?? k.note,
            variant: _noteVariant[k.note] ?? AppChipVariant.neutral,
          ),
        ]),
        const SizedBox(height: 4),
        Text(k.text, style: AppTextStyles.small.copyWith(color: t.muted)),
      ]),
    );
  }
}

/// Ein `details.acc`-Akkordeon einer Analyse-Sektion.
class _AccSection extends StatelessWidget {
  const _AccSection({
    required this.doc,
    required this.fallbackTitle,
    required this.initiallyOpen,
  });

  final AnalyseDoc? doc;
  final String fallbackTitle;
  final bool initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final a = doc;
    return Accordion(
      title: Text(a?.titel.isNotEmpty == true ? a!.titel : fallbackTitle),
      initiallyOpen: initiallyOpen,
      body: a == null
          ? Text('Diese Analyse wurde noch nicht generiert.',
              style: AppTextStyles.body.copyWith(color: t.muted))
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              MiniMd(a.markdown,
                  baseStyle: AppTextStyles.body.copyWith(color: t.ink)),
              if (a.punkte.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, p) in a.punkte.indexed)
                        PunktRow(
                          icon: TypChip(p.typ),
                          last: i == a.punkte.length - 1,
                          child: Text(p.text,
                              style: AppTextStyles.body
                                  .copyWith(fontSize: 14, color: t.ink)),
                        ),
                    ],
                  ),
                ),
            ]),
    );
  }
}
