/// ☰ Lesen-Modus — Port von `renderLesenMode`/`lesenSection`/
/// `kompaktSection` (:360-516).
///
/// Fortlaufender Literatur-Satz des GANZEN Kapitels (Serif, fs-lesen), je
/// Abschnitt ein Block mit h3-Kopf (Nummer · Titel · S.-Link · „◉ Analyse“).
/// Dichte „Kompakt“ = Kernaussagen-Digest (Klick → Dichte normal + Sprung).
/// 🖍/⚡ steuern die Markierungs-Darstellung; „◻ Ohne“ unterdrückt alles;
/// Text-Views erscheinen als dezente Blöcke unter den Absätzen (nur wo
/// Inhalt existiert). Unten die Kapitel-Navigation (← Kapitel n / n →).
/// Beim Einstieg scrollt der aktive Abschnitt an den Anfang (außer Intro
/// oder gemerkter Scrollstand).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

import '../../../core/richtext/mini_md.dart';
import '../../../core/richtext/richtext_builder.dart';
import '../../../core/router/routes.dart';
import '../../../core/shell/footnote_modal.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../data/models/models.dart';
import '../layout/dock_state.dart';
import '../layout/rich_resolver.dart';
import '../layout/studio_slots.dart';
import '../layout/studio_state.dart';
import '../pruefen/paragraph_card.dart' show stripFigMarker;

class LesenMode extends ConsumerStatefulWidget {
  const LesenMode({super.key, required this.sectionId, this.scrollController});

  final String sectionId;
  final ScrollController? scrollController;

  @override
  ConsumerState<LesenMode> createState() => _LesenModeState();
}

class _LesenModeState extends ConsumerState<LesenMode> {
  final Map<String, GlobalKey> _secKeys = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialScroll());
  }

  @override
  void didUpdateWidget(LesenMode oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Abschnittswechsel innerhalb des Lesen-Modus: erneut zum aktiven
    // Abschnitt scrollen (Kompakt-Zeilen-Klick, Kapitel-Navigation).
    if (oldWidget.sectionId != widget.sectionId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
    }
  }

  void _scrollToActive() {
    if (!mounted) return;
    final unit = ref.read(studioDomainProvider)?.ctx.unitIndex[widget.sectionId];
    if (unit == null || unit.unit.isIntro) return;
    final ctx = _secKeys[widget.sectionId]?.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx);
  }

  /// Anfangs-Scroll (:384-389): gemerkter Stand gewinnt; sonst aktiver
  /// Abschnitt an den Anfang (außer Intro).
  void _initialScroll() {
    if (!mounted) return;
    final remembered = ref
        .read(studioScrollMemoryProvider.notifier)
        .restore('lesen', widget.sectionId);
    if (remembered != null && remembered > 0) return;
    final unit = ref.read(studioDomainProvider)?.ctx.unitIndex[widget.sectionId];
    if (unit == null || unit.unit.isIntro) return;
    final ctx = _secKeys[widget.sectionId]?.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx);
  }

  @override
  Widget build(BuildContext context) {
    // Dichte-Wechsel Kompakt → Normal (Kompakt-Zeilen-Klick): danach zum
    // aktiven Abschnitt springen (:506-511).
    ref.listen(studioPrefsCtlProvider, (prev, next) {
      final was = prev?.value?.dichte;
      final now = next.value?.dichte;
      if (was == 'kompakt' && now == 'normal') {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
      }
    });
    final domain = ref.watch(studioDomainProvider);
    final prefs = ref.watch(studioPrefsCtlProvider).value ?? StudioPrefs.defaults;
    final info = domain?.ctx.unitIndex[widget.sectionId];
    if (domain == null || info == null) return const SizedBox.shrink();
    final ch = info.chapter;

    // Alle Abschnitte des Kapitels mit Absätzen (rekursiv).
    final units = <Unit>[];
    void rec(List<Unit> list) {
      for (final u in list) {
        if (u.paragraphs.isNotEmpty) units.add(u);
        rec(u.children);
      }
    }

    rec(ch.sections);

    final kompakt = prefs.dichte == 'kompakt';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (StudioSlots.instanzBar != null)
          StudioSlots.instanzBar!(context, widget.sectionId),
        // .lesen-doc: max-width 74ch zentriert.
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final u in units)
                  KeyedSubtree(
                    key: _secKeys.putIfAbsent(u.id, GlobalKey.new),
                    child: kompakt
                        ? KompaktSection(unit: u, chapter: ch)
                        : LesenSection(unit: u, chapter: ch),
                  ),
                _chapterNav(context, domain, ch),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// ← Kapitel n / Kapitel n → (springt zum ERSTEN Abschnitt mit Absätzen).
  Widget _chapterNav(BuildContext context, StudioDomain domain, Chapter ch) {
    final chapters = domain.ctx.thesis?.chapters ?? const <Chapter>[];
    final ci = chapters.indexWhere((c) => c.num == ch.num);

    String? firstSec(Chapter c) {
      String? id;
      void rec2(List<Unit> us) {
        for (final u in us) {
          if (id == null && u.paragraphs.isNotEmpty) id = u.id;
          rec2(u.children);
        }
      }

      rec2(c.sections);
      return id;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (ci > 0)
            AppButton(
              child: Text('← Kapitel ${chapters[ci - 1].num}'),
              onPressed: () {
                final id = firstSec(chapters[ci - 1]);
                if (id != null) {
                  context.go(Routes.studioPath(sec: id, modus: 'lesen'));
                }
              },
            )
          else
            const SizedBox.shrink(),
          if (ci >= 0 && ci < chapters.length - 1)
            AppButton(
              child: Text('Kapitel ${chapters[ci + 1].num} →'),
              onPressed: () {
                final id = firstSec(chapters[ci + 1]);
                if (id != null) {
                  context.go(Routes.studioPath(sec: id, modus: 'lesen'));
                }
              },
            ),
        ],
      ),
    );
  }
}

/// Ein Abschnitt im normalen Lesen-Satz (`lesenSection`, :392-446).
class LesenSection extends ConsumerWidget {
  const LesenSection({super.key, required this.unit, required this.chapter});

  final Unit unit;
  final Chapter chapter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final domain = ref.watch(studioDomainProvider);
    final prefs = ref.watch(studioPrefsCtlProvider).value ?? StudioPrefs.defaults;
    final snapshot = ref.watch(studioKvProvider).value ?? const <String, Object?>{};
    if (domain == null) return const SizedBox.shrink();

    final u = unit;
    final label = u.isIntro ? 'Kapitel ${chapter.num}' : u.id;

    // Views im Lesen (:399-409): „Ohne (clear)“ = ganz ruhig; Text-Views
    // erscheinen als Block unter dem Absatz.
    final mode = ref.watch(dockModeForProvider(u.id));
    final defs = ref.watch(dockDefsProvider);
    final clear = mode == 'clear';
    final lText = mode != null &&
            mode != 'schnell' &&
            mode != 'connections' &&
            !clear &&
            dockIsTextOf(defs, mode)
        ? mode
        : null;
    final showMarks = !clear && (prefs.fast || prefs.lesenMarks);

    final marksExtraRaw = snapshot['marksExtra'];
    final marksExtra = marksExtraRaw is Map
        ? marksExtraRaw.map((k, v) => MapEntry('$k', v))
        : const <String, Object?>{};

    final resolver = richResolverFor(domain);
    final callbacks = RichTextCallbacks(
      onFnTap: (fn) => showFootnoteModal(context, fn),
      // Im Lesen-Modus öffnet der Klick auf eine Quelle NICHT die Spalte
      // (app.js:96: nur `Studio.mode === 'pruefen'`) — der lit-Toggle bleibt.
      onXrefTap: (target) => context.go(Routes.studioPath(sec: target)),
    );

    final serif = AppTextStyles.lesen.copyWith(height: 1.78, color: t.ink);

    Widget? instBlock(Paragraph p) {
      if (lText == null) return null;
      final md = dockGetFrom(snapshot, lText, p.id).isNotEmpty
          ? dockGetFrom(snapshot, lText, p.id)
          : dockAutoFor(domain, lText, u.id, p);
      if (md.isEmpty) return null;
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
        decoration: BoxDecoration(
          color: t.surface2,
          border: Border(left: BorderSide(color: t.accentLine, width: 3)),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dockLabelOf(defs, lText).toUpperCase(),
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontFamilyFallback: AppFonts.fallback,
                fontWeight: FontWeight.w600,
                fontSize: 10.5,
                height: 1.4,
                letterSpacing: .07 * 10.5,
                color: t.muted,
              ),
            ),
            const SizedBox(height: 2),
            MiniMd(md),
          ],
        ),
      );
    }

    final children = <Widget>[
      _SectionHead(unit: u, chapter: chapter, label: label),
    ];

    for (final p in u.paragraphs) {
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

      switch (p.typeEnum) {
        case ParagraphType.list:
          for (final it in p.items) {
            children.add(Padding(
              padding: const EdgeInsets.only(left: 24, bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: serif.copyWith(fontSize: 15.5)),
                  Expanded(
                    child: RichTextView(
                      it,
                      style: serif.copyWith(fontSize: 15.5, height: 1.72),
                      resolver: resolver,
                      options: RichTextOptions(
                        fnStyle: FnStyle.mini,
                        xrefs: true,
                        marks: showMarks
                            ? domain.paraMarks(u.id, p.id, marksExtra)
                            : const [],
                        activeCats: prefs.activeCats,
                        fastread: prefs.fast,
                      ),
                      callbacks: callbacks,
                    ),
                  ),
                ],
              ),
            ));
          }
          final ib = instBlock(p);
          if (ib != null) children.add(ib);
        case ParagraphType.figure:
          children.add(_figOrMissing(context, t, fig, null, p, resolver));
          continue;
        case ParagraphType.table:
          children.add(_figOrMissing(context, t, null, tab, p, resolver));
          continue;
        default:
          final text = stripFigMarker(p.text);
          if (text.trim().isNotEmpty) {
            children.add(Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: RichTextView(
                text,
                style: serif,
                resolver: resolver,
                options: RichTextOptions(
                  fnStyle: FnStyle.mini,
                  xrefs: true,
                  // Nur bestätigte/zusammengeführte Erwähnungen (:435).
                  mentions: clear
                      ? const []
                      : richMentions(domain.mentions.forPara(u.id, p).where(
                          (mt) =>
                              mt.status == 'bestaetigt' ||
                              mt.status == 'beleg')),
                  marks: showMarks
                      ? domain.paraMarks(u.id, p.id, marksExtra)
                      : const [],
                  activeCats: prefs.activeCats,
                  fastread: prefs.fast,
                ),
                callbacks: callbacks,
              ),
            ));
            final ib = instBlock(p);
            if (ib != null) children.add(ib);
          }
      }
      if (fig != null) {
        children.add(_figCard(context, fig, null));
      }
      if (tab != null) {
        children.add(_figCard(context, null, tab));
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _figCard(BuildContext context, Figur? fig, Tabelle? tab) {
    if (fig != null && StudioSlots.figureCard != null) {
      return StudioSlots.figureCard!(context, fig, compact: false);
    }
    if (tab != null && StudioSlots.tableCard != null) {
      return StudioSlots.tableCard!(context, tab);
    }
    final t = BookClothTokens.of(context);
    final titel = fig?.titel ?? tab?.titel ?? '';
    final nummer = fig?.nummer ?? tab?.nummer ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.surface2,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(BookClothTokens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(fig != null ? '🖼 Abbildung $nummer' : '▦ Tabelle $nummer'),
          if (titel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(titel, style: AppTextStyles.small.copyWith(color: t.ink2)),
          ],
        ],
      ),
    );
  }

  /// fig-missing: Platzhalter, wenn das Manifest die Abbildung nicht kennt.
  Widget _figOrMissing(BuildContext context, BookClothTokens t, Figur? fig,
      Tabelle? tab, Paragraph p, RichTextResolver resolver) {
    if (fig != null || tab != null) return _figCard(context, fig, tab);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.surface2,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(BookClothTokens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(p.typeEnum == ParagraphType.figure ? '🖼 Abbildung' : '▦ Tabelle'),
          const SizedBox(height: 4),
          RichTextView(
            p.text,
            style: AppTextStyles.small.copyWith(color: t.ink2),
            resolver: resolver,
            options: const RichTextOptions(fnStyle: FnStyle.mini),
          ),
        ],
      ),
    );
  }
}

/// h3-Kopf eines Lese-Abschnitts.
class _SectionHead extends StatelessWidget {
  const _SectionHead({
    required this.unit,
    required this.chapter,
    required this.label,
  });

  final Unit unit;
  final Chapter chapter;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final u = unit;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontFamilyFallback: AppFonts.fallback,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              height: 1,
              color: t.accentInk,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              u.isIntro ? chapter.title : u.title,
              style: AppTextStyles.h3.copyWith(fontSize: 17, color: t.ink),
            ),
          ),
          if (u.pdfPage != null) ...[
            const SizedBox(width: 10),
            Tooltip(
              message: 'Im Original-PDF öffnen',
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => launcher.launchUrl(
                    Uri.parse('sources/thesis.pdf#page=${u.pdfPage}'),
                    mode: launcher.LaunchMode.externalApplication,
                  ),
                  child: Text('S. ${u.page}',
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontFamilyFallback: AppFonts.fallback,
                        fontWeight: FontWeight.w500,
                        fontSize: 10.5,
                        color: t.muted,
                      )),
                ),
              ),
            ),
          ],
          const SizedBox(width: 10),
          Tooltip(
            message: 'Belege & Quellen dieses Abschnitts analysieren',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => context
                    .go(Routes.studioPath(sec: u.id, modus: 'pruefen')),
                child: Text('◉ Analyse',
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontFamilyFallback: AppFonts.fallback,
                      fontWeight: FontWeight.w500,
                      fontSize: 10.5,
                      color: t.muted,
                    )),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kompakt-Dichte: Kernaussagen-Digest (`kompaktSection`, :492-516).
class KompaktSection extends ConsumerWidget {
  const KompaktSection({super.key, required this.unit, required this.chapter});

  final Unit unit;
  final Chapter chapter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final domain = ref.watch(studioDomainProvider);
    if (domain == null) return const SizedBox.shrink();
    final u = unit;
    final label = u.isIntro ? 'Kapitel ${chapter.num}' : u.id;

    final rows = <Widget>[];
    for (final p in u.paragraphs) {
      if (p.typeEnum == ParagraphType.figure ||
          p.typeEnum == ParagraphType.table) {
        continue;
      }
      final gp = domain.genPara(u.id, p.id);
      final stripped = stripFigMarker(p.text);
      final kern = (gp?.kernaussage ?? '').isNotEmpty
          ? gp!.kernaussage
          : p.typeEnum == ParagraphType.list
              ? 'Aufzählung: ${p.items.length} Punkte'
              : '${stripped.replaceAll(RegExp(r'\[\^\d+\]'), '').substring(0, stripped.length > 180 ? 180 : stripped.length)}${stripped.length > 180 ? ' …' : ''}';
      if (kern.isEmpty) continue;
      rows.add(_KernRow(
        text: kern,
        tooltip: 'Absatz ${p.id} — klicken zum Volltext',
        onTap: () {
          // Klick → Dichte normal + Sprung in den Abschnitt (:506-511).
          ref.read(studioPrefsCtlProvider.notifier).setDichte('normal');
          context.go(Routes.studioPath(sec: u.id, modus: 'lesen'));
        },
      ));
    }

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(label,
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontFamilyFallback: AppFonts.fallback,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      height: 1,
                      color: t.accentInk,
                    )),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(u.isIntro ? chapter.title : u.title,
                      style:
                          AppTextStyles.h3.copyWith(fontSize: 17, color: t.ink)),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => context
                        .go(Routes.studioPath(sec: u.id, modus: 'pruefen')),
                    child: Text('⌖',
                        style: TextStyle(
                          fontSize: 12,
                          color: t.muted,
                          fontFamilyFallback: AppFonts.fallback,
                        )),
                  ),
                ),
              ],
            ),
          ),
          ...rows,
        ],
      ),
    );
  }
}

class _KernRow extends StatefulWidget {
  const _KernRow({required this.text, required this.tooltip, required this.onTap});

  final String text;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_KernRow> createState() => _KernRowState();
}

class _KernRowState extends State<_KernRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(7, 5, 8, 5),
            decoration: BoxDecoration(
              color: _hover ? t.surface2 : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quadratischer Akzent-Punkt (`.kern-list li::before`).
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                      width: 6, height: 6, child: ColoredBox(color: t.accent)),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    widget.text,
                    style: AppTextStyles.small.copyWith(
                      fontSize: 14.5,
                      height: 1.6,
                      color: _hover ? t.ink : t.ink2,
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
