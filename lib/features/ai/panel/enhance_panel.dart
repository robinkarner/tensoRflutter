/// ⧈ Werkbank-Panel — Port von `Enhance.open/close` (enhance.js:368-441):
/// rechts einfahrendes Panel (`.enh-back`/`.enh-panel`), Breite
/// min(580px, 97vw), Slide `.42s cubic-bezier(.16,1,.3,1)`, Backdrop
/// `#120c07` 44 % + Blur 2px; Body-Grid 172px|1fr, ≤640px vollbreit mit
/// horizontaler Nav. Schließen (✕, Backdrop, Esc) bricht einen laufenden
/// ✦-Lauf ab (`Enhance._ctl.abort()`).
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../client/claude_cfg.dart';
import '../dock/magic_dock.dart';
import '../flows/ai_flow.dart';
import '../flows/registry.dart';
import 'access_view.dart';
import 'flow_view.dart';
import 'system_view.dart';

/// Panel öffnen; [activeId] auch `'_system'` / `'_access'`.
Future<void> openEnhancePanel(
  BuildContext context, {
  AiFlowCtx ctx = const AiFlowCtx(),
  String? activeId,
}) {
  return Navigator.of(context, rootNavigator: true)
      .push(_EnhancePanelRoute(ctx: ctx, activeId: activeId));
}

class _EnhancePanelRoute extends PopupRoute<void> {
  _EnhancePanelRoute({required this.ctx, this.activeId});

  final AiFlowCtx ctx;
  final String? activeId;

  @override
  Color? get barrierColor => null; // eigener Backdrop (Fade + Blur)

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => 'Schließen';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 420);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);

  @override
  void dispose() {
    // `Enhance.close()` bricht laufende ✦-Läufe ab (enhance.js:419).
    AiRunHandle.abort();
    super.dispose();
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    final screen = MediaQuery.sizeOf(context);
    final fullWidth = screen.width <= 640; // @media (max-width:640px)
    final width =
        fullWidth ? screen.width : (screen.width * .97).clamp(0.0, 580.0);

    final slide = CurvedAnimation(
      parent: animation,
      curve: const Cubic(.16, 1, .3, 1), // enh-panel-Transition
      reverseCurve: Curves.easeIn,
    );

    return Stack(
      children: [
        // `.enh-back`: #120c07 44 % + blur(2px), Fade .3s.
        Positioned.fill(
          child: FadeTransition(
            opacity: animation,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: const ColoredBox(color: Color(0x70120C07)),
              ),
            ),
          ),
        ),
        // `.enh-panel`: rechts, volle Höhe, Slide-in.
        Align(
          alignment: Alignment.centerRight,
          child: SlideTransition(
            position: Tween(begin: const Offset(1, 0), end: Offset.zero)
                .animate(slide),
            child: _PanelShell(
              width: width,
              child: _EnhancePanelBody(
                ctx: ctx,
                activeId: activeId,
                compactNav: fullWidth,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PanelShell extends StatefulWidget {
  const _PanelShell({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  State<_PanelShell> createState() => _PanelShellState();
}

class _PanelShellState extends State<_PanelShell> {
  final FocusNode _focus = FocusNode(debugLabel: 'enh-panel');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return FocusScope(
      autofocus: true,
      child: KeyboardListener(
        focusNode: _focus,
        onKeyEvent: (event) {
          // Esc schließt das Panel — Modale darüber fangen Esc als
          // eigene Routen vorher ab (Navigator-Stapel = Original-Regel).
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
          }
        },
        child: Container(
          width: widget.width,
          height: double.infinity,
          decoration: BoxDecoration(
            color: t.surface,
            border: Border(left: BorderSide(color: t.borderStrong)),
            boxShadow: const [
              // -26px 0 64px -22px rgba(10,8,22,.55)
              BoxShadow(
                offset: Offset(-26, 0),
                blurRadius: 64,
                spreadRadius: -22,
                color: Color(0x8C0A0816),
              ),
            ],
          ),
          child: Material(color: t.surface, child: widget.child),
        ),
      ),
    );
  }
}

class _EnhancePanelBody extends ConsumerStatefulWidget {
  const _EnhancePanelBody({
    required this.ctx,
    this.activeId,
    required this.compactNav,
  });

  final AiFlowCtx ctx;
  final String? activeId;
  final bool compactNav;

  @override
  ConsumerState<_EnhancePanelBody> createState() => _EnhancePanelBodyState();
}

class _EnhancePanelBodyState extends ConsumerState<_EnhancePanelBody> {
  late String _active = widget.activeId ?? 'all';

  @override
  Widget build(BuildContext context) {
    watchAiSources(ref);
    final container = ProviderScope.containerOf(context, listen: false);
    final flows = buildAiFlows(container, widget.ctx);
    final cfg = ref.watch(claudeCfgStoreProvider).value ?? ClaudeCfg.defaults;
    final acc = aiAccessInfo(cfg);

    final Widget main = switch (_active) {
      '_system' => EnhanceSystemView(
          ctx: widget.ctx,
          onOpenFlow: (id) => setState(() => _active = id),
        ),
      '_access' => const EnhanceAccessView(),
      _ => EnhanceFlowView(
          // Flow-Wechsel setzt die Ansicht komplett neu auf (Textarea etc.).
          key: ValueKey('enhflow|$_active'),
          ctx: widget.ctx,
          flowId: _active,
        ),
    };

    final nav = _Nav(
      flows: flows,
      active: _active,
      horizontal: widget.compactNav,
      onSelect: (id) => setState(() => _active = id),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Head(
          acc: acc,
          onStatus: () => setState(() => _active = '_access'),
          onClose: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: widget.compactNav
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    nav,
                    Expanded(child: _mainScroll(main)),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 172, child: nav),
                    Expanded(child: _mainScroll(main)),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _mainScroll(Widget main) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        child: main,
      );
}

// ---------------------------------------------------------------------------
// Kopf (`.enh-head`) — Ember-Basis mit Glut-Glows (app.css:2028-2037)
// ---------------------------------------------------------------------------

class _Head extends StatelessWidget {
  const _Head({required this.acc, required this.onStatus, required this.onClose});

  final AiAccessInfo acc;
  final VoidCallback onStatus;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A160D), Color(0xFF180D08)],
        ),
      ),
      child: Stack(
        children: [
          // Glut-Glows (Radial-Overlays der Magic-Signatur).
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-.85, -1.4),
                  radius: 1.35,
                  colors: [Color(0x80D66028), Color(0x00D66028)],
                  stops: [0, .56],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(1.08, -1.1),
                  radius: 1.2,
                  colors: [Color(0x4DF09148), Color(0x00F09148)],
                  stops: [0, .52],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(.2, 2.6),
                  radius: 1,
                  colors: [Color(0x578A2F1D), Color(0x008A2F1D)],
                  stops: [0, .62],
                ),
              ),
            ),
          ),
          // Topline: linear-gradient(90deg, transparent, rgba(255,214,170,.45), transparent).
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 1,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [
                  Color(0x00FFD6AA),
                  Color(0x73FFD6AA),
                  Color(0x00FFD6AA),
                ]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GPT Magic',
                        style: TextStyle(
                          fontFamily: AppFonts.display,
                          fontFamilyFallback: AppFonts.fallback,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          height: 1.1,
                          letterSpacing: -.01 * 17,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Opacity(
                        opacity: .82,
                        child: Text(
                          // CSS rendert die Unterzeile uppercase.
                          'KI-Werkbank · LaTeX ist Ground Truth'.toUpperCase(),
                          style: TextStyle(
                            fontFamily: AppFonts.ui,
                            fontFamilyFallback: AppFonts.fallback,
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                            height: 1.3,
                            letterSpacing: .06 * 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _StatusPill(acc: acc, onTap: onStatus),
                const SizedBox(width: 8),
                // `.enh-x`
                _HeadIconButton(label: '✕', onTap: onClose),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `.enh-status` — Zugangs-Pille im Kopf (Punktfarben wie im Magic-Menü).
class _StatusPill extends StatefulWidget {
  const _StatusPill({required this.acc, required this.onTap});

  final AiAccessInfo acc;
  final VoidCallback onTap;

  @override
  State<_StatusPill> createState() => _StatusPillState();
}

class _StatusPillState extends State<_StatusPill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final dotColor = switch (widget.acc.dot) {
      AiAccessDot.on => const Color(0xFF9FD48A),
      AiAccessDot.demo => const Color(0xFFF0B45C),
      AiAccessDot.off => const Color(0x73FFFFFF),
    };
    return Tooltip(
      message:
          'Zugangs-Status — klicken für die drei Wege (extern · eigener Key · AI-Space)',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _hover ? const Color(0x3DFFFFFF) : const Color(0x21FFFFFF),
              border: Border.all(color: const Color(0x33FFFFFF)),
              borderRadius: BorderRadius.circular(BookClothTokens.radiusPill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: dotColor),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.acc.label,
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontFamilyFallback: AppFonts.fallback,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    height: 1,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeadIconButton extends StatefulWidget {
  const _HeadIconButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_HeadIconButton> createState() => _HeadIconButtonState();
}

class _HeadIconButtonState extends State<_HeadIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hover ? const Color(0x47FFFFFF) : const Color(0x26FFFFFF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(fontSize: 14, height: 1, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Navigation (`.enh-nav`, gruppiert nach Scope + System)
// ---------------------------------------------------------------------------

class _Nav extends StatelessWidget {
  const _Nav({
    required this.flows,
    required this.active,
    required this.horizontal,
    required this.onSelect,
  });

  final List<AiFlow> flows;
  final String active;
  final bool horizontal;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final ganze = [for (final f in flows) if (f.scope == 'Ganze Arbeit') f];
    final abschnitt =
        [for (final f in flows) if (f.scope == 'Dieser Abschnitt') f];

    final items = <Widget>[
      if (!horizontal && ganze.isNotEmpty) _group(t, 'Ganze Arbeit'),
      for (final f in ganze) _item(t, f.id, f.icon, f.title),
      if (!horizontal && abschnitt.isNotEmpty) _group(t, 'Dieser Abschnitt'),
      for (final f in abschnitt) _item(t, f.id, f.icon, f.title),
      if (!horizontal) _group(t, 'System'),
      _item(t, '_system', '⧈', 'Datenflüsse'),
      _item(t, '_access', '🔑', 'Zugang'),
    ];

    if (horizontal) {
      // ≤640px: Nav horizontal oben (app.css:2109-2115).
      return Container(
        decoration: BoxDecoration(
          color: t.surface2,
          border: Border(bottom: BorderSide(color: t.border)),
        ),
        padding: const EdgeInsets.all(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(spacing: 4, children: items),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: t.surface2,
        border: Border(right: BorderSide(color: t.border)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 16),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: items),
      ),
    );
  }

  Widget _group(BookClothTokens t, String label) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontFamilyFallback: AppFonts.fallback,
            fontWeight: FontWeight.w700,
            fontSize: 10,
            height: 1,
            letterSpacing: .09 * 10,
            color: t.muted,
          ),
        ),
      );

  Widget _item(BookClothTokens t, String id, String icon, String title) =>
      _NavItem(
        icon: icon,
        title: title,
        active: id == active,
        onTap: () => onSelect(id),
      );
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.icon,
    required this.title,
    required this.active,
    required this.onTap,
  });

  final String icon;
  final String title;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final active = widget.active;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: active
                ? t.surface
                : _hover
                    ? t.surface3
                    : Colors.transparent,
            border: Border.all(color: active ? t.accent : Colors.transparent),
            borderRadius: BorderRadius.circular(9),
            boxShadow: active ? t.shadow1 : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.icon, style: const TextStyle(fontSize: 15, height: 1)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontFamilyFallback: AppFonts.fallback,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.2,
                    color: active || _hover ? t.ink : t.ink2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
