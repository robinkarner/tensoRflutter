/// `Charts.kapitelFluss` — Kapitel-Knoten mit Nachbar-Pfeilen und
/// Bogen-Kanten für Fernbezüge (charts.js:30-65).
///
/// Geometrie exakt: logische Breite 980, Knoten 148×58 (rx 10, surface-2,
/// border), y0=96, Gap dynamisch `(980−6·148−24)/5`; Nachbar-Pfeile auf
/// halber Knotenhöhe (baseline, Breite 2, Pfeilspitze); Fern-Kanten
/// (`to > from+1`) als kubische Bézier-Bögen oberhalb mit
/// `lift = 26 + (b−a)·13` (grid, 1.6). Knotentext „Kap. N“ 13px/700
/// accent-ink + Titel 11.5px ink-2 (>22 Zeichen → 21+…).
library;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import 'chart_common.dart';

/// Kapitel-Knoten (`{num, title, tip}`).
class FlussChapter {
  final int num;
  final String title;
  final String tip;

  const FlussChapter({required this.num, required this.title, this.tip = ''});
}

/// Fern-Kante (`{from, to, label}` — Kapitel-IDs als Strings „1“–„6“).
class FlussEdge {
  final String from;
  final String to;
  final String label;

  const FlussEdge({required this.from, required this.to, this.label = ''});
}

class KapitelFlussChart extends StatelessWidget {
  const KapitelFlussChart(
    this.chapters, {
    super.key,
    this.edges = const [],
    this.onClick,
  });

  final List<FlussChapter> chapters;
  final List<FlussEdge> edges;

  /// Klick auf einen Knoten (Kapitelnummer als String, wie `data-ch`).
  final void Function(String chapterNum)? onClick;

  static const double _w = 980, _nodeW = 148, _nodeH = 58, _y0 = 96;
  static double get _gap => (_w - 6 * _nodeW - 24) / 5;
  static double _x(int i) => 12 + i * (_nodeW + _gap);

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);

    final hits = <ChartHit>[
      // Bogen-Kanten zuerst (liegen im SVG unter den Knoten).
      for (final e in edges)
        if (_arcPoints(e) case final pts?)
          ChartHit(
            polyline: pts,
            tipTitle: 'Kapitel ${e.from} → ${e.to}',
            tipBody: e.label,
          ),
      for (final (i, c) in chapters.indexed)
        ChartHit(
          rect: Rect.fromLTWH(_x(i), _y0, _nodeW, _nodeH),
          tipTitle: 'Kapitel ${c.num}: ${c.title}',
          tipBody: c.tip,
          onTap: onClick == null ? null : () => onClick!('${c.num}'),
        ),
    ];

    return ChartCanvas(
      logicalSize: const Size(_w, _y0 + _nodeH + 14),
      painter: _FlussPainter(chapters: chapters, edges: edges, tokens: t),
      hits: hits,
    );
  }

  /// Sample-Punkte des Bogens (für die Pfad-Nähe-Treffer) — nur für echte
  /// Fern-Kanten (`b > a+1`), wie das Original.
  static List<Offset>? _arcPoints(FlussEdge e) {
    final a = (int.tryParse(e.from) ?? 0) - 1;
    final b = (int.tryParse(e.to) ?? 0) - 1;
    if (int.tryParse(e.from) == null || int.tryParse(e.to) == null) return null;
    if (b <= a + 1) return null;
    final xa = _x(a) + _nodeW / 2, xb = _x(b) + _nodeW / 2;
    final lift = 26 + (b - a) * 13.0;
    final p0 = Offset(xa, _y0 - 6);
    final c1 = Offset(xa, _y0 - lift);
    final c2 = Offset(xb, _y0 - lift);
    final p3 = Offset(xb, _y0 - 6);
    return [
      for (var i = 0; i <= 20; i++) _cubicAt(p0, c1, c2, p3, i / 20),
    ];
  }

  static Offset _cubicAt(Offset p0, Offset c1, Offset c2, Offset p3, double t) {
    final u = 1 - t;
    return p0 * (u * u * u) +
        c1 * (3 * u * u * t) +
        c2 * (3 * u * t * t) +
        p3 * (t * t * t);
  }
}

class _FlussPainter extends CustomPainter {
  _FlussPainter({
    required this.chapters,
    required this.edges,
    required this.tokens,
  });

  final List<FlussChapter> chapters;
  final List<FlussEdge> edges;
  final BookClothTokens tokens;

  static const double _nodeW = KapitelFlussChart._nodeW;
  static const double _nodeH = KapitelFlussChart._nodeH;
  static const double _y0 = KapitelFlussChart._y0;

  /// Pfeilspitze des `marker#arr` (Dreieck 8×8, refX 7 — Spitze am Linienende).
  void _arrowHead(Canvas canvas, Offset tip, Offset direction, Color color) {
    final d = direction.distance == 0
        ? const Offset(1, 0)
        : direction / direction.distance;
    final n = Offset(-d.dy, d.dx); // Normale
    const len = 7.0, half = 3.5;
    final base = tip - d * len;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(base.dx + n.dx * half, base.dy + n.dy * half)
      ..lineTo(base.dx - n.dx * half, base.dy - n.dy * half)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Bogen-Kanten oberhalb (nur Fernbezüge — Nachbarn haben schon Pfeile).
    for (final e in edges) {
      final a = (int.tryParse(e.from) ?? 0) - 1;
      final b = (int.tryParse(e.to) ?? 0) - 1;
      if (int.tryParse(e.from) == null ||
          int.tryParse(e.to) == null ||
          b <= a + 1) {
        continue;
      }
      final xa = KapitelFlussChart._x(a) + _nodeW / 2;
      final xb = KapitelFlussChart._x(b) + _nodeW / 2;
      final lift = 26 + (b - a) * 13.0;
      final path = Path()
        ..moveTo(xa, _y0 - 6)
        ..cubicTo(xa, _y0 - lift, xb, _y0 - lift, xb, _y0 - 6);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = tokens.grid,
      );
      // Endtangente zeigt von (xb, y0−lift) nach (xb, y0−6) → abwärts.
      _arrowHead(canvas, Offset(xb, _y0 - 6), const Offset(0, 1), tokens.baseline);
    }

    // Pfeile zwischen Nachbarn.
    final line = Paint()
      ..strokeWidth = 2
      ..color = tokens.baseline;
    for (var i = 0; i < 5; i++) {
      final x1 = KapitelFlussChart._x(i) + _nodeW;
      final x2 = KapitelFlussChart._x(i + 1) - 3;
      final y = _y0 + _nodeH / 2;
      canvas.drawLine(Offset(x1, y), Offset(x2, y), line);
      _arrowHead(canvas, Offset(x2, y), const Offset(1, 0), tokens.baseline);
    }

    // Knoten.
    final fill = Paint()..color = tokens.surface2;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = tokens.border;
    for (final (i, c) in chapters.indexed) {
      final x = KapitelFlussChart._x(i);
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, _y0, _nodeW, _nodeH),
        const Radius.circular(10),
      );
      canvas.drawRRect(r, fill);
      canvas.drawRRect(r, stroke);
      drawSvgText(canvas, 'Kap. ${c.num}', Offset(x + 12, _y0 + 24),
          fontSize: 13, weight: FontWeight.w700, color: tokens.accentInk);
      drawSvgText(canvas, svgEllipsis(c.title, 22, 21), Offset(x + 12, _y0 + 42),
          fontSize: 11.5, color: tokens.ink2);
    }
  }

  @override
  bool shouldRepaint(_FlussPainter oldDelegate) =>
      oldDelegate.chapters != chapters ||
      oldDelegate.edges != edges ||
      oldDelegate.tokens != tokens;
}
