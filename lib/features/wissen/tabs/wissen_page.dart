/// Seitenrahmen der Wissen-Welt — `renderAnalyse` (views_analyse.js:19-50).
///
/// Kopf: h1 „Wissen“ (wissen-ink) + Chip „✦ Cross-Projekt-Informations-
/// speicher“ + Untertitel. Darunter die Tab-Leiste in DREI beschrifteten
/// Clustern (`.a-tabgroups`, app.css:803-807):
///
///   SCHNELLVERSTÄNDNIS   📓 Erklärbuch · 🔬 Analysemodus · 🌐 Übersetzung & Instanzen
///   ZUSAMMENHÄNGE & THEMA Überblick · Kapitel · Connections · Kennzahlen
///   BEWERTUNG            ⚖ Würdigung
///
/// Aktiver Tab: wissen-ink, 2px-Unterkante in wissen, Fläche wissen-soft
/// (app.css:1241). Tab und Argument leben in der Route
/// (`/analyse/:tab/:arg` — jede Navigation rendert den Tab-Body neu).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../analysemodus/analysemodus_tab.dart';
import '../notebook/erklaerbuch_tab.dart';
import 'fazit_tab.dart';
import 'instanzen_tab.dart';
import 'kapitel_tab.dart';
import 'kennzahlen_tab.dart';
import 'ueberblick_tab.dart';
import 'wuerdigung_tab.dart';

/// Cluster-Definition (views_analyse.js:27-31 — Labels/Reihenfolge exakt).
const List<(String, List<(String, String)>)> wissenTabGroups = [
  (
    'Schnellverständnis',
    [
      ('buch', '📓 Erklärbuch'),
      ('modus', '🔬 Analysemodus'),
      ('instanzen', '🌐 Übersetzung & Instanzen'),
    ]
  ),
  (
    'Zusammenhänge & Thema',
    [
      ('ueberblick', 'Überblick'),
      ('kapitel', 'Kapitel'),
      ('fazit', 'Connections'),
      ('kennzahlen', 'Kennzahlen'),
    ]
  ),
  ('Bewertung', [('wuerdigung', '⚖ Würdigung')]),
];

class WissenPage extends ConsumerWidget {
  const WissenPage({super.key, this.tab, this.arg});

  final String? tab;
  final String? arg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final active = (tab == null || tab!.isEmpty) ? 'ueberblick' : tab!;

    // `Number(arg) || 0` bzw. `|| 6` — '0'/Nicht-Zahl fällt auf den Default.
    int numArg(int fallback) {
      final n = int.tryParse(arg ?? '') ?? 0;
      return n == 0 ? fallback : n;
    }

    final body = switch (active) {
      'modus' => AnalysemodusTab(chNum: numArg(0)),
      'buch' => const ErklaerbuchTab(),
      'instanzen' => InstanzenTab(modeArg: arg),
      'kapitel' => KapitelTab(chNum: numArg(6)),
      'fazit' => const FazitTab(),
      'wuerdigung' => const WuerdigungTab(),
      'kennzahlen' => const KennzahlenTab(),
      _ => const UeberblickTab(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // .page-head.wissen-head
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                children: [
                  Text('Wissen',
                      style: AppTextStyles.h1.copyWith(color: t.wissenInk)),
                  // `.chip.wissen-chip`
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9.5, vertical: 4),
                    decoration: BoxDecoration(
                      color: t.wissenSoft,
                      border: Border.all(color: t.wissenLine),
                      borderRadius:
                          BorderRadius.circular(BookClothTokens.radiusPill),
                    ),
                    child: Text(
                      '✦ Cross-Projekt-Informationsspeicher',
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontFamilyFallback: AppFonts.fallback,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        height: 1,
                        color: t.wissenInk,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Text(
                  'Die eigene Welt neben dem Studio — Erklärungsauflösung, '
                  'Buchkapitel, visuell Generiertes (Charts, Tabellen), '
                  'Übersetzungen und Kennzahlen. GPT-generierbar, direkt '
                  'einfügbar, mit den Quellen verbunden.',
                  style: AppTextStyles.body.copyWith(color: t.ink2),
                ),
              ),
            ],
          ),
        ),
        _TabGroups(active: active),
        const SizedBox(height: 18),
        body,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab-Leiste (.a-tabgroups)
// ---------------------------------------------------------------------------

class _TabGroups extends StatelessWidget {
  const _TabGroups({required this.active});

  final String active;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Wrap(
        spacing: 22,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          for (final (label, items) in wissenTabGroups)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // `.a-tabgroup-l`: 650 9.5/1.4, ls .1em, uppercase, wissen-ink.
                Padding(
                  padding: const EdgeInsets.only(left: 13),
                  child: Opacity(
                    opacity: .8,
                    child: Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontFamilyFallback: AppFonts.fallback,
                        fontWeight: FontWeight.w600,
                        fontSize: 9.5,
                        height: 1.4,
                        letterSpacing: .1 * 9.5,
                        color: t.wissenInk,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  for (final (key, tabLabel) in items)
                    Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: _TabLink(
                        label: tabLabel,
                        active: key == active,
                        onTap: () =>
                            context.go(Routes.analysePath(tab: key)),
                      ),
                    ),
                ]),
              ],
            ),
        ],
      ),
    );
  }
}

/// Ein Tab-Link (`.a-tabs a` — 600 13.5/1, Padding 9/13/11, 2px-Unterkante).
class _TabLink extends StatefulWidget {
  const _TabLink({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_TabLink> createState() => _TabLinkState();
}

class _TabLinkState extends State<_TabLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final color = widget.active
        ? t.wissenInk
        : _hover
            ? t.ink
            : t.muted;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 9, 13, 11),
          decoration: BoxDecoration(
            color: widget.active ? t.wissenSoft : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: widget.active ? t.wissen : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontFamilyFallback: AppFonts.fallback,
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              height: 1,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
