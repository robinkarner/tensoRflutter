/// `Charts.barH` — horizontale Balken, eine Serie (charts.js:6-27).
///
/// Geometrie exakt: logische Breite 720, Zeilenhöhe 30, Label-Spalte 210
/// (rechtsbündig, 12.5px ink-2, >32 Zeichen → 30+…), Balken ab x=210 mit
/// Höhe 18 (rowH−12), rx 4, `fill color || accent` bei Opacity .92,
/// Mindestbreite 4; Wertetext 12px/600 ink 8px rechts vom Balken. Ein
/// unsichtbares Hover-Rect über die volle Zeile trägt den Tooltip
/// (`<b>label</b>tip || valueLabel(value)`).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import 'chart_common.dart';

/// Eingabe-Zeile (`{label, value, tip?, color?}`).
class BarHItem {
  final String label;
  final double value;
  final String? tip;
  final Color? color;

  const BarHItem({
    required this.label,
    required this.value,
    this.tip,
    this.color,
  });
}

class BarHChart extends StatelessWidget {
  const BarHChart(
    this.items, {
    super.key,
    this.valueLabel,
    this.height,
  });

  final List<BarHItem> items;

  /// `valueLabel(v)` — Default `String(v)` (ganzzahlige Werte ohne ".0").
  final String Function(double v)? valueLabel;

  /// Feste logische Höhe (sonst `items·30 + 8`).
  final double? height;

  static String _defaultLabel(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : '$v';

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final label = valueLabel ?? _defaultLabel;
    const rowH = 30.0, pad = 4.0, w = 720.0;
    final h = height ?? items.length * rowH + pad * 2;

    final hits = <ChartHit>[
      for (final (i, it) in items.indexed)
        ChartHit(
          rect: Rect.fromLTWH(0, pad + i * rowH, w, rowH),
          tipTitle: it.label,
          tipBody: it.tip ?? label(it.value),
        ),
    ];

    // `.viz`-Container ist im Original ungestylt — nur der skalierende SVG.
    return ChartCanvas(
      logicalSize: Size(w, h),
      painter: _BarHPainter(items: items, valueLabel: label, tokens: t),
      hits: hits,
    );
  }
}

class _BarHPainter extends CustomPainter {
  _BarHPainter({
    required this.items,
    required this.valueLabel,
    required this.tokens,
  });

  final List<BarHItem> items;
  final String Function(double) valueLabel;
  final BookClothTokens tokens;

  @override
  void paint(Canvas canvas, Size size) {
    const rowH = 30.0, labelW = 210.0, valW = 46.0, pad = 4.0, w = 720.0;
    final max = items.fold<double>(1, (a, it) => math.max(a, it.value));
    final barMaxW = w - labelW - valW - 20;

    for (final (i, it) in items.indexed) {
      final y = pad + i * rowH;
      final bw = math.max(4.0, (it.value / max) * barMaxW);

      drawSvgText(
        canvas,
        svgEllipsis(it.label, 32, 30),
        Offset(labelW - 10, y + rowH / 2 + 4),
        fontSize: 12.5,
        color: tokens.ink2,
        anchor: SvgTextAnchor.end,
      );
      final paint = Paint()
        ..color = (it.color ?? tokens.accent).withValues(alpha: .92);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(labelW, y + 5, bw, rowH - 12),
          const Radius.circular(4),
        ),
        paint,
      );
      drawSvgText(
        canvas,
        valueLabel(it.value),
        Offset(labelW + bw + 8, y + rowH / 2 + 4),
        fontSize: 12,
        weight: FontWeight.w600,
        color: tokens.ink,
      );
    }
  }

  @override
  bool shouldRepaint(_BarHPainter oldDelegate) =>
      oldDelegate.items != items || oldDelegate.tokens != tokens;
}
