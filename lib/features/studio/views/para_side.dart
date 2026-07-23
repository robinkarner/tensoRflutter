/// Instanz-Fenster neben der Absatzkarte — Port von `paraSide`/`psHead`/
/// `psResize` (views_studio.js:2211-2292) samt `.para-side` (app.css:1490-1556):
///
///   * GESTRICHELTE Naht zur Karte (links; gestapelt: oben), `tinted` =
///     zarter Farb-Wash + Farbpunkt vor dem Titel in der View-Farbe,
///   * Kopf: Titel (uppercase Display) · Chips (✦ auto / ✎) · EIN ×
///     (schließt NUR diesen Abschnitt, `dockClose`),
///   * Inhalt: gespeicherter Text > Auto-Vorbefüllung > leerer Hinweis;
///     Doppelklick editiert die Markdown-ROHFORM in-place — Esc ODER
///     Fokusverlust übernimmt; unverändertes Auto zählt nicht als Edit.
///     Das Original bleibt unangetastet (Ground Truth).
///   * Naht als Griff: Fenster-Breite ziehen (`uiPsW`, 200–560, dir −1,
///     Doppelklick = Standard).
///
/// `connections` rendert stattdessen den ⤳-Graphen ([SideGraph]);
/// figure/table-Absätze bekommen ein leeres Fenster (`.para-side.empty`).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/richtext/mini_md.dart';
import '../../../core/theme/color_mix.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/models/models.dart';
import '../layout/css_color.dart';
import '../layout/dock_state.dart';
import '../layout/studio_state.dart';
import 'side_graph.dart';

/// Slot-Einstieg (`StudioSlots.paraSide`).
Widget buildParaSide(BuildContext context, String sectionId, Paragraph p,
    String mode, {required bool isFirst}) {
  if (p.typeEnum == ParagraphType.figure || p.typeEnum == ParagraphType.table) {
    return const _EmptySide();
  }
  if (mode == 'connections') {
    return SideGraph(sectionId: sectionId, paragraph: p, isFirst: isFirst);
  }
  return ParaSideWindow(sectionId: sectionId, paragraph: p, mode: mode);
}

/// `.para-side.empty`: durchgehende (nicht gestrichelte) Naht, surface-2.
class _EmptySide extends StatelessWidget {
  const _EmptySide();

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.surface2,
        border: Border.all(color: t.border),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(BookClothTokens.radius),
          bottomRight: Radius.circular(BookClothTokens.radius),
        ),
      ),
    );
  }
}

class ParaSideWindow extends ConsumerStatefulWidget {
  const ParaSideWindow({
    super.key,
    required this.sectionId,
    required this.paragraph,
    required this.mode,
  });

  final String sectionId;
  final Paragraph paragraph;
  final String mode;

  @override
  ConsumerState<ParaSideWindow> createState() => _ParaSideWindowState();
}

class _ParaSideWindowState extends ConsumerState<ParaSideWindow> {
  bool _editing = false;
  late final TextEditingController _ctl = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing) _finishEdit();
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Paragraph get p => widget.paragraph;

  String _stored(Map<String, Object?> snapshot) =>
      dockGetFrom(snapshot, widget.mode, p.id);

  String _auto(StudioDomain domain) =>
      dockAutoFor(domain, widget.mode, widget.sectionId, p);

  /// Doppelklick (:2257-2266): Markdown-ROHFORM an derselben Stelle.
  void _startEdit(String stored, String auto) {
    if (_editing) return;
    setState(() {
      _editing = true;
      _done = false;
      _ctl.text = stored.isNotEmpty ? stored : auto;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      _ctl.selection = TextSelection.collapsed(offset: _ctl.text.length);
    });
  }

  /// Esc ODER Fokusverlust = übernehmen (:2269-2284); unverändertes Auto
  /// zählt nicht als Edit.
  void _finishEdit() {
    if (_done) return;
    _done = true;
    final domain = ref.read(studioDomainProvider);
    final t = _ctl.text.replaceAll(' ', ' ').trim();
    final auto = domain != null ? _auto(domain) : '';
    final kv = ref.read(studioKvProvider.notifier);
    dockSetIn(kv, widget.mode, p.id, t == auto.trim() ? '' : t);
    if (mounted) setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final domain = ref.watch(studioDomainProvider);
    final snapshot =
        ref.watch(studioKvProvider).value ?? const <String, Object?>{};
    final defs = ref.watch(dockDefsProvider);
    if (domain == null) return const SizedBox.shrink();

    final stored = _stored(snapshot);
    final auto = _auto(domain);
    final text = stored.isNotEmpty ? stored : auto;
    final accent = resolveCssColor(t, dockDefOf(defs, widget.mode)?.color);
    final tinted = accent != null;

    final bg = _editing
        ? t.accent.mix(t.surface, 6)
        : tinted
            ? accent.mix(t.surface, 4)
            : t.surface;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Über der maximalen Fensterbreite (560) MUSS es der gestapelte
        // Container-Zweig sein (≤880px-Query) — Naht wandert nach oben.
        final stacked = constraints.maxWidth > 570;
        return Stack(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 16, 14),
              foregroundDecoration: _editing
                  ? BoxDecoration(
                      border: Border.all(color: t.accent.alphaPct(40), width: 2),
                      borderRadius: _radius(stacked),
                    )
                  : null,
              decoration: BoxDecoration(
                color: bg,
                border: Border(
                  top: BorderSide(color: t.border),
                  right: BorderSide(color: t.border),
                  bottom: BorderSide(color: t.border),
                  left: stacked
                      ? BorderSide(color: t.border)
                      : BorderSide.none,
                ),
                borderRadius: _radius(stacked),
                boxShadow: t.shadow1,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _head(t, accent, stored, auto),
                  const SizedBox(height: 7),
                  _body(t, stored, auto, text),
                ],
              ),
            ),
            // Gestrichelte Naht (`border-left: 1.5px dashed`).
            if (stacked)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: DashedLine(
                  axis: Axis.horizontal,
                  color: tinted
                      ? accent.mix(t.borderStrong, 70)
                      : t.borderStrong,
                ),
              )
            else
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: DashedLine(
                  axis: Axis.vertical,
                  color: tinted
                      ? accent.mix(t.borderStrong, 70)
                      : t.borderStrong,
                ),
              ),
            // Naht als Griff: Fenster-Breite ziehen (nur nebeneinander).
            if (!stacked)
              Positioned(
                left: -0,
                top: 0,
                bottom: 0,
                width: 10,
                child: _PsResize(
                  read: () => constraints.maxWidth,
                  onApply: (px) => ref
                      .read(studioPrefsCtlProvider.notifier)
                      .setPsW(px?.round()),
                ),
              ),
          ],
        );
      },
    );
  }

  BorderRadius _radius(bool stacked) => stacked
      ? const BorderRadius.only(
          bottomLeft: Radius.circular(BookClothTokens.radius),
          bottomRight: Radius.circular(BookClothTokens.radius),
        )
      : const BorderRadius.only(
          topRight: Radius.circular(BookClothTokens.radius),
          bottomRight: Radius.circular(BookClothTokens.radius),
        );

  /// `.ps-h`: Farbpunkt (tinted) · Titel · Chips · flex · ×.
  Widget _head(
      BookClothTokens t, Color? accent, String stored, String auto) {
    final defs = ref.watch(dockDefsProvider);
    final label = dockLabelOf(defs, widget.mode);
    return Container(
      padding: EdgeInsets.only(bottom: accent != null ? 6 : 0),
      decoration: accent != null
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(color: accent.alphaPct(30)),
              ),
            )
          : null,
      child: Row(
        children: [
          if (accent != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent,
                boxShadow: [BoxShadow(color: accent.alphaPct(20), spreadRadius: 3)],
              ),
            ),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontFamilyFallback: AppFonts.fallback,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                height: 1.3,
                letterSpacing: .09 * 12,
                color: accent != null ? accent.mix(t.ink, 82) : t.muted,
              ),
            ),
          ),
          const SizedBox(width: 4),
          if (_editing)
            _EditHintPill(t: t)
          else ...[
            if (stored.isEmpty && auto.isNotEmpty)
              _MiniChip(label: '✦ auto', color: t.ki, borderColor: t.ki),
            if (stored.isNotEmpty)
              _MiniChip(label: '✎', color: t.good, borderColor: t.good),
          ],
          const Spacer(),
          Tooltip(
            message: 'Instanz-Fenster dieses Abschnitts schließen',
            child: _PsIconBtn(
              label: '×',
              danger: true,
              onTap: () {
                final prefs = ref.read(studioPrefsCtlProvider).value ??
                    StudioPrefs.defaults;
                dockCloseSection(ref.read(studioKvProvider.notifier),
                    prefs.dock, widget.sectionId);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BookClothTokens t, String stored, String auto, String text) {
    if (_editing) {
      return Focus(
        onKeyEvent: (node, e) {
          if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
            _finishEdit(); // Esc = ÜBERNEHMEN (kein Verwerfen!)
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: _ctl,
          focusNode: _focus,
          maxLines: null,
          style: AppTextStyles.small
              .copyWith(fontSize: 14, height: 1.72, color: t.ink2),
          cursorColor: t.accent,
          decoration: const InputDecoration(
            isDense: true,
            isCollapsed: true,
            border: InputBorder.none,
          ),
        ),
      );
    }
    final content = text.isNotEmpty
        ? MiniMd(text)
        : Text(
            '— leer — Doppelklick und einfach losschreiben (oder 🤖 Prompt in der Instanz-Leiste)',
            style: AppTextStyles.small.copyWith(color: t.muted),
          );
    return MouseRegion(
      cursor: SystemMouseCursors.text,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: () => _startEdit(stored, auto),
        child: DefaultTextStyle.merge(
          style: AppTextStyles.small
              .copyWith(fontSize: 14, height: 1.72, color: t.ink2),
          child: content,
        ),
      ),
    );
  }
}

/// Hinweis-Pill während des Edits (`.edit-hint`).
class _EditHintPill extends StatelessWidget {
  const _EditHintPill({required this.t});

  final BookClothTokens t;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message:
          'Direkt schreiben — Markdown, kein LaTeX; Esc oder Klick außerhalb übernimmt',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: t.accentSoft,
          border: Border.all(color: t.accentLine),
          borderRadius: BorderRadius.circular(BookClothTokens.radiusPill),
        ),
        child: Text(
          '✎ · Esc fertig',
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontFamilyFallback: AppFonts.fallback,
            fontWeight: FontWeight.w600,
            fontSize: 10.5,
            height: 1,
            color: t.accentInk,
          ),
        ),
      ),
    );
  }
}

/// Mini-Chip (✦ auto / ✎) im Fensterkopf.
class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.label,
    required this.color,
    required this.borderColor,
  });

  final String label;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor.alphaPct(55)),
        borderRadius: BorderRadius.circular(BookClothTokens.radiusPill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppFonts.ui,
          fontFamilyFallback: AppFonts.fallback,
          fontWeight: FontWeight.w500,
          fontSize: 10.5,
          height: 1,
          color: color,
        ),
      ),
    );
  }
}

/// Fenster-Knopf (`.ps-ib`) — × färbt bei Hover bad.
class _PsIconBtn extends StatefulWidget {
  const _PsIconBtn({
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  State<_PsIconBtn> createState() => _PsIconBtnState();
}

class _PsIconBtnState extends State<_PsIconBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            color: _hover
                ? (widget.danger ? t.badSoft : t.surface3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontFamilyFallback: AppFonts.fallback,
              fontWeight: FontWeight.w500,
              fontSize: 14,
              height: .9,
              color: _hover ? (widget.danger ? t.bad : t.ink) : t.muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Unsichtbarer 10px-Naht-Griff (`.ps-resize`): Ziehen ändert `uiPsW`
/// (200–560, dir −1 — nach links vergrößert), Doppelklick = Standard;
/// bei Hover/Drag zarter Akzent-Wash.
class _PsResize extends StatefulWidget {
  const _PsResize({required this.read, required this.onApply});

  final double Function() read;

  /// null = Reset auf Standard.
  final void Function(double? px) onApply;

  @override
  State<_PsResize> createState() => _PsResizeState();
}

class _PsResizeState extends State<_PsResize> {
  bool _hover = false;
  bool _dragging = false;
  double _startX = 0;
  double _w0 = 0;
  double? _last;
  int _lastEmitMs = 0;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: () => widget.onApply(null),
        onHorizontalDragStart: (d) {
          _startX = d.globalPosition.dx;
          _w0 = widget.read();
          setState(() => _dragging = true);
        },
        onHorizontalDragUpdate: (d) {
          // dir −1: Ziehen nach links vergrößert das Fenster. Gedrosselt
          // (40ms), damit der KV-Store nicht je Pixel schreibt.
          _last = (_w0 - (d.globalPosition.dx - _startX)).clamp(200.0, 560.0);
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - _lastEmitMs >= 40) {
            _lastEmitMs = now;
            widget.onApply(_last);
          }
        },
        onHorizontalDragEnd: (_) {
          setState(() => _dragging = false);
          if (_last != null) widget.onApply(_last);
        },
        child: Container(
          decoration: BoxDecoration(
            color: (_hover || _dragging)
                ? t.accent.alphaPct(18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

/// Gestrichelte 1.5px-Linie (CSS `dashed` hat kein Flutter-Pendant).
class DashedLine extends StatelessWidget {
  const DashedLine({
    super.key,
    required this.axis,
    required this.color,
    this.thickness = 1.5,
    this.dash = 5,
    this.gap = 4,
  });

  final Axis axis;
  final Color color;
  final double thickness;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: axis == Axis.vertical ? thickness : null,
      height: axis == Axis.horizontal ? thickness : null,
      child: CustomPaint(
        painter: _DashPainter(
            axis: axis, color: color, thickness: thickness, dash: dash, gap: gap),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter({
    required this.axis,
    required this.color,
    required this.thickness,
    required this.dash,
    required this.gap,
  });

  final Axis axis;
  final Color color;
  final double thickness;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness;
    var pos = 0.0;
    final len = axis == Axis.vertical ? size.height : size.width;
    while (pos < len) {
      final end = (pos + dash).clamp(0.0, len);
      if (axis == Axis.vertical) {
        canvas.drawLine(Offset(thickness / 2, pos), Offset(thickness / 2, end), paint);
      } else {
        canvas.drawLine(Offset(pos, thickness / 2), Offset(end, thickness / 2), paint);
      }
      pos += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) =>
      old.color != color || old.axis != axis;
}
