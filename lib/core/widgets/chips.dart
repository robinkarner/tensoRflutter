import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Chip- und Status-Bausteine.
///
/// Kernkonvention des Designsystems: RUND = Belegstatus (Ampel-Punkte,
/// Level-Badges als Pills), QUADRATISCH = Struktur/Datei/Verbindung
/// (Eck-Marker, Struktur-Punkte, eckige Art-Chips). Diese Datei liefert
/// beide Welten: [AppChip]/[LevelBadge]/[LevelDot]/[FnChip]/[LvlBar] (rund)
/// und [StructureDot] (quadratisch, radius 1.5).

// ---------------------------------------------------------------------------
// .chip
// ---------------------------------------------------------------------------

enum AppChipVariant { neutral, ok, warn, bad, ki, accent }

/// `.chip` (theme.css:347–362): Pill, 500 12/1, surface-3.
/// `.ki` ist transparent mit Hairline — der KI-Ton bleibt bewusst leise.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.icon,
    this.variant = AppChipVariant.neutral,
    this.mini = false,
    this.squared = false,
    this.onTap,
  });

  final String label;

  /// Vorangestelltes Zeichen (KIND_ICONS, ✦, ＋ …) — Text, kein IconData.
  final String? icon;
  final AppChipVariant variant;

  /// `.chip.mini`: 10.5px, Padding 2/6.5.
  final bool mini;

  /// Eckige Variante (radius-sm statt Pill) für Struktur-/Datei-Chips —
  /// Konvention QUADRATISCH = Struktur.
  final bool squared;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final (Color fg, Color bg, Color borderColor) = switch (variant) {
      AppChipVariant.neutral => (t.ink2, t.surface3, Colors.transparent),
      AppChipVariant.ok => (t.good, t.goodSoft, Colors.transparent),
      AppChipVariant.warn => (t.warn, t.warnSoft, Colors.transparent),
      AppChipVariant.bad => (t.bad, t.badSoft, Colors.transparent),
      AppChipVariant.ki => (t.ki, Colors.transparent, t.border),
      AppChipVariant.accent => (t.accentInk, t.accentSoft, Colors.transparent),
    };

    final chip = Container(
      padding: mini
          ? const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 9.5, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(
          squared ? BookClothTokens.radiusSm : BookClothTokens.radiusPill,
        ),
      ),
      child: Text(
        icon == null ? label : '$icon $label',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: AppFonts.ui,
          fontFamilyFallback: AppFonts.fallback,
          fontWeight: FontWeight.w500,
          fontSize: mini ? 10.5 : 12,
          height: 1,
          color: fg,
        ),
      ),
    );

    if (onTap == null) return chip;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: chip),
    );
  }
}

// ---------------------------------------------------------------------------
// Beleg-Stufen (Levels 0–3)
// ---------------------------------------------------------------------------

/// Icons + Labels der drei Stufen (js/levels.js:16–20).
const Map<int, ({String icon, String label, String desc})> kLevelInfo = {
  1: (
    icon: '✦',
    label: 'vermutet',
    desc: 'Nur KI-Analyse — Fundstelle vermutet, nichts nachgewiesen',
  ),
  2: (
    icon: '❝',
    label: 'Original',
    desc: 'Originalpassage (Zitat) liegt vor — Position noch offen',
  ),
  3: (
    icon: '✓',
    label: 'belegt',
    desc: 'Position gesichert: Seite im PDF bzw. Fundstelle bestätigt',
  ),
};

/// `.lvl-badge` (theme.css:365–375): RUNDE Pill 600 11/1 mit ✦/❝/✓.
/// Level 0 → „offen" mit leerem Punkt und 60% Deckkraft (Levels.badge).
class LevelBadge extends StatelessWidget {
  const LevelBadge(this.level, {super.key});

  final int level;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final info = kLevelInfo[level];

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 3.5),
      decoration: BoxDecoration(
        color: t.lvlSoft(level) ?? Colors.transparent,
        borderRadius: BorderRadius.circular(BookClothTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (info == null) ...[LevelDot(0), const SizedBox(width: 5)],
          Text(
            info == null ? 'offen' : '${info.icon} ${info.label}',
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontFamilyFallback: AppFonts.fallback,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              height: 1,
              letterSpacing: .01 * 11,
              color: t.lvl(level) ?? t.ink2,
            ),
          ),
        ],
      ),
    );

    if (info == null) return Opacity(opacity: .6, child: badge);
    return Tooltip(message: info.desc, child: badge);
  }
}

/// `.lvl-dot`: 7×7 RUND; Level 0 = leerer Ring (inset 1.5 border-strong).
/// [ringColor] legt den Markierungsfarb-Ring um den Punkt (`Levels.dot`:
/// `box-shadow: 0 0 0 2.5px <farbe>55`).
class LevelDot extends StatelessWidget {
  const LevelDot(this.level, {super.key, this.ringColor, this.size = 7});

  final int level;
  final Color? ringColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final fill = t.lvl(level);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill ?? Colors.transparent,
        border: fill == null
            ? Border.all(color: t.borderStrong, width: 1.5)
            : null,
        boxShadow: ringColor == null
            ? null
            : [
                BoxShadow(
                  color: ringColor!.withValues(alpha: 1 / 3),
                  spreadRadius: 2.5,
                ),
              ],
      ),
    );
  }
}

/// `.lvl-bar` (theme.css:560): 5px-Pill mit Segmenten belegt/Original/
/// vermutet (Reihenfolge l3·l2·l1 wie `Levels.bar`), Rest bleibt surface-3.
class LvlBar extends StatelessWidget {
  const LvlBar({
    super.key,
    required this.l1,
    required this.l2,
    required this.l3,
    required this.total,
    this.minWidth = 60,
  });

  final int l1, l2, l3, total;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final divisor = total < 1 ? 1 : total;
    return Tooltip(
      message:
          'belegt: $l3 · Original: $l2 · vermutet: $l1 · offen: ${total - l1 - l2 - l3}',
      child: LayoutBuilder(
        builder: (context, box) => ConstrainedBox(
          // Als Flex-Kind ohne Stretch (unbegrenzte Breite, z. B. in einer
          // Row nach einem Spacer) rendert die CSS-Vorlage die Leiste exakt
          // `min-width` breit (theme.css:560) — die Segment-Row braucht
          // dafür eine endliche Breite.
          constraints: box.maxWidth.isFinite
              ? BoxConstraints(minWidth: minWidth)
              : BoxConstraints.tightFor(width: minWidth),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 5,
              child: ColoredBox(
                color: t.surface3,
                child: Row(
                  children: [
                    if (l3 > 0)
                      Expanded(
                        flex: l3,
                        child: ColoredBox(color: t.lvl3),
                      ),
                    if (l2 > 0)
                      Expanded(
                        flex: l2,
                        child: ColoredBox(color: t.lvl2),
                      ),
                    if (l1 > 0)
                      Expanded(
                        flex: l1,
                        child: ColoredBox(color: t.lvl1),
                      ),
                    if (divisor - l1 - l2 - l3 > 0)
                      Expanded(
                        flex: divisor - l1 - l2 - l3,
                        child: const SizedBox.shrink(),
                      ),
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

// ---------------------------------------------------------------------------
// Fußnoten-Chip
// ---------------------------------------------------------------------------

/// `.fn-chip` (theme.css:381–405): Mono 600 10.5/1 auf surface-2, radius 6,
/// Status-Punkt 6×6 in Stufenfarbe (lv0 = leerer Ring). [srcShort] blendet
/// den Quellen-Kurznamen ein (`.fns`, UI 500, max ~13ch).
/// [mini] = Lesemodus-Variante: nackt, 10px, accent-ink, Punkt 5×5, ohne fns.
class FnChip extends StatefulWidget {
  const FnChip(
    this.num, {
    super.key,
    this.level = 0,
    this.srcShort,
    this.mini = false,
    this.onTap,
    this.tooltip,
  });

  final int num;
  final int level;
  final String? srcShort;
  final bool mini;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  State<FnChip> createState() => _FnChipState();
}

class _FnChipState extends State<FnChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final mini = widget.mini;
    final dotFill = t.lvl(widget.level);

    final chip = Container(
      padding: mini
          ? const EdgeInsets.symmetric(horizontal: 3)
          : const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
      decoration: BoxDecoration(
        color: _hover
            ? t.accentSoft
            : mini
            ? Colors.transparent
            : t.surface2,
        border: Border.all(
          color: !mini && _hover
              ? t.accentLine
              : mini
              ? Colors.transparent
              : t.border,
        ),
        borderRadius: BorderRadius.circular(mini ? 4 : 6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status-Punkt `.fnl` — RUND, weil Belegstatus.
          Container(
            width: mini ? 5 : 6,
            height: mini ? 5 : 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotFill ?? Colors.transparent,
              border: dotFill == null
                  ? Border.all(color: t.muted, width: 1.3)
                  : null,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${widget.num}',
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontFamilyFallback: AppFonts.fallback,
              fontWeight: FontWeight.w600,
              fontSize: mini ? 10 : 10.5,
              height: 1,
              color: mini
                  ? t.accentInk
                  : _hover
                  ? t.accentInk
                  : t.ink2,
            ),
          ),
          if (!mini && widget.srcShort != null) ...[
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 84),
              child: Text(
                widget.srcShort!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontFamilyFallback: AppFonts.fallback,
                  fontWeight: FontWeight.w500,
                  fontSize: 10.5,
                  height: 1,
                  color: t.ink2,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    Widget result = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(onTap: widget.onTap, child: chip),
    );
    if (widget.tooltip != null) {
      result = Tooltip(message: widget.tooltip!, child: result);
    }
    return result;
  }
}

// ---------------------------------------------------------------------------
// Struktur-Punkt (QUADRATISCH)
// ---------------------------------------------------------------------------

/// Quadratischer Struktur-/Datei-Punkt (z. B. `.ref-src .dot`: 8×8,
/// border-radius 1.5) — bewusst NICHT rund: Struktur, kein Belegstatus.
class StructureDot extends StatelessWidget {
  const StructureDot({super.key, this.color, this.size = 8});

  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? t.accent,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}
