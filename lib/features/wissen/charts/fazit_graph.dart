/// `Charts.fazitGraph` — bipartiter Graph: Fazit-Befunde links, Herleitungs-
/// Abschnitte rechts (charts.js:68-139).
///
/// Geometrie exakt: logische Breite 980, Höhe `max(findings·56, secs·30)+60`;
/// Knoten-Spalten x=330/x=690; Abschnitte alphanumerisch sortiert
/// (localeCompare de, numeric); Kanten kubisch (`C xL+150 …, xR−150 …`,
/// 1.7/Opacity .5); Befund-Punkt r7 in Typ-Farbe (Stroke surface 2),
/// Label 12.5/650 rechtsbündig (>36 → 34+…), Subzeile 10.5 in Typ-Farbe;
/// Abschnitts-Punkt r5 surface-2/baseline, Text 12 (>34 → 32+…);
/// Spaltenköpfe „FAZIT-BEFUNDE“ / „HERGELEITET AUS“ 11/700 muted ls 1.
///
/// Hover auf einem Befund hebt seine Kanten hervor (Opacity 1, andere .12,
/// Ruhe .5 — charts.js:130-133); Klick auf Befund → [onFinding], Klick auf
/// Abschnitt → [onSection] (Original: `#/explorer/<sec>` → Studio-Redirect).
///
/// Die Legende darunter ist im Original UNGESTYLT (Master §8 L1: für `.legend`/
/// `.li`/`.sw` existieren keine CSS-Regeln; die Farb-Swatches sind größenlose
/// Inline-Spans und damit unsichtbar) — sie erscheint als schlichte Textzeile.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/models/models.dart';
import 'chart_common.dart';

/// Typ → Farbe/Icon/Label (charts.js:69-74). Fallback: ausblick.
({Color c, String icon, String label}) fazitTyp(BookClothTokens t, String typ) =>
    switch (typ) {
      'positiv' => (c: t.good, icon: '✔', label: 'Positiv'),
      'luecke' => (c: t.critical, icon: '▲', label: 'Lücke'),
      'spannung' => (c: t.warning, icon: '◆', label: 'Spannung'),
      _ => (c: t.accent, icon: '➜', label: 'Ausblick'),
    };

class FazitGraphChart extends StatefulWidget {
  const FazitGraphChart(
    this.findings, {
    super.key,
    this.onFinding,
    this.onSection,
    this.sectionTitle,
  });

  final List<FazitFinding> findings;
  final void Function(String findingId)? onFinding;

  /// Klick auf einen Abschnitts-Knoten (Original öffnet das Studio).
  final void Function(String sectionId)? onSection;

  /// Abschnittstitel fürs Label (`UNIT_INDEX[s].unit.title`); null → nur id.
  final String? Function(String sectionId)? sectionTitle;

  @override
  State<FazitGraphChart> createState() => _FazitGraphChartState();
}

class _FazitGraphChartState extends State<FazitGraphChart> {
  /// id des gehoverten Befunds (Kanten-Dimming).
  String? _hoverId;

  static const double _w = 980, _xL = 330, _xR = 690;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final findings = widget.findings;

    // Rechte Seite: alle referenzierten Abschnitte (dedupliziert, sortiert).
    final secSet = <String>{};
    for (final f in findings) {
      secSet.addAll(f.abschnitte);
    }
    final secs = secSet.toList()..sort(_localeCompareNumericDe);

    final rowHL = 56.0, rowHR = 30.0;
    final h = math.max(findings.length * rowHL, secs.length * rowHR) + 60;

    double yL(int i) {
      final step = findings.length - 1 >= 1 ? (h - 70) / (findings.length - 1) : 0;
      return 40 + i * step + (findings.length == 1 ? (h - 70) / 2 : 0);
    }

    double yR(int i) {
      final step = secs.length - 1 >= 1 ? (h - 70) / (secs.length - 1) : 0;
      return 40 + i * step + (secs.length == 1 ? (h - 70) / 2 : 0);
    }

    final secY = <String, double>{
      for (final (i, s) in secs.indexed) s: yR(i),
    };

    final hits = <ChartHit>[
      for (final (i, f) in findings.indexed)
        ChartHit(
          // Punkt + Label-Bereich links des Punkts als Trefferfläche.
          rect: Rect.fromLTWH(_xL - 260, yL(i) - 14, 260 + 16, 30),
          id: f.id,
          tipTitle:
              '${fazitTyp(t, f.typ).icon} ${f.label} (${fazitTyp(t, f.typ).label})',
          tipBody: f.beschreibung,
          onTap: widget.onFinding == null
              ? null
              : () => widget.onFinding!(f.id),
        ),
      for (final s in secs)
        ChartHit(
          rect: Rect.fromLTWH(_xR - 8, secY[s]! - 12, 300, 24),
          tipTitle: 'Abschnitt ${_secLabel(s)}',
          tipBody: 'klicken zum Öffnen',
          onTap:
              widget.onSection == null ? null : () => widget.onSection!(s),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChartCanvas(
          logicalSize: Size(_w, h),
          painter: _FazitPainter(
            findings: findings,
            secs: secs,
            secY: secY,
            yL: [for (var i = 0; i < findings.length; i++) yL(i)],
            hoverId: _hoverId,
            tokens: t,
            secLabel: _secLabel,
          ),
          hits: hits,
          onHoverId: (id) => setState(() => _hoverId = id as String?),
        ),
        // Legende — bewusst schlicht (L1: im Original ungestylte Spans).
        Text(
          '✔ Positiv erfüllt ▲ Lücke ◆ Spannung ➜ Ausblick',
          style: AppTextStyles.body.copyWith(color: t.ink),
        ),
      ],
    );
  }

  String _secLabel(String s) {
    final title = widget.sectionTitle?.call(s);
    return title == null || title.isEmpty ? s : '$s $title';
  }

  /// `localeCompare(de, numeric: true)` — Ziffernfolgen numerisch vergleichen.
  static int _localeCompareNumericDe(String a, String b) {
    final re = RegExp(r'(\d+)|(\D+)');
    final pa = re.allMatches(a).toList();
    final pb = re.allMatches(b).toList();
    for (var i = 0; i < math.min(pa.length, pb.length); i++) {
      final na = int.tryParse(pa[i].group(0)!);
      final nb = int.tryParse(pb[i].group(0)!);
      int cmp;
      if (na != null && nb != null) {
        cmp = na.compareTo(nb);
      } else {
        cmp = pa[i].group(0)!.compareTo(pb[i].group(0)!);
      }
      if (cmp != 0) return cmp;
    }
    return pa.length.compareTo(pb.length);
  }
}

class _FazitPainter extends CustomPainter {
  _FazitPainter({
    required this.findings,
    required this.secs,
    required this.secY,
    required this.yL,
    required this.hoverId,
    required this.tokens,
    required this.secLabel,
  });

  final List<FazitFinding> findings;
  final List<String> secs;
  final Map<String, double> secY;
  final List<double> yL;
  final String? hoverId;
  final BookClothTokens tokens;
  final String Function(String) secLabel;

  static const double _xL = _FazitGraphChartState._xL;
  static const double _xR = _FazitGraphChartState._xR;

  @override
  void paint(Canvas canvas, Size size) {
    // Kanten (unter den Knoten).
    for (final (i, f) in findings.indexed) {
      final typ = fazitTyp(tokens, f.typ);
      final opacity = hoverId == null ? .5 : (hoverId == f.id ? 1.0 : .12);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..color = typ.c.withValues(alpha: opacity);
      for (final s in f.abschnitte) {
        final y2 = secY[s];
        if (y2 == null) continue;
        final y1 = yL[i];
        final path = Path()
          ..moveTo(_xL + 8, y1)
          ..cubicTo(_xL + 150, y1, _xR - 150, y2, _xR - 8, y2);
        canvas.drawPath(path, paint);
      }
    }

    // Befund-Knoten links.
    for (final (i, f) in findings.indexed) {
      final typ = fazitTyp(tokens, f.typ);
      final y = yL[i];
      canvas.drawCircle(Offset(_xL - 2, y), 7, Paint()..color = typ.c);
      canvas.drawCircle(
        Offset(_xL - 2, y),
        7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = tokens.surface,
      );
      // font-weight 650 → nächstes Flutter-Gewicht 600.
      drawSvgText(canvas, svgEllipsis(f.label, 36, 34), Offset(_xL - 16, y - 3),
          fontSize: 12.5, weight: FontWeight.w600, color: tokens.ink,
          anchor: SvgTextAnchor.end);
      final fazitRef = f.fazitParagraphId.isNotEmpty
          ? ' · Fazit ${f.fazitParagraphId.replaceAll('6.0-', '')}'
          : '';
      drawSvgText(canvas, '${typ.icon} ${typ.label}$fazitRef',
          Offset(_xL - 16, y + 12),
          fontSize: 10.5, color: typ.c, anchor: SvgTextAnchor.end);
    }

    // Abschnitts-Knoten rechts.
    for (final s in secs) {
      final y = secY[s]!;
      canvas.drawCircle(Offset(_xR + 2, y), 5, Paint()..color = tokens.surface2);
      canvas.drawCircle(
        Offset(_xR + 2, y),
        5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = tokens.baseline,
      );
      drawSvgText(canvas, svgEllipsis(secLabel(s), 34, 32),
          Offset(_xR + 14, y + 4),
          fontSize: 12, color: tokens.ink2);
    }

    // Spaltenköpfe.
    drawSvgText(canvas, 'FAZIT-BEFUNDE', const Offset(_xL - 16, 18),
        fontSize: 11, weight: FontWeight.w700, color: tokens.muted,
        anchor: SvgTextAnchor.end, letterSpacing: 1);
    drawSvgText(canvas, 'HERGELEITET AUS', const Offset(_xR + 14, 18),
        fontSize: 11, weight: FontWeight.w700, color: tokens.muted,
        letterSpacing: 1);
  }

  @override
  bool shouldRepaint(_FazitPainter oldDelegate) =>
      oldDelegate.findings != findings ||
      oldDelegate.hoverId != hoverId ||
      oldDelegate.tokens != tokens;
}
