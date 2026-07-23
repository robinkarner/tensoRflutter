/// Modus-Leiste — Pendant zu `studioBar` (:147-185) und `.studio-bar` /
/// `.mode-switch` / `.dichte-switch` (app.css:291-337).
///
/// Sticky oben in der Inhaltsspalte (im Flutter-Layout: fix ÜBER dem
/// Scrollbereich — nichts springt beim Umschalten). Links das Segmented
/// ☰ Lesen · ◉ Analyse · ✎ LaTeX (Links auf `#/studio/<id>/<modus>`;
/// vor der Navigation wird der Scrollstand gesichert), in der Mitte (nur
/// Lesen) die Dichte-Leiste Normal/Kompakt/🖍/⚡, rechts `bar-tools` (leer —
/// im Original ebenso: alle KI-Funktionen leben im GPT-Hub der Topbar).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/color_mix.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import 'studio_state.dart';

/// Sichtbare Modus-Labels (`Studio.MODES`, :17 — W4: Label „◉ Analyse“,
/// interner Name `pruefen`).
const Map<String, String> studioModeLabels = {
  'lesen': '☰ Lesen',
  'pruefen': '◉ Analyse',
  'editor': '✎ LaTeX',
};

class StudioModeBar extends ConsumerWidget {
  const StudioModeBar({super.key, required this.sectionId, required this.mode});

  final String sectionId;
  final String mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final prefs = ref.watch(studioPrefsCtlProvider).value ?? StudioPrefs.defaults;

    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.fromLTRB(2, 9, 2, 8),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        // color-mix(bg 92%, transparent) — der Blur entfällt, weil die Leiste
        // hier nicht überlappt, sondern fix über dem Scrollbereich sitzt.
        color: t.bg.alphaPct(92),
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _ModeSwitch(sectionId: sectionId, active: mode),
          if (mode == 'lesen') _DichteSwitch(prefs: prefs),
          // bar-tools (rechts) — im Original leer (:160).
        ],
      ),
    );
  }
}

/// `.mode-switch`: Segmented Control auf surface-3-Track.
class _ModeSwitch extends ConsumerWidget {
  const _ModeSwitch({required this.sectionId, required this.active});

  final String sectionId;
  final String active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final dark = t.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: dark ? t.bgDeep : t.surface3,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in studioModeLabels.entries)
            _ModeTab(
              label: e.value,
              selected: e.key == active,
              onTap: () {
                if (e.key == active) return;
                // Scrollstand sichern übernimmt StudioWorkspace beim
                // Moduswechsel (didUpdateWidget) — hier nur navigieren.
                context.go(Routes.studioPath(sec: sectionId, modus: e.key));
              },
            ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatefulWidget {
  const _ModeTab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ModeTab> createState() => _ModeTabState();
}

class _ModeTabState extends State<_ModeTab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final dark = t.brightness == Brightness.dark;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: widget.selected
                ? (dark ? t.surface3 : t.surface)
                : _hover
                    ? t.surface2.alphaPct(60)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: widget.selected && !dark
                ? const [
                    BoxShadow(
                      offset: Offset(0, 1),
                      blurRadius: 2,
                      color: Color(0x14000000),
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontFamilyFallback: AppFonts.fallback,
              fontSize: 14,
              height: 1,
              fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
              color: widget.selected ? t.ink : t.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

/// `.dichte-switch` (nur Lesen): Normal · Kompakt · 🖍 · ⚡.
class _DichteSwitch extends ConsumerWidget {
  const _DichteSwitch({required this.prefs});

  final StudioPrefs prefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctl = ref.read(studioPrefsCtlProvider.notifier);
    return Tooltip(
      message: 'Textdichte',
      child: Wrap(
        spacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _DichteButton(
            label: 'Normal',
            on: prefs.dichte == 'normal',
            onTap: () => ctl.setDichte('normal'),
          ),
          _DichteButton(
            label: 'Kompakt',
            on: prefs.dichte == 'kompakt',
            onTap: () => ctl.setDichte('kompakt'),
          ),
          _DichteButton(
            label: '🖍',
            on: prefs.lesenMarks,
            tooltip: '🖍 Markierungen im Lesen-Modus dezent ein-/ausblenden',
            onTap: ctl.toggleLesenMarks,
          ),
          _DichteButton(
            label: '⚡',
            on: prefs.fast,
            tooltip:
                '⚡ Schnelllese-Anstrich: Markierungen voll ausgemalt — auch hier im Lesen-Modus',
            onTap: ctl.toggleFast,
          ),
        ],
      ),
    );
  }
}

class _DichteButton extends StatefulWidget {
  const _DichteButton({
    required this.label,
    required this.on,
    required this.onTap,
    this.tooltip,
  });

  final String label;
  final bool on;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  State<_DichteButton> createState() => _DichteButtonState();
}

class _DichteButtonState extends State<_DichteButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final btn = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: widget.on
                ? t.accentSoft
                : _hover
                    ? t.surface3
                    : Colors.transparent,
            border: Border.all(
                color: widget.on ? t.accentLine : Colors.transparent),
            borderRadius: BorderRadius.circular(BookClothTokens.radiusPill),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontFamilyFallback: AppFonts.fallback,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              height: 1,
              color: widget.on
                  ? t.accentInk
                  : _hover
                      ? t.ink
                      : t.muted,
            ),
          ),
        ),
      ),
    );
    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: btn);
    }
    return btn;
  }
}
