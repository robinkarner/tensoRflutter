/// 📓 Erklärbuch-Tab — `analyseBuch` + `nbEditModal`
/// (views_analyse.js:57-116).
///
/// nb-bar: „✎ Bearbeiten“ · „⭱ Import“ · „⭳ Export“ · Reset-Knopf
/// (nur bei eigenem Buch) bzw. Status-Chip („✦ eingebautes Buch“ /
/// „Starter-Buch“) · Spacer · „Referenz ↗“. Darunter das gerenderte Buch
/// (`.nb-doc`, max 900px zentriert).
///
/// Editor-Modal: 1fr/1fr-Split (Quelltext | Live-Vorschau mit 350 ms-
/// Debounce), Modal-Sonderbreite 1180 (`.modal:has(.nb-edit-grid)`),
/// ≤860px einspaltig. „Speichern“ persistiert und schließt.
///
/// ⭱ Import: übernimmt ein per KI generiertes Markdown-Dokument als eigenes
/// Buch (der Weg „Prompt → Modell → einfügen“ aus docs/ERKLAERBUCH.md; der
/// Magic-Ein-Klick-Weg kommt mit der AI-Schicht K-3).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/modal.dart';
import '../../quellen/util/dialogs.dart';
import '../../quellen/util/save_file.dart';
import 'erklaerbuch_referenz.dart';
import 'notebook_doc.dart';
import 'notebook_state.dart';

class ErklaerbuchTab extends ConsumerWidget {
  const ErklaerbuchTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(erklaerbuchSourceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // nb-bar
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            Expanded(
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AppButton(
                    small: true,
                    onPressed: () => _openEditModal(context, ref, source.src),
                    child: const Text('✎ Bearbeiten'),
                  ),
                  AppButton(
                    small: true,
                    tooltip:
                        'KI-generiertes Erklärbuch (Markdown) als eigene Fassung übernehmen',
                    onPressed: () => _openImportModal(context, ref),
                    child: const Text('⭱ Import'),
                  ),
                  AppButton(
                    small: true,
                    tooltip: 'Aktuelles Erklärbuch als .md sichern',
                    onPressed: () => saveTextFile('erklaerbuch.md', source.src),
                    child: const Text('⭳ Export'),
                  ),
                  if (source.own)
                    AppButton(
                      small: true,
                      tooltip:
                          'Eigenes Buch verwerfen und zum ${source.hasBuiltin ? 'mitgelieferten Buch' : 'Starter-Buch'} zurück',
                      onPressed: () => _reset(context, ref, source.hasBuiltin),
                      child: Text(
                          '↺ ${source.hasBuiltin ? 'Eingebautes Buch' : 'Starter'}'),
                    )
                  else if (source.hasBuiltin)
                    const Tooltip(
                      message:
                          'Diese Arbeit bringt ihr Erklärbuch fertig generiert mit — ✎ Bearbeiten oder ⭱ Import erzeugen eine eigene Fassung',
                      child: AppChip(
                          label: '✦ eingebautes Buch',
                          variant: AppChipVariant.ki,
                          mini: true),
                    )
                  else
                    const Tooltip(
                      message:
                          'Noch kein eigenes Buch — das Starter-Buch rechnet live mit den Daten der aktiven Arbeit',
                      child: AppChip(label: 'Starter-Buch', mini: true),
                    ),
                ],
              ),
            ),
            AppButton(
              small: true,
              variant: AppButtonVariant.ghost,
              tooltip:
                  'Vollständige Baustein-Referenz (Technologien, Schnittstellen, Datenpaket)',
              onPressed: () => showAppModal<void>(
                context,
                title: const Text('Erklärbuch — Referenz'),
                maxWidth: 900,
                body: const NotebookDoc(erklaerbuchReferenzMd, maxWidth: null),
              ),
              child: const Text('Referenz ↗'),
            ),
          ]),
        ),
        // .nb-doc
        NotebookDoc(source.src),
      ],
    );
  }

  Future<void> _reset(
      BuildContext context, WidgetRef ref, bool hasBuiltin) async {
    final ok = await showAppConfirm(
      context,
      'Eigenes Erklärbuch verwerfen und zum '
      '${hasBuiltin ? 'mitgelieferten Buch dieser Arbeit' : 'Starter-Buch'} zurückkehren?',
    );
    if (!ok) return;
    ref.read(notebookStoreProvider.notifier).set(null);
  }

  void _openEditModal(BuildContext context, WidgetRef ref, String src) {
    showAppModal<void>(
      context,
      title: const Text('✎ Erklärbuch bearbeiten'),
      maxWidth: 1180, // `.modal:has(.nb-edit-grid)` (app.css:1484)
      scrollableBody: false,
      body: _NbEditBody(
        initial: src,
        onSave: (value) {
          ref.read(notebookStoreProvider.notifier).set(value);
          closeAppModal();
        },
      ),
    );
  }

  void _openImportModal(BuildContext context, WidgetRef ref) {
    showAppModal<void>(
      context,
      title: const Text('⭱ Erklärbuch importieren'),
      scrollableBody: false,
      body: _NbImportBody(
        onApply: (value) {
          ref.read(notebookStoreProvider.notifier).set(value);
          closeAppModal();
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ✎ Editor-Modal (nbEditModal)
// ---------------------------------------------------------------------------

class _NbEditBody extends StatefulWidget {
  const _NbEditBody({required this.initial, required this.onSave});

  final String initial;
  final ValueChanged<String> onSave;

  @override
  State<_NbEditBody> createState() => _NbEditBodyState();
}

class _NbEditBodyState extends State<_NbEditBody> {
  late final TextEditingController _ctl =
      TextEditingController(text: widget.initial);
  Timer? _debounce;
  late String _preview = widget.initial;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  /// input → 350 ms Debounce → komplette Neu-Render der Vorschau
  /// (views_analyse.js:107).
  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _preview = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);

    final textarea = Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
      ),
      child: TextField(
        controller: _ctl,
        onChanged: _onChanged,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: TextStyle(
          fontFamily: AppFonts.mono,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: 12.5,
          height: 1.65,
          color: t.ink,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(10),
        ),
      ),
    );

    final preview = Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: NotebookDoc(_preview, maxWidth: null),
      ),
    );

    return LayoutBuilder(builder: (context, constraints) {
      // `.nb-edit-grid`: 1fr/1fr; ≤860px eine Spalte (app.css:1480-1483).
      final twoCols = constraints.maxWidth > 860;
      final gridH =
          (MediaQuery.sizeOf(context).height * .6).clamp(320.0, 560.0);

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: twoCols ? gridH : gridH * 1.4,
            child: twoCols
                ? Row(children: [
                    Expanded(child: textarea),
                    const SizedBox(width: 12),
                    Expanded(child: preview),
                  ])
                : Column(children: [
                    Expanded(child: textarea),
                    const SizedBox(height: 12),
                    Expanded(child: preview),
                  ]),
          ),
          const SizedBox(height: 10),
          Row(children: [
            AppButton(
              small: true,
              variant: AppButtonVariant.primary,
              onPressed: () => widget.onSave(_ctl.text),
              child: const Text('Speichern'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Vorschau aktualisiert beim Tippen · Bausteine: docs/ERKLAERBUCH.md',
                style: AppTextStyles.small.copyWith(color: t.muted),
              ),
            ),
          ]),
        ],
      );
    });
  }
}

// ---------------------------------------------------------------------------
// ⭱ Import-Modal
// ---------------------------------------------------------------------------

class _NbImportBody extends StatefulWidget {
  const _NbImportBody({required this.onApply});

  final ValueChanged<String> onApply;

  @override
  State<_NbImportBody> createState() => _NbImportBodyState();
}

class _NbImportBodyState extends State<_NbImportBody> {
  final TextEditingController _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Antwort des KI-Modells (reines Markdown-Dokument) hier einfügen — '
          'sie wird als eigenes Erklärbuch dieser Arbeit gespeichert.',
          style: AppTextStyles.small.copyWith(color: t.ink2),
        ),
        const SizedBox(height: 10),
        Container(
          height: 320,
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
          ),
          child: TextField(
            controller: _ctl,
            maxLines: null,
            expands: true,
            autofocus: true,
            textAlignVertical: TextAlignVertical.top,
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontFamilyFallback: AppFonts.fallback,
              fontSize: 12.5,
              height: 1.65,
              color: t.ink,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(10),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          AppButton(
            small: true,
            variant: AppButtonVariant.primary,
            onPressed: () {
              if (_ctl.text.trim().isEmpty) return;
              widget.onApply(_ctl.text);
            },
            child: const Text('⭱ Übernehmen'),
          ),
        ]),
      ],
    );
  }
}
