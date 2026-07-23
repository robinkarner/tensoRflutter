/// Command-Palette (Strg/⌘+K) — Pendant zu openCmdk/cmdkItems
/// (app.js:143-207).
///
/// Einträge in fester Reihenfolge: 8 Ansichten (die drei Studio-Einträge
/// zielen auf `studioLast` bzw. den ersten Abschnitt), dann alle Abschnitte,
/// dann alle Quellen. Tippen filtert case-insensitiv per `contains` auf dem
/// Titel, maximal 40 Treffer; ↑↓ wählen, ↵/Klick öffnen, Esc/Backdrop
/// schließt NUR die Palette (Capture-Semantik des Originals — ein evtl.
/// darunterliegendes Modal bleibt offen).
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/bundles/indexes.dart';
import '../../data/db/kv.dart';
import '../../data/models/models.dart';
import '../router/routes.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Ein Palette-Eintrag: Titel, Kategorie-Label, Ziel-Route (app.js:151-166).
class CmdkItem {
  final String t;
  final String k;
  final String go;

  const CmdkItem({required this.t, required this.k, required this.go});
}

/// Öffnet die Palette. Baut die Einträge frisch auf (wie das Original bei
/// jedem openCmdk) — `studioLast` kommt asynchron aus dem KV-Store.
Future<void> openCmdk(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final items = await buildCmdkItems(container);
  if (!context.mounted) return;

  showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'Schließen',
    // .cmdk-back: bg-deep 55% — die eigentliche Tönung + Blur liegen im
    // Page-Builder, damit beides gemeinsam einblendet (fadeIn .12s).
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 150),
    transitionBuilder: (context, animation, _, child) {
      // popIn .15s cubic-bezier(.2,.9,.3,1.15).
      final curved = CurvedAnimation(
        parent: animation,
        curve: const Cubic(.2, .9, .3, 1.15),
      );
      return FadeTransition(
        opacity: animation,
        child: AnimatedBuilder(
          animation: curved,
          child: child,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, 6 * (1 - curved.value)),
            child: child,
          ),
        ),
      );
    },
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        _CmdkOverlay(items: items),
  );
}

/// Einträge der Palette — exakt die Reihenfolge und Texte von cmdkItems
/// (app.js:150-168): 8 feste Ansichten (⚒⚒⚒📚◈⚙▤？, die Studio-Einträge
/// mit `studioLast`-Fallback), dann alle Abschnitte, dann alle Quellen.
/// Von K-4 final gegen das Original abgeglichen und getestet
/// (test/features/doc/cmdk_items_test.dart).
Future<List<CmdkItem>> buildCmdkItems(ProviderContainer container) async {
  final items = <CmdkItem>[];

  // Ziel-Abschnitt der Studio-Einträge: studioLast || orderedUnits()[0].
  final last = await container.read(kvStoreProvider).getJson(KvKeys.studioLast);
  final ordered = container.read(orderedUnitsProvider);
  final sec = (last is String && last.isNotEmpty)
      ? last
      : (ordered.isNotEmpty ? ordered.first : null);

  String studioGo(String modus) =>
      sec == null ? Routes.studio : Routes.studioPath(sec: sec, modus: modus);

  items.addAll([
    CmdkItem(t: '⚒ Studio — Lesen', k: 'Ansicht', go: studioGo(StudioModes.lesen)),
    CmdkItem(t: '⚒ Studio — Prüfen', k: 'Ansicht', go: studioGo(StudioModes.pruefen)),
    CmdkItem(t: '⚒ Studio — Editor', k: 'Ansicht', go: studioGo(StudioModes.editor)),
    const CmdkItem(t: '📚 Quellen-Bibliothek', k: 'Ansicht', go: Routes.quellen),
    const CmdkItem(t: '◈ Wissen — Informationsspeicher', k: 'Ansicht', go: Routes.analyse),
    const CmdkItem(t: '⚙ Status & Setup', k: 'Ansicht', go: Routes.projekt),
    const CmdkItem(t: '▤ PDF Dokument (ganze Arbeit)', k: 'Ansicht', go: Routes.doc),
    const CmdkItem(t: '？ Hilfe & Anleitung', k: 'Ansicht', go: Routes.hilfe),
  ]);

  // Alle Abschnitte mit Inhalt — Intro-Units zeigen den Kapiteltitel.
  final unitIndex = container.read(unitIndexProvider);
  for (final id in ordered) {
    final e = unitIndex[id];
    if (e == null) continue;
    final title = e.unit.isIntro ? e.chapter.title : e.unit.title;
    items.add(CmdkItem(
      t: '$id $title',
      k: 'Abschnitt',
      go: Routes.studioPath(sec: id),
    ));
  }

  // Alle Quellen in Registry-Reihenfolge.
  final runtime = container.read(activeRuntimeProvider);
  for (final s in runtime?.sources ?? const <Source>[]) {
    items.add(CmdkItem(
      t: '${computeSrcShort(s.id, s)} — ${s.title}',
      k: 'Quelle',
      go: Routes.quellenPath(s.id),
    ));
  }

  return items;
}

// ---------------------------------------------------------------------------
// Overlay-UI
// ---------------------------------------------------------------------------

/// Zeilenhöhe eines Eintrags (padding 9px + eine 14px-Zeile) — feste Höhe,
/// damit die Auswahl exakt in den Sichtbereich gescrollt werden kann.
const double _itemExtent = 37;

class _CmdkOverlay extends StatefulWidget {
  const _CmdkOverlay({required this.items});

  final List<CmdkItem> items;

  @override
  State<_CmdkOverlay> createState() => _CmdkOverlayState();
}

class _CmdkOverlayState extends State<_CmdkOverlay> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  /// Aktuell gezeigte (gefilterte) Einträge, max. 40.
  late List<CmdkItem> _shown = widget.items.take(40).toList();
  int _sel = 0;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Filter wie im Original: lowercase-`contains` auf dem Titel (app.js:184).
  void _refilter() {
    final q = _input.text.toLowerCase().trim();
    setState(() {
      _shown = widget.items
          .where((i) => q.isEmpty || i.t.toLowerCase().contains(q))
          .take(40)
          .toList();
      _sel = 0;
    });
  }

  void _move(int delta) {
    if (_shown.isEmpty) return;
    setState(() => _sel = (_sel + delta).clamp(0, _shown.length - 1));
    // Auswahl sichtbar halten (das Original scrollt implizit via Browser).
    final top = _sel * _itemExtent;
    final bottom = top + _itemExtent;
    final viewTop = _scroll.offset;
    final viewBottom = viewTop + _scroll.position.viewportDimension;
    if (top < viewTop) {
      _scroll.jumpTo(top);
    } else if (bottom > viewBottom) {
      _scroll.jumpTo(bottom - _scroll.position.viewportDimension);
    }
  }

  void _go(int n) {
    if (n < 0 || n >= _shown.length) return;
    final target = _shown[n].go;
    // Router VOR dem Pop greifen — danach ist dieser Kontext ggf. schon
    // aus dem Baum gelöst.
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go(target);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        _move(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _move(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        _go(_sel);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        // Schließt NUR die Palette — der Dialog ist die oberste Route,
        // darunterliegende Modals bleiben unberührt (app.js:191-196).
        Navigator.of(context).pop();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final screen = MediaQuery.sizeOf(context);

    return BackdropFilter(
      // .cmdk-back: color-mix(bg-deep 55%) + blur(5px).
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: ColoredBox(
        color: t.bgDeep.withValues(alpha: .55),
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: screen.height * .12, left: 12, right: 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: screen.width * .92 < 620 ? screen.width * .92 : 620,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(boxShadow: t.shadowPop),
                child: Material(
                  color: t.surface,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(BookClothTokens.radiusLg),
                    side: BorderSide(color: t.borderStrong),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildInput(t),
                      Flexible(child: _buildList(t, screen)),
                      _buildHint(t),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Suchfeld: randlos, 15px, nur eine Hairline nach unten (app.css:92).
  Widget _buildInput(BookClothTokens t) => DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.border)),
        ),
        child: Focus(
          onKeyEvent: _onKey,
          child: TextField(
            controller: _input,
            autofocus: true,
            onChanged: (_) => _refilter(),
            style: AppTextStyles.form.copyWith(fontSize: 15, color: t.ink),
            decoration: InputDecoration(
              hintText: 'Abschnitt, Quelle oder Ansicht suchen …',
              hintStyle: AppTextStyles.form.copyWith(fontSize: 15, color: t.muted),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
            ),
          ),
        ),
      );

  /// Trefferliste: max-height 46vh, Padding 7 (app.css:94).
  Widget _buildList(BookClothTokens t, Size screen) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screen.height * .46),
        child: _shown.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(22),
                child: Text(
                  'Nichts gefunden.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.small.copyWith(color: t.muted),
                ),
              )
            : ListView.builder(
                controller: _scroll,
                shrinkWrap: true,
                padding: const EdgeInsets.all(7),
                itemExtent: _itemExtent,
                itemCount: _shown.length,
                itemBuilder: (context, n) => _CmdkRow(
                  item: _shown[n],
                  selected: n == _sel,
                  onTap: () => _go(n),
                ),
              ),
      );

  /// Hinweiszeile: ↑↓ wählen · ↵ öffnen · Esc schließen (app.js:175).
  Widget _buildHint(BookClothTokens t) => Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: t.border)),
        ),
        child: Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: const [
            _HintEntry(kbd: '↑↓', label: 'wählen'),
            _HintEntry(kbd: '↵', label: 'öffnen'),
            _HintEntry(kbd: 'Esc', label: 'schließen'),
          ],
        ),
      );
}

/// Eine Trefferzeile: Titel links (ellipsis), Kategorie rechts in Mono;
/// Auswahl/Hover = accent-soft (app.css:95-98).
class _CmdkRow extends StatefulWidget {
  const _CmdkRow({required this.item, required this.selected, required this.onTap});

  final CmdkItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_CmdkRow> createState() => _CmdkRowState();
}

class _CmdkRowState extends State<_CmdkRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: widget.selected || _hover ? t.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.item.t,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 14,
                    height: 1,
                    color: t.ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                widget.item.k,
                style: AppTextStyles.mono.copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  height: 1,
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

class _HintEntry extends StatelessWidget {
  const _HintEntry({required this.kbd, required this.label});

  final String kbd;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Kbd(kbd),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.small.copyWith(fontSize: 11, color: t.muted),
        ),
      ],
    );
  }
}

/// `kbd` (theme.css:576-583): Mono 600 10.5, surface-2, border-strong mit
/// dickerer Unterkante, radius 4.
class _Kbd extends StatelessWidget {
  const _Kbd(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 2, 5, 2),
      decoration: BoxDecoration(
        color: t.surface2,
        border: Border(
          top: BorderSide(color: t.borderStrong),
          left: BorderSide(color: t.borderStrong),
          right: BorderSide(color: t.borderStrong),
          bottom: BorderSide(color: t.borderStrong, width: 2),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: AppTextStyles.mono.copyWith(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          height: 1,
          color: t.ink2,
        ),
      ),
    );
  }
}
