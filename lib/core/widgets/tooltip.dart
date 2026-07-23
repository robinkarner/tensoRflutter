import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Chart-/Viz-Tooltip — Pendant zu `U.showTip`/`U.hideTip` (util.js:670–679)
/// und `.viz-tip` (theme.css:537–547).
///
/// Ein einziger, imperativ gesteuerter Tooltip: Charts und Graphen rufen bei
/// Hover [VizTip.show] mit der Zeigerposition auf und [VizTip.hide] beim
/// Verlassen. Position wie im Original: +14px Versatz nach rechts/unten,
/// am Viewport-Rand auf 10px Abstand geklemmt. Der Tooltip fängt keine
/// Zeigerereignisse (pointer-events: none).
abstract final class VizTip {
  static OverlayEntry? _entry;
  static final ValueNotifier<(Widget, Offset)?> _content = ValueNotifier(null);

  /// Zeigt den Tooltip mit [content] an der globalen Zeigerposition
  /// [position]; wiederholte Aufrufe verschieben/aktualisieren ihn nur.
  static void show(
    BuildContext context, {
    required Widget content,
    required Offset position,
  }) {
    _content.value = (content, position);
    if (_entry != null) return;
    _entry = OverlayEntry(builder: _build);
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  /// Blendet den Tooltip aus.
  static void hide() {
    _entry?.remove();
    _entry = null;
    _content.value = null;
  }

  static Widget _build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return ValueListenableBuilder<(Widget, Offset)?>(
      valueListenable: _content,
      builder: (context, value, _) {
        if (value == null) return const SizedBox.shrink();
        final (content, position) = value;
        return Positioned.fill(
          child: IgnorePointer(
            child: CustomSingleChildLayout(
              delegate: _VizTipLayout(position),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(
                  color: t.surface,
                  border: Border.all(color: t.borderStrong),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: t.shadow2,
                ),
                child: DefaultTextStyle.merge(
                  style: AppTextStyles.small.copyWith(
                    fontSize: 13,
                    color: t.ink,
                  ),
                  child: content,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Layout: `left = min(x+14, innerWidth − w − 10)`, analog für top.
class _VizTipLayout extends SingleChildLayoutDelegate {
  const _VizTipLayout(this.position);

  final Offset position;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final x = (position.dx + 14)
        .clamp(double.negativeInfinity, size.width - childSize.width - 10);
    final y = (position.dy + 14)
        .clamp(double.negativeInfinity, size.height - childSize.height - 10);
    return Offset(x.toDouble(), y.toDouble());
  }

  @override
  bool shouldRelayout(_VizTipLayout oldDelegate) =>
      oldDelegate.position != position;
}
