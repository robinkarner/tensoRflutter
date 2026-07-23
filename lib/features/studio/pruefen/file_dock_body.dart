/// Beleg-Dock-Inhalt — Port von `renderFileDock` (:1498-1596): der
/// Vermutungs-Block (Was belegt wird · Fußnotentext ✎-editierbar ·
/// vermutete Stelle · Suchbegriffe) und darunter die [BelegChecklist].
///
/// Dies ist die S-2-Standardfüllung des Dock-Slots der Quellen-Spalte
/// ([StudioSlots.dockBody] kann sie ersetzen); [DockFnSlot] ist der Inhalt
/// des `sfd-fn-slot` in der Tab-Zeile (Markierfarbe + ↺-Zurücksetzen).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/color_mix.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/db/kv.dart';
import '../layout/studio_slots.dart';
import '../layout/studio_state.dart';
import 'beleg_checklist.dart';
import 'farb_control.dart';
import 'search_chips.dart';

/// Markierfarbe + ↺ in der Dock-Tab-Zeile (`sfd-fn-slot`, :1511-1521).
class DockFnSlot extends ConsumerWidget {
  const DockFnSlot({
    super.key,
    required this.srcId,
    required this.fn,
    required this.domain,
  });

  final String srcId;
  final int fn;
  final StudioDomain domain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final hasEntry = domain.levels.entry(fn) != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Farbe',
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontFamilyFallback: AppFonts.fallback,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              height: 1,
              color: t.muted,
            )),
        const SizedBox(width: 6),
        FarbControl(srcId: srcId, fnNum: fn, size: 24, openUpwards: true),
        if (hasEntry) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: 'Gespeicherten Stand dieser Fußnote zurücksetzen',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => domain.levels.clear(fn),
                child: Text('↺',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1,
                      color: t.ink2,
                      fontFamilyFallback: AppFonts.fallback,
                    )),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class FileDockBody extends ConsumerWidget {
  const FileDockBody({
    super.key,
    required this.sectionId,
    required this.srcId,
    required this.fn,
  });

  final String sectionId;
  final String srcId;
  final int? fn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final domain = ref.watch(studioDomainProvider);
    final fnNum = fn;
    if (domain == null || fnNum == null) {
      return Text(
        'Kein Beleg gewählt — diese Quelle ist (noch) nur als Erwähnung im Text referenziert.',
        style: AppTextStyles.small.copyWith(color: t.muted),
      );
    }

    final beleg = domain.ctx.findBeleg(fnNum);
    final inf = domain.levels.info(fnNum);
    final fnText = (domain.ctx.fnIndex[fnNum]?.text ?? '').trim();
    final snapshot = ref.watch(studioKvProvider).value ?? const <String, Object?>{};
    final fnEditsRaw = snapshot[KvKeys.fnEdits];
    final fnEdited = fnEditsRaw is Map && fnEditsRaw.containsKey('$fnNum');
    final showFnText =
        (fnText.isNotEmpty && fnText.contains(RegExp(r'\s')) && fnText.length > 12) ||
            fnEdited ||
            fnText.isNotEmpty;

    final good2 = inf.level >= 2;

    final kiChildren = <Widget>[
      if ((beleg?.claim ?? '').isNotEmpty)
        _accentLined(
          t,
          Text.rich(
            TextSpan(children: [
              const TextSpan(
                  text: 'Was belegt wird: ',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: beleg!.claim),
            ]),
            style: AppTextStyles.small
                .copyWith(fontSize: 13, height: 1.6, color: t.ink),
          ),
        ),
      if (showFnText)
        _FnTextRow(
          fnNum: fnNum,
          fnText: fnText,
          fnEdited: fnEdited,
          domain: domain,
        ),
      if ((beleg?.fundstelle ?? '').isNotEmpty)
        _accentLined(
          t,
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Vermutete Stelle '),
              TextSpan(
                text: beleg!.fundstelle,
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontFamilyFallback: AppFonts.fallback,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: t.accentInk,
                ),
              ),
            ]),
            style:
                AppTextStyles.small.copyWith(fontSize: 12.5, color: t.ink2),
          ),
        ),
      if ((beleg?.suchHinweis ?? '').isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: SearchChips(
            suchHinweis: beleg!.suchHinweis,
            onSearch: (w) {
              final handle = StudioSlots.pdfHandle;
              if (handle != null && handle.srcId == srcId) {
                handle.search(w);
              } else {
                Clipboard.setData(ClipboardData(text: w));
              }
            },
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (kiChildren.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
            margin: const EdgeInsets.only(bottom: 7),
            decoration: BoxDecoration(
              color: good2 ? t.good.alphaPct(8) : t.accentSoft,
              border: Border.all(
                  color: good2 ? t.good.alphaPct(30) : t.accentLine),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, w) in kiChildren.indexed)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                    child: w,
                  ),
              ],
            ),
          ),
        BelegChecklist(srcId: srcId, fnNum: fnNum),
      ],
    );
  }

  /// Der einheitliche 3px-Akzent-Balken links (`.sfd-ki`-Innenblöcke).
  Widget _accentLined(BookClothTokens t, Widget child) => Container(
        padding: const EdgeInsets.only(left: 10),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: t.accentLine, width: 3)),
        ),
        child: child,
      );
}

/// Fußnotentext-Zeile mit ✎-Inline-Edit (Esc/Fokusverlust ÜBERNIMMT) und ↺
/// (:1531-1572). Der Override landet in `fnEdits`; Index + Anzeigen ziehen
/// reaktiv nach (§0-Sync macht der StudioKv).
class _FnTextRow extends ConsumerStatefulWidget {
  const _FnTextRow({
    required this.fnNum,
    required this.fnText,
    required this.fnEdited,
    required this.domain,
  });

  final int fnNum;
  final String fnText;
  final bool fnEdited;
  final StudioDomain domain;

  @override
  ConsumerState<_FnTextRow> createState() => _FnTextRowState();
}

class _FnTextRowState extends ConsumerState<_FnTextRow> {
  bool _editing = false;
  late TextEditingController _ctl;
  final FocusNode _focus = FocusNode();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.fnText);
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing) _finish();
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startEdit() {
    setState(() {
      _editing = true;
      _done = false;
      _ctl.text = widget.fnText; // ohne „…“-Anführung editieren
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      _ctl.selection = TextSelection.collapsed(offset: _ctl.text.length);
    });
  }

  /// Esc ODER Fokusverlust = übernehmen (KEIN Verwerfen, :1554-1566).
  void _finish() {
    if (_done) return;
    _done = true;
    final t = _ctl.text
        .replaceAll(' ', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final orig = widget.domain.fnOrigText(widget.fnNum) ?? widget.fnText;
    final kv = ref.read(studioKvProvider.notifier);
    final all = kv.readMap(KvKeys.fnEdits);
    final next = {...all};
    if (t.isNotEmpty && t != orig) {
      next['${widget.fnNum}'] = t;
      kv.put(KvKeys.fnEdits, next);
    } else if (t == orig) {
      next.remove('${widget.fnNum}');
      kv.put(KvKeys.fnEdits, next);
    }
    if (mounted) setState(() => _editing = false);
  }

  void _reset() {
    final kv = ref.read(studioKvProvider.notifier);
    final next = {...kv.readMap(KvKeys.fnEdits)}..remove('${widget.fnNum}');
    kv.put(KvKeys.fnEdits, next);
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);

    final quote = _editing
        ? Focus(
            onKeyEvent: (node, e) {
              if (e is KeyDownEvent &&
                  e.logicalKey == LogicalKeyboardKey.escape) {
                _finish(); // Esc = ÜBERNEHMEN (kein Verwerfen!)
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: _ctl,
              focusNode: _focus,
              maxLines: null,
              style: AppTextStyles.small
                  .copyWith(fontSize: 12.5, color: t.ink, height: 1.5),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: t.surface,
                contentPadding: const EdgeInsets.all(6),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: t.accentLine),
                  borderRadius: BorderRadius.circular(4),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: t.accentLine),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          )
        : Tooltip(
            message: 'Fußnotentext — ✎ zum Bearbeiten (Copy/Paste)',
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 2, 0, 2),
              decoration: BoxDecoration(
                border:
                    Border(left: BorderSide(color: t.accentLine, width: 3)),
              ),
              child: Text(
                '„${widget.fnText}“',
                style: AppTextStyles.small
                    .copyWith(fontSize: 12.5, color: t.muted, height: 1.5),
              ),
            ),
          );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: quote),
        const SizedBox(width: 6),
        if (!_editing) ...[
          Tooltip(
            message:
                'Fußnotentext bearbeiten — frei tippen oder Text einfügen; Esc/Klick außerhalb übernimmt',
            child: _GhostIcon(icon: '✎', onTap: _startEdit),
          ),
          if (widget.fnEdited)
            Tooltip(
              message: 'Original-Fußnotentext wiederherstellen',
              child: _GhostIcon(icon: '↺', onTap: _reset),
            ),
        ],
      ],
    );
  }
}

class _GhostIcon extends StatelessWidget {
  const _GhostIcon({required this.icon, required this.onTap});

  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(icon,
              style: TextStyle(
                fontSize: 13,
                height: 1,
                color: t.ink2,
                fontFamilyFallback: AppFonts.fallback,
              )),
        ),
      ),
    );
  }
}
