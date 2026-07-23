import 'package:flutter/material.dart';

import '../theme/color_mix.dart';
import '../theme/tokens.dart';

/// Drag-Resizer — EIN Pattern für alle verstellbaren Splits.
/// Pendant zu `U.resizer` (util.js:686–719).
///
/// Vertrag wie im Original:
///  * [read] liefert die aktuelle Breite/Höhe in px (nur beim Drag-Start
///    gelesen — während des Drags zählt der zuletzt GESETZTE Wert, weil
///    read() während laufender Layout-Übergänge falsch wäre),
///  * [apply] setzt den Wert; `apply(null)` = Standardbreite,
///  * [persist] speichert am Drag-Ende den gerundeten Wert (bzw. `null`
///    nach Doppelklick-Reset) — Pendant zu `opts.store`,
///  * [dir] 1 = Handle rechts/unter dem Element, −1 = links/darüber,
///  * Doppelklick setzt auf den Standard zurück, [onDone] läuft nach
///    Drag-Ende UND Reset.
///
/// Optik (.pane-resize/.sfd-resize, app.css:1341–1351): 7px-Naht mit
/// eingerücktem Streifen (border-strong, 50%), bei Hover/Drag Akzent (90%).
class ResizerHandle extends StatefulWidget {
  const ResizerHandle({
    super.key,
    required this.read,
    required this.apply,
    this.persist,
    this.onDone,
    this.min = 220,
    this.max = 1100,
    this.dir = 1,
    this.axis = Axis.horizontal,
    this.thickness = 7,
    this.stripePadding,
  });

  /// Aktueller Wert in px (Breite bei [Axis.horizontal], Höhe bei vertical).
  final double Function() read;

  /// Neuen Wert setzen; `null` = auf Standard zurück.
  final ValueChanged<double?> apply;

  /// Persistenz am Drag-Ende: gerundete px oder `null` (Reset).
  final ValueChanged<int?>? persist;

  /// Läuft nach Drag-Ende und nach Doppelklick-Reset (Pendant zu opts.done).
  final VoidCallback? onDone;

  final double min;
  final double max;

  /// 1 = Ziehen nach rechts/unten vergrößert · −1 = umgekehrt.
  final int dir;

  /// [Axis.horizontal] = horizontales Ziehen (vertikale Naht, Spaltenbreite);
  /// [Axis.vertical] = vertikales Ziehen (horizontale Naht, z. B. Dock-Höhe).
  final Axis axis;

  /// Breite der Griffzone (Original: 7px).
  final double thickness;

  /// Einrückung des sichtbaren Streifens. Default wie CSS:
  /// horizontal `inset: 0 2px`, vertikal (Dock-Naht) `inset: 2px 8px`.
  final EdgeInsets? stripePadding;

  /// Läuft gerade irgendein Resize? (Pendant zu `body.resizing` — Layouts
  /// können damit Transitions während des Drags abschalten.)
  static final ValueNotifier<Axis?> active = ValueNotifier(null);

  @override
  State<ResizerHandle> createState() => _ResizerHandleState();
}

class _ResizerHandleState extends State<ResizerHandle> {
  bool _hover = false;
  bool _dragging = false;
  double _start = 0; // Zeigerposition beim Drag-Start
  double _w0 = 0; // Wert beim Drag-Start
  double? _last; // zuletzt gesetzter Wert (maßgeblich für persist)

  bool get _horizontal => widget.axis == Axis.horizontal;

  void _dragStart(DragStartDetails d) {
    _start = _horizontal ? d.globalPosition.dx : d.globalPosition.dy;
    _w0 = widget.read();
    _last = null;
    setState(() => _dragging = true);
    ResizerHandle.active.value = widget.axis;
  }

  void _dragUpdate(DragUpdateDetails d) {
    final p = _horizontal ? d.globalPosition.dx : d.globalPosition.dy;
    _last = ((_w0 + (p - _start) * widget.dir).clamp(widget.min, widget.max));
    widget.apply(_last);
  }

  void _dragEnd() {
    setState(() => _dragging = false);
    ResizerHandle.active.value = null;
    if (_last != null) widget.persist?.call(_last!.round());
    widget.onDone?.call();
  }

  void _reset() {
    widget.apply(null);
    widget.persist?.call(null);
    widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final lit = _hover || _dragging;
    final stripePadding = widget.stripePadding ??
        (_horizontal
            ? const EdgeInsets.symmetric(horizontal: 2)
            : const EdgeInsets.symmetric(vertical: 2, horizontal: 8));

    return MouseRegion(
      cursor: _horizontal
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: _reset,
        onHorizontalDragStart: _horizontal ? _dragStart : null,
        onHorizontalDragUpdate: _horizontal ? _dragUpdate : null,
        onHorizontalDragEnd: _horizontal ? (_) => _dragEnd() : null,
        onHorizontalDragCancel: _horizontal ? _dragEnd : null,
        onVerticalDragStart: _horizontal ? null : _dragStart,
        onVerticalDragUpdate: _horizontal ? null : _dragUpdate,
        onVerticalDragEnd: _horizontal ? null : (_) => _dragEnd(),
        onVerticalDragCancel: _horizontal ? null : _dragEnd,
        child: SizedBox(
          width: _horizontal ? widget.thickness : null,
          height: _horizontal ? null : widget.thickness,
          child: Padding(
            padding: stripePadding,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              color: lit ? t.accent.alphaPct(90) : t.borderStrong.alphaPct(50),
            ),
          ),
        ),
      ),
    );
  }
}
