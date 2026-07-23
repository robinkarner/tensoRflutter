/// Das 3-Spalten-Studio-Gerüst — Pendant zu `renderStudio` (:40-138) und dem
/// CSS-Grid `.studio` (app.css:157-210).
///
/// Spalten (links → rechts): Kapitelbaum · Inhalt · Quellen-Spalte, getrennt
/// durch 7px-Resize-Nähte. Die Spalten sind viewport-hohe Panels mit eigenem
/// Scroll (das Sticky-Pendant, Dossier 03 Flutter-Hinweis 3); die
/// Modus-Leiste sitzt fix über dem scrollenden Inhalt. Eingeklappte Spalten
/// hinterlassen fixe Rand-Leisten mit Vertikaltext (⇤ Quellen /
/// ⇥ Inhaltsverzeichnis). Unter 1000px stapelt alles (app.css:192-205).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/resizable.dart';
import '../lesen/lesen_mode.dart';
import '../pruefen/pruefen_mode.dart';
import 'studio_bar.dart';
import 'studio_file_column.dart';
import 'studio_header.dart';
import 'studio_slots.dart';
import 'studio_state.dart';
import 'studio_tree.dart';

/// Der komplette Arbeitsraum eines Abschnitts.
class StudioWorkspace extends ConsumerStatefulWidget {
  const StudioWorkspace({
    super.key,
    required this.sectionId,
    required this.mode,
    this.focusPara,
  });

  final String sectionId;
  final String mode;
  final String? focusPara;

  @override
  ConsumerState<StudioWorkspace> createState() => _StudioWorkspaceState();
}

class _StudioWorkspaceState extends ConsumerState<StudioWorkspace> {
  /// Scroll-Controller der Inhaltsspalte (Scroll-Restauration je
  /// `modus|abschnitt`, :136-137).
  late final ScrollController _contentScroll;

  /// Live-Breiten während des Drags (px) — `null` = gespeicherter/CSS-Wert.
  double? _liveTreeW;
  double? _liveFileW;

  @override
  void initState() {
    super.initState();
    final back = widget.focusPara == null
        ? ref
            .read(studioScrollMemoryProvider.notifier)
            .restore(widget.mode, widget.sectionId)
        : null;
    _contentScroll = ScrollController(initialScrollOffset: back ?? 0);
  }

  @override
  void dispose() {
    _saveScroll();
    _contentScroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(StudioWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode ||
        oldWidget.sectionId != widget.sectionId) {
      // Scrollstand des ALTEN Zustands sichern, den des neuen herstellen.
      ref.read(studioScrollMemoryProvider.notifier).save(
          oldWidget.mode, oldWidget.sectionId,
          _contentScroll.hasClients ? _contentScroll.offset : 0);
      final back = widget.focusPara == null
          ? ref
              .read(studioScrollMemoryProvider.notifier)
              .restore(widget.mode, widget.sectionId)
          : null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_contentScroll.hasClients) return;
        _contentScroll.jumpTo(
            (back ?? 0).clamp(0, _contentScroll.position.maxScrollExtent));
      });
    }
  }

  void _saveScroll() {
    if (!_contentScroll.hasClients) return;
    ref
        .read(studioScrollMemoryProvider.notifier)
        .save(widget.mode, widget.sectionId, _contentScroll.offset);
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final prefs = ref.watch(studioPrefsCtlProvider).value ?? StudioPrefs.defaults;
    final size = MediaQuery.sizeOf(context);
    final stacked = size.width <= BookClothTokens.bpWorkspace;

    // Datei-Anker nur in Prüfen + Editor (`hasFile`, :59).
    final hasFile = widget.mode != 'lesen';
    final fileOff = !hasFile || prefs.fileOff;
    final treeOff = prefs.treeOff;

    if (stacked) {
      return _buildStacked(context, t, hasFile: hasFile);
    }

    // Klemmen wie :62-68 + CSS-Caps: tree ≤ 26vw, file ≤ 50vw.
    final treeCap = (size.width * .26).roundToDouble();
    final fileCap = (size.width * .50).roundToDouble();
    final treeW =
        (_liveTreeW ?? prefs.treeW?.toDouble() ?? 240).clamp(120.0, treeCap);
    final defaultFileW = (size.width * .30).clamp(400.0, 640.0);
    final fileW =
        (_liveFileW ?? prefs.fileW?.toDouble() ?? defaultFileW).clamp(240.0, fileCap);

    // Viewport-hohe Spalten: 100vh − Topbar − 22 (app.css:218/437).
    // Bodenwert 320px: bei sehr niedrigem Viewport bleibt die Höhe positiv
    // (negatives SizedBox/Stack würde sonst einen Layout-Fehler werfen) —
    // der Gesamtbereich scrollt ohnehin in der App-Shell.
    final columnH =
        (size.height - BookClothTokens.topbarH - 22).clamp(320.0, double.infinity);

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!treeOff) ...[
          SizedBox(
            width: treeW.toDouble(),
            height: columnH,
            child: StudioTree(activeId: widget.sectionId),
          ),
          ResizerHandle(
            read: () => _liveTreeW ?? treeW.toDouble(),
            apply: (px) => setState(() => _liveTreeW = px),
            persist: (px) {
              ref.read(studioPrefsCtlProvider.notifier).setTreeW(px);
              setState(() => _liveTreeW = null);
            },
            min: 180,
            max: [420.0, [680.0, size.width * .4].reduce((a, b) => a < b ? a : b)]
                .reduce((a, b) => a > b ? a : b),
          ),
        ],
        Expanded(child: _buildContent(context, columnH)),
        if (!fileOff) ...[
          ResizerHandle(
            read: () => _liveFileW ?? fileW.toDouble(),
            apply: (px) => setState(() => _liveFileW = px),
            persist: (px) {
              ref.read(studioPrefsCtlProvider.notifier).setFileW(px);
              setState(() => _liveFileW = null);
            },
            onDone: () => StudioSlots.pdfHandle?.refresh(),
            min: 320,
            max: [560.0, size.width * .5].reduce((a, b) => a > b ? a : b),
            dir: -1, // Ziehen nach links vergrößert die Quellen-Spalte
          ),
          SizedBox(
            width: fileW.toDouble(),
            height: columnH,
            child: StudioFileColumn(sectionId: widget.sectionId),
          ),
        ],
      ],
    );

    // Rand-Leisten als Overlays am Gerüst-Rand (position:fixed-Pendant).
    return SizedBox(
      height: columnH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: row),
          if (hasFile && prefs.fileOff)
            Positioned(
              right: 0,
              top: 66,
              child: _Rail(
                icon: '⇤',
                text: 'Quellen',
                tooltip: 'Quellen-Spalte einblenden',
                side: _RailSide.right,
                onTap: () =>
                    ref.read(studioPrefsCtlProvider.notifier).setFileOff(false),
              ),
            ),
          if (treeOff)
            Positioned(
              left: 0,
              top: 66,
              child: _Rail(
                icon: '⇥',
                text: 'Inhaltsverzeichnis',
                tooltip: 'Inhaltsverzeichnis einblenden',
                side: _RailSide.left,
                onTap: () =>
                    ref.read(studioPrefsCtlProvider.notifier).setTreeOff(false),
              ),
            ),
        ],
      ),
    );
  }

  /// Inhaltsspalte: Modus-Leiste fix oben (sticky-Pendant), darunter der
  /// eigene Scrollbereich mit Kopf + Modusinhalt.
  Widget _buildContent(BuildContext context, double columnH) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StudioModeBar(sectionId: widget.sectionId, mode: widget.mode),
        Expanded(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context),
            child: SingleChildScrollView(
              controller: _contentScroll,
              child: _ContentBody(
                sectionId: widget.sectionId,
                mode: widget.mode,
                focusPara: widget.focusPara,
                scrollController: _contentScroll,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// ≤999px: einspaltig gestapelt `'tree' 'content' 'file'`; die
  /// Quellen-Spalte bekommt eine feste Höhe `min(78vh, 760px)`, der Baum
  /// max. 300px (app.css:192-205). Gescrollt wird die Seite als Ganzes;
  /// eingeklappte Spalten holen kompakte Leisten-Knöpfe zurück (Rails-
  /// Pendant der schmalen Screens, app.css:501-503).
  Widget _buildStacked(BuildContext context, BookClothTokens t,
      {required bool hasFile}) {
    final prefs = ref.watch(studioPrefsCtlProvider).value ?? StudioPrefs.defaults;
    final size = MediaQuery.sizeOf(context);
    final fileH = [size.height * .78, 760.0].reduce((a, b) => a < b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!prefs.treeOff)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: StudioTree(activeId: widget.sectionId),
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              small: true,
              variant: AppButtonVariant.ghost,
              tooltip: 'Inhaltsverzeichnis einblenden',
              onPressed: () =>
                  ref.read(studioPrefsCtlProvider.notifier).setTreeOff(false),
              child: const Text('⇥ Inhaltsverzeichnis'),
            ),
          ),
        StudioModeBar(sectionId: widget.sectionId, mode: widget.mode),
        _ContentBody(
          sectionId: widget.sectionId,
          mode: widget.mode,
          focusPara: widget.focusPara,
        ),
        if (hasFile && !prefs.fileOff)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: SizedBox(
              height: fileH,
              child: StudioFileColumn(sectionId: widget.sectionId),
            ),
          )
        else if (hasFile)
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              small: true,
              variant: AppButtonVariant.ghost,
              tooltip: 'Quellen-Spalte einblenden',
              onPressed: () =>
                  ref.read(studioPrefsCtlProvider.notifier).setFileOff(false),
              child: const Text('⇤ Quellen'),
            ),
          ),
      ],
    );
  }
}

/// Kopf + Modusinhalt (der scrollende Teil der Inhaltsspalte).
class _ContentBody extends ConsumerWidget {
  const _ContentBody({
    required this.sectionId,
    required this.mode,
    this.focusPara,
    this.scrollController,
  });

  final String sectionId;
  final String mode;
  final String? focusPara;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StudioHeader(sectionId: sectionId),
        // `.studio-inner`: max-width 980 zentriert; `.wide` (Editor) frei.
        _StudioInner(
          wide: mode == 'editor',
          child: switch (mode) {
            'lesen' => LesenMode(
                sectionId: sectionId,
                scrollController: scrollController,
              ),
            'editor' => _EditorHost(sectionId: sectionId),
            _ => PruefenMode(
                sectionId: sectionId,
                focusPara: focusPara,
                scrollController: scrollController,
              ),
          },
        ),
      ],
    );
  }
}

class _StudioInner extends StatelessWidget {
  const _StudioInner({required this.child, this.wide = false});

  final Widget child;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    if (wide) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: child,
      ),
    );
  }
}

/// ✎-LaTeX-Modus: S-3 hängt hier `renderEditorPane` ein; bis dahin zeigt
/// das Gerüst das rekonstruierte LaTeX des Abschnitts schreibgeschützt
/// (EditorLogic ist Domänen-Bestand — echte Funktion, kein Stummel).
class _EditorHost extends ConsumerWidget {
  const _EditorHost({required this.sectionId});

  final String sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slot = StudioSlots.editorPane;
    if (slot != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          slot(context, sectionId),
          SectionNav(sectionId: sectionId, mode: 'editor'),
        ],
      );
    }
    final t = BookClothTokens.of(context);
    final domain = ref.watch(studioDomainProvider);
    final tex = domain?.editor.reconstruct(sectionId) ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: t.borderStrong),
            borderRadius: BorderRadius.circular(BookClothTokens.radius),
          ),
          child: SelectableText(
            tex.isEmpty ? '% (kein LaTeX für diesen Abschnitt)' : tex,
            style: AppTextStyles.mono.copyWith(fontSize: 12.5, color: t.ink2),
          ),
        ),
        SectionNav(sectionId: sectionId, mode: 'editor'),
      ],
    );
  }
}

enum _RailSide { left, right }

/// Rand-Leiste einer eingeklappten Spalte (app.css:484-504): 34px breit,
/// Icon oben, Vertikaltext (`writing-mode: vertical-rl` → [RotatedBox]).
class _Rail extends StatefulWidget {
  const _Rail({
    required this.icon,
    required this.text,
    required this.tooltip,
    required this.side,
    required this.onTap,
  });

  final String icon;
  final String text;
  final String tooltip;
  final _RailSide side;
  final VoidCallback onTap;

  @override
  State<_Rail> createState() => _RailState();
}

class _RailState extends State<_Rail> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final radius = widget.side == _RailSide.right
        ? const BorderRadius.only(
            topLeft: Radius.circular(12), bottomLeft: Radius.circular(12))
        : const BorderRadius.only(
            topRight: Radius.circular(12), bottomRight: Radius.circular(12));
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 34,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: _hover ? t.surface3 : t.surface,
              border: Border.all(color: t.borderStrong),
              borderRadius: radius,
              boxShadow: _hover ? t.shadow2 : t.shadow1,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.icon,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1,
                      color: _hover ? t.accentInk : t.ink2,
                      fontFamilyFallback: AppFonts.fallback,
                    )),
                const SizedBox(height: 10),
                RotatedBox(
                  quarterTurns: 1,
                  child: Text(
                    widget.text,
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontFamilyFallback: AppFonts.fallback,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      height: 1,
                      letterSpacing: .02 * 12,
                      color: _hover ? t.accentInk : t.ink2,
                    ),
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
