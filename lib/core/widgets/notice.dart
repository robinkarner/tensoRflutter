import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// `.notice` (theme.css:484–494): ruhige Hinweisfläche mit Farbleiste statt
/// bunter Boxen — surface-2, Hairline, 3px-Leiste links, 13.5px in ink-2.
/// Varianten: warn (Default) · info (Akzent) · ki (Schieferblau).
enum NoticeVariant { warn, info, ki }

class Notice extends StatelessWidget {
  const Notice({
    super.key,
    required this.child,
    this.variant = NoticeVariant.warn,
  });

  /// Meist ein [Text]; Stil (13.5, ink-2) wird hier gesetzt.
  final Widget child;
  final NoticeVariant variant;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final stripe = switch (variant) {
      NoticeVariant.warn => t.warn,
      NoticeVariant.info => t.accent,
      NoticeVariant.ki => t.ki,
    };

    // Rundung + ungleiche Borders vertragen sich in Flutter nicht in EINER
    // BoxDecoration — daher: Clip + innere Farbleiste, Hairline als
    // foregroundDecoration obendrauf.
    //
    // IntrinsicHeight: die Farbleiste soll die volle Notice-Höhe füllen
    // (CrossAxisAlignment.stretch). Ohne Höhenmessung wirft das in
    // unbegrenzten Höhen-Kontexten (Column/ScrollView) „BoxConstraints
    // forces an infinite height“ — Gate-2-Fix zentral hier statt an jeder
    // Nutzstelle (Welle-2-Restpunkt K-2/1).
    return IntrinsicHeight(
      child: Container(
        foregroundDecoration: BoxDecoration(
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
          child: ColoredBox(
            color: t.surface2,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ColoredBox(color: stripe, child: const SizedBox(width: 3)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
                    child: DefaultTextStyle.merge(
                      style: AppTextStyles.small.copyWith(color: t.ink2),
                      child: child,
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
