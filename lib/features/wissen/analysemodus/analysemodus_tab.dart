/// 🔬 Analysemodus — die Arbeit selbst als angereicherte Ansicht
/// (`analyseModus`/`amodSection`, views_analyse.js:123-218).
///
/// Original-Text Kapitel für Kapitel mit den visuellen Elementen
/// (Abbildungen, Tabellen) und einer wählbaren Erklärungs-„Linse“ direkt
/// unter jedem Absatz. Die Linsen sind die Text-Instanzen des Studios
/// (dockDefs ohne special); Inhalte: `dockGet` (gespeichert) →
/// `dockAuto`-Fallback (KI-Voranalyse). Abdeckungs-Meter in der Lens-Bar:
/// „· c von t Absätzen erklärt“.
///
/// Scroll-Verhalten: Der Linsen-Wechsel läuft über den KV-Provider — die
/// Seite wird NICHT neu gemountet, die Scroll-Position bleibt von selbst
/// erhalten (das Original restauriert sie manuell, views_analyse.js:145-148).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/richtext/richtext_builder.dart';
import '../../../core/richtext/mini_md.dart';
import '../../../core/router/routes.dart';
import '../../../core/shell/footnote_modal.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/notice.dart';
import '../../../data/bundles/indexes.dart';
import '../../../data/models/models.dart';
import '../../pdf/figures/figure_card.dart';
import '../../studio/layout/dock_state.dart';
import '../../studio/layout/rich_resolver.dart';
import '../../studio/layout/studio_state.dart';
import '../../studio/pruefen/paragraph_card.dart' show stripFigMarker;
import '../tabs/wissen_card.dart';
import '../tabs/wissen_state.dart';

class AnalysemodusTab extends ConsumerWidget {
  const AnalysemodusTab({super.key, required this.chNum});

  final int chNum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final thesis = ref.watch(effectiveThesisProvider);
    final chapters = thesis?.chapters ?? const <Chapter>[];
    if (chapters.isEmpty) {
      return const Notice(child: Text('Keine Arbeit geladen.'));
    }
    final ch = chapters.where((c) => c.num == chNum).firstOrNull ?? chapters.first;

    // Text-Linsen = Views ohne special; ungültige Auswahl → erste.
    final modes = [
      for (final d in ref.watch(dockDefsProvider))
        if (!d.special) d,
    ];
    var lens = ref.watch(wissenLensProvider).value ?? 'erklaerung';
    if (!modes.any((d) => d.id == lens)) {
      lens = modes.firstOrNull?.id ?? '';
    }
    final hasLens = lens.isNotEmpty;

    final domain = ref.watch(studioDomainProvider);
    final snapshot = ref.watch(studioKvProvider).value ?? const <String, Object?>{};

    // Abdeckung VOR dem Rendern zählen (das Original schreibt den Meter nach
    // dem Abschnitts-Rendern in die Bar — Ergebnis ist identisch).
    var covered = 0, total = 0;
    final units = <Unit>[];
    void collect(List<Unit> us) {
      for (final u in us) {
        if (u.paragraphs.isNotEmpty) units.add(u);
        collect(u.children);
      }
    }

    collect(ch.sections);
    if (hasLens && domain != null) {
      for (final u in units) {
        for (final p in u.paragraphs) {
          if (p.typeEnum == ParagraphType.figure || p.typeEnum == ParagraphType.table) {
            continue;
          }
          total++;
          final md = _explMd(domain, snapshot, lens, u.id, p);
          if (md.isNotEmpty) covered++;
        }
      }
    }

    final k = ref.watch(activeRuntimeProvider)?.meta.kapitel['${ch.num}'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kapitel-Picker.
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Wrap(spacing: 10, runSpacing: 8, children: [
            for (final c in chapters)
              AppButton(
                small: true,
                variant: c.num == ch.num
                    ? AppButtonVariant.primary
                    : AppButtonVariant.solid,
                onPressed: () => context
                    .go(Routes.analysePath(tab: 'modus', arg: '${c.num}')),
                child: Text('${c.num} ${c.title}'),
              ),
          ]),
        ),
        // Lens-Bar (.amod-lens).
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Erklärung durch:',
                  style: AppTextStyles.small.copyWith(color: t.muted)),
              for (final d in modes)
                _LensButton(
                  label: d.label,
                  on: d.id == lens,
                  onTap: () =>
                      ref.read(wissenLensProvider.notifier).set(d.id),
                ),
              if (hasLens)
                Text('· $covered von $total Absätzen erklärt',
                    style: AppTextStyles.small.copyWith(color: t.muted)),
              Text(
                'Inhalte entstehen über den GPT-Knopf oben in der Kopfleiste (global) — sonst zeigt die KI-Voranalyse',
                style: AppTextStyles.small.copyWith(color: t.muted),
              ),
            ],
          ),
        ),
        // Kapitel-Kopf: die „gute Erklärung“ zum Kapitel selbst.
        if (k != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: WissenCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WissenEyebrow('Kapitel ${ch.num} — worum es geht'),
                  const SizedBox(height: 6),
                  MiniMd(k.kurzfassung,
                      baseStyle:
                          AppTextStyles.body.copyWith(color: t.ink)),
                  if (k.kernaussagen.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final s in k.kernaussagen)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text('✦ $s',
                                  style: AppTextStyles.small.copyWith(
                                      fontSize: 13, color: t.ink2)),
                            ),
                        ],
                      ),
                    ),
                  if (k.fristen.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final f in k.fristen) ...[
                            AppChip(
                                label: f.datum, variant: AppChipVariant.warn),
                            Text(f.was,
                                style: AppTextStyles.small
                                    .copyWith(color: t.ink2)),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        // Abschnitte (.amod-doc, max 880px).
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final u in units)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _AmodSection(
                      unit: u,
                      chapter: ch,
                      lens: hasLens ? lens : null,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Effektiver Erklärungs-Inhalt eines Absatzes: gespeichert > Auto-Fallback.
String _explMd(StudioDomain domain, Map<String, Object?> snapshot, String lens,
    String sectionId, Paragraph p) {
  final stored = dockGetFrom(snapshot, lens, p.id);
  if (stored.isNotEmpty) return stored;
  return dockAutoFor(domain, lens, sectionId, p);
}

/// Linsen-Knopf — `.amod-lens .btn.on`: wissen-soft/wissen/wissen-ink
/// (app.css:1255); sonst normaler `.btn.btn-sm`.
class _LensButton extends StatefulWidget {
  const _LensButton({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  State<_LensButton> createState() => _LensButtonState();
}

class _LensButtonState extends State<_LensButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: widget.on
                ? t.wissenSoft
                : _hover
                    ? t.surface2
                    : t.surface,
            border: Border.all(
                color: widget.on ? t.wissen : t.borderStrong),
            borderRadius: BorderRadius.circular(BookClothTokens.radiusXs),
          ),
          child: Text(
            widget.label,
            style: AppTextStyles.button.copyWith(
              fontSize: 13,
              color: widget.on ? t.wissenInk : t.ink,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Abschnitt (amodSection, views_analyse.js:177-218)
// ---------------------------------------------------------------------------

class _AmodSection extends ConsumerWidget {
  const _AmodSection({
    required this.unit,
    required this.chapter,
    required this.lens,
  });

  final Unit unit;
  final Chapter chapter;
  final String? lens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final domain = ref.watch(studioDomainProvider);
    final snapshot =
        ref.watch(studioKvProvider).value ?? const <String, Object?>{};
    final defs = ref.watch(dockDefsProvider);
    final figByPara = ref.watch(figByParaProvider);
    final tabByPara = ref.watch(tabByParaProvider);
    final resolver = richResolverFor(domain);

    final label = unit.isIntro ? 'Kapitel ${chapter.num}' : unit.id;
    final title = unit.isIntro ? chapter.title : unit.title;

    final callbacks = RichTextCallbacks(
      onFnTap: (fn) => showFootnoteModal(context, fn),
      onXrefTap: (sec) => context.go(Routes.studioPath(sec: sec)),
    );

    // `.amod-p`: 14/1.75.
    final pStyle = AppTextStyles.body
        .copyWith(fontSize: 14, height: 1.75, color: t.ink);
    // `.amod-list`: 14/1.7.
    final listStyle = AppTextStyles.body
        .copyWith(fontSize: 14, height: 1.7, color: t.ink);

    Widget? expl(Paragraph p) {
      if (lens == null || domain == null) return null;
      final md = _explMd(domain, snapshot, lens!, unit.id, p);
      if (md.isEmpty) return null;
      // `.amod-exp`: wissen-Leiste links, wissen-soft, Radius 0/10/10/0.
      return Container(
        margin: const EdgeInsets.fromLTRB(0, 6, 0, 14),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: t.wissenSoft,
          border: Border(left: BorderSide(color: t.wissen, width: 3)),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // `.ae-t`: 650 10/1.4 uppercase wissen-ink.
            Text(
              dockLabelOf(defs, lens!).toUpperCase(),
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontFamilyFallback: AppFonts.fallback,
                fontWeight: FontWeight.w600,
                fontSize: 10,
                height: 1.4,
                letterSpacing: .09 * 10,
                color: t.wissenInk,
              ),
            ),
            const SizedBox(height: 2),
            MiniMd(md,
                baseStyle: AppTextStyles.small
                    .copyWith(fontSize: 13, height: 1.6, color: t.ink)),
          ],
        ),
      );
    }

    final children = <Widget>[
      // h3: mono-Label (wissen-ink) + Titel + ⌖ Studio.
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Text(label,
            style: AppTextStyles.mono
                .copyWith(fontSize: 12, color: t.wissenInk)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              style: AppTextStyles.h3.copyWith(color: t.ink)),
        ),
        AppButton(
          small: true,
          onPressed: () => context.go(Routes.studioPath(
              sec: unit.id, modus: StudioModes.pruefen)),
          child: const Text('⌖ Studio'),
        ),
      ]),
    ];

    for (final p in unit.paragraphs) {
      final fig = figByPara[p.id];
      final tab = tabByPara[p.id];

      if (p.typeEnum == ParagraphType.figure) {
        children.add(fig != null
            ? FigureCard(fig,
                onQuelleTap: (srcId) =>
                    context.go(Routes.quellenPath(srcId)))
            : _figMissing(t, '🖼 Abbildung', p.text, resolver, callbacks));
        continue;
      }
      if (p.typeEnum == ParagraphType.table) {
        children.add(tab != null
            ? TableCard(tab)
            : _figMissing(t, '▦ Tabelle', p.text, resolver, callbacks));
        continue;
      }
      if (p.typeEnum == ParagraphType.list) {
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 0, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final it in p.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('•  ', style: listStyle),
                        Expanded(
                          child: RichTextView(
                            it,
                            style: listStyle,
                            options: const RichTextOptions(
                                fnStyle: FnStyle.mini, xrefs: true),
                            resolver: resolver,
                            callbacks: callbacks,
                          ),
                        ),
                      ]),
                ),
            ],
          ),
        ));
      } else {
        final text = stripFigMarker(p.text);
        if (text.trim().isNotEmpty) {
          children.add(Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 4),
            child: RichTextView(
              text,
              style: pStyle,
              options:
                  const RichTextOptions(fnStyle: FnStyle.mini, xrefs: true),
              resolver: resolver,
              callbacks: callbacks,
            ),
          ));
        }
      }

      final ex = expl(p);
      if (ex != null) children.add(ex);
      if (fig != null) {
        children.add(FigureCard(fig,
            onQuelleTap: (srcId) => context.go(Routes.quellenPath(srcId))));
      }
      if (tab != null) children.add(TableCard(tab));
    }

    return WissenCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  /// `.fig-missing`-Platzhalter (gestrichelt, eyebrow + Rohtext).
  Widget _figMissing(BookClothTokens t, String eyebrow, String text,
      RichTextResolver resolver, RichTextCallbacks callbacks) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 16, 0, 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface2,
        border: Border.all(color: t.borderStrong, width: 1.5),
        borderRadius: BorderRadius.circular(BookClothTokens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WissenEyebrow(eyebrow),
          const SizedBox(height: 6),
          RichTextView(
            text,
            style: AppTextStyles.small.copyWith(color: t.ink2),
            options: const RichTextOptions(fnStyle: FnStyle.mini),
            resolver: resolver,
            callbacks: callbacks,
          ),
        ],
      ),
    );
  }
}
