import 'dart:ui';

/// Pendant zur CSS-Funktion `color-mix(in srgb, A x%, B)`.
///
/// Das Original nutzt color-mix an weit über 60 Stellen — für Hover-Töne,
/// Farb-Washes, Fokus-Ringe, Tag-Hintergründe usw. Zwei Fälle decken alles ab:
///
/// 1. `color-mix(in srgb, C x%, transparent)` — C mit x% Deckkraft
///    → [alphaPct]. (sRGB-Interpolation gegen transparent ergibt exakt
///    die Farbe mit skaliertem Alpha.)
/// 2. `color-mix(in srgb, A x%, B)` — lineare Mischung zweier Farben
///    → [mix]: `A.mix(B, x)` gewichtet A mit x% und B mit (100−x)%.
extension BookClothColorMix on Color {
  /// `color-mix(in srgb, this pct%, other)` — this gewichtet mit [pct] Prozent.
  Color mix(Color other, double pct) => Color.lerp(other, this, pct / 100)!;

  /// `color-mix(in srgb, this pct%, transparent)` — Deckkraft auf [pct] Prozent
  /// der bisherigen skaliert (Washes, Hairlines, Fokus-Ringe).
  Color alphaPct(double pct) => withValues(alpha: a * pct / 100);
}
