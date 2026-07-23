/// Markierungsfarben-Wahl — Port von `farbControl` (:326-355) samt
/// `.farbdot`/`.farbpop` (app.css:566-607): automatischer Vorschlag
/// (gestrichelter Ring), Popover mit „A auto“ + den 8 Palette-Swatches,
/// Klick außerhalb schließt.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/levels.dart';
import '../layout/studio_state.dart';

class FarbControl extends ConsumerStatefulWidget {
  const FarbControl({
    super.key,
    required this.srcId,
    required this.fnNum,
    this.size = 20,
    this.openUpwards = false,
  });

  final String srcId;
  final int fnNum;

  /// Dock-Slot nutzt 24×24 (app.css:543).
  final double size;

  /// Im Dock öffnet das Popover nach OBEN (app.css:544).
  final bool openUpwards;

  @override
  ConsumerState<FarbControl> createState() => _FarbControlState();
}

class _FarbControlState extends ConsumerState<FarbControl> {
  final OverlayPortalController _pop = OverlayPortalController();
  final LayerLink _link = LayerLink();

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final domain = ref.watch(studioDomainProvider);
    if (domain == null) return const SizedBox.shrink();

    final entry = domain.levels.entry(widget.fnNum);
    final explicit = entry?['farbe'] is String && '${entry!['farbe']}'.isNotEmpty
        ? '${entry['farbe']}'
        : null;
    final effective =
        explicit ?? domain.levels.autoFarbe(widget.srcId, widget.fnNum);
    final color = BookClothTokens.markFarbe(effective) ?? t.muted;

    void pick(String? key) {
      // Levels.save leert leere Felder selbst; '' entfernt die Farbe.
      domain.levels.save(widget.fnNum, {'farbe': key ?? ''});
      _pop.hide();
    }

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _pop,
        overlayChildBuilder: (context) => Positioned.fill(
          child: Stack(
            children: [
              // Klick außerhalb schließt (close-on-outside-click, :348).
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _pop.hide,
                ),
              ),
              CompositedTransformFollower(
                link: _link,
                targetAnchor: widget.openUpwards
                    ? Alignment.topLeft
                    : Alignment.bottomLeft,
                followerAnchor: widget.openUpwards
                    ? Alignment.bottomLeft
                    : Alignment.topLeft,
                offset: Offset(0, widget.openUpwards ? -6 : 6),
                child: _FarbPop(
                  explicit: explicit,
                  onAuto: () => pick(null),
                  onPick: pick,
                ),
              ),
            ],
          ),
        ),
        child: Tooltip(
          message:
              'Markierungsfarbe — automatisch vorgeschlagen, klicken zum Ändern',
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _pop.toggle,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(
                    color: explicit == null
                        ? color.withValues(alpha: .4)
                        : t.surface,
                    width: 2,
                    // auto = gestrichelt gibt es in Flutter-Border nicht —
                    // die halbtransparente Kante trägt dieselbe Botschaft.
                  ),
                  boxShadow: [
                    BoxShadow(color: t.borderStrong, spreadRadius: 1.5),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Das Popover: Pill mit „A auto“ + 8 Swatches.
class _FarbPop extends StatelessWidget {
  const _FarbPop({
    required this.explicit,
    required this.onAuto,
    required this.onPick,
  });

  final String? explicit;
  final VoidCallback onAuto;
  final void Function(String key) onPick;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.borderStrong),
          borderRadius: BorderRadius.circular(BookClothTokens.radiusPill),
          boxShadow: t.shadowPop,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // „A auto“
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onAuto,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: t.surface2,
                    border: Border.all(
                      color: explicit == null ? t.accent : t.borderStrong,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('A',
                          style: TextStyle(
                            fontFamily: AppFonts.mono,
                            fontFamilyFallback: AppFonts.fallback,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            height: 1,
                            color:
                                explicit == null ? t.accentInk : t.ink2,
                          )),
                      Text('auto',
                          style: TextStyle(
                            fontFamily: AppFonts.ui,
                            fontFamilyFallback: AppFonts.fallback,
                            fontWeight: FontWeight.w500,
                            fontSize: 9.5,
                            height: 1.2,
                            color: t.muted,
                          )),
                    ],
                  ),
                ),
              ),
            ),
            for (final f in Levels.farben) ...[
              const SizedBox(width: 5),
              Tooltip(
                message: f.key,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => onPick(f.key),
                    child: Container(
                      width: 17,
                      height: 17,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: BookClothTokens.markFarbe(f.key),
                        boxShadow: explicit == f.key
                            ? [
                                BoxShadow(color: t.surface, spreadRadius: 2),
                                BoxShadow(
                                  color: BookClothTokens.markFarbe(f.key)!,
                                  spreadRadius: 3.5,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
