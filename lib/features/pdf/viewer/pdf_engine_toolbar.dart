/// `.pe-bar` — die Viewer-Toolbar (pdfengine.js:867-887, app.css:887-904):
/// Seiten-Gruppe (‹ · Nummern-Input „/ N" · ›) · Zoom-Gruppe (− ⤢% ＋) ·
/// Suche (pe-q + Info) · Modus-Gruppe (✥ Markieren / 💬 Kommentar, entfällt
/// bei viewOnly) · Aktiv-Anzeige rechtsbündig.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../marks/mark_overlay.dart';

/// Der aktive Beleg des Studios (opts.getActive-Ergebnis, Dossier 05 §7).
class ActiveBeleg {
  final int fn;

  /// Farb-KEY der Beleg-Palette (nicht Hex).
  final String? farbe;
  final String? label;

  const ActiveBeleg({required this.fn, this.farbe, this.label});
}

class PdfEngineToolbar extends StatelessWidget {
  const PdfEngineToolbar({
    super.key,
    required this.page,
    required this.pageCount,
    required this.pageInput,
    required this.zoomPercent,
    required this.searchController,
    required this.searchFocus,
    required this.searchInfo,
    required this.viewOnly,
    required this.mode,
    required this.active,
    required this.warnNoActive,
    required this.onPrev,
    required this.onNext,
    required this.onPageSubmitted,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
    required this.onSearch,
    required this.onSearchCleared,
    required this.onMode,
  });

  final int page;
  final int pageCount;
  final TextEditingController pageInput;
  final int zoomPercent;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final String searchInfo;
  final bool viewOnly;

  /// 'select' | 'comment'.
  final String mode;
  final ActiveBeleg? active;

  /// Warnung „Kein Beleg aktiv — …" nach fehlgeschlagener Auswahl.
  final bool warnNoActive;

  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<int> onPageSubmitted;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;
  final ValueChanged<String> onSearch;
  final VoidCallback onSearchCleared;
  final ValueChanged<String> onMode;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        // pe-q: width clamp(210px, 32cqw, 380px).
        final qWidth = (constraints.maxWidth * .32).clamp(210.0, 380.0);
        return Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _grp(t, tooltip:
                      'Endlos-Scroll: einfach durchscrollen — die Seitenzahl folgt; '
                      '‹/› bzw. ←/→ springen zum Seitenanfang', children: [
                    AppButton(
                      small: true,
                      tooltip: 'Zur vorherigen Seite springen (←)',
                      onPressed: onPrev,
                      child: const Text('‹'),
                    ),
                    _pageNum(t),
                    AppButton(
                      small: true,
                      tooltip: 'Zur nächsten Seite springen (→)',
                      onPressed: onNext,
                      child: const Text('›'),
                    ),
                  ]),
                  _grp(t, tooltip: 'Zoom — auch mit + / −', children: [
                    AppButton(
                      small: true,
                      tooltip: 'Verkleinern (−)',
                      onPressed: onZoomOut,
                      child: const Text('−'),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 66),
                      child: AppButton(
                        small: true,
                        tooltip: 'Auf Breite einpassen (0)',
                        onPressed: onFit,
                        child: Text(
                          '⤢ $zoomPercent%',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                    AppButton(
                      small: true,
                      tooltip: 'Vergrößern (+)',
                      onPressed: onZoomIn,
                      child: const Text('＋'),
                    ),
                  ]),
                  _grp(t,
                      tooltip:
                          'Volltextsuche im PDF — Enter springt zur nächsten Trefferseite',
                      last: viewOnly,
                      children: [
                        SizedBox(width: qWidth, child: _searchField(t)),
                        if (searchInfo.isNotEmpty)
                          Text(searchInfo,
                              style: AppTextStyles.small.copyWith(color: t.muted)),
                      ]),
                  if (!viewOnly)
                    _grp(t, last: true, children: [
                      _modeButton(t, 'select', '✥ Markieren',
                          'Text auswählen → Markierung + Zitat in den aktiven Beleg'),
                      _modeButton(t, 'comment', '💬 Kommentar',
                          'Klick platziert einen Kommentar-Pin'),
                    ]),
                ],
              ),
            ),
            if (!viewOnly) ...[
              const SizedBox(width: 8),
              Flexible(child: _activeInfo(t)),
            ],
          ],
        );
      }),
    );
  }

  /// `.pe-grp`: Inline-Gruppe mit border-right als Trenner.
  Widget _grp(BookClothTokens t,
      {String? tooltip, bool last = false, required List<Widget> children}) {
    final row = Container(
      padding: EdgeInsets.only(right: last ? 0 : 8),
      decoration: last
          ? null
          : BoxDecoration(border: Border(right: BorderSide(color: t.border))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            children[i],
          ],
        ],
      ),
    );
    return tooltip == null ? row : Tooltip(message: tooltip, child: row);
  }

  /// `.pe-pagenum`: Zahlen-Input (54 px, Mono 12) + „/ N".
  Widget _pageNum(BookClothTokens t) {
    final style = TextStyle(
      fontFamily: AppFonts.mono,
      fontFamilyFallback: AppFonts.fallback,
      fontWeight: FontWeight.w600,
      fontSize: 12,
      height: 1,
      color: t.ink2,
    );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 54,
        child: TextField(
          controller: pageInput,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: style,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BookClothTokens.radiusXs),
              borderSide: BorderSide(color: t.borderStrong),
            ),
          ),
          onSubmitted: (v) {
            final n = int.tryParse(v);
            if (n != null && n >= 1 && n <= pageCount) onPageSubmitted(n);
          },
        ),
      ),
      const SizedBox(width: 4),
      Text('/ $pageCount', style: style),
    ]);
  }

  Widget _searchField(BookClothTokens t) => TextField(
        controller: searchController,
        focusNode: searchFocus,
        style: AppTextStyles.form.copyWith(fontSize: 13.5, color: t.ink),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'im PDF suchen …',
          hintStyle: AppTextStyles.form.copyWith(fontSize: 13.5, color: t.muted),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
            borderSide: BorderSide(color: t.borderStrong),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
            borderSide: BorderSide(color: t.accent),
          ),
        ),
        onSubmitted: onSearch,
        onChanged: (v) {
          if (v.isEmpty) onSearchCleared();
        },
      );

  /// `.pe-mode` — aktiver Modus in accent-soft.
  Widget _modeButton(BookClothTokens t, String value, String label, String tip) {
    final on = mode == value;
    return Tooltip(
      message: tip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => onMode(value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: on ? t.accentSoft : t.surface,
              border: Border.all(color: on ? t.accentLine : t.borderStrong),
              borderRadius: BorderRadius.circular(BookClothTokens.radiusXs),
            ),
            child: Text(
              label,
              style: AppTextStyles.button.copyWith(
                fontSize: 13,
                color: on ? t.accentInk : t.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// `.pe-active` — rechtsbündige Beleg-Anzeige (pdfengine.js:899-905, 1216).
  Widget _activeInfo(BookClothTokens t) {
    if (warnNoActive) {
      return Text(
        'Kein Beleg aktiv — links einen Beleg wählen, dann auswählen.',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: AppTextStyles.small.copyWith(color: t.warn),
      );
    }
    final a = active;
    if (a == null) {
      return Text(
        'kein Beleg aktiv — links einen wählen',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: AppTextStyles.small.copyWith(color: t.muted),
      );
    }
    return Text.rich(
      TextSpan(children: [
        const TextSpan(text: 'aktiv: '),
        TextSpan(
          text: '[${a.fn}]',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: a.farbe != null ? markColorOf(a.farbe) : t.warn,
          ),
        ),
        const TextSpan(text: ' — Auswahl im Text wird diesem Beleg zugeordnet'),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
      style: AppTextStyles.small.copyWith(color: t.muted),
    );
  }
}
