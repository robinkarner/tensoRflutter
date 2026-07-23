/// Beleg-Zeile — Port von `belegRow` (:1033-1130) + Spannen-Steuerung
/// `openSpanCtl` (:1151-1183) + `selectBeleg` (:1187-1194).
///
/// Kopfzeile: Status-Punkt + `[n]` · Level-Badge · 🖍-Mark-Chip ·
/// Quellen-Links · „Prüfen“. Darunter Claim, ✦-Vermutung, Suchbegriffe,
/// zusammengeführte Erwähnungen (❞ … ↺) und ab Stufe 2 die Fundstelle.
/// Klick irgendwo = Beleg aktivieren (Satzspannen-Highlight + Quellen-Spalte
/// rechts); Doppelklick = Spannen-Steuerung „± Satz“.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/util/sentences.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/chips.dart';
import '../../../data/bundles/indexes.dart';
import '../../../data/db/kv.dart';
import '../../../data/models/models.dart';
import '../layout/rich_resolver.dart';
import '../layout/studio_slots.dart';
import '../layout/studio_state.dart';
import 'search_chips.dart';

class BelegRow extends ConsumerStatefulWidget {
  const BelegRow({
    super.key,
    required this.sectionId,
    required this.paraId,
    required this.beleg,
  });

  final String sectionId;
  final String paraId;
  final Beleg beleg;

  @override
  ConsumerState<BelegRow> createState() => _BelegRowState();
}

class _BelegRowState extends ConsumerState<BelegRow> {
  bool _hover = false;

  /// Spannen-Steuerung offen? (Doppelklick, :1124-1128)
  bool _spanCtl = false;

  Beleg get b => widget.beleg;

  void _select(String? srcId) {
    // selectBeleg: Auswahl + Satzspanne + Quellen-Spalte (:1187-1194).
    studioFileShow(ref, context, srcId, b.num, sectionId: widget.sectionId);
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final domain = ref.watch(studioDomainProvider);
    if (domain == null) return const SizedBox.shrink();

    final fnEntry = domain.ctx.fnIndex[b.num];
    final srcs = b.quellen.isNotEmpty ? b.quellen : (fnEntry?.sources ?? const []);
    final primary = srcs.isNotEmpty ? srcs.first : null;
    final inf = domain.levels.info(b.num);
    final sel = ref.watch(studioSelectionProvider);
    final isSel = sel?.fn == b.num;
    final marks = primary != null
        ? (StudioSlots.marksForFn?.call(primary, b.num) ?? const [])
        : const [];

    // Ring-Farbe des Status-Punkts (Levels.dot): explizit > farbeFor.
    Color? ring;
    final entry = domain.levels.entry(b.num);
    final explicitFarbe =
        entry?['farbe'] is String && '${entry!['farbe']}'.isNotEmpty
            ? '${entry['farbe']}'
            : null;
    final farbKey = explicitFarbe ??
        (primary != null ? domain.levels.farbeFor(primary, b.num) : null);
    if (farbKey != null) ring = BookClothTokens.markFarbe(farbKey);

    // Mit diesem Beleg zusammengeführte Erwähnungen (❞ … ↺, :1100-1114).
    final p = _paragraph(domain);
    final merged = p == null
        ? const []
        : [
            for (final mt in domain.mentions.forPara(widget.sectionId, p))
              if (mt.status == 'beleg' && mt.fn == b.num) mt,
          ];

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _select(primary),
        onDoubleTap: () => setState(() => _spanCtl = true),
        child: Container(
          margin: const EdgeInsets.only(top: 5),
          padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
          decoration: BoxDecoration(
            color: isSel
                ? t.accentSoft
                : _hover
                    ? t.surface2
                    : Colors.transparent,
            border: Border.all(
              color: isSel || _hover ? t.accentLine : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- b-head -------------------------------------------------
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LevelDot(inf.level, ringColor: ring),
                      const SizedBox(width: 5),
                      Text(
                        '[${b.num}]',
                        style: TextStyle(
                          fontFamily: AppFonts.mono,
                          fontFamilyFallback: AppFonts.fallback,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          height: 1,
                          color: t.accentInk,
                        ),
                      ),
                    ],
                  ),
                  LevelBadge(inf.level),
                  if (marks.isNotEmpty)
                    AppChip(
                      label: marks.length > 1
                          ? '🖍 ${marks.length}'
                          : '🖍 S. ${marks.first.page}',
                      mini: true,
                      onTap: () => _select(primary),
                    ),
                  // Quellen-Links „Kürzel · Kürzel“
                  for (final (i, id) in srcs.indexed)
                    _SrcLink(
                      srcId: id,
                      withSeparator: i > 0,
                      onTap: () => _select(id),
                    ),
                  AppButton(
                    small: true,
                    variant: AppButtonVariant.primary,
                    tooltip:
                        'Beleg rechts in der Quellen-Spalte öffnen (PDF + Formular)',
                    onPressed: () => _select(primary),
                    child: const Text('Prüfen'),
                  ),
                ],
              ),
              // ---- Claim --------------------------------------------------
              if (b.claim.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 2),
                  child: Tooltip(
                    message:
                        'Doppelklick: belegte Textspanne oben im Absatz markieren (satzweise erweiterbar)',
                    waitDuration: const Duration(milliseconds: 700),
                    child: Text(
                      b.claim,
                      style: AppTextStyles.small
                          .copyWith(fontSize: 13.5, color: t.ink2),
                    ),
                  ),
                ),
              // ---- ✦ vermutet --------------------------------------------
              if (b.fundstelle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'vermutet '),
                      TextSpan(
                        text: b.fundstelle,
                        style: TextStyle(
                          fontFamily: AppFonts.mono,
                          fontFamilyFallback: AppFonts.fallback,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: t.accentInk,
                        ),
                      ),
                    ]),
                    style: AppTextStyles.small
                        .copyWith(fontSize: 12, color: t.muted),
                  ),
                ),
              // ---- Suchbegriffe ------------------------------------------
              if (b.suchHinweis.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: SearchChips(
                    suchHinweis: b.suchHinweis,
                    maxTermLength: 30,
                    onSearch: (w) {
                      // Beleg aktivieren, dann suchen, sobald das PDF steht
                      // (Mount ist async, :1086-1095).
                      _select(primary);
                      if (primary != null) {
                        studioPdfSearchWhenReady(primary, w);
                      }
                    },
                  ),
                ),
              // ---- ❞ zusammengeführte Erwähnungen ------------------------
              for (final mt in merged)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(children: [
                            const TextSpan(text: '❞ im Text '),
                            TextSpan(
                              text: mt.snippet,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const TextSpan(text: ' — zeigt auf diesen Beleg'),
                          ]),
                          style: AppTextStyles.small
                              .copyWith(fontSize: 12, color: t.muted),
                        ),
                      ),
                      AppButton(
                        small: true,
                        variant: AppButtonVariant.ghost,
                        tooltip:
                            'Zusammenführung lösen — wieder eigene Erwähnungs-Instanz',
                        onPressed: () => domain.mentions
                            .setStatus(mt.key, 'bestaetigt', mt.srcId),
                        child: const Text('↺'),
                      ),
                    ],
                  ),
                ),
              // ---- Fundstelle (Stufe ≥ 2) --------------------------------
              if (inf.level >= 2 &&
                  ((inf.zitat ?? '').isNotEmpty ||
                      '${inf.seite ?? ''}'.isNotEmpty ||
                      (inf.fundstelle ?? '').isNotEmpty))
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                  decoration: BoxDecoration(
                    color: t.surface2,
                    border: Border(
                      top: BorderSide(color: t.border),
                      right: BorderSide(color: t.border),
                      bottom: BorderSide(color: t.border),
                      left: BorderSide(color: t.good, width: 3),
                    ),
                    borderRadius:
                        BorderRadius.circular(BookClothTokens.radiusXs),
                  ),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 3,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(inf.level == 3 ? '✓' : '❝',
                          style: TextStyle(fontSize: 13, color: t.good)),
                      if ('${inf.seite ?? ''}'.isNotEmpty)
                        Text('S. ${inf.seite}',
                            style: AppTextStyles.small.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: t.ink)),
                      if ((inf.fundstelle ?? '').isNotEmpty)
                        Text(inf.fundstelle!,
                            style: AppTextStyles.small.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: t.ink)),
                      if ((inf.zitat ?? '').isNotEmpty)
                        Text(
                          '„${inf.zitat!.length > 220 ? '${inf.zitat!.substring(0, 220)}…' : inf.zitat}“',
                          style: TextStyle(
                            fontFamily: AppFonts.serif,
                            fontFamilyFallback: AppFonts.fallback,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: t.ink2,
                          ),
                        ),
                      AppChip(label: inf.herkunft ?? 'manuell', mini: true),
                    ],
                  ),
                ),
              // ---- Spannen-Steuerung (nach Doppelklick) -------------------
              if (_spanCtl && p != null)
                _SpanCtl(
                  sectionId: widget.sectionId,
                  paragraph: p,
                  fnNum: b.num,
                  onClose: () => setState(() => _spanCtl = false),
                  onChanged: () {
                    // Beleg aktiv setzen, damit die Spanne im Absatz oben
                    // sichtbar wird.
                    ref
                        .read(studioSelectionProvider.notifier)
                        .select(primary, b.num);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Paragraph? _paragraph(StudioDomain domain) {
    final unit = domain.ctx.unitIndex[widget.sectionId]?.unit;
    if (unit == null) return null;
    for (final p in unit.paragraphs) {
      if (p.id == widget.paraId) return p;
    }
    return null;
  }
}

class _SrcLink extends StatefulWidget {
  const _SrcLink({
    required this.srcId,
    required this.withSeparator,
    required this.onTap,
  });

  final String srcId;
  final bool withSeparator;
  final VoidCallback onTap;

  @override
  State<_SrcLink> createState() => _SrcLinkState();
}

class _SrcLinkState extends State<_SrcLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Consumer(builder: (context, ref, _) {
      final s = ref.watch(srcByIdProvider)[widget.srcId];
      final short = ref.watch(srcShortProvider(widget.srcId));
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.withSeparator)
            Text(' · ',
                style: AppTextStyles.small
                    .copyWith(fontSize: 13, color: t.muted)),
          Tooltip(
            message:
                '${s?.title ?? widget.srcId} — rechts in der Quellen-Spalte prüfen',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hover = true),
              onExit: (_) => setState(() => _hover = false),
              child: GestureDetector(
                onTap: widget.onTap,
                child: Text(
                  short,
                  style: AppTextStyles.small.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _hover ? t.accentInk : t.ink,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

/// „Belegte Textspanne: n Satz/Sätze bis [n] · + Satz davor · − Satz · ✕“
/// (`span-ctl`, :1151-1183). Persistiert über `belegSpans`; das Highlight
/// oben im Absatz zieht reaktiv nach.
class _SpanCtl extends ConsumerWidget {
  const _SpanCtl({
    required this.sectionId,
    required this.paragraph,
    required this.fnNum,
    required this.onClose,
    required this.onChanged,
  });

  final String sectionId;
  final Paragraph paragraph;
  final int fnNum;
  final VoidCallback onClose;
  final VoidCallback onChanged;

  BelegSpanResult? _span(WidgetRef ref) {
    final domain = ref.watch(studioDomainProvider);
    final snapshot = ref.watch(studioKvProvider).value ?? const <String, Object?>{};
    if (domain == null) return null;
    return belegSpanHighlight(domain, snapshot, sectionId, paragraph, fnNum)?.$1;
  }

  void _setBack(WidgetRef ref, int n) {
    final kv = ref.read(studioKvProvider.notifier);
    final all = kv.readMap(KvKeys.belegSpans);
    kv.put(KvKeys.belegSpans, {...all, '$fnNum': n < 0 ? 0 : n});
    onChanged();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final span = _span(ref);
    final label = span != null
        ? '${span.to - span.from + 1} ${span.to == span.from ? 'Satz' : 'Sätze'} bis [$fnNum]'
        : 'kein Absatztext markierbar';

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(9, 6, 9, 6),
      decoration: BoxDecoration(
        color: t.accent.withValues(alpha: .05),
        border: Border.all(color: t.accentLine, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 7,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Belegte Textspanne:',
              style: AppTextStyles.small.copyWith(color: t.muted)),
          Text(label,
              style: AppTextStyles.small
                  .copyWith(fontWeight: FontWeight.w700, color: t.ink)),
          AppButton(
            small: true,
            tooltip: 'Einen Satz mehr davor zur Spanne zählen',
            onPressed: span == null
                ? null
                : () => _setBack(ref, (span.to - span.from) + 1),
            child: const Text('+ Satz davor'),
          ),
          AppButton(
            small: true,
            tooltip: 'Einen Satz weniger',
            onPressed: span == null
                ? null
                : () => _setBack(ref, (span.to - span.from) - 1),
            child: const Text('− Satz'),
          ),
          AppButton(
            small: true,
            variant: AppButtonVariant.ghost,
            tooltip: 'Markierung ausblenden',
            onPressed: onClose,
            child: const Text('✕'),
          ),
        ],
      ),
    );
  }
}
