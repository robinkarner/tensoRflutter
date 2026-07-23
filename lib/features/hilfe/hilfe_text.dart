/// Rich-Text-Bausteine der Hilfe-Seite: <b>/<code>/<kbd>-Pendants als
/// InlineSpans plus der Karten-Rahmen. Die Hilfe rendert lange Fließtexte
/// mit eingestreuten Code-/Tasten-Chips — diese Helfer halten die
/// Karten-Dateien lesbar.
library;

import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/eyebrow.dart';

/// `<b>` — 700 in Fließtextfarbe.
TextSpan hb(String text) =>
    TextSpan(text: text, style: const TextStyle(fontWeight: FontWeight.w700));

/// `<i>` — kursiv.
TextSpan hi(String text) =>
    TextSpan(text: text, style: const TextStyle(fontStyle: FontStyle.italic));

/// `<code>` (theme.css:296): mono auf surface-3 — als Inline-Hintergrund.
TextSpan hcode(BuildContext context, String text) {
  final t = BookClothTokens.of(context);
  return TextSpan(
    text: text,
    style: TextStyle(
      fontFamily: AppFonts.mono,
      fontFamilyFallback: AppFonts.fallback,
      fontSize: 12,
      color: t.ink2,
      background: Paint()..color = t.surface3,
    ),
  );
}

/// `<kbd>` (theme.css:576-580): Tasten-Chip mono 600 10.5 mit Hairline.
InlineSpan hkbd(BuildContext context, String text) {
  final t = BookClothTokens.of(context);
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
      decoration: BoxDecoration(
        color: t.surface2,
        border: Border.all(color: t.borderStrong),
        borderRadius: BorderRadius.circular(BookClothTokens.radiusXs),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppFonts.mono,
          fontFamilyFallback: AppFonts.fallback,
          fontWeight: FontWeight.w600,
          fontSize: 10.5,
          height: 1,
          color: t.ink2,
        ),
      ),
    ),
  );
}

/// Externer Link (`<a target="_blank">`) — accent-ink, unterstrichen.
InlineSpan hlink(BuildContext context, String label, VoidCallback onTap) {
  final t = BookClothTokens.of(context);
  return WidgetSpan(
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          label,
          style: AppTextStyles.small.copyWith(
            color: t.accentInk,
            decoration: TextDecoration.underline,
            decorationColor: t.accentLine,
          ),
        ),
      ),
    ),
  );
}

/// `.card` der Hilfe-Seite mit `.eyebrow`-Überzeile (theme.css:306-312).
class HilfeCard extends StatelessWidget {
  const HilfeCard({super.key, required this.eyebrow, required this.children});

  final String eyebrow;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(BookClothTokens.radius),
        boxShadow: t.shadow1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(alignment: Alignment.centerLeft, child: Eyebrow(eyebrow)),
          ...children,
        ],
      ),
    );
  }
}

/// `.hilfe-tab` (app.css:1336-1338): 13px, th versal 11px mit starker
/// Unterlinie, td mit gestrichelter Unterlinie, Zeilenhöhe 1.55 —
/// horizontal scrollbar eingebettet (`overflow-x:auto`).
class HilfeTable extends StatelessWidget {
  const HilfeTable({super.key, required this.headers, required this.rows});

  final List<String> headers;

  /// Zellen als fertige Widgets (meist Text.rich).
  final List<List<Widget>> rows;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    // Mindestbreite 640, damit die Tabelle auf schmalen Viewports horizontal
    // scrollt statt zu quetschen (`overflow-x:auto`-Pendant); die Flex-
    // Spalten brauchen eine ENDLICHE Breite, daher LayoutBuilder + SizedBox.
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth.isFinite && box.maxWidth > 640 ? box.maxWidth : 640.0;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: w,
          child: Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.top,
          columnWidths: {
            for (var i = 0; i < headers.length; i++)
              i: const FlexColumnWidth(),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: t.borderStrong)),
              ),
              children: [
                for (final h in headers)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 6, 10, 6),
                    child: Text(
                      h.toUpperCase(),
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontFamilyFallback: AppFonts.fallback,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        letterSpacing: .04 * 11,
                        color: t.muted,
                      ),
                    ),
                  ),
              ],
            ),
            for (final row in rows)
              TableRow(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: t.border,
                      style: BorderStyle.solid,
                    ),
                  ),
                ),
                children: [
                  for (final cell in row)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 10, 8),
                      child: cell,
                    ),
                ],
              ),
          ],
          ),
        ),
      );
    });
  }
}
