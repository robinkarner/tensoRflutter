/// Markierungs-Overlay einer PDF-Seite: Highlights (`.pe-hl`), Such-Flash
/// (`.pe-found`), Live-Auswahl (::selection) und Kommentar-Pins (`.pe-pin`).
///
/// Rohwerte aus Dossier 05 §5: Füllung = Belegfarbe + Alpha 0x55, Outline
/// 1 px in der Belegfarbe, `mix-blend-mode: multiply` (hell) bzw. normal +
/// Opacity .55 (dunkel); Fallback-Farbe `#e8c33f`. Pin: Mono 700 10 px,
/// Border 1.5 px in Belegfarbe (Fallback warn), Radius Pill, Schatten
/// 0 2px 8px rgb(0 0 0/.2); Drag-Schwelle 4 px, Clamp 0–0.98.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import 'pdf_mark.dart';

/// Fallback-Markierungsfarbe (pdfengine.js:1115).
const Color kMarkFallbackColor = Color(0xFFE8C33F);

/// Effektive Farbe eines Farb-Keys (Levels-Palette, Fallback `#e8c33f`).
Color markColorOf(String? farbKey) =>
    BookClothTokens.markFarbe(farbKey) ?? kMarkFallbackColor;

/// Zeichnet Highlights + Flash + Live-Auswahl einer Seite in Pixel-
/// Koordinaten (Rects sind 0..1-normalisiert, Ursprung oben links).
class MarkHighlightPainter extends CustomPainter {
  MarkHighlightPainter({
    required this.marks,
    this.flashRects = const [],
    this.selectionRects = const [],
    this.selectionColor = const Color(0x59B4552D),
    required this.dark,
  });

  final List<PdfMark> marks;
  final List<MarkRect> flashRects;
  final List<MarkRect> selectionRects;

  /// `::selection`: color-mix(accent 35%, transparent) (app.css:934).
  final Color selectionColor;

  /// Dark-Mode: normal + Opacity .55 statt multiply (app.css:948-949).
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    Rect toPx(MarkRect r) => Rect.fromLTWH(
        r.x * size.width, r.y * size.height, r.w * size.width, r.h * size.height);

    for (final m in marks) {
      final hex = markColorOf(m.farbe);
      // hex+'55' ≈ Alpha 0x55; im Dark-Modus wirkt zusätzlich Opacity .55
      // auf der ganzen Ebene → hier direkt eingerechnet.
      final fill = Paint()
        ..color = dark ? hex.withAlpha((0x55 * .55).round()) : hex.withAlpha(0x55)
        ..blendMode = dark ? BlendMode.srcOver : BlendMode.multiply;
      final outline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = dark ? hex.withValues(alpha: .55) : hex;
      for (final r in m.rects) {
        final rect = toPx(r);
        final rr = RRect.fromRectAndRadius(rect, const Radius.circular(2));
        canvas.drawRRect(rr, fill);
        canvas.drawRRect(rr, outline);
      }
    }

    // Live-Auswahl (unter dem Flash, über den Marks).
    for (final r in selectionRects) {
      canvas.drawRect(toPx(r), Paint()..color = selectionColor);
    }

    // Such-Flash `.pe-found`: Gelb 60 % + Outline #e8a800.
    if (flashRects.isNotEmpty) {
      final fill = Paint()..color = BookClothTokens.searchHit;
      final outline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = BookClothTokens.searchHitOutline;
      for (final r in flashRects) {
        final rr = RRect.fromRectAndRadius(toPx(r), const Radius.circular(2));
        canvas.drawRRect(rr, fill);
        canvas.drawRRect(rr, outline);
      }
    }
  }

  @override
  bool shouldRepaint(MarkHighlightPainter old) =>
      old.marks != marks ||
      old.flashRects != flashRects ||
      old.selectionRects != selectionRects ||
      old.dark != dark;
}

/// Ein Kommentar-Pin (`.pe-pin`): 💬 + `[fn]`, frei verschiebbar.
///
/// Pointer-Logik wie pdfengine.js:1142-1164: erst ab 4 px Manhattan-Distanz
/// gilt der Zug als Bewegung (→ [onDragEnd] mit neuer Position), sonst ist
/// es ein Klick (→ [onTap], öffnet den Editor).
class MarkPin extends StatefulWidget {
  const MarkPin({
    super.key,
    required this.mark,
    required this.pageSize,
    required this.onMoved,
    required this.onTap,
  });

  final PdfMark mark;

  /// Seitengröße in Pixeln (für die Delta-Normalisierung).
  final Size pageSize;

  /// Persistieren nach echtem Drag: neue 0..1-Position.
  final void Function(double x, double y) onMoved;
  final VoidCallback onTap;

  @override
  State<MarkPin> createState() => _MarkPinState();
}

class _MarkPinState extends State<MarkPin> {
  Offset? _startLocal;
  late double _x, _y;
  double _startX = 0, _startY = 0;
  Offset _dragDelta = Offset.zero;
  bool _moved = false;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _syncFromMark();
  }

  @override
  void didUpdateWidget(MarkPin old) {
    super.didUpdateWidget(old);
    if (!_dragging) _syncFromMark();
  }

  void _syncFromMark() {
    final c = widget.mark.comment;
    _x = c?.x ?? 0;
    _y = c?.y ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final color = widget.mark.farbe != null
        ? markColorOf(widget.mark.farbe)
        : t.warn; // CSS-Fallback var(--warn)

    final pin = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(BookClothTokens.radiusPill),
        boxShadow: const [
          BoxShadow(offset: Offset(0, 2), blurRadius: 8, color: Color(0x33000000)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('💬', style: TextStyle(fontSize: 10, height: 1)),
          if (widget.mark.fn != null) ...[
            const SizedBox(width: 3),
            Text(
              '[${widget.mark.fn}]',
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontFamilyFallback: AppFonts.fallback,
                fontWeight: FontWeight.w700,
                fontSize: 10,
                height: 1,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );

    return Positioned(
      left: _x * widget.pageSize.width,
      top: _y * widget.pageSize.height,
      child: Tooltip(
        message: widget.mark.comment?.text ?? '',
        child: MouseRegion(
          cursor: _dragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) {
              _startLocal = e.position;
              _startX = _x;
              _startY = _y;
              _dragDelta = Offset.zero;
              _moved = false;
              _dragging = true;
            },
            onPointerMove: (e) {
              final start = _startLocal;
              if (start == null) return;
              _dragDelta = e.position - start;
              // 4-px-Manhattan-Schwelle (js:1152).
              if (_dragDelta.dx.abs() + _dragDelta.dy.abs() > 4) _moved = true;
              setState(() {
                _x = (_startX + _dragDelta.dx / widget.pageSize.width)
                    .clamp(0.0, 0.98);
                _y = (_startY + _dragDelta.dy / widget.pageSize.height)
                    .clamp(0.0, 0.98);
              });
            },
            onPointerUp: (_) {
              _dragging = false;
              if (_startLocal == null) return;
              _startLocal = null;
              if (_moved) {
                widget.onMoved(_x, _y);
              } else {
                widget.onTap();
              }
            },
            onPointerCancel: (_) {
              _dragging = false;
              _startLocal = null;
              setState(_syncFromMark);
            },
            child: pin,
          ),
        ),
      ),
    );
  }
}
