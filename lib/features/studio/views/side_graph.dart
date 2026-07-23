/// ⤳ Connections-Fenster — Port von `sideGraph` (views_studio.js:2296-2337)
/// samt `.para-side.graph`/`.agp` (app.css:1570-1591):
///
/// Kernaussage des Absatzes oben, dann max. 6 absatz-eigene Kanten als
/// farbige Link-Zeilen (3px-Farbkante links, 6%-Wash, Typ-Icon +
/// Richtungs-Label + Ziel-Abschnitt in Mono); beim ERSTEN Absatz des
/// Abschnitts zusätzlich „Abschnitt gesamt“ (dedupliziert, max. 8).
/// Kanten sind Links auf `#/studio/<ziel>/pruefen`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/color_mix.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/models/models.dart';
import '../../../domain/domain.dart';
import '../layout/dock_state.dart';
import '../layout/studio_state.dart';
import 'para_side.dart';

/// Kantenfarben aus dem Token-System (:2299) — „folgerung“ trägt als
/// häufigster Typ die Marken-Terracotta.
Color graphEdgeColor(BookClothTokens t, String typ) => switch (typ) {
      'folgerung' => t.accentInk,
      'grundlage' => t.good,
      'aufgriff' => t.catFrist,
      'vergleich' => t.catAkteur,
      'fazit' => t.catTech,
      'quellen' => t.catNorm,
      _ => t.muted, // xref
    };

class _EdgeRow {
  final ConnectionEdge c;
  final bool out;
  final String other;

  const _EdgeRow({required this.c, required this.out, required this.other});
}

class SideGraph extends ConsumerWidget {
  const SideGraph({
    super.key,
    required this.sectionId,
    required this.paragraph,
    required this.isFirst,
  });

  final String sectionId;
  final Paragraph paragraph;
  final bool isFirst;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final domain = ref.watch(studioDomainProvider);
    final snapshot =
        ref.watch(studioKvProvider).value ?? const <String, Object?>{};
    if (domain == null) return const SizedBox.shrink();

    final connections = Connections(
      domain.ctx,
      StudioDomainStore(snapshot, ref.read(studioKvProvider.notifier)),
    );
    final fs = connections.forSection(sectionId);

    final mine = <_EdgeRow>[];
    final secLevel = <_EdgeRow>[];
    for (final c in fs.out) {
      (c.von.paraId == paragraph.id ? mine : secLevel)
          .add(_EdgeRow(c: c, out: true, other: c.nach.sectionId ?? '?'));
    }
    for (final c in fs.inbound) {
      (c.nach.paraId == paragraph.id ? mine : secLevel)
          .add(_EdgeRow(c: c, out: false, other: c.von.sectionId ?? '?'));
    }

    final kern = domain.genPara(sectionId, paragraph.id)?.kernaussage ?? '';

    final children = <Widget>[];
    if (kern.isNotEmpty) {
      // Die Kernaussage des Absatzes lebt HIER (statt doppelt unterm Text).
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          kern,
          style: AppTextStyles.small
              .copyWith(fontSize: 13, height: 1.55, color: t.ink2),
        ),
      ));
    }
    for (final e in mine.take(6)) {
      children.add(_AgpRow(edge: e));
    }
    if (isFirst && secLevel.isNotEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 3),
        child: Text('ABSCHNITT GESAMT',
            style: AppTextStyles.eyebrow.copyWith(color: t.muted)),
      ));
      final seen = <String>{};
      for (final e in secLevel) {
        final k = '${e.c.typ}|${e.out ? 'out' : 'in'}|${e.other}';
        if (!seen.add(k)) continue;
        if (seen.length > 8) break;
        children.add(_AgpRow(edge: e));
      }
    }
    if (children.isEmpty) {
      children.add(Text('— keine Verbindungen an diesem Absatz',
          style: AppTextStyles.small.copyWith(color: t.muted)));
    }

    return LayoutBuilder(builder: (context, constraints) {
      final stacked = constraints.maxWidth > 570;
      return Stack(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 16, 14),
            decoration: BoxDecoration(
              color: t.surface,
              border: Border(
                top: BorderSide(color: t.border),
                right: BorderSide(color: t.border),
                bottom: BorderSide(color: t.border),
                left: stacked ? BorderSide(color: t.border) : BorderSide.none,
              ),
              borderRadius: stacked
                  ? const BorderRadius.only(
                      bottomLeft: Radius.circular(BookClothTokens.radius),
                      bottomRight: Radius.circular(BookClothTokens.radius),
                    )
                  : const BorderRadius.only(
                      topRight: Radius.circular(BookClothTokens.radius),
                      bottomRight: Radius.circular(BookClothTokens.radius),
                    ),
              boxShadow: t.shadow1,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '⤳ CONNECTIONS',
                        style: TextStyle(
                          fontFamily: AppFonts.display,
                          fontFamilyFallback: AppFonts.fallback,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          height: 1.3,
                          letterSpacing: .09 * 12,
                          color: t.muted,
                        ),
                      ),
                    ),
                    Tooltip(
                      message: 'Instanz-Fenster dieses Abschnitts schließen',
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            final prefs =
                                ref.read(studioPrefsCtlProvider).value ??
                                    StudioPrefs.defaults;
                            // dockClose (:2201-2207) — nur DIESER Abschnitt.
                            dockCloseSection(
                                ref.read(studioKvProvider.notifier),
                                prefs.dock,
                                sectionId);
                          },
                          child: Text('×',
                              style: TextStyle(
                                  fontSize: 14, height: .9, color: t.muted)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ...children,
              ],
            ),
          ),
          if (stacked)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: DashedLine(axis: Axis.horizontal, color: t.borderStrong),
            )
          else
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: DashedLine(axis: Axis.vertical, color: t.borderStrong),
            ),
        ],
      );
    });
  }
}

/// Eine Kanten-Zeile (`.agp`): 3px-Farbkante, 6%-Wash, Icon + Richtung +
/// Ziel (Mono, in der Kantenfarbe) + optionales Label (52 Zeichen).
class _AgpRow extends StatefulWidget {
  const _AgpRow({required this.edge});

  final _EdgeRow edge;

  @override
  State<_AgpRow> createState() => _AgpRowState();
}

class _AgpRowState extends State<_AgpRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final e = widget.edge;
    final col = graphEdgeColor(t, e.c.typ);
    final typ = Connections.types[e.c.typ] ?? Connections.types['xref']!;
    final label = e.c.label;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => context.go(
            Routes.studioPath(sec: e.other, modus: StudioModes.pruefen)),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(12, 5, 8, 5),
          decoration: BoxDecoration(
            color: col.alphaPct(_hover ? 14 : 6),
            border: Border(left: BorderSide(color: col, width: 3)),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: '${typ.icon} '),
                  TextSpan(text: e.out ? typ.out : typ.inLabel),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: e.other,
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontFamilyFallback: AppFonts.fallback,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                      color: col,
                    ),
                  ),
                ]),
                style: AppTextStyles.small
                    .copyWith(fontSize: 12.5, height: 1.4, color: t.ink),
              ),
              if (label.isNotEmpty)
                Text(
                  label.length > 52 ? label.substring(0, 52) : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.small
                      .copyWith(fontSize: 11.5, color: t.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
