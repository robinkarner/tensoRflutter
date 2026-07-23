import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'buttons.dart';

/// Modal-System — Pendant zu `U.modal`/`U.closeModal` (util.js:647–667).
///
/// Es gibt immer maximal EIN Modal (kein Stapeln): Öffnet ein Aufrufer ein
/// neues, wird ein evtl. offenes zuerst geschlossen — dessen Cleanup-Hook
/// (Pendant zu `U._modalCleanup`) läuft dabei ab. Geschlossen wird per
/// ✕-Knopf, Backdrop-Klick oder Escape.
///
/// Optik (theme.css:512–532): Backdrop Schwarz 34% + Blur 3px, Panel oben
/// zentriert (7vh Kopffreiheit), Breite min(780px, 100%), max-height 84vh,
/// popIn-Animation (.14s, überschwingende Kurve).

/// Das aktuell offene Modal (Ein-Modal-Semantik).
_AppModalRoute<Object?>? _activeModal;

/// Öffnet das App-Modal. [onClose] ist der Cleanup-Hook und läuft bei JEDEM
/// Schließweg (✕, Backdrop, Esc, Ersatz durch ein neues Modal, programmatisch).
/// [maxWidth] deckt Sonderbreiten ab (Notebook-Editor: 1180). Bei
/// [scrollableBody] false verwaltet der Body seinen Scroll selbst.
Future<T?> showAppModal<T>(
  BuildContext context, {
  required Widget title,
  required Widget body,
  VoidCallback? onClose,
  double maxWidth = 780,
  bool scrollableBody = true,
}) {
  closeAppModal();
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = _AppModalRoute<T>(
    title: title,
    body: body,
    maxWidth: maxWidth,
    scrollableBody: scrollableBody,
  );
  _activeModal = route;
  return navigator.push(route).whenComplete(() {
    if (identical(_activeModal, route)) _activeModal = null;
    onClose?.call();
  });
}

/// Schließt das offene Modal (falls vorhanden) — Pendant zu `U.closeModal`.
void closeAppModal() {
  final route = _activeModal;
  _activeModal = null;
  if (route == null || !route.isActive) return;
  if (route.isCurrent) {
    route.navigator?.pop();
  } else {
    route.navigator?.removeRoute(route);
  }
}

class _AppModalRoute<T> extends RawDialogRoute<T> {
  _AppModalRoute({
    required Widget title,
    required Widget body,
    required double maxWidth,
    required bool scrollableBody,
  }) : super(
          barrierDismissible: true,
          barrierLabel: 'Schließen',
          // Backdrop: color-mix(#000 34%, transparent); der Blur liegt im Page-
          // Builder, damit er App UND Barriere gemeinsam weichzeichnet.
          barrierColor: const Color(0x57000000),
          transitionDuration: const Duration(milliseconds: 140),
          pageBuilder: (context, animation, secondaryAnimation) =>
              _AppModalScaffold(
            title: title,
            body: body,
            maxWidth: maxWidth,
            scrollableBody: scrollableBody,
          ),
          transitionBuilder: (context, animation, _, child) {
            // popIn: opacity 0→1, translateY(6px)→0, scale .99→1 mit leicht
            // überschwingender Kurve cubic-bezier(.2,.9,.3,1.1).
            final curved = CurvedAnimation(
              parent: animation,
              curve: const Cubic(.2, .9, .3, 1.1),
            );
            return FadeTransition(
              opacity: animation,
              child: AnimatedBuilder(
                animation: curved,
                child: child,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, 6 * (1 - curved.value)),
                  child: Transform.scale(
                    scale: .99 + .01 * curved.value,
                    child: child,
                  ),
                ),
              ),
            );
          },
        );
}

class _AppModalScaffold extends StatelessWidget {
  const _AppModalScaffold({
    required this.title,
    required this.body,
    required this.maxWidth,
    required this.scrollableBody,
  });

  final Widget title;
  final Widget body;
  final double maxWidth;
  final bool scrollableBody;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final screen = MediaQuery.sizeOf(context);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
      child: Align(
        alignment: Alignment.topCenter,
        // Inhalt oben zentriert: padding 7vh 18px 18px.
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, screen.height * .07, 18, 18),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: screen.height * .84,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(boxShadow: t.shadowPop),
              child: Material(
                color: t.surface,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(BookClothTokens.radius),
                  side: BorderSide(color: t.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(t),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 15, 18, 18),
                        child: scrollableBody
                            ? SingleChildScrollView(child: body)
                            : body,
                      ),
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

  /// Kopfzeile `.modal-h`: Titel (h3, 15.5px) + ✕ als Ghost-Button.
  Widget _header(BookClothTokens t) => Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 11),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: DefaultTextStyle.merge(
                style: AppTextStyles.h3.copyWith(fontSize: 15.5, color: t.ink),
                child: title,
              ),
            ),
            const SizedBox(width: 10),
            const AppButton(
              variant: AppButtonVariant.ghost,
              small: true,
              tooltip: 'Schließen',
              onPressed: closeAppModal,
              child: Text('✕'),
            ),
          ],
        ),
      );
}
