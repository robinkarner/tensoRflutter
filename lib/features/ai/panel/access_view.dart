/// 🔑 Zugang-Ansicht — Port von `Enhance._showAccess` (enhance.js:583-610):
/// die drei Wege zur Magie — transparent nebeneinander; die aktive Karte
/// trägt den grünen Ring (`.acc-card.active`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/color_mix.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/chips.dart';
import '../client/claude_cfg.dart';
import 'claude_cfg_form.dart';

class EnhanceAccessView extends ConsumerWidget {
  const EnhanceAccessView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final cfg = ref.watch(claudeCfgStoreProvider).value ?? ClaudeCfg.defaults;
    final hasKey = cfg.hasAccess;
    final viaProxy = hasKey && cfg.apiKey.trim().isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🔑', style: TextStyle(fontSize: 26, height: 1)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zugang — drei Wege zur Magie',
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
                    'Alle drei nutzen DIESELBEN Prompts und DENSELBEN Format-Checker — nur der Weg zum Modell unterscheidet sich.',
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
        const SizedBox(height: 12),
        _AccCard(
          active: !hasKey,
          head: Row(
            children: [
              Text('⧉ Extern kopieren', style: _headStyle(t)),
              const SizedBox(width: 8),
              const AppChip(label: 'gratis', mini: true),
              if (!hasKey) ...[
                const SizedBox(width: 5),
                const AppChip(
                    label: 'aktiv nutzbar', mini: true, variant: AppChipVariant.ok),
              ],
            ],
          ),
          body:
              '„⧉ Kopieren“ gibt den kompletten Prompt an ein beliebiges GPT (ChatGPT, Claude.ai, …). Die Antwort hier einfügen, mit „✓ Prüfen“ checken, dann „⭱ Übernehmen“. Funktioniert immer — ohne Konto, ohne Kosten in der App.',
        ),
        const SizedBox(height: 8),
        _AccCard(
          active: hasKey && !viaProxy,
          head: Row(
            children: [
              Text('🔑 Eigener Claude-Zugang', style: _headStyle(t)),
              if (hasKey && !viaProxy) ...[
                const SizedBox(width: 8),
                const AppChip(
                    label: 'verbunden', mini: true, variant: AppChipVariant.ok),
              ],
            ],
          ),
          body:
              'Eigener API-Key — bleibt lokal in diesem Browser und geht ausschließlich an die eingestellte Adresse. „Mit Claude“ streamt die Antwort direkt ins Feld, mit Live-Token- und Kostenanzeige vor und nach jedem Lauf.',
          form: const Padding(
            padding: EdgeInsets.only(top: 9),
            child: ClaudeCfgForm(),
          ),
        ),
        const SizedBox(height: 8),
        _AccCard(
          active: viaProxy,
          soon: viaProxy ? 'verbunden' : 'in Vorbereitung',
          head: Row(
            children: [
              Flexible(
                  child:
                      Text('☁ Thesis-Studio AI-Space', style: _headStyle(t))),
              const SizedBox(width: 8),
              const AppChip(label: '≈ 1 € / Durchlauf', mini: true),
            ],
          ),
          body:
              'Zentral über den Anbieter: jede:r Nutzer:in bekommt einen eigenen AI-Space — ein abgeschottetes Arbeitsverzeichnis mit den eigenen Daten, der Notation und dem vorab generierten Verzeichnis. Claude arbeitet nur in diesem Verzeichnis (kein Zugriff darüber hinaus), der Key bleibt serverseitig. In der App erscheint nur der Fixpreis. Technisch läuft das über die Basis-URL im Formular oben — sobald der Space bereitsteht, einfach die zugeteilte Adresse eintragen. Bis dahin lässt sich der komplette Ablauf gefahrlos im Demo-Modus durchspielen (Haken im Formular oben): „Mit Claude“ streamt dann eine ehrlich gekennzeichnete Simulation, importiert aber nie erfundene Daten.',
        ),
      ],
    );
  }

  TextStyle _headStyle(BookClothTokens t) => TextStyle(
        fontFamily: AppFonts.ui,
        fontFamilyFallback: AppFonts.fallback,
        fontWeight: FontWeight.w700,
        fontSize: 13.5,
        height: 1.3,
        color: t.ink,
      );
}

/// `.acc-card[.active]` — Karte, aktiv mit gutem Ring + „soon“-Sticker.
class _AccCard extends StatelessWidget {
  const _AccCard({
    required this.active,
    required this.head,
    required this.body,
    this.form,
    this.soon,
  });

  final bool active;
  final Widget head;
  final String body;
  final Widget? form;
  final String? soon;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(
                color: active ? t.good.mix(t.borderStrong, 55) : t.borderStrong),
            borderRadius: BorderRadius.circular(11),
            boxShadow: active
                ? [BoxShadow(color: t.good.alphaPct(10), spreadRadius: 3)]
                : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              head,
              const SizedBox(height: 5),
              Text(
                body,
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: 12.5,
                  height: 1.55,
                  color: t.muted,
                ),
              ),
              ?form,
            ],
          ),
        ),
        if (soon != null)
          Positioned(
            top: -7,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: t.accentSoft,
                border: Border.all(color: t.accentLine),
                borderRadius: BorderRadius.circular(BookClothTokens.radiusPill),
              ),
              child: Text(
                soon!.toUpperCase(),
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontFamilyFallback: AppFonts.fallback,
                  fontWeight: FontWeight.w700,
                  fontSize: 9.5,
                  height: 1,
                  letterSpacing: .07 * 9.5,
                  color: t.accentInk,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
