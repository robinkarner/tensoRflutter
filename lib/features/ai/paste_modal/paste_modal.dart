/// ⭱ Einfüge-Fenster (ZENTRAL) — Port von `Enhance.pasteModal`
/// (enhance.js:887-954): oben der aktuelle Speicherstand dieser Stelle,
/// darunter die externe GPT-Antwort einfügen — der Format-Checker läuft
/// automatisch beim Tippen/Einfügen (350 ms Debounce), ⭱ übernimmt.
///
/// Multi-Variante (⚡ Voranalyse): gekochte Antwort als readonly-Textarea +
/// ⧉/⭳-Knöpfe, „⧉ Gesamt-Prompt kopieren (inkl. LaTeX)“ und der Sprung in
/// „⭱ Analysen importieren (mehrere Dateien)“ (K-2-Modal).
library;

import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/modal.dart';
import '../../../core/widgets/notice.dart';
import '../../../data/models/models.dart';
import '../../../data/repos/project_repository.dart';
import '../../projekt/projekt.dart';
import '../../quellen/util/save_file.dart';
import '../client/claude_client.dart';
import '../flows/ai_flow.dart';
import '../flows/checkers.dart';
import '../flows/registry.dart';
import '../widgets/ai_bits.dart';
import 'info_modal.dart';

/// Modal öffnen. [opts]-Pendant: [prefill], [autocheck], [note], [onDone].
void showAiPasteModal(
  BuildContext context, {
  required AiFlowCtx ctx,
  required String flowId,
  String? prefill,
  bool autocheck = false,
  String? note,
  VoidCallback? onDone,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  final flow = aiFlowById(buildAiFlows(container, ctx), flowId);
  showAppModal<void>(
    context,
    title: Text('${flow.icon} ${flow.title} — Einfügen & Übernehmen'),
    body: _PasteBody(
      ctx: ctx,
      flowId: flowId,
      prefill: prefill,
      autocheck: autocheck,
      note: note,
      onDone: onDone,
    ),
  );
}

/// Eingebaute-Arbeit-Sperre des Multi-Imports (enhance.js:923-925): nur
/// echte Instanz-Arbeiten haben einen Record für den Analysen-Import.
Future<void> aiOpenMultiImport(BuildContext context, {required String alertText}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final boot = container.read(projectBootProvider).value;
  final activeId = boot?.activeId ?? ProjectRecord.defaultId;
  ProjectRecord? rec;
  if (activeId != ProjectRecord.defaultId) {
    try {
      rec = await container.read(projectRepositoryProvider).get(activeId);
    } catch (_) {
      rec = null;
    }
  }
  if (!context.mounted) return;
  if (rec == null) {
    aiAlert(context, alertText);
    return;
  }
  closeAppModal();
  showImportAnalysenModal(context, rec: rec);
}

/// `alert(...)`-Pendant — schlichtes OK-Fenster.
void aiAlert(BuildContext context, String text) {
  final t = BookClothTokens.of(context);
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BookClothTokens.radiusLg)),
      child: Container(
        width: 420,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text,
                style: AppTextStyles.small
                    .copyWith(fontSize: 14, height: 1.5, color: t.ink)),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                small: true,
                variant: AppButtonVariant.primary,
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PasteBody extends ConsumerStatefulWidget {
  const _PasteBody({
    required this.ctx,
    required this.flowId,
    this.prefill,
    this.autocheck = false,
    this.note,
    this.onDone,
  });

  final AiFlowCtx ctx;
  final String flowId;
  final String? prefill;
  final bool autocheck;
  final String? note;
  final VoidCallback? onDone;

  @override
  ConsumerState<_PasteBody> createState() => _PasteBodyState();
}

class _PasteBodyState extends ConsumerState<_PasteBody> {
  late final TextEditingController _ans =
      TextEditingController(text: widget.prefill ?? '');
  Timer? _debounce;
  AiCheckResult? _check;
  String _msg = '';
  AiMsgTone _tone = AiMsgTone.mut;
  bool _rawCopied = false;
  bool _promptCopied = false;

  AiFlow get _flow {
    final container = ProviderScope.containerOf(context, listen: false);
    return aiFlowById(buildAiFlows(container, widget.ctx), widget.flowId);
  }

  @override
  void initState() {
    super.initState();
    if (widget.autocheck && _ans.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runCheck());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ans.dispose();
    super.dispose();
  }

  void _runCheck() {
    if (!mounted) return;
    if (_ans.text.trim().isEmpty) {
      setState(() => _check = null);
      return;
    }
    setState(() => _check = runAiCheck(_flow, _ans.text, claudeClean));
  }

  /// Format-Checker debounced 350 ms bei input (enhance.js:939).
  void _onInput(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _runCheck);
  }

  void _doApply(String text) {
    final flow = _flow;
    try {
      final out = flow.run?.call(claudeClean(text)) ?? '';
      setState(() {
        _msg = '✓ $out';
        _tone = AiMsgTone.ok;
      });
      Timer(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        // Root-Kontext überlebt das Schließen des Modals (done navigiert).
        final nav = Navigator.of(context, rootNavigator: true);
        closeAppModal();
        widget.onDone?.call();
        flow.done?.call(nav.context);
      });
    } catch (e) {
      setState(() {
        _msg = '✗ ${aiErrText(e)}';
        _tone = AiMsgTone.err;
      });
      _runCheck();
    }
  }

  Future<void> _loadFile() async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'md', 'txt'],
      withData: true,
    );
    final bytes = res?.files.firstOrNull?.bytes;
    if (bytes == null || !mounted) return;
    _ans.text = utf8.decode(bytes, allowMalformed: true);
    _runCheck();
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    // Live-Stände beobachten (Referenz + Checker sehen frische Daten).
    watchAiSources(ref);
    final flow = _flow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.note != null) ...[
          // `.notice.info.small` (enhance.js:892).
          Notice(
            variant: NoticeVariant.info,
            child: Text(widget.note!,
                style: AppTextStyles.small.copyWith(color: t.ink2)),
          ),
          const SizedBox(height: 10),
        ],
        // `.pm-ref` — aktueller Speicherstand dieser Stelle.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: t.surface2,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Eyebrow('Aktueller Speicherstand dieser Stelle'),
              const SizedBox(height: 6),
              if (flow.reference != null) AiReferenceView(flow.reference!()),
            ],
          ),
        ),
        if (flow.multi) ..._multiPart(t, flow) else ..._singlePart(t, flow),
        // `.pm-foot`
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: t.border)),
          ),
          child: Row(
            children: [
              _inlink(t, '⧈ Alle Stellen & Datenflüsse', () {
                final nav = Navigator.of(context, rootNavigator: true);
                closeAppModal();
                showAiInfoModal(nav.context,
                    ctx: widget.ctx, currentId: widget.flowId);
              }),
              const Spacer(),
              Text('Format-Checker läuft automatisch beim Einfügen',
                  style: AppTextStyles.small.copyWith(color: t.muted)),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _singlePart(BookClothTokens t, AiFlow flow) => [
        const SizedBox(height: 14),
        const Eyebrow('Externe GPT-Antwort einfügen'),
        const SizedBox(height: 6),
        AiAnswerField(
          controller: _ans,
          placeholder: flow.placeholder ?? 'Antwort hier einfügen …',
          onChanged: _onInput,
        ),
        if (_check != null) AiCheckBox(_check!),
        const SizedBox(height: 8),
        Row(
          children: [
            AppButton(
              small: true,
              variant: AppButtonVariant.primary,
              onPressed: () {
                if (_ans.text.trim().isEmpty) {
                  setState(() {
                    _msg = 'Antwort einfügen — der Checker meldet sich automatisch.';
                    _tone = AiMsgTone.mut;
                  });
                  return;
                }
                _doApply(_ans.text);
              },
              child: const Text('⭱ Übernehmen'),
            ),
            const SizedBox(width: 8),
            AppButton(
              small: true,
              onPressed: _loadFile,
              child: const Text('Datei laden'),
            ),
            const SizedBox(width: 8),
            Expanded(child: AiMsgText(_msg, _tone)),
          ],
        ),
      ];

  List<Widget> _multiPart(BookClothTokens t, AiFlow flow) => [
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Die Voranalyse-Antwort umfasst '),
            const TextSpan(
                text: 'mehrere Dateien', style: TextStyle(fontWeight: FontWeight.w700)),
            const TextSpan(
                text: ' — Prompt kopieren, extern ausführen (oder direkt kochen), dann alle Dateien importieren:'),
          ]),
          style: AppTextStyles.small.copyWith(color: t.muted),
        ),
        if (widget.prefill != null && widget.prefill!.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Eyebrow('Gekochte Antwort — als Dateien sichern, dann importieren'),
          const SizedBox(height: 6),
          AiAnswerField(controller: _ans, readOnly: true),
          const SizedBox(height: 6),
          Row(
            children: [
              AppButton(
                small: true,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: widget.prefill!));
                  if (mounted) setState(() => _rawCopied = true);
                },
                child: Text(_rawCopied ? '✔ kopiert' : '⧉ Antwort kopieren'),
              ),
              const SizedBox(width: 8),
              AppButton(
                small: true,
                onPressed: () =>
                    saveTextFile('voranalyse-antwort.txt', widget.prefill!),
                child: const Text('⭳ Antwort speichern (.txt)'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            AppButton(
              small: true,
              onPressed: () async {
                final container = ProviderScope.containerOf(context, listen: false);
                await Clipboard.setData(
                    ClipboardData(text: aiPromptFor(container, flow)));
                if (mounted) setState(() => _promptCopied = true);
              },
              child: Text(_promptCopied
                  ? '✔ kopiert'
                  : '⧉ Gesamt-Prompt kopieren (inkl. LaTeX)'),
            ),
            const SizedBox(width: 8),
            AppButton(
              small: true,
              variant: AppButtonVariant.primary,
              onPressed: () => aiOpenMultiImport(
                Navigator.of(context, rootNavigator: true).context,
                alertText:
                    'Diese Arbeit ist eingebaut — ihre Voranalyse wird mitgeliefert. Für eine neue Voranalyse eine eigene .tex-Arbeit importieren (🗂-Menü).',
              ),
              child: const Text('⭱ Analysen importieren (mehrere Dateien)'),
            ),
          ],
        ),
      ];

  Widget _inlink(BookClothTokens t, String label, VoidCallback onTap) =>
      MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Text(
            label,
            style: AppTextStyles.small.copyWith(
              color: t.accentInk,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      );
}
