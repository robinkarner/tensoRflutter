import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/color_mix.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Bild-Lightbox (app.css:153–155): Vollbild-Overlay auf bg-deep 88% mit
/// Blur 8px; das Bild liegt auf `--fig-bg-pop` (immer hell) mit 12px Rand,
/// max 94vw × 88vh. Klick irgendwo schließt (cursor: zoom-out); optionale
/// Bildunterschrift fix am unteren Rand. Einblendung: fadeIn .13s.
Future<void> showLightbox(
  BuildContext context, {
  required Widget image,
  String? caption,
}) {
  return Navigator.of(context, rootNavigator: true).push(PageRouteBuilder(
    opaque: false,
    transitionDuration: const Duration(milliseconds: 130),
    reverseTransitionDuration: const Duration(milliseconds: 130),
    pageBuilder: (context, animation, secondaryAnimation) =>
        _Lightbox(image: image, caption: caption),
    transitionsBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  ));
}

class _Lightbox extends StatelessWidget {
  const _Lightbox({required this.image, this.caption});

  final Widget image;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final screen = MediaQuery.sizeOf(context);

    return MouseRegion(
      cursor: SystemMouseCursors.zoomOut,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            color: t.bgDeep.alphaPct(88),
            padding: const EdgeInsets.all(30),
            child: Stack(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: screen.width * .94,
                      maxHeight: screen.height * .88,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: t.figBgPop,
                        borderRadius:
                            BorderRadius.circular(BookClothTokens.radius),
                        boxShadow: t.shadowPop,
                      ),
                      child: image,
                    ),
                  ),
                ),
                if (caption != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: -18, // 12px vom Fensterrand (30px Padding − 18)
                    child: Text(
                      caption!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.small.copyWith(
                        fontSize: 13,
                        color: t.ink2,
                      ),
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
