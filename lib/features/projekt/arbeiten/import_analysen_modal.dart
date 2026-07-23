/// ⭱ Analysen importieren — Port von `importAnalysenModal(rec, onDone)`
/// (views_projekt.js:437-490): Multi-File-Import der GPT-Ausgaben mit dem
/// 11-stufigen Dateiname-Mapping (`ProjectRepository.applyGeneratedFile`),
/// `.md` → Erklärbuch, Registry ZULETZT anwenden, danach IMMER speichern.
/// „Fertig — Arbeit neu laden“: ist die Arbeit aktiv, läuft der E8-Reboot
/// (statt `location.reload()`), sonst nur der Listen-Redraw des Aufrufers.
library;

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/modal.dart';
import '../../../data/models/models.dart';
import '../../../data/repos/project_repository.dart';
import 'works_actions.dart';

/// Modal öffnen. [onDone] = Listen-Redraw des Arbeiten-Menüs (läuft nur,
/// wenn die Arbeit NICHT aktiv ist — sonst Reboot).
void showImportAnalysenModal(
  BuildContext context, {
  required ProjectRecord rec,
  VoidCallback? onDone,
}) {
  showAppModal(
    context,
    title: Text('⭱ Analysen importieren — ${rec.name}'),
    body: _ImportAnalysenBody(rec: rec, onDone: onDone),
  );
}

/// Eine Logzeile mit Farb-Klasse (Original: inline style var(--bad)/…).
class _LogLine {
  final String text;

  /// null = normal, 'bad' = rot, 'warn' = gelb, 'mut' = muted.
  final String? tone;

  const _LogLine(this.text, [this.tone]);
}

class _ImportAnalysenBody extends ConsumerStatefulWidget {
  const _ImportAnalysenBody({required this.rec, this.onDone});

  final ProjectRecord rec;
  final VoidCallback? onDone;

  @override
  ConsumerState<_ImportAnalysenBody> createState() =>
      _ImportAnalysenBodyState();
}

class _ImportAnalysenBodyState extends ConsumerState<_ImportAnalysenBody> {
  /// Der Record wandert durch die Importe (applyGeneratedFile liefert
  /// jeweils eine aktualisierte Kopie — Original mutiert in-place).
  late ProjectRecord _rec = widget.rec;
  final List<_LogLine> _log = [];
  bool _busy = false;

  void _add(String text, [String? tone]) =>
      setState(() => _log.add(_LogLine(text, tone)));

  /// Datei-Schleife (views_projekt.js:449-483). Reihenfolge wie im Original:
  /// je Datei einsortieren (Registry nur merken), Registry ZULETZT anwenden,
  /// dann IMMER speichern.
  Future<void> _pickAndImport() async {
    if (_busy) return;
    // Original-accept ist application/json; .md (Erklärbuch) wird im Code
    // trotzdem behandelt — hier deshalb beide Endungen im Picker.
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'md'],
      allowMultiple: true,
      withData: true,
    );
    if (res == null || res.files.isEmpty || !mounted) return;
    setState(() => _busy = true);

    final repo = ref.read(projectRepositoryProvider);
    List<Object?>? registry;
    for (final f in res.files) {
      final bytes = f.bytes;
      if (bytes == null) continue;
      try {
        if (RegExp(r'\.md$', caseSensitive: false).hasMatch(f.name)) {
          // Erklärbuch kommt als Markdown (kein JSON) — direkt übernehmen.
          final md = utf8.decode(bytes, allowMalformed: true);
          final raw = Map<String, dynamic>.from(_rec.raw);
          raw['userModified'] = true;
          final gen = raw['generated'];
          final g = gen is Map
              ? gen.map((k, v) => MapEntry('$k', v))
              : <String, Object?>{};
          g['erklaerbuch'] = md;
          raw['generated'] = g;
          _rec = ProjectRecord.fromJson(raw);
          _add('✓ Erklärbuch (${(md.length / 1024).toStringAsFixed(0)} KB) übernommen');
          continue;
        }
        final obj = json.decode(utf8.decode(bytes));
        final r = repo.applyGeneratedFile(_rec, f.name, obj);
        _rec = r.rec;
        if (r.registryError != null) {
          _add('✗ ${f.name}: ${r.registryError}', 'bad');
        } else if (r.registry != null) {
          registry = r.registry;
          _add('⏳ Registry erkannt (${registry!.length} Quellen) — wird angewendet …');
        } else if (r.label != null) {
          _add('✓ ${r.label}');
        } else {
          _add('⚠ ${f.name}: nicht zuordenbar oder ungültiger Inhalt '
              '(Dateiname/Struktur prüfen)', 'warn');
        }
      } catch (err) {
        _add('✗ ${f.name}: ${err is FormatException ? err.message : err}', 'bad');
      }
    }

    // Registry zuletzt anwenden (views_projekt.js:472-481).
    if (registry != null) {
      try {
        final (r, updated) = await applyRegistry(repo, _rec, registry);
        _rec = updated;
        if (r.ok) {
          final stats = r.stats ?? const <String, Object?>{};
          _add('✓ Registry angewendet — ${stats['quellen']} Quellen, '
              '${r.warnings.isNotEmpty ? r.warnings.join(' · ') : 'alle Fußnoten geprüft'}');
        } else {
          for (final x in r.errors) {
            _add('✗ $x', 'bad');
          }
        }
      } catch (err) {
        _add('✗ Registry nicht anwendbar: '
            '${err is FormatException ? err.message : err}', 'bad');
      }
    }

    await repo.save(_rec);
    if (!mounted) return;
    _add('Gespeichert.', 'mut');
    setState(() => _busy = false);
  }

  /// „Fertig — Arbeit neu laden“ (views_projekt.js:485-489): Modal zu;
  /// aktive Arbeit → E8-Reboot, sonst Listen-Redraw. Boot-Zugriffe VOR dem
  /// Schließen greifen (das Schließen entsorgt diesen State).
  Future<void> _done() async {
    final boot = ref.read(projectBootProvider).value;
    final bootNotifier = ref.read(projectBootProvider.notifier);
    final onDone = widget.onDone;
    closeAppModal();
    if (boot?.activeId == _rec.id) {
      await bootNotifier.reboot();
    } else {
      onDone?.call();
    }
  }

  Color? _tone(BookClothTokens t, String? tone) => switch (tone) {
        'bad' => t.bad,
        'warn' => t.warn,
        'mut' => t.muted,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Erklärtext mit der Liste erkannter Dateinamen (Code-Spans mono).
        Text.rich(
          TextSpan(children: [
            const TextSpan(
                text: 'Die Dateien aus der GPT-Antwort auf den Gesamt-Prompt '
                    'hier laden (mehrere auf einmal möglich). Erkannt werden: '),
            _code('<abschnitt>.json'),
            const TextSpan(text: ' (z. B. 3_2_1.json), '),
            _code('kapitel-N.json'),
            const TextSpan(text: ', '),
            _code('gesamt.json'),
            const TextSpan(text: ', '),
            _code('fazit-connections.json'),
            const TextSpan(text: ', '),
            _code('connections.json'),
            const TextSpan(text: ', '),
            _code('struktur/quellen/inhalt/standards.json'),
            const TextSpan(text: ', '),
            _code('instanzen.json'),
            const TextSpan(text: ' (eigene Absatz-Instanzen), '),
            _code('erklaerbuch.md'),
            const TextSpan(text: ' (eingebautes Buch), '),
            _code('figures.json'),
            const TextSpan(text: ', '),
            _code('registry.json'),
            const TextSpan(
                text: ' (Quellen-Registry) sowie Quellen-Dossiers (per sourceId).'),
          ]),
          style: AppTextStyles.small.copyWith(color: t.muted),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            variant: AppButtonVariant.primary,
            small: true,
            onPressed: _busy ? null : _pickAndImport,
            child: const Text('Dateien wählen'),
          ),
        ),
        // #iaLog: max-height 220, eigener Scroll.
        if (_log.isNotEmpty) ...[
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final l in _log)
                    Text(
                      l.text,
                      style: AppTextStyles.small
                          .copyWith(color: _tone(t, l.tone) ?? t.ink2),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            small: true,
            onPressed: _done,
            child: const Text('Fertig — Arbeit neu laden'),
          ),
        ),
      ],
    );
  }

  static TextSpan _code(String text) => TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: AppFonts.mono,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: 12,
        ),
      );
}
