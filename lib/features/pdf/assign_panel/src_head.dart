/// Einheitlicher Quellen-Kopf + Kategorie-Tags — Ports von `U.srcHeadHtml`
/// (util.js:469-480) und `U.srcTags`/`srcTagsHtml` (util.js:483-498):
/// Chips (Art · Jahr · id · ＋ manuell), Titel in Serif 19.5px, darunter
/// Autoren · DOI; Tags (venue/publisher/oa/paywall/problem) max [max],
/// Label auf 46 Zeichen gekürzt.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/color_mix.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/chips.dart';
import '../../../data/bundles/kind_labels.dart';
import '../../../data/models/models.dart';
import 'src_kv.dart';

/// `.src-head`: Chips-Zeile · Serif-Titel · Autor/DOI-Unterzeile.
class SrcHead extends StatelessWidget {
  const SrcHead({super.key, required this.source, this.compact = false});

  final Source source;

  /// `.src-head.compact`: Titel 15.5px statt 19.5px.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final s = source;
    final kindIcon = kindIcons[s.kind] ?? '';
    final kindLabel = kindLabels[s.kind] ?? (s.kind.isNotEmpty ? s.kind : 'Quelle');

    // Unterzeile: Autor (bzw. longTitle, wenn weder Autor noch DOI) · DOI.
    final authorPart = s.author ??
        ((s.author == null && s.doi == null && s.longTitle != null) ? s.longTitle : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppChip(label: '$kindIcon $kindLabel'.trim()),
            if (s.year != null) AppChip(label: '${s.year}'),
            Text(s.id, style: AppTextStyles.mono.copyWith(fontSize: 12.5, color: t.ink2)),
            if (s.custom) const AppChip(label: '＋ manuell', variant: AppChipVariant.warn),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          s.title.isNotEmpty ? s.title : s.id,
          style: TextStyle(
            fontFamily: AppFonts.serif,
            fontFamilyFallback: AppFonts.fallback,
            fontSize: compact ? 15.5 : 19.5,
            height: 1.35,
            fontWeight: FontWeight.w600,
            color: t.ink,
          ),
        ),
        if (authorPart != null || s.doi != null) ...[
          const SizedBox(height: 3),
          Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (authorPart != null)
                Text(authorPart, style: AppTextStyles.small.copyWith(color: t.muted)),
              if (authorPart != null && s.doi != null)
                Text('·', style: AppTextStyles.small.copyWith(color: t.muted)),
              if (s.doi != null)
                Tooltip(
                  message: 'DOI öffnen',
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => launchUrl(Uri.parse('https://doi.org/${s.doi}'),
                          mode: LaunchMode.externalApplication),
                      child: Text(
                        'DOI ${s.doi}',
                        style: AppTextStyles.small.copyWith(color: t.accentInk),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Ein Kategorie-Tag der Quelle.
class SrcTag {
  /// 'venue' | 'publisher' | 'oa' | 'paywall' | 'problem'.
  final String cat;
  final String label;

  const SrcTag({required this.cat, required this.label});
}

/// Tags aus Quelle + Recherche-Metadaten ableiten (util.js:483-494).
List<SrcTag> srcTagsFor(Source s, FileSearchInfo? fsr) {
  final tags = <SrcTag>[];
  final venue = fsr?.venue ?? s.container;
  if (venue != null && venue.isNotEmpty) {
    tags.add(SrcTag(cat: 'venue', label: 'veröffentlicht: $venue'));
  }
  if (fsr?.publisher != null && fsr!.publisher!.isNotEmpty) {
    tags.add(SrcTag(cat: 'publisher', label: 'Publisher: ${fsr.publisher}'));
  }
  if (fsr?.openAccess == true) tags.add(const SrcTag(cat: 'oa', label: 'Open Access'));
  if (fsr?.openAccess == false) tags.add(const SrcTag(cat: 'paywall', label: 'Paywall'));
  if (fsr?.problem != null && fsr!.problem!.isNotEmpty) {
    tags.add(SrcTag(cat: 'problem', label: '⚠ ${fsr.problem}'));
  }
  return tags;
}

/// `.stag` (app.css:1401-1412): kleines farbiges Tag; Basiston 13-15 % der
/// Tag-Farbe, Border 38-40 %, Ink je Theme aus den Tag-Tokens.
class SrcTagChip extends StatelessWidget {
  const SrcTagChip(this.tag, {super.key});

  final SrcTag tag;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final (Color base, Color ink, double bgPct, double borderPct) = switch (tag.cat) {
      'venue' => (t.tagVenue, t.tagVenueInk, 13, 38),
      'publisher' => (t.tagPublisher, t.tagPublisherInk, 13, 38),
      'oa' => (t.tagOa, t.tagOaInk, 15, 40),
      'paywall' => (t.tagPaywall, t.tagPaywallInk, 14, 40),
      _ => (t.warn, t.warn, 0, 40), // problem: warn-soft + warn
    };
    final label =
        tag.label.length > 46 ? '${tag.label.substring(0, 45)}…' : tag.label;

    return Tooltip(
      message: tag.label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: tag.cat == 'problem' ? t.warnSoft : base.alphaPct(bgPct),
          border: Border.all(color: base.alphaPct(borderPct)),
          borderRadius: BorderRadius.circular(BookClothTokens.radiusPill),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontFamilyFallback: AppFonts.fallback,
            fontWeight: FontWeight.w600,
            fontSize: 11,
            height: 1.35,
            color: ink,
          ),
        ),
      ),
    );
  }
}
