/// ＋ Neue Arbeit aus LaTeX — Port von `neueArbeitModal()`
/// (views_projekt.js:343-434): .tex laden oder einfügen → Live-Parse mit
/// 450-ms-Debounce und deutscher Fehlerausgabe → „Anlegen & aktivieren“
/// (E8-Reboot statt `location.reload()`).
///
/// Bewusste Abweichungen (im Code je Stelle kommentiert):
///  * 📄 PDF → LaTeX (Beta) entfällt (Entscheidung E5) — der Knopf bleibt
///    als deaktivierter Hinweis an der Original-Position stehen.
///  * Drag&Drop von Dateien aufs Modal entfällt vorerst (bräuchte ein
///    zusätzliches Paket wie desktop_drop; pubspec ist für Feature-Wellen
///    tabu) — der Datei-Weg läuft über „.tex-Datei laden“.
library;

import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/modal.dart';
import '../../../core/widgets/notice.dart';
import '../../../data/repos/project_repository.dart';
import '../../../domain/texparse.dart';
import 'works_actions.dart';

/// Modal öffnen. [ref] liefert Repository + Boot-Notifier des Aufrufers
/// (Arbeiten-Menü in der Topbar).
void showNeueArbeitModal(BuildContext context, WidgetRef ref) {
  showAppModal(
    context,
    title: const Text('＋ Neue Arbeit aus LaTeX'),
    body: const _NeueArbeitBody(),
  );
}

class _NeueArbeitBody extends ConsumerStatefulWidget {
  const _NeueArbeitBody();

  @override
  ConsumerState<_NeueArbeitBody> createState() => _NeueArbeitBodyState();
}

class _NeueArbeitBodyState extends ConsumerState<_NeueArbeitBody> {
  final _nameCtrl = TextEditingController();
  final _texCtrl = TextEditingController();

  /// Debounce-Timer des Live-Parse (450 ms, views_projekt.js:422).
  Timer? _checkTimer;

  /// Letztes Parse-Ergebnis (`lastResult`) — Grundlage für Name-Fallback
  /// und den Create-Enable.
  TexParseResult? _lastResult;
  bool _creating = false;
  String _createError = '';

  @override
  void dispose() {
    _checkTimer?.cancel();
    _nameCtrl.dispose();
    _texCtrl.dispose();
    super.dispose();
  }

  /// `check()` (views_projekt.js:407-420): leerer Text leert den Report,
  /// sonst parsen und Erfolg/Fehler/Warnungen rendern.
  void _check() {
    final tex = _texCtrl.text;
    setState(() {
      _createError = '';
      _lastResult = tex.trim().isEmpty ? null : TexParse.parse(tex);
    });
  }

  void _onTexChanged(String _) {
    _checkTimer?.cancel();
    _checkTimer = Timer(const Duration(milliseconds: 450), () {
      if (mounted) _check();
    });
  }

  /// „.tex-Datei laden“ (views_projekt.js:368-372): Inhalt in die Textarea,
  /// leeres Namensfeld aus dem Dateinamen (ohne .tex/.txt) vorbelegen.
  Future<void> _loadTexFile() async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['tex', 'txt'],
      withData: true,
    );
    final f = res?.files.firstOrNull;
    if (f == null || f.bytes == null || !mounted) return;
    _texCtrl.text = utf8.decode(f.bytes!, allowMalformed: true);
    if (_nameCtrl.text.isEmpty) {
      _nameCtrl.text = f.name.replaceAll(RegExp(r'\.(tex|txt)$', caseSensitive: false), '');
    }
    _check();
  }

  /// „Anlegen & aktivieren“ (views_projekt.js:426-433): erneut parsen,
  /// speichern, Modal zu, Arbeit aktivieren (Reboot) + nach #/projekt.
  Future<void> _create() async {
    if (_creating) return;
    setState(() => _creating = true);
    final tex = _texCtrl.text;
    final metaTitle = _metaString(_lastResult, 'title');
    final name = _nameCtrl.text.trim().isNotEmpty
        ? _nameCtrl.text.trim()
        : (metaTitle.isNotEmpty ? metaTitle : 'Neue Arbeit');
    final r = await createFromTex(ref.read(projectRepositoryProvider), name, tex);
    if (!mounted) return;
    if (!r.ok) {
      setState(() {
        _creating = false;
        _createError = r.errors.join(' · ');
      });
      return;
    }
    // Projects.setActive-Pendant: Navigation + E8-Reboot (CONTRACTS §0).
    // Router/Notifier VOR dem Schließen greifen — das Schließen entsorgt
    // diesen State.
    final router = GoRouter.of(context);
    final bootNotifier = ref.read(projectBootProvider.notifier);
    closeAppModal();
    router.go(Routes.projekt);
    await bootNotifier.activateProject(r.id!);
  }

  static String _metaString(TexParseResult? r, String key) {
    final meta = r?.thesis?['meta'];
    if (meta is Map) return meta[key]?.toString() ?? '';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final r = _lastResult;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Erklärtext — Original ohne die Drag&Drop-/PDF-Beta-Sätze (E5;
        // beide Wege existieren in dieser Version nicht).
        Text(
          'Den vollständigen LaTeX-Quelltext laden oder einfügen. Die Software '
          'parst Gliederung, Absätze und Fußnoten live und meldet genau, '
          'wenn etwas nicht ladbar ist.',
          style: AppTextStyles.small.copyWith(color: t.muted),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: 8,
          children: [
            AppButton(
              small: true,
              onPressed: _loadTexFile,
              child: const Text('.tex-Datei laden'),
            ),
            // E5: „📄 PDF → LaTeX (Beta)“ ist zurückgestellt — der Knopf
            // bleibt als deaktivierter Hinweis an der Original-Position.
            const AppButton(
              small: true,
              tooltip: 'PDF → LaTeX (Beta) ist in dieser Version nicht '
                  'enthalten — mit echtem LaTeX-Quelltext bleibt das Ergebnis '
                  'immer besser',
              onPressed: null,
              child: Text('📄 PDF → LaTeX (Beta)'),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Name der Arbeit',
                      style: AppTextStyles.small.copyWith(color: t.ink2)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _nameCtrl,
                    decoration:
                        const InputDecoration(hintText: 'z. B. Masterarbeit XY'),
                    style: AppTextStyles.form.copyWith(color: t.ink),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _texCtrl,
          onChanged: _onTexChanged,
          minLines: 8,
          maxLines: 16,
          // Placeholder ohne den Drag&Drop-Zusatz des Originals („— Datei
          // hierher ziehen geht auch“) — Drag&Drop entfällt (siehe oben).
          decoration: const InputDecoration(
            hintText:
                r'\documentclass… oder direkt der Hauptteil mit \chapter/\section …',
          ),
          style: AppTextStyles.mono.copyWith(fontSize: 11.5, color: t.ink),
        ),
        const SizedBox(height: 10),
        Row(
          spacing: 8,
          children: [
            AppButton(
              small: true,
              tooltip:
                  'Parse-Test erneut ausführen (läuft beim Tippen automatisch)',
              onPressed: _check,
              child: const Text('↻ Prüfen'),
            ),
            AppButton(
              variant: AppButtonVariant.primary,
              small: true,
              onPressed: (r?.ok ?? false) && !_creating ? _create : null,
              child: const Text('Anlegen & aktivieren'),
            ),
          ],
        ),
        // #naReport — Erfolgs-/Fehler-Notice + Fehler-/Warnzeilen.
        if (r != null) ...[
          const SizedBox(height: 10),
          _ParseReport(result: r),
        ],
        if (_createError.isNotEmpty) ...[
          const SizedBox(height: 10),
          _BadNotice(text: '✗ $_createError'),
        ],
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(children: [
            TextSpan(
                text: 'Danach: ',
                style: TextStyle(fontWeight: FontWeight.w600, color: t.ink2)),
            const TextSpan(
                text: '„🤖 Gesamt-Prompt“ an der neuen Arbeit kopieren '
                    '(Formatvorgabe + Notation + LaTeX) → Antwort über '
                    '„⭱ Analysen“ importieren (Registry, Abschnitte, Dossiers, '
                    'Connections) → PDFs über die Quellen-Bibliothek beschaffen.'),
          ]),
          style: AppTextStyles.small.copyWith(color: t.muted),
        ),
      ],
    );
  }
}

/// Erfolgs-/Fehler-Report des Live-Parse (views_projekt.js:412-418).
class _ParseReport extends StatelessWidget {
  const _ParseReport({required this.result});

  final TexParseResult result;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final r = result;
    final stats = r.stats ?? const <String, Object?>{};
    final meta = r.thesis?['meta'];
    final title = meta is Map ? (meta['title']?.toString() ?? '') : '';
    final author = meta is Map ? (meta['author']?.toString() ?? '') : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (r.ok)
          Notice(
            variant: NoticeVariant.info,
            child: Text.rich(TextSpan(children: [
              TextSpan(
                  text: '✓ Ladbar: ${stats['kapitel']} Kapitel · '
                      '${stats['abschnitte']} Abschnitte · '
                      '${stats['fussnoten']} Fußnoten. Titel erkannt: '),
              TextSpan(
                  text: title,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              if (author.isNotEmpty) TextSpan(text: ' — $author'),
            ])),
          )
        else
          const _BadNotice(text: '✗ Nicht ladbar. Gründe:', boldHead: true),
        for (final e in r.errors)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('✗ $e',
                style: AppTextStyles.small.copyWith(color: t.bad)),
          ),
        for (final w in r.warnings)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('⚠ $w',
                style: AppTextStyles.small.copyWith(color: t.warn)),
          ),
      ],
    );
  }
}

/// `.notice` mit roter Bordüre (`style="border-color:var(--bad)"`).
class _BadNotice extends StatelessWidget {
  const _BadNotice({required this.text, this.boldHead = false});

  final String text;
  final bool boldHead;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
      decoration: BoxDecoration(
        color: t.surface2,
        border: Border.all(color: t.bad),
        borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
      ),
      child: boldHead
          ? Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: text.split(' Gründe:').first,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const TextSpan(text: ' Gründe:'),
              ]),
              style: AppTextStyles.small.copyWith(color: t.ink2),
            )
          : Text(text, style: AppTextStyles.small.copyWith(color: t.ink2)),
    );
  }
}
