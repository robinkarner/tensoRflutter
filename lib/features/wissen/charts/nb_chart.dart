/// `Notebook.chart` — die SVG-Diagramm-Engine des Erklärbuchs als
/// CustomPainter (notebook.js:268-382, E11).
///
/// Rahmen: `.nb-chart.card.flat` (Padding 14/16) mit optionaler
/// `.eyebrow`-Titelzeile; in der Wissen-Welt trägt jede Card die blaue
/// 2px-Oberkante. Achsen-Charts: logisch 760×(height||300), padL 52 /
/// padR 14 / padT 10 / padB 42, nice-Ticks, de-AT-Zahlen, Balken-Slots
/// 0.62 (stacked) bzw. 0.72/Serien, Punkt-Radien 3.4 (line) / 4 (scatter),
/// Grundlinie zum Schluss. Pie/Donut: viewBox 240×220 bei fester Breite
/// 230 px, cx/cy 120/110, r 88, Donut-Innenradius 46 — Anteile über 99.95 %
/// werden als Vollkreis gezeichnet (Bogen mit Start=Ende kollabiert,
/// notebook.js:287-292); Null-Werte erscheinen nur in der Legende.
///
/// Serienfarben: expliziter Hex-String oder die Token-Palette
/// (`Notebook.PALETTE`) — zur Renderzeit aus dem Theme aufgelöst, damit die
/// Charts Hell/Dunkel folgen. Pie-Segmente nutzen IMMER die Palette nach
/// Werte-Index (wie das Original).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../studio/layout/css_color.dart';
import 'bar_h.dart';
import 'chart_common.dart';
import 'chart_spec.dart';

/// `Notebook.PALETTE` (notebook.js:160): Terracotta führt, danach klar
/// unterscheidbare Kategorie-Töne — aufgelöst gegen die aktiven Tokens.
List<Color> nbPalette(BookClothTokens t) => [
      t.accent,
      t.catNorm,
      t.catFrist,
      t.catAkteur,
      t.catZahl,
      t.catLuecke,
      t.catThese,
      t.catAbk,
    ];

/// `Notebook.color(i)` — Palette rotierend, Fallback Terracotta.
Color nbColor(BookClothTokens t, int i) {
  final p = nbPalette(t);
  return p[i % p.length];
}

/// Aufgelöste Serienfarbe: expliziter CSS-String > Palette[i].
Color nbSeriesColor(BookClothTokens t, NbChartSeries s, int i) =>
    resolveCssColor(t, s.color) ?? nbColor(t, i);

class NbChart extends StatelessWidget {
  const NbChart(this.spec, {super.key});

  final NbChartSpec spec;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);

    Widget body;
    if (spec.series.isEmpty) {
      body = Text('chart: keine „series“ angegeben.',
          style: AppTextStyles.small.copyWith(color: t.muted));
    } else {
      body = switch (spec.type) {
        'pie' || 'donut' => _PieChart(spec: spec),
        'barh' => BarHChart(
            [
              for (final (i, l) in spec.labels.indexed)
                BarHItem(
                  label: l,
                  value: i < spec.series.first.numbers.length
                      ? spec.series.first.numbers[i]
                      : 0,
                  // `series[0].color` = expliziter Wert || Palette[0].
                  color: nbSeriesColor(t, spec.series.first, 0),
                ),
            ],
            valueLabel: (v) => nbChartFmt(v),
          ),
        'bar' || 'line' || 'area' || 'scatter' => _AxisChart(spec: spec),
        _ => Text(
            'chart: Typ „${spec.type}“ unbekannt (bar, barh, line, area, scatter, pie, donut).',
            style: AppTextStyles.small.copyWith(color: t.muted)),
      };
    }

    // `.nb-chart.card.flat` — in der Wissen-Welt mit blauer Card-Oberkante.
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(BookClothTokens.radius),
      ),
      foregroundDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.wissenLine, width: 2)),
        borderRadius: BorderRadius.circular(BookClothTokens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (spec.title != null && spec.title!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                spec.title!.toUpperCase(),
                style: AppTextStyles.eyebrow.copyWith(color: t.wissenInk),
              ),
            ),
          body,
        ],
      ),
    );
  }
}

/// Legende `.nb-legend`: Swatch 11×11 (radius 3) + Name (12.5, ink-2).
class NbLegend extends StatelessWidget {
  const NbLegend(this.entries, {super.key});

  /// (Farbe, Label, fetter Zusatz — Pie zeigt den Wert fett).
  final List<(Color, String, String?)> entries;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: [
          for (final (color, label, boldSuffix) in entries)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: label),
                  if (boldSuffix != null)
                    TextSpan(
                        text: ' $boldSuffix',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
                style: AppTextStyles.small
                    .copyWith(fontSize: 12.5, color: t.ink2, height: 1.3),
              ),
            ]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Achsen-Diagramme (bar / line / area / scatter)
// ---------------------------------------------------------------------------

class _AxisChart extends StatelessWidget {
  const _AxisChart({required this.spec});

  final NbChartSpec spec;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    const w = 760.0;
    final h = spec.height ?? 300.0;
    final range = axisRange(spec);
    final geo = _AxisGeometry(spec: spec, range: range, h: h);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChartCanvas(
          logicalSize: Size(w, h),
          painter: _AxisPainter(spec: spec, geo: geo, tokens: t),
          hits: geo.hits(t),
        ),
        if (spec.series.length > 1)
          NbLegend([
            for (final (i, ser) in spec.series.indexed)
              (nbSeriesColor(t, ser, i), ser.name, null),
          ]),
        if (spec.x != null || spec.y != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              [
                if (spec.y != null) 'y: ${spec.y}',
                if (spec.x != null) 'x: ${spec.x}',
              ].join(' · '),
              style: AppTextStyles.small.copyWith(fontSize: 12.5, color: t.muted),
            ),
          ),
      ],
    );
  }
}

/// Geometrie der Achsen-Charts — von Painter UND Hover-Zielen geteilt.
class _AxisGeometry {
  _AxisGeometry({required this.spec, required this.range, required this.h});

  final NbChartSpec spec;
  final ({double vMin, double vMax, double step}) range;
  final double h;

  static const double w = 760, padL = 52, padR = 14, padT = 10, padB = 42;
  double get iw => w - padL - padR;
  double get ih => h - padT - padB;

  double y(double v) =>
      padT + ih - ((v - range.vMin) / (range.vMax - range.vMin)) * ih;

  double x(int i) => padL +
      (spec.labels.length <= 1 ? iw / 2 : (i / (spec.labels.length - 1)) * iw);

  /// Balken-Rechtecke samt Tooltip-Daten.
  List<(Rect, String, String)> barRects() {
    final out = <(Rect, String, String)>[];
    final labels = spec.labels;
    final stacked = spec.effectiveStacked;
    final slot = iw / labels.length;
    final bw = stacked ? slot * 0.62 : slot * 0.72 / spec.series.length;
    for (final (li, l) in labels.indexed) {
      var acc = 0.0;
      for (final (si, ser) in spec.series.indexed) {
        final v = li < ser.numbers.length ? ser.numbers[li] : 0.0;
        final x0 = stacked
            ? padL + li * slot + (slot - bw) / 2
            : padL + li * slot + slot * 0.14 + si * bw;
        final y1 = stacked ? y(acc + v) : y(v);
        final y0 = stacked ? y(acc) : y(0);
        out.add((
          Rect.fromLTWH(x0, math.min(y0, y1), math.max(1, bw - 1),
              math.max(1, (y0 - y1).abs())),
          l,
          '${ser.name}: ${nbChartFmt(v)}',
        ));
        acc += v;
      }
    }
    return out;
  }

  /// Scatter-Normierung je Serie (Port der Inline-Formel notebook.js:363).
  (double minX, double maxX) scatterRangeOf(NbChartSeries ser) {
    var minX = double.infinity, maxX = double.negativeInfinity;
    for (final p in ser.values) {
      minX = math.min(minX, p is List ? NbChartSeries.numOf(p.firstOrNull) : 0);
      maxX = math.max(
          maxX, p is List ? NbChartSeries.numOf(p.firstOrNull) : ser.values.length.toDouble());
    }
    if (!minX.isFinite) minX = 0;
    if (!maxX.isFinite) maxX = 0;
    return (minX, maxX);
  }

  List<ChartHit> hits(BookClothTokens t) {
    final out = <ChartHit>[];
    switch (spec.type) {
      case 'bar':
        for (final (rect, title, body) in barRects()) {
          out.add(ChartHit(rect: rect, tipTitle: title, tipBody: body));
        }
      case 'line' || 'area':
        for (final ser in spec.series) {
          for (final (i, v) in ser.numbers.indexed) {
            out.add(ChartHit(
              test: (p) => (p - Offset(x(i), y(v))).distance <= 6,
              tipTitle: i < spec.labels.length ? spec.labels[i] : '',
              tipBody: '${ser.name}: ${nbChartFmt(v)}',
            ));
          }
        }
      case 'scatter':
        for (final ser in spec.series) {
          final (minX, maxX) = scatterRangeOf(ser);
          for (final (i, p) in ser.values.indexed) {
            final vx = p is List ? NbChartSeries.numOf(p.firstOrNull) : i.toDouble();
            final vy = p is List
                ? NbChartSeries.numOf(p.length > 1 ? p[1] : null)
                : NbChartSeries.numOf(p);
            final xs = padL + ((vx - minX) / math.max(1e-9, maxX - minX)) * iw;
            out.add(ChartHit(
              test: (q) => (q - Offset(xs, y(vy))).distance <= 6,
              tipTitle: ser.name,
              tipBody: '(${nbChartFmt(vx)}, ${nbChartFmt(vy)})',
            ));
          }
        }
    }
    return out;
  }
}

class _AxisPainter extends CustomPainter {
  _AxisPainter({required this.spec, required this.geo, required this.tokens});

  final NbChartSpec spec;
  final _AxisGeometry geo;
  final BookClothTokens tokens;

  @override
  void paint(Canvas canvas, Size size) {
    const w = _AxisGeometry.w;
    const padL = _AxisGeometry.padL, padR = _AxisGeometry.padR;
    final range = geo.range;

    // Gitterlinien + Y-Ticks.
    final grid = Paint()
      ..strokeWidth = 1
      ..color = tokens.grid;
    for (var v = range.vMin; v <= range.vMax + 1e-9; v += range.step) {
      final yy = geo.y(v);
      canvas.drawLine(Offset(padL, yy), Offset(w - padR, yy), grid);
      drawSvgText(canvas, nbChartFmt(v), Offset(padL - 7, yy + 3.5),
          fontSize: 10.5, color: tokens.muted, anchor: SvgTextAnchor.end);
    }

    // X-Beschriftung (jede n-te, Kürzung auf 14 Zeichen).
    final labels = spec.labels;
    final xLabelEvery = (labels.length / 14).ceil().clamp(1, 1 << 30);
    for (final (i, l) in labels.indexed) {
      if (i % xLabelEvery != 0) continue;
      final xx = spec.type == 'bar'
          ? padL + (i + 0.5) * (geo.iw / labels.length)
          : geo.x(i);
      final short = l.length > 14 ? l.substring(0, 14) : l;
      drawSvgText(canvas, short, Offset(xx, geo.h - _AxisGeometry.padB + 16),
          fontSize: 10.5, color: tokens.muted, anchor: SvgTextAnchor.middle);
    }

    // Daten.
    switch (spec.type) {
      case 'bar':
        final rects = geo.barRects();
        for (final (li, _) in labels.indexed) {
          for (final (si, ser) in spec.series.indexed) {
            final rect = rects[li * spec.series.length + si].$1;
            canvas.drawRRect(
              RRect.fromRectAndRadius(rect, const Radius.circular(2.5)),
              Paint()
                ..color = nbSeriesColor(tokens, ser, si).withValues(alpha: .92),
            );
          }
        }
      case 'line' || 'area':
        for (final (si, ser) in spec.series.indexed) {
          final color = nbSeriesColor(tokens, ser, si);
          final pts = [
            for (final (i, v) in ser.numbers.indexed) Offset(geo.x(i), geo.y(v)),
          ];
          if (pts.isEmpty) continue;
          if (spec.type == 'area') {
            // Polygon: (padL, y0) → alle Punkte → (x(letzter), y0).
            final area = Path()..moveTo(padL, geo.y(0));
            for (final p in pts) {
              area.lineTo(p.dx, p.dy);
            }
            area.lineTo(geo.x(ser.numbers.length - 1), geo.y(0));
            area.close();
            canvas.drawPath(area, Paint()..color = color.withValues(alpha: .16));
          }
          final line = Path()..moveTo(pts.first.dx, pts.first.dy);
          for (final p in pts.skip(1)) {
            line.lineTo(p.dx, p.dy);
          }
          canvas.drawPath(
            line,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.4
              ..strokeJoin = StrokeJoin.round
              ..color = color,
          );
          for (final p in pts) {
            canvas.drawCircle(p, 3.4, Paint()..color = color);
          }
        }
      case 'scatter':
        for (final (si, ser) in spec.series.indexed) {
          final color = nbSeriesColor(tokens, ser, si);
          final (minX, maxX) = geo.scatterRangeOf(ser);
          for (final (i, p) in ser.values.indexed) {
            final vx =
                p is List ? NbChartSeries.numOf(p.firstOrNull) : i.toDouble();
            final vy = p is List
                ? NbChartSeries.numOf(p.length > 1 ? p[1] : null)
                : NbChartSeries.numOf(p);
            final xs =
                padL + ((vx - minX) / math.max(1e-9, maxX - minX)) * geo.iw;
            canvas.drawCircle(Offset(xs, geo.y(vy)), 4,
                Paint()..color = color.withValues(alpha: .8));
          }
        }
    }

    // Grundlinie zum Schluss (über den Daten, notebook.js:374).
    canvas.drawLine(
      Offset(padL, geo.y(0)),
      Offset(w - padR, geo.y(0)),
      Paint()
        ..strokeWidth = 1.4
        ..color = tokens.baseline,
    );
  }

  @override
  bool shouldRepaint(_AxisPainter oldDelegate) =>
      oldDelegate.spec != spec || oldDelegate.tokens != tokens;
}

// ---------------------------------------------------------------------------
// Pie / Donut
// ---------------------------------------------------------------------------

class _PieChart extends StatelessWidget {
  const _PieChart({required this.spec});

  final NbChartSpec spec;

  static const double _cx = 120, _cy = 110, _r = 88, _rDonut = 46;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final vals = spec.series.first.numbers;
    final total = vals.fold(0.0, (a, b) => a + b);
    final safeTotal = total == 0 ? 1.0 : total;
    final r0 = spec.type == 'donut' ? _rDonut : 0.0;

    // Segmente (Winkel) für Painter + Hit-Test vorberechnen.
    final segments = <({double a0, double a1, Color color, double v, int i})>[];
    var a0 = -math.pi / 2;
    for (final (i, v) in vals.indexed) {
      if (v == 0) continue; // Null-Segmente zeichnen nichts
      final a1 = a0 + (v / safeTotal) * math.pi * 2;
      segments.add((a0: a0, a1: a1, color: nbColor(t, i), v: v, i: i));
      a0 = a1;
    }

    bool inRing(Offset p, double from, double to) {
      final d = p - const Offset(_cx, _cy);
      final dist = d.distance;
      if (dist < r0 || dist > _r) return false;
      var ang = math.atan2(d.dy, d.dx);
      // Winkel in den Bereich [from, from+2π) heben.
      while (ang < from) {
        ang += math.pi * 2;
      }
      return ang <= to;
    }

    final hits = <ChartHit>[
      for (final seg in segments)
        ChartHit(
          test: seg.v / safeTotal > 0.9995
              ? (p) {
                  final dist = (p - const Offset(_cx, _cy)).distance;
                  return dist >= r0 && dist <= _r;
                }
              : (p) => inRing(p, seg.a0, seg.a1),
          tipTitle: seg.i < spec.labels.length ? spec.labels[seg.i] : '',
          tipBody:
              '${nbChartFmt(seg.v)} (${(100 * seg.v / safeTotal).round()}%)',
        ),
    ];

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        SizedBox(
          width: 230,
          child: ChartCanvas(
            logicalSize: const Size(240, 220),
            fixedWidth: 230,
            painter: _PiePainter(
                segments: segments, r0: r0, total: safeTotal),
            hits: hits,
          ),
        ),
        NbLegend([
          for (final (i, v) in vals.indexed)
            (
              nbColor(t, i),
              i < spec.labels.length ? spec.labels[i] : '',
              nbChartFmt(v),
            ),
        ]),
      ],
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter({required this.segments, required this.r0, required this.total});

  final List<({double a0, double a1, Color color, double v, int i})> segments;
  final double r0;
  final double total;

  static const double _cx = _PieChart._cx, _cy = _PieChart._cy, _r = _PieChart._r;

  @override
  void paint(Canvas canvas, Size size) {
    const center = Offset(_cx, _cy);
    for (final seg in segments) {
      final paint = Paint()..color = seg.color.withValues(alpha: .9);
      if (seg.v / total > 0.9995) {
        // Vollkreis: als Ring/Kreis (ein Bogen mit Start=Ende kollabiert).
        if (r0 > 0) {
          canvas.drawCircle(
            center,
            (_r + r0) / 2,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = _r - r0
              ..color = seg.color.withValues(alpha: .9),
          );
        } else {
          canvas.drawCircle(center, _r, paint);
        }
        continue;
      }
      final sweep = seg.a1 - seg.a0;
      final path = Path();
      if (r0 > 0) {
        // Ringsegment: Außenbogen hin, Innenbogen zurück.
        path.moveTo(_cx + _r * math.cos(seg.a0), _cy + _r * math.sin(seg.a0));
        path.arcTo(Rect.fromCircle(center: center, radius: _r), seg.a0, sweep,
            false);
        path.lineTo(_cx + r0 * math.cos(seg.a1), _cy + r0 * math.sin(seg.a1));
        path.arcTo(Rect.fromCircle(center: center, radius: r0), seg.a1, -sweep,
            false);
        path.close();
      } else {
        path.moveTo(_cx, _cy);
        path.lineTo(_cx + _r * math.cos(seg.a0), _cy + _r * math.sin(seg.a0));
        path.arcTo(Rect.fromCircle(center: center, radius: _r), seg.a0, sweep,
            false);
        path.close();
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_PiePainter oldDelegate) =>
      oldDelegate.segments != segments;
}
