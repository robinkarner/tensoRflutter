/// `.pe-ocr.on-page` — die Leiste auf Scan-Seiten ohne Textebene
/// (app.css:1653-1665). OCR selbst entfällt in dieser Version (E3):
/// an der Original-Position steht der Hinweis statt des 🔍-Buttons.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';

class PdfOcrHintBar extends StatelessWidget {
  const PdfOcrHintBar({super.key, required this.page});

  final int page;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Opacity(
      opacity: .96,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: t.warnSoft,
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
          boxShadow: t.shadow1,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '⚠ S. $page: kein Textlayer (Scan?)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.small.copyWith(fontSize: 12.5, color: t.warn),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'OCR in dieser Version nicht verfügbar',
              style: AppTextStyles.small.copyWith(fontSize: 12.5, color: t.warn),
            ),
          ],
        ),
      ),
    );
  }
}
