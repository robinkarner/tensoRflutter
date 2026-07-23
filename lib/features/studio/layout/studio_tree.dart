/// Kapitelbaum (linke Spalte) — Pendant zu `studioTree`/`editTreeTitle`/
/// `progDots` (:212-308) und `.studio-tree` (app.css:216-286).
///
/// EIN Panel im Stil der Quellen-Spalte: Kopfzeile „☰ Inhaltsverzeichnis“
/// mit ⇤-Einklappen, darunter der scrollende Baum — Kapitel als flache
/// Gruppen mit Hairline-Trennern, Caret dreht beim Öffnen, ✎-Umbenennen
/// inline (Enter/Blur = sichern, **Esc = verwerfen** — die einzige
/// Esc-Ausnahme der App!, leeres Feld = Original zurück), Fortschritts-Dots
/// je Abschnitt.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/corner_marker.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../data/bundles/indexes.dart';
import '../../../data/db/kv.dart';
import '../../../data/models/models.dart';
import '../../../domain/levels.dart' show LevelCounts;
import 'sf_iconbtn.dart';
import 'studio_state.dart';

class StudioTree extends ConsumerStatefulWidget {
  const StudioTree({super.key, required this.activeId});

  final String activeId;

  @override
  ConsumerState<StudioTree> createState() => _StudioTreeState();
}

class _StudioTreeState extends ConsumerState<StudioTree> {
  /// Offene Kapitel (Nutzer-Toggles über die Initial-Logik hinaus).
  final Map<int, bool> _open = {};

  /// Gerade umbenannter Titel (`ch<num>` oder Abschnitts-ID) — genau einer.
  String? _editingKey;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final thesis = ref.watch(effectiveThesisProvider);
    final activeCh = int.tryParse(widget.activeId.split('.').first) ?? -1;

    return CornerMarked(
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.borderStrong),
          borderRadius: BorderRadius.circular(BookClothTokens.radiusLg),
          boxShadow: t.shadow1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // .st-bar
            Container(
              constraints: const BoxConstraints(minHeight: 49),
              padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: t.border)),
              ),
              child: Row(
                children: [
                  const Expanded(child: Eyebrow.bar('☰ Inhaltsverzeichnis')),
                  SfIconBtn(
                    icon: '⇤',
                    tooltip: 'Inhaltsverzeichnis nach links einklappen',
                    onTap: () => ref
                        .read(studioPrefsCtlProvider.notifier)
                        .setTreeOff(true),
                  ),
                ],
              ),
            ),
            // .st-body
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 16),
                children: [
                  for (final (i, ch) in (thesis?.chapters ?? const <Chapter>[]).indexed)
                    _chapterGroup(context, ch, hairline: i > 0, activeCh: activeCh),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chapterGroup(BuildContext context, Chapter ch,
      {required bool hairline, required int activeCh}) {
    final t = BookClothTokens.of(context);
    final open = _open[ch.num] ?? (ch.num == activeCh);
    final domain = ref.watch(studioDomainProvider);
    final counts =
        domain?.levels.countsFor(domain.levels.numsForChapter(ch.num));

    // Alle Unterpunkte mit Absätzen (rekursiv).
    final items = <Unit>[];
    void rec(List<Unit> units) {
      for (final u in units) {
        if (u.paragraphs.isNotEmpty) items.add(u);
        rec(u.children);
      }
    }

    rec(ch.sections);

    return Container(
      margin: EdgeInsets.only(top: hairline ? 3 : 0),
      padding: EdgeInsets.only(top: hairline ? 3 : 0),
      decoration: hairline
          ? BoxDecoration(border: Border(top: BorderSide(color: t.border)))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChapterHead(
            ch: ch,
            open: open,
            counts: counts,
            editing: _editingKey == 'ch${ch.num}',
            onToggle: () => setState(() => _open[ch.num] = !open),
            onRename: () => setState(() => _editingKey = 'ch${ch.num}'),
            onEditDone: _finishEdit,
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 1, bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final u in items)
                    _SectionRow(
                      unit: u,
                      chapter: ch,
                      active: u.id == widget.activeId,
                      editing: _editingKey == u.id,
                      onRename: () => setState(() => _editingKey = u.id),
                      onEditDone: _finishEdit,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Titel-Edit abschließen: speichern (leer = Original zurück) oder
  /// verwerfen; persistiert unter `titleEdits` — die effektive Sicht und
  /// alle Indizes ziehen reaktiv nach (rebuildDataIndexes-Pendant).
  void _finishEdit({required String key, required bool save, String? value}) {
    if (save) {
      final kv = ref.read(studioKvProvider.notifier);
      final all = kv.readMap(KvKeys.titleEdits);
      final next = {...all};
      final val = (value ?? '').trim();
      if (val.isEmpty) {
        next.remove(key); // leer = Original wiederherstellen
      } else {
        next[key] = val;
      }
      kv.put(KvKeys.titleEdits, next);
    }
    setState(() => _editingKey = null);
  }
}

typedef _EditDone = void Function({required String key, required bool save, String? value});

/// Kapitel-Kopfzeile: ▸-Caret (rotiert bei open), Nummer, Titel,
/// Fortschrittsbalken, ✎.
class _ChapterHead extends StatefulWidget {
  const _ChapterHead({
    required this.ch,
    required this.open,
    required this.counts,
    required this.editing,
    required this.onToggle,
    required this.onRename,
    required this.onEditDone,
  });

  final Chapter ch;
  final bool open;
  final LevelCounts? counts;
  final bool editing;
  final VoidCallback onToggle;
  final VoidCallback onRename;
  final _EditDone onEditDone;

  @override
  State<_ChapterHead> createState() => _ChapterHeadState();
}

class _ChapterHeadState extends State<_ChapterHead> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final counts = widget.counts;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.editing ? null : widget.onToggle,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _hover && !widget.editing ? t.surface2 : Colors.transparent,
            borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
          ),
          child: Row(
            children: [
              AnimatedRotation(
                turns: widget.open ? .25 : 0,
                duration: const Duration(milliseconds: 130),
                child: Text('▸',
                    style: TextStyle(
                        fontSize: 10,
                        height: 1,
                        color: t.muted,
                        fontFamilyFallback: AppFonts.fallback)),
              ),
              const SizedBox(width: 9),
              SizedBox(
                width: 14,
                child: Text('${widget.ch.num}',
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontFamilyFallback: AppFonts.fallback,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                      height: 1,
                      color: t.accentInk,
                    )),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: widget.editing
                    ? _TreeEditField(
                        initial: widget.ch.title,
                        onDone: (save, v) => widget.onEditDone(
                            key: 'ch${widget.ch.num}', save: save, value: v),
                      )
                    : Text(
                        widget.ch.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontFamilyFallback: AppFonts.fallback,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          height: 1.25,
                          color: t.ink,
                        ),
                      ),
              ),
              if (counts != null && counts.total > 0) ...[
                const SizedBox(width: 6),
                LvlBar(
                  l1: counts.l1,
                  l2: counts.l2,
                  l3: counts.l3,
                  total: counts.total,
                  minWidth: 44,
                ),
              ],
              if (!widget.editing)
                _RenameBtn(
                  visible: _hover,
                  tooltip: 'Kapitel umbenennen',
                  onTap: widget.onRename,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Abschnittszeile: Nummer (Intro: ·), Titel, Fortschritts-Dot, ✎.
class _SectionRow extends ConsumerStatefulWidget {
  const _SectionRow({
    required this.unit,
    required this.chapter,
    required this.active,
    required this.editing,
    required this.onRename,
    required this.onEditDone,
  });

  final Unit unit;
  final Chapter chapter;
  final bool active;
  final bool editing;
  final VoidCallback onRename;
  final _EditDone onEditDone;

  @override
  ConsumerState<_SectionRow> createState() => _SectionRowState();
}

class _SectionRowState extends ConsumerState<_SectionRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final u = widget.unit;
    final domain = ref.watch(studioDomainProvider);

    // progDots (:302-308): alles belegt → l3, teils → l2, sonst l1.
    Widget? prog;
    if (domain != null) {
      final c = domain.levels.countsFor(domain.levels.numsForSection(u.id));
      if (c.total > 0) {
        final (level, title) = c.l3 == c.total
            ? (3, 'alles belegt')
            : (c.l3 + c.l2 > 0 ? (2, 'teilweise geprüft') : (1, 'nur KI-vermutet'));
        prog = Tooltip(message: title, child: LevelDot(level));
      }
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.editing
                  ? null
                  : () => context.go(Routes.studioPath(sec: u.id)),
              child: Container(
                padding: EdgeInsets.only(
                  left: u.level >= 3 ? 22 : 8,
                  right: 8,
                  top: 5,
                  bottom: 5,
                ),
                decoration: BoxDecoration(
                  color: widget.active
                      ? t.accentSoft
                      : _hover
                          ? t.surface3
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(BookClothTokens.radiusXs),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 34,
                      child: Text(
                        u.isIntro ? '·' : u.id,
                        style: TextStyle(
                          fontFamily: AppFonts.mono,
                          fontFamilyFallback: AppFonts.fallback,
                          fontWeight: FontWeight.w600,
                          fontSize: 10.5,
                          height: 1,
                          color: t.accentInk,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: widget.editing
                          ? _TreeEditField(
                              initial: u.title,
                              onDone: (save, v) => widget.onEditDone(
                                  key: u.id, save: save, value: v),
                            )
                          : Text(
                              u.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: AppFonts.ui,
                                fontFamilyFallback: AppFonts.fallback,
                                fontWeight: widget.active
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                fontSize: 13,
                                height: 1.3,
                                color: widget.active ? t.accentInk : t.ink2,
                              ),
                            ),
                    ),
                    if (prog != null) ...[
                      const SizedBox(width: 7),
                      prog,
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (!widget.editing)
            _RenameBtn(
              visible: _hover,
              tooltip: 'Abschnitt umbenennen',
              onTap: widget.onRename,
            ),
        ],
      ),
    );
  }
}

/// Inline-Edit-Feld (`input.tree-edit`): Enter/Blur = sichern, Esc =
/// verwerfen — die EINZIGE Stelle, an der Esc verwirft (:296).
class _TreeEditField extends StatefulWidget {
  const _TreeEditField({required this.initial, required this.onDone});

  final String initial;
  final void Function(bool save, String value) onDone;

  @override
  State<_TreeEditField> createState() => _TreeEditFieldState();
}

class _TreeEditFieldState extends State<_TreeEditField> {
  late final TextEditingController _ctl =
      TextEditingController(text: widget.initial);
  final FocusNode _focus = FocusNode();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _finish(true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      _ctl.selection =
          TextSelection(baseOffset: 0, extentOffset: _ctl.text.length);
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _finish(bool save) {
    if (_done) return;
    _done = true;
    widget.onDone(save, _ctl.text);
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    // Esc über einen Eltern-Focus abfangen (Key-Events steigen vom
    // fokussierten TextField die Fokus-Kette hoch).
    return Focus(
      onKeyEvent: (node, e) {
        if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
          _finish(false);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TextField(
        controller: _ctl,
        focusNode: _focus,
        onSubmitted: (_) => _finish(true),
        style: TextStyle(
          fontFamily: AppFonts.ui,
          fontFamilyFallback: AppFonts.fallback,
          fontWeight: FontWeight.w500,
          fontSize: 13,
          height: 1.3,
          color: t.ink,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          filled: true,
          fillColor: t.surface,
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: t.accent),
            borderRadius: BorderRadius.circular(6),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: t.accent),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}

/// ✎-Knopf — dezent bei Hover der Zeile (`.tree-ren`).
class _RenameBtn extends StatelessWidget {
  const _RenameBtn({
    required this.visible,
    required this.tooltip,
    required this.onTap,
  });

  final bool visible;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Opacity(
      opacity: visible ? .7 : 0,
      child: Tooltip(
        message: tooltip,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              child: Text('✎',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1,
                    color: t.muted,
                    fontFamilyFallback: AppFonts.fallback,
                  )),
            ),
          ),
        ),
      ),
    );
  }
}

