/// Fußzeile — Pendant zu `footer.footer` (index.html:55-58, app.css:79-84):
/// Flex space-between mit Umbruch, 12px in muted, Hairline oben,
/// Padding 14/24/24. Links: Produkt-Claim; rechts: vier Bereichs-Links
/// mit ·-Trennern.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/routes.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final muted = AppTextStyles.small.copyWith(fontSize: 12, color: t.muted);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 6,
        spacing: 14,
        children: [
          Text(
            'Thesis Studio — KI-gestützte Quellen- und Belegarbeit für '
            'wissenschaftliche Arbeiten',
            style: muted,
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const _FooterLink('Bibliothek', Routes.quellen),
              Text(' · ', style: muted),
              const _FooterLink('Status', Routes.projekt),
              Text(' · ', style: muted),
              const _FooterLink('Wissen', Routes.analyse),
              Text(' · ', style: muted),
              const _FooterLink('Hilfe', Routes.hilfe),
            ],
          ),
        ],
      ),
    );
  }
}

/// Link im globalen `a`-Stil (theme.css:293): accent-ink, keine Unterstreichung.
class _FooterLink extends StatelessWidget {
  const _FooterLink(this.label, this.path);

  final String label;
  final String path;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go(path),
        child: Text(
          label,
          style: AppTextStyles.small.copyWith(fontSize: 12, color: t.accentInk),
        ),
      ),
    );
  }
}
