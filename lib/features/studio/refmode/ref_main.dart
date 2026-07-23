/// Rechte Seite des Referenzierungsmodus — Port von `refShowSource`
/// (views_studio.js:1922-2026) samt `.ref-pdfbar`/`.ref-pdfhost`/`.ref-law`
/// (app.css:696-711):
///
/// Kopfleiste: kompakter Quell-Streifen (Titel · Autoren · Jahr) + 📚 Dossier,
/// dann die Ansichten-Tabs 「📄 PDF」「☰ Text」[「§ Register」] + ↗ offizielle
/// Seite + „Datei …“ (transiente Zuordnungs-Ansicht — wird NIE als Standard
/// gemerkt). Darunter je Ansicht: PDF-Engine (markierbar, onCapture →
/// aktiver Beleg) · markierbarer Quellentext · Fundstellen-Register
/// (Rechtsquellen, max. 18 Zeilen) · AssignPanel.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../data/bundles/indexes.dart';
import '../../../data/repos/project_repository.dart';
import '../../pdf/pdf.dart';
import '../layout/studio_state.dart';
import 'provision_register.dart';
import 'ref_mode.dart';
import 'src_text_pane.dart';

class RefMain extends ConsumerWidget {
  const RefMain({super.key, required this.screen, required this.srcId});

  final RefModeScreenState screen;
  final String srcId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final domain = ref.watch(studioDomainProvider);
    final src = ref.watch(srcByIdProvider)[srcId];
    if (domain == null) return const SizedBox.shrink();

    final isLaw = src != null &&
        (src.kind == 'recht-eu' || src.kind == 'recht-at');
    final view = screen.viewFor(srcId, isLaw: isLaw);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- ref-pdfbar -----------------------------------------------------
        Container(
          padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border(bottom: BorderSide(color: t.border)),
          ),
          child: Row(
            children: [
              Flexible(child: _SrcStrip(srcId: srcId)),
              const SizedBox(width: 9),
              AppButton(
                small: true,
                tooltip: '📚 Dossier dieser Quelle anzeigen',
                onPressed: src == null
                    ? null
                    : () => showDossierModal(
                          context,
                          source: src,
                          onQuellenseite: () =>
                              context.go(Routes.quellenPath(srcId)),
                        ),
                child: const Text('📚'),
              ),
              const Spacer(),
              _tab(context, 'pdf', '📄 PDF', 'PDF mit Markieren', view),
              const SizedBox(width: 5),
              _tab(context, 'text', '☰ Text',
                  'Hinterlegter Quellentext — Auswahl übernimmt das Zitat', view),
              if (isLaw) ...[
                const SizedBox(width: 5),
                _tab(context, 'register', '§ Register',
                    'Fundstellen-Register (Art/§ → wo verwendet)', view),
              ],
              if (src != null) _OfficialLink(srcId: srcId),
              const SizedBox(width: 5),
              AppButton(
                small: true,
                tooltip:
                    'Datei-Zuordnung direkt hier: prüfen, ersetzen, entfernen',
                onPressed: () =>
                    screen.showSource(srcId, forceView: 'datei'),
                child: const Text('Datei …'),
              ),
            ],
          ),
        ),
        // ---- ref-pdfhost ----------------------------------------------------
        Expanded(
          child: ColoredBox(
            color: t.surface2,
            child: _host(context, ref, t, domain, view, isLaw),
          ),
        ),
      ],
    );
  }

  Widget _tab(BuildContext context, String v, String label, String tooltip,
      String current) {
    return AppButton(
      small: true,
      variant: current == v ? AppButtonVariant.primary : AppButtonVariant.solid,
      tooltip: tooltip,
      onPressed: () => screen.showSource(srcId, forceView: v),
      child: Text(label),
    );
  }

  Widget _host(BuildContext context, WidgetRef ref, BookClothTokens t,
      StudioDomain domain, String view, bool isLaw) {
    // Transiente Datei-Zuordnung (`datei`).
    if (view == 'datei') {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: AssignPanel(
          srcId: srcId,
          onDone: () {
            screen.invalidateProbe(srcId);
            screen.showSource(srcId);
          },
          onCancel: () => screen.showSource(srcId),
          onMeta: () => screen.invalidateProbe(srcId),
        ),
      );
    }

    if (view == 'register') {
      return _register(context, ref, t, domain);
    }

    if (view == 'text') {
      return SrcTextPane(
        srcId: srcId,
        activeInfo: screen.activeInfo,
        onQuote: (text) {
          final a = screen.activeInfo();
          if (a == null) return;
          screen.zitatCtl(a.fn).text = text;
          screen.saveItem(a.fn, srcId);
        },
        onChanged: () => screen.invalidateProbe(srcId),
      );
    }

    // PDF-Ansicht — Startseite: erste Markierung des aktiven Belegs, sonst
    // gespeicherte Seite, sonst 1.
    final probe = screen.hasPdfOf(srcId);
    if (probe == null) {
      return Center(
        child: Text('Lade Datei …',
            style: AppTextStyles.small.copyWith(color: t.muted)),
      );
    }
    if (!probe) {
      // `PdfEngine.missingInfo`-Pendant: keine Datei — direkt zuordnen.
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('▣', style: TextStyle(fontSize: 34, color: t.muted)),
            const SizedBox(height: 8),
            Text('Keine Datei zu dieser Quelle',
                style: AppTextStyles.small
                    .copyWith(fontWeight: FontWeight.w600, color: t.ink2)),
            const SizedBox(height: 4),
            Text(
              'PDF zuordnen oder Quellentext unter ☰ Text hinterlegen — beides ist markierbar.',
              textAlign: TextAlign.center,
              style: AppTextStyles.small.copyWith(color: t.muted),
            ),
            const SizedBox(height: 10),
            AppButton(
              small: true,
              variant: AppButtonVariant.primary,
              onPressed: () => screen.showSource(srcId, forceView: 'datei'),
              child: const Text('Datei …'),
            ),
          ],
        ),
      );
    }

    var startPage = 1;
    final fn = screen.activeFn;
    if (fn != null) {
      final marks =
          ref.read(levelsMarksForFnProvider)?.call(srcId, fn) ?? const [];
      final pg = marks.isNotEmpty
          ? marks.first.page
          : domain.levels.info(fn).seite;
      final pgNum = pg is num ? pg.toInt() : int.tryParse('$pg');
      if (pgNum != null && pgNum > 0) startPage = pgNum;
    }

    return PdfEngineView(
      key: ValueKey('ref-pdf-$srcId'),
      srcId: srcId,
      page: startPage,
      controller: screen.engine,
      getActive: screen.activeInfo,
      onCapture: screen.onCapture,
    );
  }

  /// `§ Register` (:1982-1993): Hinweis-Notice + Fundstellen-Register
  /// (max. 18 Zeilen) + Link auf die Quellenseite.
  Widget _register(BuildContext context, WidgetRef ref, BookClothTokens t,
      StudioDomain domain) {
    final src = ref.watch(srcByIdProvider)[srcId];
    final provs = provisionRegister(src);
    final repo = ref.read(projectRepositoryProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FutureBuilder<EffectiveSrcLinks>(
            future: src == null ? null : repo.srcLinks(src),
            builder: (context, snap) {
              final hasOfficial =
                  (snap.data?.official ?? '').isNotEmpty;
              return Container(
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                decoration: BoxDecoration(
                  color: t.surface2,
                  border: Border(
                      left: BorderSide(color: t.accent, width: 3)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text.rich(
                  TextSpan(children: [
                    const TextSpan(
                        text: 'Rechtsquelle — der Nachweis läuft über die '),
                    const TextSpan(
                        text: 'Fundstelle',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const TextSpan(
                        text: ' (Art/§), links direkt am Zitierelement. '),
                    if (hasOfficial)
                      const TextSpan(
                          text:
                              'Der ↗-Link öffnet die konsolidierte Fassung (EUR-Lex/RIS); dort mit Strg F suchen. '),
                    const TextSpan(
                        text: 'Alternativ: konsolidierte Fassung als '),
                    const TextSpan(
                        text: 'PDF',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const TextSpan(
                        text: ' zuordnen oder den Gesetzestext unter '),
                    const TextSpan(
                        text: '☰ Text',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const TextSpan(
                        text: ' hinterlegen — beides ist markierbar.'),
                  ]),
                  style: AppTextStyles.small
                      .copyWith(height: 1.55, color: t.ink2),
                ),
              );
            },
          ),
          if (provs.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
              child: Text('FUNDSTELLEN-REGISTER DIESER QUELLE',
                  style: AppTextStyles.eyebrow.copyWith(color: t.muted)),
            ),
            for (final pr in provs.take(18))
              Container(
                padding: const EdgeInsets.fromLTRB(2, 6, 2, 6),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: t.border)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    SizedBox(
                      width: 74,
                      child: Text(
                        pr.key,
                        style: TextStyle(
                          fontFamily: AppFonts.mono,
                          fontFamilyFallback: AppFonts.fallback,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: t.accentInk,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${pr.cites.length}× zitiert · ${({for (final c in pr.cites) c.sectionId}.toList()..removeWhere((x) => x.isEmpty)).take(5).join(', ')}',
                        style:
                            AppTextStyles.small.copyWith(color: t.muted),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Vollständig auf der '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).maybePop();
                          context.go(Routes.quellenPath(srcId));
                        },
                        child: Text('Quellenseite',
                            style: AppTextStyles.small
                                .copyWith(color: t.accentInk)),
                      ),
                    ),
                  ),
                  const TextSpan(text: '.'),
                ]),
                style: AppTextStyles.small.copyWith(color: t.muted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Kompakter Quell-Streifen (`U.srcStripHtml`-Pendant): id (Mono) · Titel ·
/// Autoren/Jahr.
class _SrcStrip extends ConsumerWidget {
  const _SrcStrip({required this.srcId});

  final String srcId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final s = ref.watch(srcByIdProvider)[srcId];
    final sub = [
      if ((s?.author ?? '').isNotEmpty) s!.author!,
      if (s?.year != null) '${s!.year}',
    ].join(' · ');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          srcId,
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontFamilyFallback: AppFonts.fallback,
            fontWeight: FontWeight.w600,
            fontSize: 11.5,
            color: t.accentInk,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            s?.title ?? srcId,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.small.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: t.ink,
            ),
          ),
        ),
        if (sub.isNotEmpty) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.small
                    .copyWith(fontSize: 12, color: t.muted)),
          ),
        ],
      ],
    );
  }
}

/// ↗ Offizielle Seite (Link-Kaskade Override > doi.org > url).
class _OfficialLink extends ConsumerWidget {
  const _OfficialLink({required this.srcId});

  final String srcId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final src = ref.watch(srcByIdProvider)[srcId];
    if (src == null) return const SizedBox.shrink();
    final repo = ref.read(projectRepositoryProvider);
    return FutureBuilder<EffectiveSrcLinks>(
      future: repo.srcLinks(src),
      builder: (context, snap) {
        final url = snap.data?.official;
        if (url == null || url.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(left: 5),
          child: AppButton(
            small: true,
            tooltip: '↗ Offizielle Seite öffnen: $url',
            onPressed: () => launcher.launchUrl(Uri.parse(url),
                mode: launcher.LaunchMode.externalApplication),
            child: const Text('↗'),
          ),
        );
      },
    );
  }
}
