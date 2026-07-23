import 'package:flutter/material.dart';

import '../theme/color_mix.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Button-Bausteine des Book-Cloth-Systems.
///
/// [AppButton] deckt `.btn` / `.btn-primary` / `.btn-ghost` (+ `.btn-sm`)
/// pixelgenau ab — inklusive Hover-/Active-Flächen und der 45%-Dämpfung im
/// deaktivierten Zustand.
///
/// [MagicButton] ist der ikonische BLOCK-Knopf des Magic-Systems („wie ein
/// altes Spielmenü", app.css:1767–1826): EINE flache Farbe, dicke dunkle
/// Kante, harter Sockel-Schatten (0 Blur), Baloo 2. Klick drückt den Block
/// in den Sockel; beim Kochen pulsiert die Helligkeit; das Finale ist ein
/// grün eingespielter, sich zeichnender ✓-Haken.

// ---------------------------------------------------------------------------
// .btn-Familie
// ---------------------------------------------------------------------------

enum AppButtonVariant {
  /// `.btn`: surface + border-strong.
  solid,

  /// `.btn-primary`: Akzent-Füllung, 600.
  primary,

  /// `.btn-ghost`: transparent, ink-2.
  ghost,
}

class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.child,
    this.onPressed,
    this.variant = AppButtonVariant.solid,
    this.small = false,
    this.tooltip,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;

  /// `.btn-sm`: Padding 5/10, 13px, radius-xs.
  final bool small;
  final String? tooltip;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final enabled = widget.onPressed != null;

    // Zustandsfarben je Variante (theme.css:325–345).
    final (Color bg, Color fg, Color borderColor) = switch (widget.variant) {
      AppButtonVariant.solid => (
          _pressed
              ? t.surface3
              : _hover
                  ? t.surface2
                  : t.surface,
          t.ink,
          _hover ? t.ink.alphaPct(26) : t.borderStrong,
        ),
      AppButtonVariant.primary => (
          _hover || _pressed ? t.accentStrong : t.accent,
          t.accentContrast,
          _hover || _pressed ? t.accentStrong : t.accent,
        ),
      AppButtonVariant.ghost => (
          _hover || _pressed ? t.surface3 : Colors.transparent,
          _hover ? t.ink : t.ink2,
          Colors.transparent,
        ),
    };

    final style = AppTextStyles.button.copyWith(
      color: fg,
      fontSize: widget.small ? 13 : 14,
      fontWeight: widget.variant == AppButtonVariant.primary
          ? FontWeight.w600
          : FontWeight.w500,
    );

    Widget button = Opacity(
      // [disabled]: opacity .45.
      opacity: enabled ? 1 : .45,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = _pressed = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: widget.small
                ? const EdgeInsets.symmetric(horizontal: 10, vertical: 5)
                : const EdgeInsets.symmetric(horizontal: 13, vertical: 7.5),
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(widget.small
                  ? BookClothTokens.radiusXs
                  : BookClothTokens.radiusSm),
            ),
            child: DefaultTextStyle.merge(
              style: style,
              child: IconTheme.merge(
                data: IconThemeData(color: fg, size: widget.small ? 14 : 16),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }
    return button;
  }
}

// ---------------------------------------------------------------------------
// Magic-Familie
// ---------------------------------------------------------------------------

/// Die drei Erscheinungsformen des Block-Knopfs.
enum MagicVariant {
  /// `.magic-main` (Magic-Dock): 13px, min-width 121, Preis-Slot rechts.
  main,

  /// `.magic-top` (GPT-Hub in der Topbar): 13.5px, Padding 7/12.
  top,

  /// `.ai-magic` (Dialog): min-height 54, Hauptzeile 15.5 + Mono-Subzeile.
  dialog,
}

/// Lebenszyklus beim „Kochen".
enum MagicPhase { idle, busy, done }

class MagicButton extends StatefulWidget {
  const MagicButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = MagicVariant.main,
    this.phase = MagicPhase.idle,
    this.price,
    this.priceLive = false,
    this.sub,
    this.unset = false,
    this.compact = false,
  });

  final String label;

  /// Auch im Busy-Zustand aktiv — Klick während des Kochens = Abbruch.
  final VoidCallback? onPressed;
  final MagicVariant variant;
  final MagicPhase phase;

  /// Preis-Slot-Text (`.mm-price`, nur [MagicVariant.main]) — z. B. „0.33 €"
  /// oder „einrichten →"; beim Kochen der Live-Token-Zähler.
  final String? price;

  /// `.mm-price.live`: hellerer Slot während des Token-Zählens.
  final bool priceLive;

  /// Subzeile (`.aim-sub`, nur [MagicVariant.dialog]) — Kosten/Modell.
  final String? sub;

  /// Kein Zugang & Demo aus: entsättigt, Preis-Slot als Einrichten-Link.
  final bool unset;

  /// `.magic-dock.compact`: engere Leisten (11.5px, Padding 6/9).
  final bool compact;

  @override
  State<MagicButton> createState() => _MagicButtonState();
}

class _MagicButtonState extends State<MagicButton>
    with SingleTickerProviderStateMixin {
  bool _hover = false;
  bool _pressed = false;

  /// mmCook: brightness 1↔1.09, 1.2s, endlos.
  late final AnimationController _cook =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void initState() {
    super.initState();
    _syncCook();
  }

  @override
  void didUpdateWidget(MagicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase) _syncCook();
  }

  void _syncCook() {
    if (widget.phase == MagicPhase.busy) {
      _cook.repeat(reverse: true);
    } else {
      _cook.stop();
      _cook.value = 0;
    }
  }

  @override
  void dispose() {
    _cook.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final busy = widget.phase == MagicPhase.busy;
    final dialog = widget.variant == MagicVariant.dialog;

    // Beim Drücken sinkt der Block um 3px in den Sockel (Schatten → 0).
    final pressedDown = _pressed && widget.onPressed != null;

    final labelStyle = TextStyle(
      fontFamily: AppFonts.magic,
      fontFamilyFallback: AppFonts.magicFallbackChain,
      fontWeight: FontWeight.w500,
      color: BookClothTokens.magicText,
      height: dialog ? 1.15 : 1,
      fontSize: switch (widget.variant) {
        MagicVariant.main => widget.compact ? 11.5 : 13,
        MagicVariant.top => 13.5,
        MagicVariant.dialog => 15.5,
      },
      letterSpacing: switch (widget.variant) {
        MagicVariant.main => .015 * 13,
        MagicVariant.top => .02 * 13.5,
        MagicVariant.dialog => .015 * 15.5,
      },
    );

    final padding = switch (widget.variant) {
      MagicVariant.main => widget.compact
          ? const EdgeInsets.symmetric(horizontal: 9, vertical: 6)
          : const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      MagicVariant.top => const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      MagicVariant.dialog =>
        const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    };

    Widget content = switch (widget.variant) {
      MagicVariant.dialog => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.label, style: labelStyle, overflow: TextOverflow.ellipsis),
                  if (widget.sub != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Opacity(
                        opacity: .92,
                        child: Text(
                          widget.sub!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppFonts.mono,
                            fontFamilyFallback: AppFonts.fallback,
                            fontWeight: FontWeight.w500,
                            fontSize: 11.5,
                            height: 1.2,
                            color: BookClothTokens.magicText,
                            // .unset: Subzeile ist der Einrichten-Link.
                            decoration: widget.unset
                                ? TextDecoration.underline
                                : TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      _ => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ),
            if (widget.price != null) ...[
              SizedBox(width: widget.variant == MagicVariant.top ? 7 : 8),
              _PriceSlot(
                text: widget.price!,
                live: widget.priceLive,
                underline: widget.unset,
              ),
            ],
          ],
        ),
    };

    final radius = BorderRadius.circular(dialog ? 8 : 6);

    Widget block = AnimatedBuilder(
      animation: _cook,
      builder: (context, child) {
        // Helligkeit: Hover 1.05 · Active .95 · Kochen 1↔1.09 (als weißer/
        // schwarzer Farb-Schleier statt echtem CSS-Filter).
        double brightness = 1;
        if (busy && !reduceMotion) brightness = 1 + .09 * _cook.value;
        if (_hover && !busy) brightness = 1.05;
        if (pressedDown) brightness = .95;
        return Container(
          constraints: BoxConstraints(
            minWidth: switch (widget.variant) {
              MagicVariant.main => widget.compact ? 125 : 121,
              _ => 0,
            },
            minHeight: dialog ? 54 : 0,
          ),
          padding: padding,
          transform: Matrix4.translationValues(0, pressedDown ? 3 : 0, 0),
          decoration: BoxDecoration(
            color: busy && dialog ? null : t.magicTop,
            // .ai-magic.busy: grauer Verlauf statt Orange.
            gradient: busy && dialog
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      BookClothTokens.magicBusyA,
                      BookClothTokens.magicBusyB,
                    ],
                  )
                : null,
            border: Border.all(color: t.magicEdge, width: 2),
            borderRadius: radius,
            // Harter Sockel-Schatten: 0 3px 0 Kante (0 Blur!); gedrückt → 0.
            boxShadow: pressedDown || (busy && dialog)
                ? const []
                : [BoxShadow(offset: const Offset(0, 3), color: t.magicEdge)],
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: radius,
            color: brightness >= 1
                ? Colors.white.withValues(alpha: (brightness - 1))
                : Colors.black.withValues(alpha: (1 - brightness)),
          ),
          child: child,
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          content,
          // ✓-Finale: grüne Fläche poppt ein, der Haken zeichnet sich.
          if (widget.phase == MagicPhase.done)
            Positioned.fill(
              child: _MagicCheck(reduceMotion: reduceMotion, radius: radius),
            ),
        ],
      ),
    );

    // .unset: grayscale(.55) saturate(.55) — via Sättigungs-Matrix.
    if (widget.unset && !busy) {
      block = ColorFiltered(
        colorFilter: ColorFilter.matrix(_saturationMatrix(_hover ? .6 : .42)),
        child: block,
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = _pressed = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: block,
      ),
    );
  }
}

/// `.mm-price`: eingelassener Preis-Slot (Mono 600 9.5, dunkle Mulde).
class _PriceSlot extends StatelessWidget {
  const _PriceSlot({required this.text, required this.live, required this.underline});

  final String text;
  final bool live;
  final bool underline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: live ? const Color(0x801E0802) : const Color(0x571E0802),
        border: Border.all(color: const Color(0x4D000000)),
        borderRadius: BorderRadius.circular(5),
        boxShadow: const [
          // inset-Schatten oben ist in Flutter nicht direkt möglich — die
          // helle Unterkante (0 1px 0 white .22) trägt den „Mulden"-Eindruck.
          BoxShadow(offset: Offset(0, 1), color: Color(0x38FFFFFF)),
        ],
      ),
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(
          fontFamily: AppFonts.mono,
          fontFamilyFallback: AppFonts.fallback,
          fontWeight: FontWeight.w600,
          fontSize: 9.5,
          height: 1,
          letterSpacing: .04 * 9.5,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: live
              ? BookClothTokens.magicPriceLiveText
              : BookClothTokens.magicPriceText,
          decoration: underline ? TextDecoration.underline : TextDecoration.none,
        ),
      ),
    );
  }
}

/// `.mm-check`: mmCheckIn (Pop .24s, überschwingend) + mmDraw (Haken .38s,
/// Verzögerung .14s). Bei reduzierter Bewegung steht beides sofort.
class _MagicCheck extends StatelessWidget {
  const _MagicCheck({required this.reduceMotion, required this.radius});

  final bool reduceMotion;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final pop = TweenAnimationBuilder<double>(
      tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: const Cubic(.34, 1.56, .64, 1),
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0, 1),
        child: Transform.scale(scale: .6 + .4 * v, child: child),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: BookClothTokens.magicCheckBg,
          borderRadius: radius,
        ),
        alignment: Alignment.center,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
          duration: const Duration(milliseconds: 520), // .14s Delay + .38s Zug
          builder: (context, v, _) {
            // Delay nachbilden: erst ab 27% der Laufzeit beginnt der Strich.
            final draw = ((v - .27) / .73).clamp(0.0, 1.0);
            return CustomPaint(
              size: const Size(16, 16),
              painter: _CheckPainter(draw),
            );
          },
        ),
      ),
    );
    return pop;
  }
}

/// Der SVG-Haken `M4.5 12.8 L9.5 17.8 L19.5 6.8` (viewBox 24), weiß, 3.2
/// rund — gezeichnet über Pfadlängen-Anteil [progress].
class _CheckPainter extends CustomPainter {
  const _CheckPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final s = size.width / 24;
    final path = Path()
      ..moveTo(4.5 * s, 12.8 * s)
      ..lineTo(9.5 * s, 17.8 * s)
      ..lineTo(19.5 * s, 6.8 * s);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white;
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Sättigungs-Matrix für den `.unset`-Filter (grayscale+saturate-Emulation).
List<double> _saturationMatrix(double s) {
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final sr = (1 - s) * lr, sg = (1 - s) * lg, sb = (1 - s) * lb;
  return [
    sr + s, sg, sb, 0, 0,
    sr, sg + s, sb, 0, 0,
    sr, sg, sb + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}
