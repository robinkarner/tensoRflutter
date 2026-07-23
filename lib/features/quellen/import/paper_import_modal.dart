/// 🤖 Paper → Quellen (KI) — der neue Sammel-Import: aus einem Paper bzw.
/// dessen Literaturverzeichnis erkennt ein Modell ALLE zitierten Quellen und
/// legt sie als manuelle Quellen an; auf Wunsch werden die öffentlich
/// auffindbaren PDFs direkt heruntergeladen und zugeordnet.
///
/// Universeller Copy/Paste-Weg (funktioniert MIT und OHNE API-Key, wie die
/// bestehenden ✦-Flows): Prompt kopieren → in ein externes GPT einfügen →
/// Antwort zurück ins Feld. Die reine Logik steckt in [paperSourcesLogic];
/// dieses Modal ist nur die Projektion.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/modal.dart';
import '../../../data/bundles/indexes.dart';
import '../../../data/repos/project_repository.dart';
import '../../pdf/assign_panel/download_engine.dart';
import 'paper_sources_logic.dart';

/// Öffnet den KI-Quellen-Import. [onDone] läuft nach dem Anlegen mit der
/// Anzahl neuer Quellen (Aufrufer kann die Liste auffrischen).
void showPaperImportModal(BuildContext context, {void Function(int created)? onDone}) {
  showAppModal(
    context,
    title: const Text('🤖 Paper → Quellen (KI)'),
    body: _PaperImportBody(onDone: onDone),
    maxWidth: 560,
  );
}

class _PaperImportBody extends ConsumerStatefulWidget {
  const _PaperImportBody({this.onDone});

  final void Function(int created)? onDone;

  @override
  ConsumerState<_PaperImportBody> createState() => _PaperImportBodyState();
}

class _PaperImportBodyState extends ConsumerState<_PaperImportBody> {
  final _paper = TextEditingController();
  final _answer = TextEditingController();
  bool _download = true;
  bool _busy = false;
  String _msg = '';
  int _done = 0;
  int _total = 0;

  @override
  void dispose() {
    _paper.dispose();
    _answer.dispose();
    super.dispose();
  }

  String? get _arbeitTitel =>
      ref.read(projectBootProvider).value?.runtime.thesis.meta.title;

  Future<void> _copyPrompt() async {
    if (_paper.text.trim().isEmpty) {
      setState(() => _msg = '✗ Erst den Paper-Text bzw. das Literaturverzeichnis einfügen.');
      return;
    }
    await Clipboard.setData(
      ClipboardData(text: paperSourcesPrompt(_paper.text, arbeitTitel: _arbeitTitel)),
    );
    setState(() => _msg =
        '✓ Prompt kopiert — in ein externes GPT einfügen, Antwort unten einsetzen.');
  }

  Future<void> _create() async {
    final raw = _answer.text.trim();
    if (raw.isEmpty) {
      setState(() => _msg = '✗ Erst die JSON-Antwort des Modells einfügen.');
      return;
    }
    final RecognizedSources parsed;
    try {
      parsed = parseRecognizedSources(
        raw,
        existingIds: ref.read(srcByIdProvider).keys.toSet(),
      );
    } catch (e) {
      setState(() => _msg = '✗ ${e is FormatException ? e.message : e}');
      return;
    }
    if (parsed.records.isEmpty) {
      setState(() => _msg = '✗ Keine Quellen erkannt (${parsed.skipped} übersprungen).');
      return;
    }

    setState(() {
      _busy = true;
      _done = 0;
      _total = parsed.records.length;
      _msg = 'Lege ${parsed.records.length} Quelle(n) an …';
    });

    final repo = ref.read(projectRepositoryProvider);
    for (final rec in parsed.records) {
      await repo.saveCustomSource(rec);
    }
    await ref.read(projectBootProvider.notifier).reboot();

    var downloaded = 0;
    var tried = 0;
    if (_download) {
      final engine = await ref.read(downloadEngineProvider.future);
      var i = 0;
      for (final rec in parsed.records) {
        i++;
        if (mounted) setState(() => _done = i);
        final link = dlLinkFor(EffectiveSrcLinks(official: _officialFor(rec)));
        if (link == null) continue;
        tried++;
        final r = await engine.tryDownload('${rec['id']}', link);
        if (r.ok) downloaded++;
      }
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _msg = '✓ ${parsed.records.length} Quelle(n) angelegt'
          '${parsed.renamed > 0 ? ' · ${parsed.renamed} umbenannt (id-Kollision)' : ''}'
          '${parsed.skipped > 0 ? ' · ${parsed.skipped} übersprungen' : ''}'
          '${_download ? ' · $downloaded/$tried PDF geladen' : ''}. '
          'Fenster schließen (×).';
    });
    widget.onDone?.call(parsed.records.length);
  }

  /// Offizieller Link wie [effectiveSrcLinks]: url gewinnt, sonst doi.org.
  String? _officialFor(Map<String, dynamic> rec) {
    final url = '${rec['url'] ?? ''}';
    if (url.isNotEmpty) return url;
    final doi = '${rec['doi'] ?? ''}';
    return doi.isNotEmpty ? 'https://doi.org/$doi' : null;
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);

    Widget field(TextEditingController c, String hint, int lines) => TextField(
          controller: c,
          minLines: lines,
          maxLines: lines,
          style: AppTextStyles.body.copyWith(fontSize: 13.5, color: t.ink),
          decoration: InputDecoration(hintText: hint),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
          Text(
            'Aus einem Paper (bzw. dessen Literaturverzeichnis) erkennt ein '
            'Modell alle zitierten Quellen und legt sie hier an. Universell '
            'per Copy/Paste — mit ODER ohne API-Key.',
            style: AppTextStyles.small.copyWith(color: t.muted),
          ),
          const SizedBox(height: 12),
          Text('1 · Paper-Text / Literaturverzeichnis einfügen',
              style: AppTextStyles.small.copyWith(color: t.ink2, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          field(_paper, 'Text des Papers oder nur die Referenzen …', 5),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              variant: AppButtonVariant.ghost,
              small: true,
              tooltip: 'Erkennungs-Prompt in die Zwischenablage — in ein externes '
                  'GPT einfügen, Antwort unten einsetzen',
              onPressed: _busy ? null : () => unawaited(_copyPrompt()),
              child: const Text('⧉ Prompt kopieren'),
            ),
          ),
          const SizedBox(height: 12),
          Text('2 · JSON-Antwort des Modells einfügen',
              style: AppTextStyles.small.copyWith(color: t.ink2, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          field(_answer, '{"sources":[ … ]}', 5),
          const SizedBox(height: 10),
          _DownloadCheck(
            value: _download,
            onChanged: _busy ? null : (v) => setState(() => _download = v),
          ),
          const SizedBox(height: 12),
          Row(children: [
            AppButton(
              variant: AppButtonVariant.primary,
              small: true,
              onPressed: _busy ? null : () => unawaited(_create()),
              child: Text(_busy && _total > 0 ? 'Arbeite … $_done/$_total' : 'Quellen anlegen'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(_msg, style: AppTextStyles.small.copyWith(color: t.muted)),
            ),
          ]),
        ],
    );
  }
}

class _DownloadCheck extends StatelessWidget {
  const _DownloadCheck({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: value,
              onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '⭳ Gefundene PDFs gleich herunterladen (arXiv/Open-Access) & zuordnen',
              style: AppTextStyles.small.copyWith(color: t.ink2),
            ),
          ),
        ]),
      ),
    );
  }
}
