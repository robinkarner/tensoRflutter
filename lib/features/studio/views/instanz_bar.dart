/// Views-/Instanz-Leiste — Port von `instanzBar` (views_studio.js:646-679)
/// samt `.inst-bar`/`.dock-switch` (app.css:1533-1543):
///
/// Rechts der „Views“-Eyebrow eine Chip-Reihe: „∅ Ohne“ + alle View-
/// Definitionen (ohne die Legacy-„◻ Ohne“-clear-View) + „✎“ (Verwaltung).
/// EIN Klick wählt die View GLOBAL (`uiDockMode`) und setzt alle
/// Abschnitts-Abweichungen zurück (`dockBySection = {}`); das × am Fenster
/// schließt nur den jeweiligen Abschnitt.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/color_mix.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../layout/css_color.dart';
import '../layout/dock_state.dart';
import '../layout/studio_state.dart';
import 'instanz_edit_modal.dart';

class InstanzBar extends ConsumerWidget {
  const InstanzBar({super.key, required this.sectionId});

  final String sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final mode = ref.watch(dockModeForProvider(sectionId));
    // ∅ und „◻ Ohne“ waren dasselbe — nur EIN „∅ Ohne“ (none), :648-649.
    final defs = [
      for (final d in ref.watch(dockDefsProvider))
        if (d.id != 'clear') d,
    ];

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 2),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: t.surface2,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(BookClothTokens.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('VIEWS', style: AppTextStyles.eyebrow.copyWith(color: t.muted)),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _DockChip(
                  label: '∅ Ohne',
                  tooltip: 'Ohne View — die normale Ansicht',
                  active: mode == null,
                  color: null,
                  onTap: () =>
                      ref.read(studioPrefsCtlProvider.notifier).setDock(null),
                ),
                for (final d in defs)
                  _DockChip(
                    label: d.label,
                    tooltip: d.label +
                        (d.id == 'srcview'
                            ? ' — streicht alle Sätze an, die der aktiven Quelle (rechts) zugeordnet sind; kräftiger, wo exakt belegt'
                            : ' öffnen — gilt für alle Abschnitte') +
                        (d.project ? ' · von dieser Arbeit mitgeliefert' : ''),
                    active: mode == d.id,
                    color: resolveCssColor(t, d.color),
                    onTap: () =>
                        ref.read(studioPrefsCtlProvider.notifier).setDock(d.id),
                  ),
                _DockChip(
                  label: '✎',
                  tooltip:
                      'Views verwalten: neue View mit KI erstellen, recompilen, löschen',
                  active: false,
                  color: null,
                  onTap: () => showInstanzEditModal(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ein View-Chip (`.dock-switch button`): optionaler Farbpunkt mit Glow-Ring;
/// aktiv trägt der Chip den Ton der View (12 % Wash, 55 % Border).
class _DockChip extends StatefulWidget {
  const _DockChip({
    required this.label,
    required this.tooltip,
    required this.active,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final bool active;
  final Color? color;
  final VoidCallback onTap;

  @override
  State<_DockChip> createState() => _DockChipState();
}

class _DockChipState extends State<_DockChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final c = widget.color;

    Color bg = _hover ? t.surface3 : t.surface;
    Color border = t.border;
    Color fg = t.ink2;
    if (widget.active) {
      if (c != null) {
        bg = c.mix(t.surface, 12);
        border = c.mix(t.border, 55);
        fg = c.mix(t.ink, 75);
      } else {
        bg = t.surface3;
        border = t.borderStrong;
        fg = t.ink;
      }
    }

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (c != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c,
                      boxShadow: [
                        BoxShadow(color: c.alphaPct(22), spreadRadius: 2),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontFamilyFallback: AppFonts.fallback,
                    fontWeight:
                        widget.active ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 12.5,
                    height: 1,
                    color: fg,
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
