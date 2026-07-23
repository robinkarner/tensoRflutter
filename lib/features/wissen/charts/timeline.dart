/// `Charts.timeline` — vertikale HTML-Timeline (charts.js:142-160).
///
/// WICHTIG (Master §8 L1 + Dossier 06 §4.12): Für `.tl-*`, `.viz`
/// (Container), `.legend`, `.li` und `.sw` existieren im Original KEINE
/// CSS-Regeln. Die Timeline rendert dort als schlichte, untereinander
/// gestapelte Text-Divs — der Punkt (`.tl-dot`) und die Linie (`.tl-line`)
/// sind größenlose Divs und damit UNSICHTBAR, die Legenden-Swatches ebenso.
/// Dieser Port baut exakt diese IST-Optik nach (nichts erfinden): Legende
/// als Textzeile, je Eintrag drei gestapelte Textzeilen (Datum, Label, Sub).
library;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/models/models.dart';

class TimelineList extends StatelessWidget {
  const TimelineList(this.items, {super.key, this.datumLabelOf});

  final List<TimelineEvent> items;

  /// Vorformatiertes Datum (`U.fmtDate`) — null/leer fällt aufs Roh-Datum.
  final String Function(TimelineEvent it)? datumLabelOf;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final base = AppTextStyles.body.copyWith(color: t.ink);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // `.legend`: drei Inline-Spans ohne Styling — eine Textzeile
        // (die farbigen Swatches sind im Original unsichtbar).
        Text('🇪🇺 EU-Frist 🇦🇹 nationaler Termin ● gefüllt = erledigt · ○ Ring = offen',
            style: base),
        for (final it in items) ...[
          // `.tl-row` > Block-Divs: Datum, (unsichtbare Punktspalte), Body.
          Text(
            (datumLabelOf?.call(it) ?? '').isNotEmpty
                ? datumLabelOf!.call(it)
                : it.datum,
            style: base,
          ),
          Text(it.label, style: base),
          Text(
            '${it.isAt ? '🇦🇹 Österreich' : '🇪🇺 EU'} · '
            '${it.isErledigt ? '✔ erledigt' : '○ offen'}',
            style: base,
          ),
        ],
      ],
    );
  }
}
