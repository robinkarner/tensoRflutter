/// Beleg-Checkliste „⌖ Beleg-Nachweis n/3“ — Port von `belegChecklist`
/// (:1602-1644) samt `.bcheck` (app.css:982-1047).
///
/// Drei exakt ausgerichtete Zeilen: 📍 Seite/Fundstelle · ❝ Zitat ·
/// 🖍 Markierung im PDF. Seite/Fundstelle und Zitat sind DIREKT editierbar —
/// „fehlt“ IST das Eingabefeld (gestrichelt als Einlade-Signal); gespeichert
/// wird bei Änderung (Enter = Feld verlassen). Die Markierungs-Zeile zeigt
/// vorhandene PDF-Markierungen als Sprungknöpfe.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../layout/studio_slots.dart';
import '../layout/studio_state.dart';

class BelegChecklist extends ConsumerWidget {
  const BelegChecklist({super.key, required this.srcId, required this.fnNum});

  final String srcId;
  final int fnNum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final domain = ref.watch(studioDomainProvider);
    if (domain == null) return const SizedBox.shrink();

    final inf = domain.levels.info(fnNum);
    final posType = domain.levels.positionType(srcId);
    final posLabel = posType == 'seite' ? 'Seite' : 'Fundstelle (Art/§)';
    final hasZitat = (inf.zitat ?? '').isNotEmpty;
    final seiteText = inf.seite == null ? '' : '${inf.seite}';
    final hasPos = seiteText.isNotEmpty || (inf.fundstelle ?? '').isNotEmpty;
    final marks = StudioSlots.marksForFn?.call(srcId, fnNum) ?? const [];
    final done = (hasPos ? 1 : 0) + (hasZitat ? 1 : 0) + (marks.isNotEmpty ? 1 : 0);
    final l3 = inf.level == 3;

    void save(String key, Object? value) {
      domain.levels.save(fnNum, {key: value});
    }

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.borderStrong),
        borderRadius: BorderRadius.circular(12),
        boxShadow: t.shadow1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // bc-head
          Container(
            padding: const EdgeInsets.fromLTRB(13, 7, 12, 7),
            decoration: BoxDecoration(
              color: l3 ? t.goodSoft : t.surface2,
              border: Border(bottom: BorderSide(color: t.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '⌖ BELEG-NACHWEIS',
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontFamilyFallback: AppFonts.fallback,
                      fontWeight: FontWeight.w700,
                      fontSize: 10.5,
                      height: 1.3,
                      letterSpacing: .09 * 10.5,
                      color: l3 ? t.good : t.muted,
                    ),
                  ),
                ),
                Text(
                  '$done/3${done == 3 ? ' ✓' : ''}',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontFamilyFallback: AppFonts.fallback,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    height: 1,
                    color: l3 ? t.good : t.muted,
                  ),
                ),
              ],
            ),
          ),
          // 📍 Seite / Fundstelle
          _CheckRow(
            icon: '📍',
            label: posLabel,
            ok: hasPos,
            hairline: false,
            child: posType == 'seite'
                ? _CheckInput(
                    key: ValueKey('seite-$fnNum-$seiteText'),
                    initial: seiteText,
                    hint: 'fehlt — S. eintragen',
                    ok: hasPos,
                    number: true,
                    onSave: (v) =>
                        save('seite', int.tryParse(v.trim()) ?? ''),
                  )
                : _CheckInput(
                    key: ValueKey('fund-$fnNum-${inf.fundstelle ?? ''}'),
                    initial: inf.fundstelle ?? '',
                    hint: 'fehlt — z. B. Art 9 Abs 2 / § 22 Abs 4',
                    ok: hasPos,
                    onSave: (v) => save('fundstelle', v.trim()),
                  ),
          ),
          // ❝ Zitat
          _CheckRow(
            icon: '❝',
            label: 'Zitat',
            ok: hasZitat,
            hairline: true,
            child: _CheckInput(
              key: ValueKey('zitat-$fnNum-${inf.zitat ?? ''}'),
              initial: inf.zitat ?? '',
              hint: 'fehlt — Originalpassage (oder im PDF markieren)',
              ok: hasZitat,
              onSave: (v) => save('zitat', v.trim()),
            ),
          ),
          // 🖍 Markierung im PDF
          _CheckRow(
            icon: '🖍',
            label: 'Markierung im PDF',
            ok: marks.isNotEmpty,
            hairline: true,
            child: marks.isEmpty
                ? Text(
                    'keine — im PDF markieren',
                    style: AppTextStyles.small.copyWith(
                      fontSize: 13,
                      color: t.muted,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                : Wrap(
                    spacing: 3,
                    runSpacing: 2,
                    children: [
                      for (final m in marks)
                        _MarkJump(
                          page: m.page,
                          color: BookClothTokens.markFarbe(m.farbe) ??
                              const Color(0xFFE8C33F),
                          onTap: () {
                            final handle = StudioSlots.pdfHandle;
                            if (handle != null &&
                                handle.srcId == srcId &&
                                m.page != null) {
                              handle.goto(m.page!);
                            }
                          },
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.icon,
    required this.label,
    required this.ok,
    required this.hairline,
    required this.child,
  });

  final String icon;
  final String label;
  final bool ok;
  final bool hairline;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.fromLTRB(13, 5, 12, 5),
      decoration: hairline
          ? BoxDecoration(border: Border(top: BorderSide(color: t.border)))
          : null,
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Row(
              children: [
                SizedBox(
                  width: 17,
                  child: Text(icon,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontFamilyFallback: AppFonts.fallback,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: ok ? t.ink : t.ink2,
                    ),
                  ),
                ),
                if (ok) ...[
                  const SizedBox(width: 7),
                  Tooltip(
                    message: 'erledigt',
                    child: Text('✓',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: t.good,
                        )),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// `.bc-in`: das nahtlose Direkt-Edit-Feld; speichert bei Enter/Fokusverlust.
class _CheckInput extends StatefulWidget {
  const _CheckInput({
    super.key,
    required this.initial,
    required this.hint,
    required this.ok,
    required this.onSave,
    this.number = false,
  });

  final String initial;
  final String hint;
  final bool ok;
  final void Function(String value) onSave;
  final bool number;

  @override
  State<_CheckInput> createState() => _CheckInputState();
}

class _CheckInputState extends State<_CheckInput> {
  late final TextEditingController _ctl =
      TextEditingController(text: widget.initial);
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  void _commit() {
    if (_ctl.text != widget.initial) widget.onSave(_ctl.text);
  }

  @override
  void dispose() {
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return SizedBox(
      height: 30,
      child: TextField(
        controller: _ctl,
        focusNode: _focus,
        keyboardType: widget.number ? TextInputType.number : TextInputType.text,
        onSubmitted: (_) {
          _commit();
          _focus.unfocus();
        },
        style: TextStyle(
          fontFamily: AppFonts.ui,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: 13,
          fontWeight: widget.ok ? FontWeight.w600 : FontWeight.w400,
          color: t.ink,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: widget.hint,
          hintStyle: TextStyle(
            fontFamily: AppFonts.ui,
            fontFamilyFallback: AppFonts.fallback,
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: t.muted,
          ),
          filled: true,
          fillColor: widget.ok ? t.surface : t.surface2,
          contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: widget.ok ? t.border : t.borderStrong),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: t.accent, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

/// `.bc-mark`: Sprungknopf „S. n →“ mit Farb-Punkt.
class _MarkJump extends StatefulWidget {
  const _MarkJump({required this.page, required this.color, required this.onTap});

  final Object? page;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_MarkJump> createState() => _MarkJumpState();
}

class _MarkJumpState extends State<_MarkJump> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Tooltip(
      message: 'Im PDF auf S. ${widget.page} zeigen',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _hover ? t.accentSoft : t.surface,
              border: Border.all(color: _hover ? t.accent : t.borderStrong),
              borderRadius: BorderRadius.circular(BookClothTokens.radiusPill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color,
                    boxShadow: const [
                      BoxShadow(color: Color(0x14000000), spreadRadius: 1),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'S. ${widget.page} →',
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontFamilyFallback: AppFonts.fallback,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                    height: 1,
                    color: _hover ? t.accentInk : t.ink2,
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
