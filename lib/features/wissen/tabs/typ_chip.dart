/// Befund-Typ-Chips — `TYP_CHIP`/`TYP_LABEL`/`typChip`
/// (views_analyse.js:10-12, Texte wortwörtlich).
library;

import 'package:flutter/material.dart';

import '../../../core/widgets/chips.dart';

/// Typ → Chip-Variante (`TYP_CHIP`).
const Map<String, AppChipVariant> typChipVariant = {
  'positiv': AppChipVariant.ok,
  'luecke': AppChipVariant.bad,
  'spannung': AppChipVariant.warn,
  'ausblick': AppChipVariant.accent,
  'staerke': AppChipVariant.ok,
  'schwaeche': AppChipVariant.bad,
  'hinweis': AppChipVariant.warn,
};

/// Typ → Anzeige-Label (`TYP_LABEL`).
const Map<String, String> typChipLabel = {
  'positiv': '✔ erfüllt',
  'luecke': '▲ Lücke',
  'spannung': '◆ Spannung',
  'ausblick': '➜ Ausblick',
  'staerke': '✔ Stärke',
  'schwaeche': '▲ Schwäche',
  'hinweis': '◆ Hinweis',
};

/// `typChip(t)` — unbekannte Typen zeigen den Roh-Wert im neutralen Chip.
class TypChip extends StatelessWidget {
  const TypChip(this.typ, {super.key});

  final String typ;

  @override
  Widget build(BuildContext context) => AppChip(
        label: typChipLabel[typ] ?? typ,
        variant: typChipVariant[typ] ?? AppChipVariant.neutral,
      );
}
