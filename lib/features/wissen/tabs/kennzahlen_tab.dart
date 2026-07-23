/// Kennzahlen — 5 Stat-Kacheln + 3 barH-Charts
/// (`analyseKennzahlen`, views_analyse.js:441-480).
///
/// Kacheln: „Fußnoten gesamt“, „verschiedene Quellen“, „Absätze“,
/// „aufgelöste Sätze“, „Belege pro Absatz (Ø)“ (= fussnoten/absaetze auf
/// eine Nachkommastelle; Fallback „–“). Charts: Beleg-Dichte je Kapitel,
/// Quellenmix nach Typ (feste kind-Reihenfolge), Meistzitierte Quellen
/// (volle Breite, mit Hinweiszeile + Link auf die Quellen-Bibliothek).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/bundles/indexes.dart';
import '../charts/bar_h.dart';
import 'wissen_card.dart';
import 'wissen_state.dart';

class KennzahlenTab extends ConsumerWidget {
  const KennzahlenTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final st = ref.watch(wissenStatsProvider);
    final chapters = ref.watch(effectiveThesisProvider)?.chapters ?? const [];

    // `st.fussnoten ?? '–'` — nur FEHLENDE Stats zeigen den Strich.
    String v(int? n) => n == null ? '–' : '$n';
    // `st.fussnoten && st.absaetze ? … : '–'` — hier zählt Truthiness (0 → –).
    final avg = (st != null && st.fussnoten > 0 && st.absaetze > 0)
        ? (st.fussnoten / st.absaetze).toStringAsFixed(1)
        : '–';

    final tiles = [
      (v(st?.fussnoten), 'Fußnoten gesamt'),
      (v(st?.quellen), 'verschiedene Quellen'),
      (v(st?.absaetze), 'Absätze'),
      (v(st?.saetze), 'aufgelöste Sätze'),
      (avg, 'Belege pro Absatz (Ø)'),
    ];

    final charts = <Widget>[];
    if (st != null && st.fnPerChapter.isNotEmpty) {
      charts.add(WissenCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const WissenEyebrow('Beleg-Dichte je Kapitel'),
          const SizedBox(height: 8),
          BarHChart(
            [
              for (final ch in chapters)
                BarHItem(
                  label: '${ch.num} ${ch.title}',
                  value: (st.fnPerChapter['${ch.num}'] ?? 0).toDouble(),
                  tip:
                      '${st.fnPerChapter['${ch.num}'] ?? 0} Fußnoten · ${st.paraPerChapter['${ch.num}'] ?? 0} Absätze',
                ),
            ],
            valueLabel: (v) => '${v.round()} Fn.',
          ),
        ]),
      ));
    }
    if (st != null && st.byKind.isNotEmpty) {
      const order = [
        'recht-eu', 'recht-at', 'artikel', 'report', 'online', 'konferenz',
        'norm',
      ];
      charts.add(WissenCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const WissenEyebrow('Quellenmix nach Typ'),
          const SizedBox(height: 8),
          BarHChart(
            [
              for (final k in order)
                if ((st.byKind[k] ?? 0) > 0)
                  BarHItem(
                    label: st.kindLabels[k] ?? k,
                    value: st.byKind[k]!.toDouble(),
                  ),
            ],
            valueLabel: (v) => '${v.round()} Quellen',
          ),
        ]),
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // `.statgrid`: auto-fit minmax(155px, 1fr), gap 12.
      AutoGrid(
        minWidth: 155,
        gap: 12,
        children: [
          for (final (value, label) in tiles) _StatTile(value: value, label: label),
        ],
      ),
      if (charts.isNotEmpty) ...[
        const SizedBox(height: 16),
        AutoGrid(minWidth: 300, children: charts),
      ],
      if (st != null && st.topSources.isNotEmpty) ...[
        const SizedBox(height: 14),
        // volle Breite (`grid-column: 1 / -1`).
        WissenCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const WissenEyebrow('Meistzitierte Quellen (Zitierstellen)'),
            const SizedBox(height: 8),
            BarHChart(
              [
                for (final s in st.topSources)
                  BarHItem(
                    label: s.title,
                    value: s.cites.toDouble(),
                    tip: '${kindLabels[s.kind] ?? s.kind} · id: ${s.id}',
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(
                      text:
                          'Die Arbeit stützt sich primär auf die Rechtsakte selbst — Details je Quelle in der '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => context.go(Routes.quellen),
                        child: Text('Quellen-Bibliothek',
                            style: AppTextStyles.small.copyWith(
                                fontSize: 12.5, color: t.accentInk)),
                      ),
                    ),
                  ),
                  const TextSpan(text: '.'),
                ]),
                style:
                    AppTextStyles.small.copyWith(fontSize: 12.5, color: t.muted),
              ),
            ),
          ]),
        ),
      ],
    ]);
  }
}

/// `.stat`-Kachel (app.css:104-107): Wert 600 22/1.1 Display tabular,
/// Label 11.5 muted 600.
class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
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
      foregroundDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.wissenLine, width: 2)),
        borderRadius: BorderRadius.circular(BookClothTokens.radius),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          value,
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
            letterSpacing: .02 * 11.5,
            color: t.muted,
          ),
        ),
      ]),
    );
  }
}
