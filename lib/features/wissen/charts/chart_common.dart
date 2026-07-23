/// Gemeinsames Gerüst der Wissen-Charts (E11: CustomPainter statt SVG).
///
/// Die Original-Diagramme (js/charts.js, notebook.js:268-382) sind SVGs mit
/// `viewBox` — sie skalieren über die Container-Breite und tragen Tooltips
/// über `data-tip`-Attribute (`Charts._wireTips` → `U.showTip`). Dieses Modul
/// liefert die drei Pendants:
///
///  * [ChartCanvas] — zeichnet einen Painter im LOGISCHEN Koordinatensystem
///    des Originals (z. B. 760×300) und skaliert ihn auf die Container-Breite
///    (`width=100%` + viewBox); optional feste Breite (Pie: 230px).
///  * [ChartHit] — Hover-/Klick-Ziele in logischen Koordinaten (Rechteck,
///    Pfad-Nähe oder freier Test); das letzte treffende Ziel gewinnt
///    (SVG-Z-Ordnung: später gezeichnet = oben).
///  * [drawSvgText] — Text wie ein SVG-`<text>`: Position ist die BASELINE,
///    `text-anchor` start/middle/end.
///
/// Tooltips laufen über den zentralen [VizTip] (+14px-Versatz, Viewport-
/// Klemmung — util.js:670-679); das Tip-Muster `<b>Titel</b>Text` wird als
/// fette Titelzeile + Fließtextzeile gesetzt ([vizTipContent]).
library;

import 'package:flutter/material.dart';

import '../../../core/theme/typography.dart';
import '../../../core/widgets/tooltip.dart';

// ---------------------------------------------------------------------------
// Hover-/Klick-Ziele
// ---------------------------------------------------------------------------

/// Ein Ziel im logischen Chart-Koordinatensystem.
class ChartHit {
  /// Rechteckiges Ziel (unsichtbares Hover-Rect des Originals).
  final Rect? rect;

  /// Pfad-Ziel: Treffer, wenn der Zeiger näher als [tolerance] an der
  /// Polylinie ist (für Bézier-Bögen als Sample-Punkte).
  final List<Offset>? polyline;
  final double tolerance;

  /// Freier Test (Kreis-/Ringsegmente der Pie-Charts).
  final bool Function(Offset p)? test;

  /// Tooltip: fette Titelzeile + Text (`<b>…</b>…`-Muster). Ohne Titel
  /// erscheint kein Tooltip.
  final String? tipTitle;
  final String tipBody;

  final VoidCallback? onTap;

  /// Frei nutzbare Kennung (z. B. Finding-id fürs Hover-Dimming).
  final Object? id;

  const ChartHit({
    this.rect,
    this.polyline,
    this.tolerance = 6,
    this.test,
    this.tipTitle,
    this.tipBody = '',
    this.onTap,
    this.id,
  });

  bool contains(Offset p) {
    if (test != null && test!(p)) return true;
    if (rect != null && rect!.contains(p)) return true;
    final line = polyline;
    if (line != null && line.length >= 2) {
      for (var i = 0; i + 1 < line.length; i++) {
        if (_distToSegment(p, line[i], line[i + 1]) <= tolerance) return true;
      }
    }
    return false;
  }

  static double _distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.distanceSquared;
    if (len2 == 0) return (p - a).distance;
    var t = ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2;
    t = t.clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }
}

/// Tooltip-Inhalt im `<b>Titel</b>Text`-Muster der data-tips.
Widget vizTipContent(String title, String body) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        if (body.isNotEmpty) Text(body, style: const TextStyle(fontSize: 13)),
      ],
    );

// ---------------------------------------------------------------------------
// Skalierender Zeichen-Host
// ---------------------------------------------------------------------------

/// Zeichnet [painter] (logisches System [logicalSize]) auf Container-Breite
/// skaliert; verdrahtet Hover-Tooltips und Klicks der [hits].
class ChartCanvas extends StatefulWidget {
  const ChartCanvas({
    super.key,
    required this.logicalSize,
    required this.painter,
    this.hits = const [],
    this.fixedWidth,
    this.onHoverId,
  });

  final Size logicalSize;
  final CustomPainter painter;
  final List<ChartHit> hits;

  /// Feste Breite statt 100 % (Pie/Donut: `width:230px`).
  final double? fixedWidth;

  /// Meldet die [ChartHit.id] des aktuell gehoverten Ziels (fazitGraph-
  /// Dimming); null beim Verlassen.
  final ValueChanged<Object?>? onHoverId;

  @override
  State<ChartCanvas> createState() => _ChartCanvasState();
}

class _ChartCanvasState extends State<ChartCanvas> {
  ChartHit? _hovered;

  @override
  void dispose() {
    if (_hovered != null) VizTip.hide();
    super.dispose();
  }

  ChartHit? _hitAt(Offset logical) {
    // SVG-Z-Ordnung: das ZULETZT gezeichnete Ziel liegt oben.
    for (final h in widget.hits.reversed) {
      if (h.contains(logical)) return h;
    }
    return null;
  }

  void _onHover(PointerEvent event, double scale) {
    final logical = event.localPosition / scale;
    final hit = _hitAt(logical);
    if (!identical(hit, _hovered)) {
      if (hit?.id != _hovered?.id) widget.onHoverId?.call(hit?.id);
      setState(() => _hovered = hit);
    }
    if (hit?.tipTitle != null) {
      // mousemove: Tooltip folgt dem Zeiger (util.js:671-673).
      VizTip.show(context,
          content: vizTipContent(hit!.tipTitle!, hit.tipBody),
          position: event.position);
    } else {
      VizTip.hide();
    }
  }

  void _onExit() {
    if (_hovered != null) widget.onHoverId?.call(null);
    setState(() => _hovered = null);
    VizTip.hide();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final logical = widget.logicalSize;
      final maxW = constraints.maxWidth;
      final w = widget.fixedWidth ??
          (maxW.isFinite && maxW > 0 ? maxW : logical.width);
      final scale = w / logical.width;
      final h = logical.height * scale;

      return MouseRegion(
        cursor: _hovered?.onTap != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        onHover: (e) => _onHover(e, scale),
        onExit: (_) => _onExit(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _hitAt(d.localPosition / scale)?.onTap?.call(),
          child: CustomPaint(
            size: Size(w, h),
            painter: _ScaledPainter(widget.painter, scale, logical),
          ),
        ),
      );
    });
  }
}

/// Skaliert den logischen Painter auf die Zielgröße (viewBox-Pendant).
class _ScaledPainter extends CustomPainter {
  const _ScaledPainter(this.inner, this.scale, this.logicalSize);

  final CustomPainter inner;
  final double scale;
  final Size logicalSize;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(scale);
    inner.paint(canvas, logicalSize);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScaledPainter oldDelegate) =>
      oldDelegate.scale != scale || oldDelegate.inner != inner;
}

// ---------------------------------------------------------------------------
// SVG-Text-Helfer
// ---------------------------------------------------------------------------

/// `text-anchor` des Originals.
enum SvgTextAnchor { start, middle, end }

/// Zeichnet Text wie ein SVG-`<text>`-Element: [pos] ist der BASELINE-Punkt
/// am Anker. Chart-Beschriftungen laufen in der UI-Schrift (Inter).
void drawSvgText(
  Canvas canvas,
  String text,
  Offset pos, {
  required double fontSize,
  required Color color,
  FontWeight weight = FontWeight.w400,
  SvgTextAnchor anchor = SvgTextAnchor.start,
  double letterSpacing = 0,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: AppFonts.ui,
        fontFamilyFallback: AppFonts.fallback,
        fontSize: fontSize,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        color: color,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final baseline = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  final dx = switch (anchor) {
    SvgTextAnchor.start => 0.0,
    SvgTextAnchor.middle => tp.width / 2,
    SvgTextAnchor.end => tp.width,
  };
  tp.paint(canvas, Offset(pos.dx - dx, pos.dy - baseline));
}

/// JS-`slice`-Kürzung der Chart-Labels (`label.length > max ? slice+… : label`).
String svgEllipsis(String s, int maxLen, int cutTo) =>
    s.length > maxLen ? '${s.substring(0, cutTo)}…' : s;
