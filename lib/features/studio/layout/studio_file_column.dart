/// Quellen-Spalte (Hauptanker RECHTS) — der HOST: Pendant zu
/// `renderFilePane` (:1250-1473) und `.studio-file` (app.css:435-561).
///
/// S-2 baut die Spalte als Gerüst mit Slots, die S-1/S-3 füllen
/// ([StudioSlots.fileCard] = assignPanel, [StudioSlots.fileView] =
/// PdfEngine.mount/renderDocView, [StudioSlots.dockBody] = renderFileDock):
///
///   sf-bar   Quellen-Switch (Picker) · ⤢ Große Ansicht · ⇥ einklappen
///   sf-host  sf-card (Quell-Karte) + sf-view (PDF)
///   sfd-resize (Naht, Höhe ziehbar; < 110px → Auto-Zuklapp)
///   sf-dock  Fußnoten-Dropdown + Farb-/↺-Slot + ▾/▸ + Dock-Inhalt
///
/// Die aktive Quelle/Fußnote lebt im [studioFileProvider] (inkl.
/// Generation-Token gegen Async-Races, :1348-1366) — die Slot-Widgets der
/// PDF-Engine erhalten das Token und dürfen nur als jüngste Generation den
/// Slot behalten.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/corner_marker.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/resizable.dart';
import '../../../data/bundles/indexes.dart';
import '../../../domain/levels.dart' show Levels;
import '../pruefen/file_dock_body.dart';
import 'sf_iconbtn.dart';
import 'source_picker.dart';
import 'studio_slots.dart';
import 'studio_state.dart';

class StudioFileColumn extends ConsumerStatefulWidget {
  const StudioFileColumn({super.key, required this.sectionId});

  final String sectionId;

  @override
  ConsumerState<StudioFileColumn> createState() => _StudioFileColumnState();
}

class _StudioFileColumnState extends ConsumerState<StudioFileColumn> {
  /// Live-Höhe des Docks während des Drags.
  double? _liveDockH;
  final GlobalKey _dockKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final domain = ref.watch(studioDomainProvider);
    final sel = ref.watch(studioSelectionProvider);
    final file = ref.watch(studioFileProvider);
    final prefs = ref.watch(studioPrefsCtlProvider).value ?? StudioPrefs.defaults;

    // Aktive Quelle bestimmen (:1259-1267): Studio.sel hat Vorrang, sonst
    // gemerkte Quelle, sonst die erste des Abschnitts.
    final bySrc = domain?.sectionSources(widget.sectionId) ?? const <String, List<int>>{};
    final srcById = ref.watch(srcByIdProvider);
    String? srcId = file.srcId;
    int? fn = file.fn;
    if (sel != null && sel.srcId != null &&
        (bySrc.containsKey(sel.srcId) || srcById.containsKey(sel.srcId))) {
      srcId = sel.srcId;
      fn = sel.fn;
    }
    if (srcId == null || (!bySrc.containsKey(srcId) && !srcById.containsKey(srcId))) {
      srcId = bySrc.isNotEmpty ? bySrc.keys.first : null;
      fn = null;
    }
    // Zustand nachziehen, wenn die Ableitung von der gemerkten Quelle abweicht.
    if (srcId != file.srcId) {
      final resolved = srcId;
      final resolvedFn = fn;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(studioFileProvider.notifier).show(resolved, resolvedFn);
        }
      });
    }

    final panel = srcId == null
        ? _emptyPane(t)
        : _sourcePane(context, t, domain, srcId, fn, bySrc, prefs);

    return CornerMarked(
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.borderStrong),
          borderRadius: BorderRadius.circular(BookClothTokens.radiusLg),
          boxShadow: t.shadow1,
        ),
        child: panel,
      ),
    );
  }

  /// Abschnitt ohne Belege (:1272-1275).
  Widget _emptyPane(BookClothTokens t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
          decoration:
              BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
          child: Row(
            children: [
              const Eyebrow.bar('▣ Quellen'),
              const Spacer(),
              SfIconBtn(
                icon: '⇥',
                tooltip: 'Quellen-Spalte nach rechts einklappen',
                onTap: () =>
                    ref.read(studioPrefsCtlProvider.notifier).setFileOff(true),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: t.surface2,
            padding: const EdgeInsets.fromLTRB(18, 26, 18, 26),
            alignment: Alignment.topCenter,
            child: Text(
              'Dieser Abschnitt hat keine Belege — sobald Zitierstellen existieren, '
              'steht hier das PDF der Quelle als Hauptanker: markieren übernimmt '
              'Zitat + Seite in den aktiven Beleg.',
              textAlign: TextAlign.center,
              style: AppTextStyles.small.copyWith(color: t.muted),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sourcePane(
    BuildContext context,
    BookClothTokens t,
    StudioDomain? domain,
    String srcId,
    int? fnIn,
    Map<String, List<int>> bySrc,
    StudioPrefs prefs,
  ) {
    final srcById = ref.watch(srcByIdProvider);
    final s = srcById[srcId];
    final short = ref.watch(srcShortProvider(srcId));
    final file = ref.watch(studioFileProvider);

    // Fußnoten-Liste der Quelle in diesem Abschnitt (Fallback: alle
    // Zitierstellen der Quelle, :1285-1286).
    final fns = bySrc[srcId] ?? domain?.levels.numsForSource(srcId) ?? const <int>[];
    var fn = fnIn;
    if (fn == null || !fns.contains(fn)) fn = fns.isNotEmpty ? fns.first : null;

    final dockClosed = prefs.dockClosed;
    final dockH = _liveDockH ?? prefs.sfDockH?.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- sf-bar ---------------------------------------------------------
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
          decoration:
              BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
          child: Row(
            children: [
              Flexible(
                child: _SrcButton(
                  icon: kindIcons[s?.kind] ?? '📄',
                  name: short,
                  onTap: () => showSourcePickerModal(
                    context,
                    ref,
                    sectionId: widget.sectionId,
                    currentId: srcId,
                    onPick: (id) {
                      final list =
                          bySrc[id] ?? domain?.levels.numsForSource(id) ?? const <int>[];
                      final first = list.isNotEmpty ? list.first : null;
                      ref.read(studioSelectionProvider.notifier).select(id, first);
                      ref.read(studioFileProvider.notifier).show(id, first);
                    },
                  ),
                ),
              ),
              const Spacer(),
              SfIconBtn(
                icon: '⤢',
                tooltip:
                    'Große Ansicht: alle Zitierelemente des Absatzes + PDF nebeneinander',
                onTap: () {
                  final open = StudioSlots.openRefMode;
                  final entry = fn != null ? domain?.ctx.fnIndex[fn] : null;
                  if (open != null && entry != null) {
                    open(context, entry.sectionId, entry.paragraphId,
                        srcId: srcId, fn: fn);
                  }
                },
              ),
              const SizedBox(width: 6),
              SfIconBtn(
                icon: '⇥',
                tooltip: 'Quellen-Spalte nach rechts einklappen',
                onTap: () {
                  ref.read(studioPrefsCtlProvider.notifier).setFileOff(true);
                  StudioSlots.pdfHandle = null;
                },
              ),
            ],
          ),
        ),
        // ---- sf-host: Karte + View -----------------------------------------
        Expanded(
          child: Container(
            color: t.surface2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FileCardSlot(srcId: srcId),
                Expanded(child: _FileViewSlot(srcId: srcId, fn: fn, gen: file.gen)),
              ],
            ),
          ),
        ),
        // ---- Naht + Dock ----------------------------------------------------
        ResizerHandle(
          axis: Axis.vertical,
          dir: -1, // Naht liegt ÜBER dem Dock: nach oben ziehen = höher
          read: () {
            final box = _dockKey.currentContext?.findRenderObject() as RenderBox?;
            return _liveDockH ?? box?.size.height ?? 260;
          },
          apply: (px) => setState(() => _liveDockH = px),
          persist: (px) {
            ref.read(studioPrefsCtlProvider.notifier).setSfDockH(px);
            setState(() => _liveDockH = null);
          },
          min: 60,
          max: MediaQuery.sizeOf(context).height * .7,
          onDone: () {
            // Klein genug gezogen → Dock klappt zu, das PDF bekommt die
            // volle Höhe (:1457-1466).
            final box = _dockKey.currentContext?.findRenderObject() as RenderBox?;
            final h = box?.size.height ?? 0;
            if (h < 110 && !prefs.dockClosed) {
              final ctl = ref.read(studioPrefsCtlProvider.notifier);
              ctl.setDockClosed(true);
              ctl.setSfDockH(null);
              setState(() => _liveDockH = null);
            }
          },
        ),
        _Dock(
          key: _dockKey,
          sectionId: widget.sectionId,
          srcId: srcId,
          fn: fn,
          fns: fns,
          closed: dockClosed,
          height: dockClosed ? null : dockH,
        ),
      ],
    );
  }
}

/// `.sf-srcbtn`: Kind-Icon + Kürzel + ▾ — öffnet den Quellen-Picker.
class _SrcButton extends StatefulWidget {
  const _SrcButton({required this.icon, required this.name, required this.onTap});

  final String icon;
  final String name;
  final VoidCallback onTap;

  @override
  State<_SrcButton> createState() => _SrcButtonState();
}

class _SrcButtonState extends State<_SrcButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Tooltip(
      message:
          'Quelle wählen — ALLE Quellen durchsuchbar (Beleg ↔ Erwähnung), nicht nur dieser Abschnitt',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _hover ? t.surface3 : t.surface,
              border: Border.all(color: t.borderStrong),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.icon, style: const TextStyle(fontSize: 14, height: 1)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    widget.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontFamilyFallback: AppFonts.fallback,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: t.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text('▾',
                    style: TextStyle(fontSize: 10, height: 1, color: t.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// sf-card-Slot: `PdfEngine.assignPanel` (S-1). Rückfall: kompakte
/// Quell-Karte (Titel · Autor · Jahr) — echte Information, kein Stummel.
class _FileCardSlot extends ConsumerWidget {
  const _FileCardSlot({required this.srcId});

  final String srcId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slot = StudioSlots.fileCard;
    if (slot != null) {
      // Karte eingeklappt, wenn Datei/Definition vorhanden ist, entscheidet
      // das assignPanel selbst über seine Datenlage — der Host reicht nur
      // den Standard „eingeklappt“ durch (:1361-1365).
      return slot(context, srcId, collapsed: true);
    }
    final t = BookClothTokens.of(context);
    final s = ref.watch(srcByIdProvider)[srcId];
    if (s == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(BookClothTokens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.serif,
              fontFamilyFallback: AppFonts.fallback,
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              height: 1.35,
              color: t.ink,
            ),
          ),
          if ((s.author ?? '').isNotEmpty || s.year != null) ...[
            const SizedBox(height: 2),
            Text(
              [if ((s.author ?? '').isNotEmpty) s.author, if (s.year != null) '${s.year}']
                  .join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.small.copyWith(color: t.muted, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }
}

/// sf-view-Slot: PDF-Engine (S-1). Rückfall: ruhige leere Fläche — identisch
/// zum Original ohne geladenes PdfEngine-Modul.
class _FileViewSlot extends StatelessWidget {
  const _FileViewSlot({required this.srcId, required this.fn, required this.gen});

  final String srcId;
  final int? fn;
  final int gen;

  @override
  Widget build(BuildContext context) {
    final slot = StudioSlots.fileView;
    if (slot != null) return slot(context, srcId, fn: fn, startPage: null, gen: gen);
    return const SizedBox.expand();
  }
}

/// `.sf-dock`: Tab-Zeile (Fußnoten-Dropdown + Slot + ▾/▸) + Inhalt.
class _Dock extends ConsumerWidget {
  const _Dock({
    super.key,
    required this.sectionId,
    required this.srcId,
    required this.fn,
    required this.fns,
    required this.closed,
    required this.height,
  });

  final String sectionId;
  final String srcId;
  final int? fn;
  final List<int> fns;
  final bool closed;
  final double? height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final domain = ref.watch(studioDomainProvider);

    final tabs = Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
      decoration: closed
          ? null
          : BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
      child: Row(
        children: [
          Expanded(child: _FnDropdown(srcId: srcId, fn: fn, fns: fns)),
          const SizedBox(width: 8),
          // sfd-fn-slot: Markierfarbe + ↺ (gezeichnet vom Dock-Inhalt S-2/S-3)
          if (fn != null && domain != null)
            DockFnSlot(srcId: srcId, fn: fn!, domain: domain),
          const SizedBox(width: 8),
          _MinBtn(closed: closed),
        ],
      ),
    );

    final body = closed
        ? const SizedBox.shrink()
        : Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
              child: StudioSlots.dockBody != null
                  ? StudioSlots.dockBody!(context, srcId, fn)
                  : FileDockBody(sectionId: sectionId, srcId: srcId, fn: fn),
            ),
          );

    final dock = Container(
      height: height,
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.borderStrong)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [tabs, body],
      ),
    );
    if (height != null || closed) return dock;
    // Standard: max-height 38% — über die Eltern-Spalte begrenzt.
    return LayoutBuilder(
      builder: (context, _) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: (MediaQuery.sizeOf(context).height * .38),
        ),
        child: dock,
      ),
    );
  }
}

/// Fußnoten-/Beleg-Dropdown (`select.sf-fn`, :1320-1328):
/// „[n] {✦/❝/✓} [🖍] {Claim/Fußnotentext(40)}“.
class _FnDropdown extends ConsumerWidget {
  const _FnDropdown({required this.srcId, required this.fn, required this.fns});

  final String srcId;
  final int? fn;
  final List<int> fns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final domain = ref.watch(studioDomainProvider);
    if (domain == null || fns.isEmpty) {
      return Text('—', style: AppTextStyles.small.copyWith(color: t.muted));
    }

    String labelFor(int n) {
      final inf = domain.levels.info(n);
      final icon = Levels.levelDefs[inf.level]?.icon ?? '·';
      final marks = StudioSlots.marksForFn;
      final marked =
          (marks != null && marks(srcId, n).isNotEmpty) ? ' 🖍' : '';
      final bb = domain.ctx.findBeleg(n);
      var text = bb?.claim ?? '';
      if (text.isEmpty) text = domain.ctx.fnIndex[n]?.text ?? '';
      if (text.length > 40) text = text.substring(0, 40);
      return '[$n] $icon$marked $text';
    }

    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: fn != null && fns.contains(fn) ? fn : fns.first,
        isExpanded: true,
        isDense: true,
        style: AppTextStyles.small.copyWith(fontSize: 12.5, color: t.ink),
        dropdownColor: t.surface,
        borderRadius: BorderRadius.circular(7),
        items: [
          for (final n in fns)
            DropdownMenuItem(
              value: n,
              child: Text(labelFor(n), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (n) {
          if (n == null) return;
          // Wechsel setzt Studio.file.fn + Studio.sel; die Engine springt
          // zur Markierungs-/Beleg-Seite (:1416-1422).
          ref.read(studioFileProvider.notifier).setFn(n);
          ref.read(studioSelectionProvider.notifier).select(srcId, n);
          final handle = StudioSlots.pdfHandle;
          if (handle != null && handle.srcId == srcId) {
            handle.refreshActive();
            final marks = StudioSlots.marksForFn?.call(srcId, n) ?? const [];
            final page = marks.isNotEmpty
                ? marks.first.page
                : domain.levels.info(n).seite;
            handle.goto(page ?? 1);
          }
        },
      ),
    );
  }
}

/// ▾/▸-Umschalter des Dock-Bereichs (`.sfd-min`).
class _MinBtn extends ConsumerStatefulWidget {
  const _MinBtn({required this.closed});

  final bool closed;

  @override
  ConsumerState<_MinBtn> createState() => _MinBtnState();
}

class _MinBtnState extends ConsumerState<_MinBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Tooltip(
      message: 'Beleg-Bereich ein-/ausklappen',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: () => ref
              .read(studioPrefsCtlProvider.notifier)
              .setDockClosed(!widget.closed),
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hover ? t.surface : t.accentSoft,
              border: Border.all(color: _hover ? t.accent : t.accentLine),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.closed ? '▸' : '▾',
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontFamilyFallback: AppFonts.fallback,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                height: 1,
                color: _hover ? t.ink : t.accentInk,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
