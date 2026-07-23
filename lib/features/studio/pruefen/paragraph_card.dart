/// Absatzkarte — Port von `paragraphCard`/`toggleParagraph`/
/// `buildResolution`/`paraEditBadge`/`appendScFlag` (:708-928).
///
/// Klickbarer `para-body` (öffnet die Beleg-Auflösung), Kategorie-Chips
/// direkt unter dem Text (togglen die Kategorie GLOBAL), Fußhinweis
/// „▸ N Belege — …“, ✎-bearbeitet-Badge mit ↺, 🤖-Stil-Check-Zähler.
/// Offen: Beleg-Zeilen + Erwähnungs-Workflow. Der Doppelklick-Edit gehört
/// S-3 (views/) und hängt am [StudioSlots.paraEditStart]-Slot.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/richtext/categories.dart';
import '../../../core/richtext/richtext_builder.dart';
import '../../../core/router/routes.dart';
import '../../../core/shell/footnote_modal.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../data/db/kv.dart';
import '../../../data/models/models.dart';
import '../../../domain/levels.dart' show LevelCounts;
import '../../../domain/stylecheck.dart';
import '../layout/rich_resolver.dart';
import '../layout/studio_slots.dart';
import '../layout/studio_state.dart';
import 'beleg_row.dart';
import 'mention_rows.dart';
import 'stylecheck_ui.dart';

class ParagraphCard extends ConsumerStatefulWidget {
  const ParagraphCard({
    super.key,
    required this.sectionId,
    required this.paragraph,
    this.initiallyOpen = false,
    this.jumpFlash = false,
    this.clear = false,
    this.srcViewSrcId,
  });

  final String sectionId;
  final Paragraph paragraph;

  /// Karte offen starten (aktiver Beleg / focusPara, :555-571).
  final bool initiallyOpen;

  /// `.jump-flash` (Absatz-Anker, 2400ms Outline).
  final bool jumpFlash;

  /// „◻ Ohne“-View: keine Marks, keine Erwähnungs-Hervorhebung.
  final bool clear;

  /// Aktive Quelle des ◘-Quelle-Views (Satz-Highlights) oder null.
  final String? srcViewSrcId;

  @override
  ConsumerState<ParagraphCard> createState() => _ParagraphCardState();
}

class _ParagraphCardState extends ConsumerState<ParagraphCard> {
  late bool _open = widget.initiallyOpen;
  bool _flash = false;
  bool _hoverBody = false;

  @override
  void initState() {
    super.initState();
    if (widget.jumpFlash) {
      _flash = true;
      Future<void>.delayed(const Duration(milliseconds: 2400), () {
        if (mounted) setState(() => _flash = false);
      });
    }
  }

  @override
  void didUpdateWidget(ParagraphCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Aktiver Beleg öffnet seine Karte nach jedem Render wieder (:555-560).
    if (widget.initiallyOpen && !oldWidget.initiallyOpen && !_open) {
      _open = true;
    }
  }

  Paragraph get p => widget.paragraph;

  void _toggle() {
    setState(() => _open = !_open);
    // Beim Schließen verschwindet das Satzspannen-Highlight mit der
    // Auflösung (Original: clearHighlight('beleg-span'), :907) — das
    // Highlight hängt hier an `_open` und geht reaktiv mit zu.
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final domain = ref.watch(studioDomainProvider);
    final prefs = ref.watch(studioPrefsCtlProvider).value ?? StudioPrefs.defaults;
    final snapshot = ref.watch(studioKvProvider).value ?? const <String, Object?>{};

    if (domain == null) return const SizedBox.shrink();

    final belege = domain.paraBelege(widget.sectionId, p);
    final counts = domain.levels.countsFor([for (final b in belege) b.num]);
    final flagged =
        prefs.styleCheck && p.isText ? const StyleCheck().analyzePara(p.text) : null;

    final peMap = snapshot[KvKeys.paraEdits];
    final edited = peMap is Map && peMap.containsKey(p.id);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      clipBehavior: Clip.hardEdge,
      foregroundDecoration: _flash
          ? BoxDecoration(
              border: Border.all(color: t.accent, width: 2),
              borderRadius: BorderRadius.circular(BookClothTokens.radius),
            )
          : null,
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(BookClothTokens.radius),
        boxShadow: t.shadow1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- para-body ----------------------------------------------------
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hoverBody = true),
            onExit: (_) => setState(() => _hoverBody = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              onDoubleTap: p.isText
                  ? () => StudioSlots.paraEditStart
                      ?.call(context, widget.sectionId, p)
                  : null,
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                decoration: BoxDecoration(
                  color: _open || _hoverBody ? t.surface2 : Colors.transparent,
                  border: _open
                      ? Border(bottom: BorderSide(color: t.border))
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _paraContent(context, t, domain, prefs, snapshot),
                    _catsRow(t, domain, prefs, snapshot),
                    _hintRow(t, counts, belege.length, edited, flagged, snapshot),
                  ],
                ),
              ),
            ),
          ),
          // ---- resolution ---------------------------------------------------
          if (_open) _resolution(context, t, domain, belege),
        ],
      ),
    );
  }

  /// `marksExtra`-Map aus dem Snapshot (zusätzliche KI-Markierungen).
  Map<String, Object?> _marksExtraOf(Map<String, Object?> snapshot) {
    final v = snapshot[KvKeys.marksExtra];
    return v is Map ? v.map((k, val) => MapEntry('$k', val)) : const {};
  }

  /// Absatzinhalt: Text/List/Figure/Table mit RichText.
  Widget _paraContent(
    BuildContext context,
    BookClothTokens t,
    StudioDomain domain,
    StudioPrefs prefs,
    Map<String, Object?> snapshot,
  ) {
    final marksExtra = _marksExtraOf(snapshot);
    final clear = widget.clear;
    final style = AppTextStyles.body
        .copyWith(fontSize: 16, height: 1.75, color: t.ink);

    final callbacks = RichTextCallbacks(
      onFnTap: (fn) => showFootnoteModal(context, fn),
      onSrcLit: (srcId, fn) {
        // Quelle nur im Prüfen-Modus öffnen (app.js:92-98) — hier IST
        // Prüfen-Modus.
        studioFileShow(ref, context, srcId,
            fn ?? _firstNumForSource(domain, srcId),
            sectionId: widget.sectionId);
      },
      onXrefTap: (target) => context.go(Routes.studioPath(sec: target)),
    );

    // Highlights: aktive Belegspanne (nur offen) + Stil-Check + ◘ Quelle.
    final highlights = <RichHighlight>[];
    final sel = ref.watch(studioSelectionProvider);
    if (_open &&
        sel?.fn != null &&
        domain.ctx.fnIndex[sel!.fn!]?.paragraphId == p.id) {
      final hl = belegSpanHighlight(
          domain, snapshot, widget.sectionId, p, sel.fn!);
      if (hl != null) highlights.add(hl.$2);
    }
    if (prefs.styleCheck) highlights.addAll(styleCheckHighlights(p));
    if (widget.srcViewSrcId != null) {
      highlights.addAll(
          srcViewHighlights(domain, widget.sectionId, p, widget.srcViewSrcId!));
    }

    final fastread = FastreadScope.of(context);

    switch (p.typeEnum) {
      case ParagraphType.list:
        final marks = clear
            ? const <Mark>[]
            : domain.paraMarks(widget.sectionId, p.id, marksExtra);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final it in p.items)
              Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•  ', style: style),
                    Expanded(
                      child: RichTextView(
                        it,
                        style: style,
                        resolver: richResolverFor(domain),
                        options: RichTextOptions(
                          marks: marks,
                          activeCats: prefs.activeCats,
                          xrefs: true,
                          fastread: fastread,
                        ),
                        callbacks: callbacks,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      case ParagraphType.figure:
      case ParagraphType.table:
        Figur? fig;
        for (final f in domain.runtime.figures.figuren) {
          if (f.paragraphId == p.id) {
            fig = f;
            break;
          }
        }
        Tabelle? tab;
        for (final x in domain.runtime.figures.tabellen) {
          if (x.paragraphId == p.id) {
            tab = x;
            break;
          }
        }
        if (fig != null && StudioSlots.figureCard != null) {
          return StudioSlots.figureCard!(context, fig, compact: true);
        }
        if (tab != null && StudioSlots.tableCard != null) {
          return StudioSlots.tableCard!(context, tab);
        }
        return Text.rich(
          TextSpan(children: [
            TextSpan(
              text: p.typeEnum == ParagraphType.figure
                  ? '🖼 Abbildung: '
                  : '▦ Tabelle: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: p.text.replaceAll(RegExp(r'\[\^\d+\]'), '')),
          ]),
          style: AppTextStyles.small.copyWith(fontSize: 14, color: t.ink2),
        );
      default:
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720), // ~78ch
          child: RichTextView(
            stripFigMarker(p.text),
            style: style,
            resolver: richResolverFor(domain),
            options: RichTextOptions(
              marks: clear
                  ? const []
                  : domain.paraMarks(widget.sectionId, p.id, marksExtra),
              activeCats: prefs.activeCats,
              xrefs: true,
              fastread: fastread,
              mentions: clear
                  ? const []
                  : richMentions(domain.mentions
                      .forPara(widget.sectionId, p)
                      .where((mt) => mt.status != 'verworfen')),
              highlights: highlights,
            ),
            callbacks: callbacks,
          ),
        );
    }
  }

  /// Kategorie-Chips: nur die in DIESEM Absatz vorkommenden; Klick blendet
  /// die Kategorie ÜBERALL ein/aus (:737-755).
  Widget _catsRow(BookClothTokens t, StudioDomain domain, StudioPrefs prefs,
      Map<String, Object?> snapshot) {
    if (widget.clear || !(p.isText || p.typeEnum == ParagraphType.list)) {
      return const SizedBox.shrink();
    }
    final present = {
      for (final m in domain.paraMarks(
          widget.sectionId, p.id, _marksExtraOf(snapshot)))
        m.kategorie,
    };
    final cats = [for (final c in catOrder) if (present.contains(c)) c];
    if (cats.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 2,
        children: [
          for (final cat in cats)
            _CatChip(
              cat: cat,
              off: !prefs.activeCats.contains(cat),
              onTap: () =>
                  ref.read(studioPrefsCtlProvider.notifier).toggleCat(cat),
            ),
        ],
      ),
    );
  }

  /// Fußhinweis „▸ N Belege — x belegt · y Original · z vermutet · p.id“
  /// (+ ✎-Badge + 🤖-Chip).
  Widget _hintRow(
    BookClothTokens t,
    LevelCounts counts,
    int nBelege,
    bool edited,
    List<FlaggedSentence>? flagged,
    Map<String, Object?> snapshot,
  ) {
    final text = nBelege > 0
        ? '▸ $nBelege Beleg${nBelege > 1 ? 'e' : ''} — ${counts.l3} belegt · ${counts.l2} Original · ${counts.l1} vermutet'
        : 'Keine Belege in diesem Absatz';

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 0,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '$text · ${p.id}',
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontFamilyFallback: AppFonts.fallback,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: t.muted,
            ),
          ),
          if (edited) ...[
            Text(' · ',
                style: AppTextStyles.small.copyWith(color: t.muted)),
            _EditBadge(
              onRestore: _restoreOriginal,
            ),
          ],
          if (flagged != null && flagged.isNotEmpty) ...[
            Text(' · ',
                style: AppTextStyles.small.copyWith(color: t.muted)),
            ScFlag(paragraph: p, flagged: flagged),
          ],
        ],
      ),
    );
  }

  /// ↺ Original wiederherstellen (:843-852): Override löschen + LaTeX des
  /// Abschnitts synchron halten.
  void _restoreOriginal() {
    final domain = ref.read(studioDomainProvider);
    final kv = ref.read(studioKvProvider.notifier);
    final next = {...kv.readMap(KvKeys.paraEdits)}..remove(p.id);
    kv.put(KvKeys.paraEdits, next);
    if (domain != null) {
      domain.editor
          .saveEdit(widget.sectionId, domain.editor.reconstruct(widget.sectionId));
      domain.mentions.invalidate();
    }
  }

  Widget _resolution(BuildContext context, BookClothTokens t,
      StudioDomain domain, List<Beleg> belege) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      color: t.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (belege.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('BELEGE IN DIESEM ABSATZ',
                    style: AppTextStyles.eyebrow.copyWith(color: t.muted)),
                AppButton(
                  small: true,
                  tooltip:
                      'Große Ansicht: Zitierelemente links, PDF mit Markierungen rechts',
                  onPressed: () => StudioSlots.openRefMode
                      ?.call(context, widget.sectionId, p.id),
                  child: const Text('⌖ Große Ansicht'),
                ),
              ],
            ),
            for (final b in belege)
              BelegRow(sectionId: widget.sectionId, paraId: p.id, beleg: b),
          ] else
            Text('Keine Belege in diesem Absatz.',
                style: AppTextStyles.small.copyWith(color: t.muted)),
          MentionRows(
            sectionId: widget.sectionId,
            paragraph: p,
            belegNums: {for (final b in belege) b.num},
          ),
        ],
      ),
    );
  }

  int? _firstNumForSource(StudioDomain domain, String srcId) {
    final nums = domain.levels.numsForSource(srcId);
    return nums.isNotEmpty ? nums.first : null;
  }
}

/// ⚡-Zustand für die Karten (fastread-on färbt ALLE Marks voll aus) —
/// gesetzt vom PruefenMode, gelesen in [_ParagraphCardState._paraContent].
class FastreadScope extends InheritedWidget {
  const FastreadScope({super.key, required this.fastread, required super.child});

  final bool fastread;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FastreadScope>()?.fastread ??
      false;

  @override
  bool updateShouldNotify(FastreadScope oldWidget) =>
      oldWidget.fastread != fastread;
}

/// `[ABBILDUNG: …]`/`[TABELLE: …]`-Marker entfernen (`stripFigMarker`, :319).
String stripFigMarker(String? text) => (text ?? '')
    .replaceAll(RegExp(r'\s*\[(?:ABBILDUNG|TABELLE):[^\]]*\]\s*'), ' ')
    .replaceAll(RegExp(r'\s{2,}'), ' ')
    .trim();

/// Kategorie-Chip (`.pc-cat`).
class _CatChip extends StatefulWidget {
  const _CatChip({required this.cat, required this.off, required this.onTap});

  final String cat;
  final bool off;
  final VoidCallback onTap;

  @override
  State<_CatChip> createState() => _CatChipState();
}

class _CatChipState extends State<_CatChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final c = t.cat(widget.cat) ?? t.accent;
    return Tooltip(
      message:
          '${catLabels[widget.cat] ?? widget.cat} — klicken blendet diese Kategorie überall ein/aus',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Opacity(
            opacity: widget.off ? .45 : 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              decoration: BoxDecoration(
                color: _hover ? t.surface2 : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: widget.off ? .3 : 1,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration:
                          BoxDecoration(shape: BoxShape.circle, color: c),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    catLabels[widget.cat] ?? widget.cat,
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontFamilyFallback: AppFonts.fallback,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      height: 1,
                      letterSpacing: .01 * 12,
                      color: _hover ? t.ink2 : t.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip „✎ bearbeitet“ + ↺ (edit-badge).
class _EditBadge extends StatelessWidget {
  const _EditBadge({required this.onRestore});

  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
          decoration: BoxDecoration(
            color: t.warnSoft,
            borderRadius: BorderRadius.circular(BookClothTokens.radiusPill),
          ),
          child: Text(
            '✎ bearbeitet',
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontFamilyFallback: AppFonts.fallback,
              fontWeight: FontWeight.w500,
              fontSize: 10.5,
              height: 1,
              color: t.warn,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Tooltip(
          message: 'Original wiederherstellen',
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onRestore,
              child: Text('↺',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1,
                    color: t.accentInk,
                    fontFamilyFallback: AppFonts.fallback,
                  )),
            ),
          ),
        ),
      ],
    );
  }
}
