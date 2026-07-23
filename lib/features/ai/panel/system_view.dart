/// ⧈ System-Ansicht — Port von `Enhance._showSystem` (enhance.js:546-580):
/// das GLOBALE Bild — wie alle Datenpakete zusammenhängen, von der Ground
/// Truth bis zu den Ansichten; darunter die klickbaren Datenpaket-Karten.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/bundles/indexes.dart';
import '../flows/ai_flow.dart';
import '../flows/registry.dart';

class EnhanceSystemView extends ConsumerWidget {
  const EnhanceSystemView({super.key, required this.ctx, required this.onOpenFlow});

  final AiFlowCtx ctx;
  final ValueChanged<String> onOpenFlow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    watchAiSources(ref);
    final container = ProviderScope.containerOf(context, listen: false);
    final flows = [
      for (final f in buildAiFlows(container, ctx))
        if (!f.toggle) f,
    ];
    final meta = ref.watch(activeRuntimeProvider)?.thesis.meta;

    final h4 = TextStyle(
      fontFamily: AppFonts.ui,
      fontFamilyFallback: AppFonts.fallback,
      fontWeight: FontWeight.w600,
      fontSize: 13.5,
      height: 1.25,
      color: t.ink,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Kopf
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('⧈', style: TextStyle(fontSize: 26, height: 1)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Datenflüsse — wie alles zusammenhängt',
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontFamilyFallback: AppFonts.fallback,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      height: 1.25,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Jede KI-Funktion ist ein klar definiertes Datenpaket. Nichts wird erfunden: die KI schlägt vor, der Mensch belegt.',
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontFamilyFallback: AppFonts.fallback,
                      fontSize: 12.5,
                      height: 1.45,
                      color: t.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('Das globale Bild', style: h4),
        const SizedBox(height: 8),
        // `.sys-flow` — vertikale Kette aus Nodes + Links.
        _node(t, 'Σ', accent: t.accent, boldText: 'Ground Truth: das LaTeX der Arbeit',
            rest:
                '„${meta?.title ?? 'aktive Arbeit'}“ — bleibt unverändert gespeichert. Fußnoten-Arbeiten (EHDS) und \\cite-Paper (Sensors) werden beim Parsen auf EIN internes Format normalisiert — alle Funktionen arbeiten syntax-unabhängig.'),
        _link(t, 'plus Notation-Docs (Formatvorgabe) + Verzeichnis-/Titel-Attribute'),
        _node(t, '⧉', boldText: 'Prompt je Datenpaket',
            rest:
                'Formatvorgabe + Notation + die jeweils nötigen Daten — je Stelle einsehbar (ⓘ) und anpassbar (⚙).'),
        _link(t, 'extern kopieren · eigener Claude-Key · AI-Space (Anbieter)'),
        _node(t, '◆', accent: t.ki, boldText: 'Modell erzeugt die Antwort',
            rest:
                'extern (GPT/Claude/…) oder direkt hier mit Live-Kosten. Demo-Modus simuliert ehrlich, importiert aber nie erfundene Daten.'),
        _link(t, '✓ Format-Checker prüft VOR dem Übernehmen'),
        _node(t, '⭱', accent: t.good, boldText: 'Import in den Prüfstand',
            rest:
                'Jedes Paket hat seinen festen Speicherort — alles bleibt lokal, exportierbar, ersetzbar. Der Status springt nachvollziehbar ✦ vermutet → ❝ Original → ✓ belegt.'),
        const SizedBox(height: 14),
        Text('Die Datenpakete im Einzelnen', style: h4),
        const SizedBox(height: 8),
        // `.sys-grid` — klickbare Karten.
        LayoutBuilder(builder: (context, box) {
          final cols = (box.maxWidth / 215).floor().clamp(1, 4);
          final w = (box.maxWidth - (cols - 1) * 7) / cols;
          return Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final f in flows)
                SizedBox(
                  width: w,
                  child: _SysCard(flow: f, onTap: () => onOpenFlow(f.id)),
                ),
            ],
          );
        }),
        const SizedBox(height: 10),
        Text(
          'Klick auf ein Paket öffnet die Funktion. Die eingebauten Arbeiten bringen ihre Voranalyse mit; eigene .tex-Arbeiten erzeugen sie über ⚡ Voranalyse.',
          style: AppTextStyles.small.copyWith(color: t.muted),
        ),
      ],
    );
  }

  /// `.sys-node[.gt|.ki|.ok]` — Karte mit 3px-Farbkante links.
  Widget _node(BookClothTokens t, String ic,
      {Color? accent, required String boldText, required String rest}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(
          left: accent != null
              ? BorderSide(color: accent, width: 3)
              : BorderSide(color: t.borderStrong),
          top: BorderSide(color: t.borderStrong),
          right: BorderSide(color: t.borderStrong),
          bottom: BorderSide(color: t.borderStrong),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(ic,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, height: 1.3)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: boldText,
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13, color: t.ink),
                ),
                const TextSpan(text: '\n'),
                TextSpan(text: rest),
              ]),
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontFamilyFallback: AppFonts.fallback,
                fontWeight: FontWeight.w500,
                fontSize: 12.5,
                height: 1.45,
                color: t.ink2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// `.sys-link` — Verbinder-Zeile mit kleinem Steg.
  Widget _link(BookClothTokens t, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 22, top: 1, bottom: 1),
      child: Row(
        children: [
          Container(
            width: 2,
            height: 16,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: t.borderStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontFamilyFallback: AppFonts.fallback,
                fontWeight: FontWeight.w500,
                fontSize: 10.5,
                height: 1.6,
                color: t.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `.sys-card` — Datenpaket-Karte (Icon · Titel · Stat + in→ziel).
class _SysCard extends StatefulWidget {
  const _SysCard({required this.flow, required this.onTap});

  final AiFlow flow;
  final VoidCallback onTap;

  @override
  State<_SysCard> createState() => _SysCardState();
}

class _SysCardState extends State<_SysCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final f = widget.flow;
    final sub = f.paket != null
        ? '${f.paket!.input.join(' + ')} → ${f.paket!.ziel}'
        : f.erzeugt;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: _hover ? t.surface : t.surface2,
            border: Border.all(color: _hover ? t.accent : t.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(f.icon, style: const TextStyle(fontSize: 14, height: 1)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      f.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontFamilyFallback: AppFonts.fallback,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        height: 1.3,
                        color: t.ink,
                      ),
                    ),
                  ),
                  Text(
                    f.stat?.call() ?? '',
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontFamilyFallback: AppFonts.fallback,
                      fontWeight: FontWeight.w600,
                      fontSize: 10.5,
                      height: 1,
                      color: t.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                sub,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: 11.5,
                  height: 1.45,
                  color: t.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
