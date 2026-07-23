/// Linke Spalte des Referenzierungsmodus — Port von `refItem`/`markWords`
/// (views_studio.js:1755-1920) samt `.ref-side`/`.ref-src`/`.ref-item`
/// (app.css:639-671):
///
///   * `details.ref-ctx` „Absatztext“ (zugeklappt, max. 160px scroll),
///   * je Quelle eine `ref-src`-Karte: Kopf mit QUADRAT-Punkt (8×8,
///     radius 1.5 — Struktur, nicht Status!), Kürzel, Kind-Chip,
///     [LvlBar]; aktiv = Akzent-Ring + accent-soft-Kopf,
///   * darunter die Zitierelemente: Status-Punkt+[n]+Badge+Farbwahl+„✥ aktiv“,
///     Claim/Fußnotentext mit Suchwort-`mark.sw` in der Markierungsfarbe,
///     ✦-vermutet, ⧉/🔎-Chips, Zitat-Textarea, Positions-Feld (Seite ODER
///     Fundstelle je Quell-Art) + „✓ Speichern“. Fokus im Item aktiviert es.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/richtext/richtext_builder.dart';
import '../../../core/theme/color_mix.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/chips.dart';
import '../../../data/bundles/indexes.dart';
import '../../../data/models/models.dart';
import '../../../domain/levels.dart';
import '../layout/rich_resolver.dart';
import '../layout/studio_state.dart';
import '../pruefen/farb_control.dart';
import '../pruefen/paragraph_card.dart' show stripFigMarker;
import '../pruefen/search_chips.dart' show searchTerms;
import 'ref_mode.dart';

/// Suchwörter (≥4 Zeichen, längste zuerst, case-insensitive) im Text als
/// `mark.sw`-Spans hervorheben — Port von `markWords` (:1910-1920).
List<InlineSpan> markWordSpans(String text, String hinweis, Color color) {
  final words = {
    for (final w in hinweis.split(RegExp(r'\s+')))
      if (w.length >= 4) w,
  }.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  if (words.isEmpty || text.isEmpty) return [TextSpan(text: text)];
  final pattern = words.map(RegExp.escape).join('|');
  final re = RegExp('($pattern)', caseSensitive: false);
  final spans = <InlineSpan>[];
  var pos = 0;
  for (final m in re.allMatches(text)) {
    if (m.start > pos) spans.add(TextSpan(text: text.substring(pos, m.start)));
    spans.add(TextSpan(
      text: m.group(0),
      style: TextStyle(backgroundColor: color.alphaPct(28)),
    ));
    pos = m.end;
  }
  if (pos < text.length) spans.add(TextSpan(text: text.substring(pos)));
  return spans;
}

class RefSide extends ConsumerStatefulWidget {
  const RefSide({super.key, required this.screen, required this.paragraph});

  final RefModeScreenState screen;
  final Paragraph paragraph;

  @override
  ConsumerState<RefSide> createState() => _RefSideState();
}

class _RefSideState extends ConsumerState<RefSide> {
  bool _ctxOpen = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final s = widget.screen;
    final domain = ref.watch(studioDomainProvider);
    if (domain == null) return const SizedBox.shrink();

    final belege = s.belege;
    final children = <Widget>[
      // details.ref-ctx „Absatztext“
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _ctxOpen = !_ctxOpen),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Text('ABSATZTEXT',
                      style: AppTextStyles.eyebrow.copyWith(color: t.muted)),
                ),
              ),
            ),
            if (_ctxOpen)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: RichTextView(
                    stripFigMarker(widget.paragraph.text),
                    style: AppTextStyles.small
                        .copyWith(fontSize: 13, height: 1.65, color: t.ink2),
                    resolver: richResolverFor(domain),
                    options: const RichTextOptions(fnStyle: FnStyle.mini),
                  ),
                ),
              ),
          ],
        ),
      ),
    ];

    for (final id in s.srcOrder) {
      final src = ref.watch(srcByIdProvider)[id];
      final mine = [
        for (final b in belege)
          if ((b.quellen.isNotEmpty
                  ? b.quellen
                  : (domain.ctx.fnIndex[b.num]?.sources ?? const <String>[]))
              .contains(id))
            b,
      ];
      final counts = domain.levels.countsFor([for (final b in mine) b.num]);
      final active = id == s.srcId;

      children.add(Container(
        margin: const EdgeInsets.only(bottom: 10),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: active ? t.accentLine : t.border),
          borderRadius: BorderRadius.circular(BookClothTokens.radius),
          boxShadow: active
              ? [BoxShadow(color: t.accentLine, spreadRadius: 1)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // header
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => s.showSource(id),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                  decoration: BoxDecoration(
                    color: active ? t.accentSoft : null,
                    border: active
                        ? Border(bottom: BorderSide(color: t.border))
                        : null,
                  ),
                  child: Row(
                    children: [
                      // QUADRAT-Punkt (Struktur): 8×8, radius 1.5.
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active ? t.accent : t.borderStrong,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          ref.watch(srcShortProvider(id)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.small.copyWith(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: t.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AppChip(
                        mini: true,
                        label:
                            '${kindIcons[src?.kind] ?? ''} ${kindLabels[src?.kind] ?? ''}'
                                .trim(),
                      ),
                      const Spacer(),
                      LvlBar(
                        l1: counts.l1,
                        l2: counts.l2,
                        l3: counts.l3,
                        total: counts.total,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            for (final (i, b) in mine.indexed)
              RefItem(
                screen: s,
                beleg: b,
                srcId: id,
                first: i == 0,
                focused: b.num == s.activeFn,
              ),
          ],
        ),
      ));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
      children: children,
    );
  }
}

/// Ein Zitierelement (`refItem`, :1821-1907).
class RefItem extends ConsumerWidget {
  const RefItem({
    super.key,
    required this.screen,
    required this.beleg,
    required this.srcId,
    required this.first,
    required this.focused,
  });

  final RefModeScreenState screen;
  final Beleg beleg;
  final String srcId;
  final bool first;
  final bool focused;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final domain = ref.watch(studioDomainProvider);
    if (domain == null) return const SizedBox.shrink();

    final fnNum = beleg.num;
    final inf = domain.levels.info(fnNum);
    final posType = domain.levels.positionType(srcId);
    final fnText = domain.ctx.fnIndex[fnNum]?.text ?? '';
    final hex = Levels.farbHex(domain.levels.farbeFor(srcId, fnNum));
    final markColor = hex != null
        ? Color(0xFF000000 | int.parse(hex.substring(1), radix: 16))
        : const Color(0xFFE8C33F);

    return Focus(
      onFocusChange: (has) {
        // focusin (:1902-1905): Fokus im Item aktiviert es (+ Quellwechsel).
        if (has) {
          if (screen.srcId != srcId) screen.showSource(srcId);
          screen.setActive(fnNum);
        }
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: focused ? t.accentSoft : null,
          border: Border(
            top: first ? BorderSide.none : BorderSide(color: t.border),
            // `.ref-item.focus`: inset 2.5px 0 0 accent — als linke Kante.
            left: focused
                ? BorderSide(color: t.accent, width: 2.5)
                : BorderSide.none,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ri-head
            Row(
              children: [
                LevelDot(inf.level,
                    ringColor: markColor, size: 7),
                const SizedBox(width: 7),
                Text('[$fnNum]',
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontFamilyFallback: AppFonts.fallback,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: t.accentInk,
                    )),
                const SizedBox(width: 7),
                LevelBadge(inf.level),
                const SizedBox(width: 7),
                Tooltip(
                  message: 'Markierungsfarbe dieses Belegs',
                  child: FarbControl(srcId: srcId, fnNum: fnNum, size: 18),
                ),
                const Spacer(),
                _SmallBtn(
                  label: '✥ aktiv',
                  tooltip:
                      'Diesen Beleg zum Ziel der PDF-Markierung machen',
                  primary: focused,
                  onTap: () {
                    if (screen.srcId != srcId) {
                      screen.showSource(srcId, fn: fnNum);
                    }
                    screen.setActive(fnNum);
                  },
                ),
              ],
            ),
            if (beleg.claim.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                    children:
                        markWordSpans(beleg.claim, beleg.suchHinweis, markColor)),
                style: AppTextStyles.small
                    .copyWith(fontSize: 13, height: 1.55, color: t.ink),
              ),
            ],
            if (fnText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: '„'),
                  ...markWordSpans(fnText, beleg.suchHinweis, markColor),
                  const TextSpan(text: '“'),
                ]),
                style: AppTextStyles.small
                    .copyWith(fontSize: 12, height: 1.5, color: t.muted),
              ),
            ],
            if (beleg.fundstelle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: '✦ vermutet ',
                      style: TextStyle(color: t.ki)),
                  TextSpan(
                      text: beleg.fundstelle,
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: t.ki)),
                ]),
                style: AppTextStyles.small.copyWith(fontSize: 12),
              ),
            ],
            if (beleg.suchHinweis.isNotEmpty) ...[
              const SizedBox(height: 6),
              _RiSuch(screen: screen, beleg: beleg, srcId: srcId),
            ],
            const SizedBox(height: 7),
            TextField(
              controller: screen.zitatCtl(fnNum),
              maxLines: null,
              minLines: 2,
              style: AppTextStyles.small
                  .copyWith(fontSize: 12.5, height: 1.5, color: t.ink),
              decoration: _deco(t,
                  hint: 'Zitat — im PDF markieren oder hier einfügen …'),
            ),
            const SizedBox(height: 7),
            // ri-foot
            Row(
              children: [
                if (posType == 'seite') ...[
                  Text('S.',
                      style: AppTextStyles.small.copyWith(color: t.ink2)),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 70,
                    child: TextField(
                      controller: screen.posCtl(fnNum, srcId),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: AppTextStyles.small
                          .copyWith(fontSize: 12.5, color: t.ink),
                      decoration: _deco(t),
                    ),
                  ),
                  const SizedBox(width: 7),
                  _SmallBtn(
                    label: '→ Seite',
                    tooltip: 'PDF rechts auf diese Seite stellen',
                    onTap: () {
                      final v = int.tryParse(
                          screen.posCtl(fnNum, srcId).text.trim());
                      if (screen.srcId != srcId) {
                        screen.showSource(srcId, fn: fnNum);
                      }
                      screen.engine.goto(v == null || v < 1 ? 1 : v);
                    },
                  ),
                ] else
                  Expanded(
                    child: TextField(
                      controller: screen.posCtl(fnNum, srcId),
                      style: AppTextStyles.small
                          .copyWith(fontSize: 12.5, color: t.ink),
                      decoration:
                          _deco(t, hint: 'Fundstelle: Art/§ …'),
                    ),
                  ),
                const Spacer(),
                _SmallBtn(
                  label: '✓ Speichern',
                  primary: true,
                  onTap: () => screen.saveItem(fnNum, srcId),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _deco(BookClothTokens t, {String? hint}) => InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle:
            AppTextStyles.small.copyWith(fontSize: 12, color: t.muted),
        filled: true,
        fillColor: t.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: t.borderStrong),
          borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: t.accent, width: 2),
          borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
        ),
      );
}

/// ⧉-alle + 🔎-Suchchips eines Zitierelements (:1857-1871) — „⧉ alle“
/// kopiert (1s „✔“), 🔎 sucht rechts (900ms grüner Erfolgszustand).
class _RiSuch extends StatefulWidget {
  const _RiSuch({
    required this.screen,
    required this.beleg,
    required this.srcId,
  });

  final RefModeScreenState screen;
  final Beleg beleg;
  final String srcId;

  @override
  State<_RiSuch> createState() => _RiSuchState();
}

class _RiSuchState extends State<_RiSuch> {
  bool _copied = false;
  String? _okTerm;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        _chip(
          t,
          label: _copied ? '✔' : '⧉ alle',
          tooltip: 'Alle Suchbegriffe kopieren',
          bold: true,
          ok: false,
          onTap: () async {
            await Clipboard.setData(
                ClipboardData(text: widget.beleg.suchHinweis));
            if (!mounted) return;
            setState(() => _copied = true);
            Future<void>.delayed(const Duration(milliseconds: 1000), () {
              if (mounted) setState(() => _copied = false);
            });
          },
        ),
        for (final w in searchTerms(widget.beleg.suchHinweis))
          _chip(
            t,
            label: '🔎 ${w.length > 30 ? '${w.substring(0, 29)}…' : w}',
            tooltip: '„$w“ im PDF rechts suchen',
            bold: false,
            ok: _okTerm == w,
            onTap: () {
              final s = widget.screen;
              if (s.srcId != widget.srcId) {
                s.showSource(widget.srcId, fn: widget.beleg.num);
              }
              s.engine.search(w);
              setState(() => _okTerm = w);
              Future<void>.delayed(const Duration(milliseconds: 900), () {
                if (mounted) setState(() => _okTerm = null);
              });
            },
          ),
      ],
    );
  }

  Widget _chip(
    BookClothTokens t, {
    required String label,
    required String tooltip,
    required bool bold,
    required bool ok,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
            decoration: BoxDecoration(
              color: t.surface2,
              border: Border.all(color: ok ? t.good : t.border),
              borderRadius: BorderRadius.circular(BookClothTokens.radiusPill),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontFamilyFallback: AppFonts.fallback,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                fontSize: 11,
                height: 1,
                color: ok ? t.good : t.ink2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kleiner Knopf im Item (btn-sm-Pendant).
class _SmallBtn extends StatefulWidget {
  const _SmallBtn({
    required this.label,
    required this.onTap,
    this.tooltip,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final String? tooltip;
  final bool primary;

  @override
  State<_SmallBtn> createState() => _SmallBtnState();
}

class _SmallBtnState extends State<_SmallBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final btn = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: widget.primary
                ? t.accentSoft
                : (_hover ? t.surface2 : t.surface),
            border: Border.all(
                color: widget.primary ? t.accentLine : t.borderStrong),
            borderRadius: BorderRadius.circular(BookClothTokens.radiusXs),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontFamilyFallback: AppFonts.fallback,
              fontWeight: widget.primary ? FontWeight.w600 : FontWeight.w500,
              fontSize: 13,
              height: 1,
              color: widget.primary ? t.accentInk : t.ink,
            ),
          ),
        ),
      ),
    );
    return widget.tooltip != null
        ? Tooltip(message: widget.tooltip!, child: btn)
        : btn;
  }
}
