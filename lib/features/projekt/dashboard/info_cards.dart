/// Rechte Dashboard-Spalte: „Connections“-Karte (views_projekt.js:226-240)
/// und „Anleitung — wie die Teile zusammenspielen“ (:242-267) mit den vier
/// nativen `<details>`-Akkordeons.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/accordion.dart';
import '../../../core/widgets/chips.dart';
import '../../../data/db/kv.dart';
import '../../quellen/state/quellen_kv.dart';
import 'dash_card.dart';

// ---------------------------------------------------------------------------
// Connections
// ---------------------------------------------------------------------------

class ConnectionsCard extends ConsumerWidget {
  const ConnectionsCard({super.key, required this.domain});

  final QuellenDomain domain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    // `U.storeGet('kiConnections')` — importierte KI-Kanten aus dem
    // KV-Schnappschuss (views_projekt.js:227).
    ref.watch(quellenKvProvider);
    final kiRaw = ref
        .watch(quellenKvProvider.notifier)
        .readMap(KvKeys.kiConnections)['connections'];
    final kiConn = kiRaw is List ? kiRaw.length : 0;
    final bundled = domain.runtime.meta.connections?.connections.length ?? 0;

    return ProjektCard(
      eyebrow: 'Connections — inhaltliche Verbindungen',
      children: [
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(children: [
            const TextSpan(
                text: 'Querverweise und Fazit-Herleitungen erkennt die '
                    'Software selbst. Zusätzliche '),
            TextSpan(
                text: 'KI-Connections',
                style: TextStyle(fontWeight: FontWeight.w700, color: t.ink2)),
            const TextSpan(
                text: ' (Folgerung, Wiederaufgriff, Grundlage, Vergleich) '
                    'erscheinen in der ⤳ Connections-Instanz neben den '
                    'Absätzen.'),
          ]),
          style: AppTextStyles.small.copyWith(color: t.muted),
        ),
        const SizedBox(height: 8),
        Row(
          spacing: 8,
          children: [
            AppChip(label: '$bundled aus Voranalyse'),
            AppChip(
              label: '$kiConn importiert',
              variant: kiConn > 0 ? AppChipVariant.ok : AppChipVariant.neutral,
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Anleitung
// ---------------------------------------------------------------------------

class AnleitungCard extends StatelessWidget {
  const AnleitungCard({super.key});

  /// Externe Doku — im Original relative Repo-Links (`docs/…`); die App hat
  /// kein eigenes docs-Verzeichnis, daher zeigen die Links auf die
  /// veröffentlichte Web-Version (minimal angepasst, sonst tote Links).
  static const _docsBase = 'https://robinkarner.github.io/thesoR/docs/';

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    TextStyle small = AppTextStyles.small.copyWith(color: t.ink2, height: 1.55);
    TextSpan code(String s) => TextSpan(
          text: s,
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontFamilyFallback: AppFonts.fallback,
            fontSize: 12,
          ),
        );
    TextSpan b(String s) =>
        TextSpan(text: s, style: const TextStyle(fontWeight: FontWeight.w700));

    Widget acc(String title, InlineSpan body) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Accordion(
            title: Text(title),
            body: Text.rich(TextSpan(children: [body]), style: small),
          ),
        );

    return ProjektCard(
      eyebrow: 'Anleitung — wie die Teile zusammenspielen',
      children: [
        acc(
          'GPT-Voranalyse (Basis)',
          TextSpan(children: [
            const TextSpan(text: 'Die Voranalyse liegt in '),
            code('data/generated/'),
            const TextSpan(
                text: ' (bzw. im Import der Arbeit): je Abschnitt '
                    'Kernaussagen, Satz-Markierungen und '),
            b('Belege'),
            const TextSpan(
                text: ' (Claim + vermutete Fundstelle + Suchbegriffe je '
                    'Fußnote), je Quelle ein Dossier, dazu Zusammenfassungen, '
                    'Fazit-Connections und KI-Connections. Alles Weitere '
                    '(Zitate, Positionen, Markierungen) entsteht beim Prüfen '
                    'und bleibt im Browser — pro Arbeit getrennt.'),
          ]),
        ),
        acc(
          'Nachladbare Analysen (Resolutions)',
          TextSpan(children: [
            const TextSpan(text: 'Eine '),
            const TextSpan(
                text: 'Resolution',
                style: TextStyle(fontStyle: FontStyle.italic)),
            const TextSpan(text: ' ('),
            code('docs/resolution.schema.json'),
            const TextSpan(
                text: ') trägt je Fußnote Seite/Fundstelle + Zitat + Status '
                    'nach. Import je Quelle in der Bibliothek oder als Datei '),
            code('data/resolutions/<id>.json'),
            const TextSpan(
                text: ' (wird automatisch erkannt). Manuell Erfasstes hat '
                    'Vorrang.'),
          ]),
        ),
        acc(
          'GPT — überall dasselbe Muster',
          TextSpan(children: [
            const TextSpan(text: 'Jeder GPT-Dialog sagt oben, '),
            b('was der Prompt enthält'),
            const TextSpan(text: ' und '),
            b('wohin die Antwort fließt'),
            const TextSpan(
                text: ' — Prompt kopieren und Antwort importieren passieren '
                    'immer im SELBEN Dialog. '),
            b('Neue Arbeit komplett:'),
            const TextSpan(text: ' „Gesamt-Prompt“ an der Arbeit (rechts). '),
            b('Alles andere:'),
            const TextSpan(text: ' GPT-Knopf oben in der Kopfleiste. '),
            b('Je Quelle (Fundstellen):'),
            const TextSpan(text: ' 🤖 GPT hier oder auf der Quellenseite. '),
            b('Neue Quelle:'),
            const TextSpan(text: ' 🤖 Ergänzung (Quellenseite). '),
            b('Connections:'),
            const TextSpan(text: ' rechts. '),
            b('Markierungen:'),
            const TextSpan(text: ' Studio → 🖍.'),
          ]),
        ),
        acc(
          'Sichern & Umziehen',
          const TextSpan(
              text: 'Bibliothek → „⭳ Sichern“ exportiert den Prüfstand der '
                  'aktiven Arbeit (Status, Zitate, Markierungen, Links, '
                  'Notizen) als eine JSON-Datei. Arbeiten selbst lassen sich '
                  'rechts einzeln exportieren/importieren.'),
        ),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Mehr: '),
            _link(context, 'PROJEKT-FORMAT.md ↗', '${_docsBase}PROJEKT-FORMAT.md'),
            const TextSpan(text: ' · '),
            _link(context, 'QUELLEN-WORKFLOW.md ↗', '${_docsBase}QUELLEN-WORKFLOW.md'),
          ]),
          style: AppTextStyles.small.copyWith(color: t.muted),
        ),
      ],
    );
  }

  static InlineSpan _link(BuildContext context, String label, String url) {
    final t = BookClothTokens.of(context);
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => launchUrl(Uri.parse(url)),
          child: Text(
            label,
            style: AppTextStyles.small.copyWith(
              color: t.accentInk,
              decoration: TextDecoration.underline,
              decorationColor: t.accentLine,
            ),
          ),
        ),
      ),
    );
  }
}
