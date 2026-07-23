/// Topbar — Pendant zu `header.topbar` (index.html:22-52, app.css:9-67):
/// Marke (TS-Badge + „Thesis Studio / Quellen- & Belegarbeit“) · Hauptnav
/// (Studio/Quellen/Status/Hilfe/Wissen, „Wissen“ in der eigenen Farbwelt) ·
/// Aktionen (Generate GPT · 🔍 Suchen · ▤ PDF Dokument · 🗄 Speicher ·
/// 🗂 Arbeiten-Wechsler · ◐ Theme).
///
/// Die beiden Dropdown-Anker (#worksPop/#gptPop) sind hier als
/// Overlay-Popovers gebaut — gegenseitig exklusiv, Outside-Klick schließt,
/// Routenwechsel schließt (app.js:103-138). Der works-pop-Inhalt ist das
/// Arbeiten-Menü (K-2, [WorksMenuCard]); der gpt-pop-Inhalt ist der
/// Generate-GPT-Hub (K-3, [GptHubCard] = `Enhance.hub`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/repos/project_repository.dart';
import '../../features/ai/ai.dart';
import '../../features/projekt/arbeiten/works_menu.dart';
import '../../features/quellen/store_modal/store_modal.dart';
import '../router/routes.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/buttons.dart';
import 'cmdk.dart';
import 'theme_controller.dart';

part 'topbar.g.dart';

/// Ab dieser Breite tragen die Aktions-Buttons Text-Labels; darunter nur
/// Icons (`@media (max-width: 760px)`, app.css:64-68).
const double _kLabelBreakpoint = 760;

class Topbar extends ConsumerStatefulWidget {
  const Topbar({super.key, required this.location});

  /// Aktuelle Router-Location — steuert die Active-Markierung der Nav und
  /// schließt bei Wechsel die Popovers.
  final String location;

  @override
  ConsumerState<Topbar> createState() => _TopbarState();
}

class _TopbarState extends ConsumerState<Topbar> {
  final _worksCtl = OverlayPortalController();
  final _gptCtl = OverlayPortalController();
  final _worksBtnKey = GlobalKey();
  final _gptBtnKey = GlobalKey();

  @override
  void didUpdateWidget(Topbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Routenwechsel: beide Popovers schließen — der Kontext wird beim
    // nächsten Öffnen frisch abgeleitet (app.js:138).
    if (oldWidget.location != widget.location) {
      _worksCtl.hide();
      _gptCtl.hide();
    }
  }

  /// Öffnen des einen schließt das andere (app.js:107/123).
  void _toggle(OverlayPortalController ctl, OverlayPortalController other) {
    other.hide();
    ctl.toggle();
  }

  /// Position des Buttons in Overlay-(=globalen)Koordinaten — Grundlage der
  /// Popover-Verankerung (die Topbar sitzt fix oben, daher stabil).
  Rect _buttonRect(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return Rect.zero;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final showLabels = MediaQuery.sizeOf(context).width > _kLabelBreakpoint;
    final view = Routes.viewOf(widget.location);

    return Container(
      height: BookClothTokens.topbarH,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Row(
        spacing: 14,
        children: [
          const _Brand(),
          Expanded(child: _MainNav(view: view)),
          _buildActions(t, showLabels),
        ],
      ),
    );
  }

  Widget _buildActions(BookClothTokens t, bool showLabels) {
    return Row(
      spacing: 6,
      children: [
        // ✦ Generate GPT (magic-top) + gpt-pop-Anker
        OverlayPortal(
          controller: _gptCtl,
          overlayChildBuilder: (context) => _GptPopover(
            anchor: _buttonRect(_gptBtnKey),
            groupId: _gptCtl,
            onDismiss: _gptCtl.hide,
            location: widget.location,
          ),
          child: TapRegion(
            groupId: _gptCtl,
            child: KeyedSubtree(
              key: _gptBtnKey,
              child: Tooltip(
                message: 'Generate GPT — alle KI-Funktionen an einem Ort: '
                    'direkt ausführen, Prompt kopieren, Antwort einfügen, Konzept',
                child: MagicButton(
                  label: 'Generate GPT',
                  variant: MagicVariant.top,
                  onPressed: () => _toggle(_gptCtl, _worksCtl),
                ),
              ),
            ),
          ),
        ),

        // 🔍 Suchen → Command-Palette
        _ActionButton(
          icon: '🔍',
          label: 'Suchen',
          showLabel: showLabels,
          tooltip: 'Suchen und springen (Strg/⌘ K)',
          onPressed: () => openCmdk(context),
        ),

        // ▤ PDF Dokument → #/doc
        _ActionButton(
          icon: '▤',
          label: 'PDF Dokument',
          showLabel: showLabels,
          tooltip: 'PDF Dokument: die ganze Arbeit als EIN Dokument — '
              'komplettes LaTeX generieren oder als PDF drucken',
          onPressed: () => context.go(Routes.doc),
        ),

        // 🗄 Speicher → storeModal (S-4, features/quellen/store_modal)
        _ActionButton(
          icon: '🗄',
          label: 'Speicher',
          showLabel: showLabels,
          tooltip: 'Quellen- & Dateispeicher: alle Quellen + nicht zugeordnete '
              'Dateien, zuweisen & Quelle aus Datei erstellen',
          onPressed: () => showStoreModal(context),
        ),

        // 🗂 Arbeiten-Wechsler + works-pop-Anker
        OverlayPortal(
          controller: _worksCtl,
          overlayChildBuilder: (context) => _WorksPopover(
            groupId: _worksCtl,
            onDismiss: _worksCtl.hide,
          ),
          child: TapRegion(
            groupId: _worksCtl,
            child: KeyedSubtree(
              key: _worksBtnKey,
              child: _WorkSwitch(
                showBody: showLabels,
                onPressed: () => _toggle(_worksCtl, _gptCtl),
              ),
            ),
          ),
        ),

        // ◐ Theme-Zyklus
        const _ThemeButton(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Marke
// ---------------------------------------------------------------------------

/// `.brand`: TS-Badge (accent, radius-xs) + zweizeiliger Namenszug —
/// Klick führt zur Startansicht `#/studio`.
class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go(Routes.studio),
        child: Row(
          spacing: 10,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: t.accent,
                borderRadius: BorderRadius.circular(BookClothTokens.radiusXs),
              ),
              child: Text(
                'TS',
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontFamilyFallback: AppFonts.fallback,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  height: 1,
                  letterSpacing: .05 * 11,
                  color: t.accentContrast,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Thesis Studio',
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontFamilyFallback: AppFonts.fallback,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    height: 1.2,
                    letterSpacing: -.01 * 13.5,
                    color: t.ink,
                  ),
                ),
                Text(
                  'Quellen- & Belegarbeit',
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontFamilyFallback: AppFonts.fallback,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    height: 1.25,
                    letterSpacing: .01 * 12,
                    color: t.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hauptnavigation
// ---------------------------------------------------------------------------

/// `.mainnav`: fünf Links, horizontal scrollbar; `.active` = surface-3 + 600.
/// „Wissen“ trägt die Sonderfarbe der Wissen-Welt (`.nav-wissen`).
class _MainNav extends StatelessWidget {
  const _MainNav({required this.view});

  final String view;

  @override
  Widget build(BuildContext context) {
    // Active-Logik wie app.js:221-222 — home/leer aktiviert „Studio“.
    bool active(String nav) =>
        nav == view || ((view == 'home' || view.isEmpty) && nav == 'studio');

    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          spacing: 1,
          children: [
            _NavLink(label: 'Studio', path: Routes.studio, active: active('studio')),
            _NavLink(label: 'Quellen', path: Routes.quellen, active: active('quellen')),
            _NavLink(label: 'Status', path: Routes.projekt, active: active('projekt')),
            _NavLink(label: 'Hilfe', path: Routes.hilfe, active: active('hilfe')),
            _NavLink(
              label: 'Wissen',
              path: Routes.analyse,
              active: active('analyse'),
              wissen: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavLink extends StatefulWidget {
  const _NavLink({
    required this.label,
    required this.path,
    required this.active,
    this.wissen = false,
  });

  final String label;
  final String path;
  final bool active;

  /// `.nav-wissen`: Schrift in wissen-ink statt ink-2 (app.css:1237).
  final bool wissen;

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final color = widget.wissen
        ? t.wissenInk
        : widget.active || _hover
            ? t.ink
            : t.ink2;
    final bg = widget.active
        ? t.surface3
        : _hover
            ? t.surface2
            : Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => context.go(widget.path),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(BookClothTokens.radiusXs),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontFamilyFallback: AppFonts.fallback,
              fontWeight: widget.active ? FontWeight.w600 : FontWeight.w500,
              fontSize: 13.5,
              height: 1,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Aktions-Buttons
// ---------------------------------------------------------------------------

/// `.btn-ghost.btn-sm.ta-btn`: Icon-Zeichen (14px) + Label (500 13px);
/// unter 760px nur das Icon.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.showLabel,
    required this.tooltip,
    required this.onPressed,
  });

  final String icon;
  final String label;
  final bool showLabel;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      variant: AppButtonVariant.ghost,
      small: true,
      tooltip: tooltip,
      onPressed: onPressed,
      child: Row(
        spacing: 6,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14, height: 1)),
          if (showLabel) Text(label),
        ],
      ),
    );
  }
}

/// `.theme-btn`: Ghost-Button mit dem Zyklus-Zeichen ◐/☀/☾ und dem
/// dynamischen Tooltip „Theme: … (klicken zum Wechseln)“.
class _ThemeButton extends ConsumerWidget {
  const _ThemeButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting =
        ref.watch(themeControllerProvider).value ?? ThemeSetting.auto;
    return AppButton(
      variant: AppButtonVariant.ghost,
      small: true,
      tooltip: setting.tooltip,
      onPressed: () => ref.read(themeControllerProvider.notifier).cycle(),
      child: SizedBox(
        width: 18,
        child: Text(
          setting.icon,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, height: 1),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Arbeiten-Wechsler
// ---------------------------------------------------------------------------

/// `.work-switch` (app.css:50-63): beschriftete Bar mit 🗂, Eyebrow „Arbeit“,
/// dem NAMEN der aktiven Arbeit (max. 46 Zeichen, app.js:49) und ▾-Caret.
class _WorkSwitch extends ConsumerStatefulWidget {
  const _WorkSwitch({required this.showBody, required this.onPressed});

  final bool showBody;
  final VoidCallback onPressed;

  @override
  ConsumerState<_WorkSwitch> createState() => _WorkSwitchState();
}

class _WorkSwitchState extends ConsumerState<_WorkSwitch> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final title = ref.watch(activeWorkTitleProvider);
    final display = title.length > 46 ? title.substring(0, 46) : title;

    return Tooltip(
      message: 'Aktive Arbeit wechseln, neue aus .tex anlegen, '
          'Gesamt-Prompt / Analysen / Export',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            constraints: BoxConstraints(maxWidth: widget.showBody ? 280 : 64),
            padding: widget.showBody
                ? const EdgeInsets.fromLTRB(10, 5, 11, 5)
                : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _hover ? t.surface3 : t.surface2,
              border: Border.all(color: _hover ? t.accent : t.borderStrong),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              spacing: widget.showBody ? 9 : 5,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🗂', style: TextStyle(fontSize: 16, height: 1)),
                if (widget.showBody)
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ARBEIT',
                          style: TextStyle(
                            fontFamily: AppFonts.display,
                            fontFamilyFallback: AppFonts.fallback,
                            fontWeight: FontWeight.w700,
                            fontSize: 9.5,
                            height: 1.3,
                            letterSpacing: .09 * 9.5,
                            color: t.muted,
                          ),
                        ),
                        Tooltip(
                          message: title,
                          child: Text(
                            display,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppFonts.ui,
                              fontFamilyFallback: AppFonts.fallback,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              height: 1.25,
                              color: t.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Text('▾', style: TextStyle(fontSize: 10, height: 1, color: t.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Anzeigename der aktiven Arbeit (app.js:46-49): Meta-Titel, außer er ist
/// leer oder „Unbenannte Arbeit“ — dann der Projekt-Name. Vor Boot-Ende
/// steht wie im HTML der Platzhalter „…“.
@Riverpod(keepAlive: true)
String activeWorkTitle(Ref ref) {
  final boot = ref.watch(projectBootProvider).value;
  if (boot == null) return '…';
  final metaTitle = boot.runtime.thesis.meta.title;
  if (metaTitle.isNotEmpty && metaTitle != 'Unbenannte Arbeit') return metaTitle;
  return boot.activeName.isNotEmpty ? boot.activeName : 'Arbeit';
}

// ---------------------------------------------------------------------------
// Popover-Anker (#worksPop / #gptPop)
// ---------------------------------------------------------------------------

/// `.works-pop` (app.css:1259): rechtsbündig unter den Topbar-Aktionen,
/// Breite min(560px, 94vw), max-height 72vh. Inhalt = die
/// Arbeiten-Verwaltung (K-2, `projektArbeitenCard`-Pendant).
class _WorksPopover extends StatelessWidget {
  const _WorksPopover({required this.groupId, required this.onDismiss});

  final Object groupId;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final width = screen.width * .94 < 560 ? screen.width * .94 : 560.0;

    return Positioned(
      top: BookClothTokens.topbarH + 8,
      right: 16,
      width: width,
      child: _PopoverCard(
        groupId: groupId,
        onDismiss: onDismiss,
        maxHeight: screen.height * .72,
        child: WorksMenuCard(onDismiss: onDismiss),
      ),
    );
  }
}

/// `.gpt-pop` (app.css:1871): bündig unter dem GPT-Knopf, Breite
/// min(540px, 94vw), gegen den rechten Viewport-Rand geklemmt (8px Abstand,
/// app.js:126-131). Inhalt = der Generate-GPT-Hub (K-3, `Enhance.hub`);
/// die gp-list scrollt selbst, der gp-foot bleibt stehen.
class _GptPopover extends StatelessWidget {
  const _GptPopover({
    required this.anchor,
    required this.groupId,
    required this.onDismiss,
    required this.location,
  });

  final Rect anchor;
  final Object groupId;
  final VoidCallback onDismiss;
  final String location;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final width = screen.width * .94 < 540 ? screen.width * .94 : 540.0;
    // Klemmung: ragt der rechte Rand über innerWidth-8, wird left reduziert.
    var left = anchor.left;
    final over = (left + width) - (screen.width - 8);
    if (over > 0) left -= over;
    if (left < 8) left = 8;

    return Positioned(
      top: anchor.bottom + 8,
      left: left,
      width: width,
      child: _PopoverCard(
        groupId: groupId,
        onDismiss: onDismiss,
        maxHeight: screen.height * .72,
        radius: 12,
        scrollable: false,
        child: GptHubCard(location: location, onDismiss: onDismiss),
      ),
    );
  }
}

/// Gemeinsame Popover-Karte: surface, Hairline, Pop-Schatten; Outside-Klick
/// schließt (TapRegion-Gruppe umfasst Button UND Karte).
class _PopoverCard extends StatelessWidget {
  const _PopoverCard({
    required this.groupId,
    required this.onDismiss,
    required this.child,
    required this.maxHeight,
    this.radius = BookClothTokens.radius,
    this.scrollable = true,
  });

  final Object groupId;
  final VoidCallback onDismiss;
  final Widget child;
  final double maxHeight;
  final double radius;

  /// false = der Inhalt verwaltet seinen Scroll selbst (GPT-Hub: gp-list
  /// scrollt, gp-foot bleibt stehen).
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return TapRegion(
      groupId: groupId,
      onTapOutside: (_) => onDismiss(),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(boxShadow: t.shadowPop),
          child: Material(
            color: t.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
              side: BorderSide(color: t.border),
            ),
            child: scrollable ? SingleChildScrollView(child: child) : child,
          ),
        ),
      ),
    );
  }
}
