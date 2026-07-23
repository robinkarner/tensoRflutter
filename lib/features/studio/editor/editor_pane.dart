/// ✎-LaTeX-Modus — Port von `renderEditorPane` (editor.js:164-268):
///
///   * Kopfzeile: Hinweistext (+ Chip „✎ lokal bearbeitet“) · Speichern ·
///     Zurücksetzen · ⭳ Abschnitt.tex · ⭳ Gesamt.tex
///   * Snippet-Toolbar (8 Einfüge-Knöpfe + „＋ Quelle“ + `$`-Hinweis)
///   * Split Quelltext+Prüfbericht | Live-Vorschau — Verhältnis in Prozent
///     (25–70, `uiEdPct`), 7px-Naht mit Doppelklick-Reset auf 50 %;
///     unter 940px Inhaltsbreite stapeln die Spalten (Container-Query).
///   * Live-Vorschau + Lint mit 220ms-Debounce.
///
/// Änderungen liegen ausschließlich in `texEdits` (projekt-gescoped, über
/// [EditorLogic.saveEdit]) — die Originaldaten bleiben Ground Truth.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../data/db/kv.dart';
import '../../../core/widgets/resizable.dart';
import '../../../domain/editor_logic.dart';
import '../layout/source_picker.dart';
import '../layout/studio_state.dart';
import 'editor_lint_view.dart';
import 'editor_preview.dart';
import 'editor_state.dart';
import 'tex_save.dart';

class EditorPane extends ConsumerStatefulWidget {
  const EditorPane({super.key, required this.sectionId});

  final String sectionId;

  @override
  ConsumerState<EditorPane> createState() => _EditorPaneState();
}

class _EditorPaneState extends ConsumerState<EditorPane> {
  final TextEditingController _tex = TextEditingController();
  Timer? _debounce;
  PreviewDocument _preview = const PreviewDocument([]);
  LintResult _lint = const LintResult(errs: [], warns: []);

  /// Live-Prozent während des Naht-Drags (sonst zählt der gespeicherte Wert).
  double? _livePct;

  @override
  void initState() {
    super.initState();
    _initText();
    _tex.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(EditorPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sectionId != widget.sectionId) _initText();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tex.dispose();
    super.dispose();
  }

  EditorLogic? get _editor => ref.read(studioDomainProvider)?.editor;

  /// `current = edits[sectionId] ?? reconstruct(sectionId)` (editor.js:167).
  void _initText() {
    final ed = _editor;
    if (ed == null) return;
    _tex.text = ed.edits()[widget.sectionId] ?? ed.reconstruct(widget.sectionId);
    _refresh();
  }

  /// Tippen: 220ms-Debounce, dann Vorschau + Lint (editor.js:229-230).
  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), _refresh);
  }

  void _refresh() {
    final ed = _editor;
    if (ed == null || !mounted) return;
    setState(() {
      _preview = ed.preview(_tex.text);
      _lint = ed.lint(_tex.text);
    });
  }

  void _insertSnippet(String ins) {
    final r = applySnippet(_tex.text, _tex.selection, ins);
    _tex.value = TextEditingValue(
      text: r.text,
      selection: TextSelection.collapsed(offset: r.cursor),
    );
    _refresh();
  }

  /// „＋ Quelle“: Selektion beim Klick merken, dann `\cite{id}` dort
  /// einsetzen (editor.js:244-255).
  void _insertCite() {
    final selAtOpen = _tex.selection;
    showSourcePickerModal(
      context,
      ref,
      sectionId: widget.sectionId,
      currentId: null,
      onPick: (id) {
        final cite = '\\cite{$id}';
        final a = selAtOpen.isValid ? selAtOpen.start : _tex.text.length;
        final e = selAtOpen.isValid ? selAtOpen.end : _tex.text.length;
        final v = _tex.text;
        _tex.value = TextEditingValue(
          text: v.substring(0, a) + cite + v.substring(e),
          selection: TextSelection.collapsed(offset: a + cite.length),
        );
        _refresh();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final domain = ref.watch(studioDomainProvider);
    if (domain == null) return const SizedBox.shrink();

    // Edit-Zustand reaktiv (Chip + Zurücksetzen-Knopf).
    final snapshot = ref.watch(studioKvProvider).value ?? const <String, Object?>{};
    final te = snapshot[KvKeys.texEdits];
    final hasEdit = te is Map && te.containsKey(widget.sectionId);

    final pct = _livePct ??
        (ref.watch(editorSplitPctProvider).value ?? 50).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- Kopfzeile ------------------------------------------------------
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Eingeschränkter Befehlssatz — Änderungen bleiben lokal im '
                      'Browser; das PDF der Quellen steht rechts in der '
                      'Quellen-Spalte.',
                      style: AppTextStyles.small.copyWith(color: t.muted),
                    ),
                    if (hasEdit)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9.5, vertical: 4),
                        decoration: BoxDecoration(
                          color: t.warnSoft,
                          borderRadius:
                              BorderRadius.circular(BookClothTokens.radiusPill),
                        ),
                        child: Text(
                          '✎ lokal bearbeitet',
                          style: TextStyle(
                            fontFamily: AppFonts.ui,
                            fontFamilyFallback: AppFonts.fallback,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                            height: 1,
                            color: t.warn,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  AppButton(
                    small: true,
                    variant: AppButtonVariant.primary,
                    onPressed: () {
                      domain.editor.saveEdit(widget.sectionId, _tex.text);
                    },
                    child: const Text('Speichern'),
                  ),
                  AppButton(
                    small: true,
                    onPressed: hasEdit
                        ? () {
                            domain.editor.clearEdit(widget.sectionId);
                            // Zurück auf die Rekonstruktion.
                            _tex.text =
                                domain.editor.reconstruct(widget.sectionId);
                            _refresh();
                          }
                        : null,
                    child: const Text('Zurücksetzen'),
                  ),
                  AppButton(
                    small: true,
                    tooltip: 'Diesen Abschnitt als .tex herunterladen',
                    onPressed: () => saveTexFile(
                        EditorLogic.sectionExportName(widget.sectionId),
                        _tex.text),
                    child: const Text('⭳ Abschnitt.tex'),
                  ),
                  AppButton(
                    small: true,
                    tooltip:
                        'Gesamte Arbeit als .tex (mit allen lokalen Änderungen)',
                    onPressed: () => saveTexFile(
                        EditorLogic.exportAllName, domain.editor.fullDocument()),
                    child: const Text('⭳ Gesamt.tex'),
                  ),
                ],
              ),
            ],
          ),
        ),
        // ---- Snippet-Toolbar ------------------------------------------------
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (final (label, ins) in kEditorSnippets)
                      _ToolbarBtn(
                        label: label,
                        tooltip: 'einfügen',
                        onTap: () => _insertSnippet(ins),
                      ),
                    _ToolbarBtn(
                      label: '＋ Quelle',
                      tooltip:
                          'Quelle als \\cite einfügen — die ganze Quellenauswahl durchsuchbar',
                      onTap: _insertCite,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Auswahl wird in '),
                  TextSpan(
                    text: r'$',
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontFamilyFallback: AppFonts.fallback,
                      backgroundColor: t.surface3,
                    ),
                  ),
                  const TextSpan(text: ' eingesetzt'),
                ]),
                style: AppTextStyles.small.copyWith(color: t.muted),
              ),
            ],
          ),
        ),
        // ---- Split: Quelltext | Vorschau ------------------------------------
        LayoutBuilder(
          builder: (context, constraints) {
            final total = constraints.maxWidth;
            // @container content ≤940px: einspaltig (app.css:843-846).
            if (total <= 940) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _leftPane(t),
                  const SizedBox(height: 14),
                  _rightPane(t),
                ],
              );
            }
            const gap = 14.0;
            const handle = 7.0;
            final usable = total - handle - 2 * gap;
            final leftW =
                (usable * pct / 100).clamp(300.0, usable - 320.0);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: leftW, child: _leftPane(t)),
                const SizedBox(width: gap),
                SizedBox(
                  height: 620,
                  child: ResizerHandle(
                    read: () => leftW,
                    apply: (px) {
                      setState(() {
                        _livePct = px == null
                            ? 50
                            : (100 * px / usable).clamp(25.0, 70.0);
                      });
                    },
                    persist: (px) {
                      final ctl = ref.read(editorSplitPctProvider.notifier);
                      if (px == null) {
                        ctl.reset();
                      } else {
                        ctl.set((_livePct ?? 50).round());
                      }
                      setState(() => _livePct = null);
                    },
                    min: 300,
                    max: usable - 320,
                  ),
                ),
                const SizedBox(width: gap),
                Expanded(child: _rightPane(t)),
              ],
            );
          },
        ),
      ],
    );
  }

  /// Linke Spalte: `textarea.tex` + Prüfbericht.
  Widget _leftPane(BookClothTokens t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _tex,
          maxLines: null,
          minLines: 24,
          // Kein Spellcheck — Quelltext (spellcheck=false im Original).
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontFamilyFallback: AppFonts.fallback,
            fontSize: 13,
            height: 1.7,
            color: t.ink,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: t.surface,
            contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: t.borderStrong),
              borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: t.accent, width: 2),
              borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
            ),
          ),
        ),
        EditorLintView(result: _lint),
      ],
    );
  }

  /// Rechte Spalte: Eyebrow + Vorschau-Karte.
  Widget _rightPane(BookClothTokens t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Eyebrow('Live-Vorschau'),
        ),
        Container(
          constraints: const BoxConstraints(minHeight: 560),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(BookClothTokens.radius),
            boxShadow: t.shadow1,
          ),
          child: TexPreview(document: _preview),
        ),
      ],
    );
  }
}

/// Toolbar-Knopf (`.tex-toolbar .btn`): Mono 11.5px.
class _ToolbarBtn extends StatefulWidget {
  const _ToolbarBtn({
    required this.label,
    required this.tooltip,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_ToolbarBtn> createState() => _ToolbarBtnState();
}

class _ToolbarBtnState extends State<_ToolbarBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: _hover ? t.surface2 : t.surface,
              border: Border.all(color: t.borderStrong),
              borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontFamilyFallback: AppFonts.fallback,
                fontWeight: FontWeight.w500,
                fontSize: 11.5,
                height: 1,
                color: t.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
