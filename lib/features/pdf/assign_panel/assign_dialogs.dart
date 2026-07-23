/// Dialoge der Quell-Karte: 📚 Dossier (util.js:425-442), 📝 Notizen
/// (util.js:446-464), 🌐 Internetquelle/Website-Material (pdfengine.js:
/// 571-586, 608-623), 📝 Quellentext (js:634-643), Σ LaTeX-Material
/// (js:644-662) und die Σ-Ansicht (js:698-706).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/modal.dart';
import '../../../data/bundles/kind_labels.dart';
import '../../../data/models/models.dart';

/// 📚 Dossier einer Quelle — von überall aufrufbar. [onQuellenseite]
/// navigiert zur Quellenseite (der Link schließt das Modal selbst).
void showDossierModal(
  BuildContext context, {
  required Source source,
  VoidCallback? onQuellenseite,
}) {
  final t = BookClothTokens.of(context);
  final s = source;

  showAppModal(
    context,
    title: Text('📚 Dossier — ${s.title.isNotEmpty ? s.title : s.id}'),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            AppChip(
                label:
                    '${kindIcons[s.kind] ?? ''} ${kindLabels[s.kind] ?? s.kind}'.trim()),
            if (s.year != null) AppChip(label: '${s.year}'),
            if (s.container != null)
              AppChip(label: 'veröffentlicht: ${s.container}'),
          ],
        ),
        const SizedBox(height: 8),
        MarkdownBody(
          data: s.dossier.isNotEmpty
              ? s.dossier
              : '_Kein Dossier hinterlegt — auf der Quellenseite per 🤖 Ergänzung nachtragbar._',
        ),
        if (s.keyPoints.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Eyebrow('Kernpunkte'),
          const SizedBox(height: 6),
          for (final k in s.keyPoints)
            Padding(
              padding: const EdgeInsets.only(left: 18, top: 2, bottom: 2),
              child: Text('•  $k',
                  style: AppTextStyles.small.copyWith(fontSize: 13, color: t.ink)),
            ),
        ],
        if (s.zitierweise != null) ...[
          const SizedBox(height: 10),
          const Eyebrow('Zitierweise'),
          const SizedBox(height: 4),
          _ZitierweiseRow(zitierweise: s.zitierweise!),
        ],
        if (onQuellenseite != null) ...[
          const SizedBox(height: 12),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                closeAppModal();
                onQuellenseite();
              },
              child: Text('Quellenseite ↗',
                  style: AppTextStyles.small.copyWith(color: t.accentInk)),
            ),
          ),
        ],
      ],
    ),
  );
}

/// Zitierweise + ⧉-Kopierknopf (✔ für 1200 ms).
class _ZitierweiseRow extends StatefulWidget {
  const _ZitierweiseRow({required this.zitierweise});

  final String zitierweise;

  @override
  State<_ZitierweiseRow> createState() => _ZitierweiseRowState();
}

class _ZitierweiseRowState extends State<_ZitierweiseRow> {
  bool _copied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(widget.zitierweise,
              style: AppTextStyles.small.copyWith(color: t.ink)),
        ),
        const SizedBox(width: 8),
        AppButton(
          small: true,
          tooltip: 'Zitierweise kopieren',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: widget.zitierweise));
            setState(() => _copied = true);
            _timer?.cancel();
            _timer = Timer(const Duration(milliseconds: 1200), () {
              if (mounted) setState(() => _copied = false);
            });
          },
          child: Text(_copied ? '✔' : '⧉'),
        ),
      ],
    );
  }
}

/// 📝 Eigene Notizen — speichert beim Tippen (400 ms Debounce,
/// „✓ gespeichert" für 1200 ms).
void showNoteModal(
  BuildContext context, {
  required String titel,
  required String initial,
  required void Function(String text) onSave,
}) {
  final short = titel.length > 60 ? titel.substring(0, 60) : titel;
  showAppModal(
    context,
    title: Text('📝 Notizen — $short'),
    body: _NoteEditor(initial: initial, onSave: onSave),
  );
}

class _NoteEditor extends StatefulWidget {
  const _NoteEditor({required this.initial, required this.onSave});

  final String initial;
  final void Function(String) onSave;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);
  Timer? _debounce;
  Timer? _stateTimer;
  String _stateText = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _stateTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _ctrl,
          minLines: 6,
          maxLines: 14,
          style: AppTextStyles.form.copyWith(color: t.ink),
          decoration: const InputDecoration(
            hintText: 'Eigene Notizen zu dieser Quelle — bleiben lokal im Browser …',
          ),
          onChanged: (v) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 400), () {
              widget.onSave(v);
              if (!mounted) return;
              setState(() => _stateText = '✓ gespeichert');
              _stateTimer?.cancel();
              _stateTimer = Timer(const Duration(milliseconds: 1200), () {
                if (mounted) setState(() => _stateText = '');
              });
            });
          },
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 18,
          child: Text(_stateText,
              style: AppTextStyles.small.copyWith(color: t.muted)),
        ),
      ],
    );
  }
}

/// 🌐-URL-Dialog (Internetquelle definieren ODER Website-Material anlegen).
/// `https://` wird bei Bedarf vorangestellt; Enter = Übernehmen.
void showUrlModal(
  BuildContext context, {
  required String title,
  required String hint,
  required String buttonLabel,
  String? initial,
  required void Function(String url) onSubmit,
}) {
  final ctrl = TextEditingController(text: initial ?? '');
  void save() {
    var v = ctrl.text.trim();
    if (v.isEmpty) return;
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(v)) {
      v = 'https://$v';
    }
    closeAppModal();
    onSubmit(v);
  }

  showAppModal(
    context,
    title: Text(title),
    onClose: ctrl.dispose,
    body: Builder(builder: (context) {
      final t = BookClothTokens.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(hint, style: AppTextStyles.small.copyWith(color: t.muted)),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            autofocus: true,
            style: AppTextStyles.form.copyWith(color: t.ink),
            decoration: const InputDecoration(hintText: 'https://…'),
            onSubmitted: (_) => save(),
          ),
          const SizedBox(height: 12),
          Row(children: [
            AppButton(
              variant: AppButtonVariant.primary,
              onPressed: save,
              child: Text(buttonLabel),
            ),
          ]),
        ],
      );
    }),
  );
}

/// 📝 Quellentext-Modal (markierbare Text-Ansicht) — mit „⭱ .txt/.md laden".
void showSrcTextModal(
  BuildContext context, {
  required String initial,
  required Future<String?> Function() pickTextFile,
  required void Function(String text) onSubmit,
}) {
  final ctrl = TextEditingController(text: initial);
  showAppModal(
    context,
    title: const Text('📝 Quellentext (markierbare Text-Ansicht)'),
    onClose: ctrl.dispose,
    body: Builder(builder: (context) {
      final t = BookClothTokens.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: ctrl,
            minLines: 8,
            maxLines: 16,
            style: AppTextStyles.mono.copyWith(fontSize: 12.5, color: t.ink),
            decoration: const InputDecoration(hintText: 'Quellentext …'),
          ),
          const SizedBox(height: 8),
          Row(children: [
            AppButton(
              small: true,
              onPressed: () async {
                final text = await pickTextFile();
                if (text != null) ctrl.text = text;
              },
              child: const Text('⭱ .txt/.md laden'),
            ),
            const SizedBox(width: 7),
            AppButton(
              variant: AppButtonVariant.primary,
              small: true,
              onPressed: () {
                final v = ctrl.text;
                closeAppModal();
                onSubmit(v);
              },
              child: const Text('Übernehmen'),
            ),
          ]),
        ],
      );
    }),
  );
}

/// Σ LaTeX-Material-Modal: Name + „⭱ .tex laden" + Textarea + Hinzufügen.
void showTexMaterialModal(
  BuildContext context, {
  required Future<(String name, String text)?> Function() pickTexFile,
  required void Function(String name, String text) onSubmit,
}) {
  final nameCtrl = TextEditingController();
  final texCtrl = TextEditingController();
  showAppModal(
    context,
    title: const Text('Σ LaTeX-Material hinzufügen'),
    onClose: () {
      nameCtrl.dispose();
      texCtrl.dispose();
    },
    body: Builder(builder: (context) {
      final t = BookClothTokens.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(children: [
              const TextSpan(
                  text: 'Übergeordnet verknüpfbar: ',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const TextSpan(
                  text: 'im View-Manager (✎) nutzt eine mit dieser Quelle '
                      'verknüpfte View das Material als Textbasis der Generierung.'),
            ]),
            style: AppTextStyles.small.copyWith(color: t.muted),
          ),
          const SizedBox(height: 8),
          Row(children: [
            SizedBox(
              width: 200,
              child: TextField(
                controller: nameCtrl,
                style: AppTextStyles.form.copyWith(color: t.ink),
                decoration:
                    const InputDecoration(hintText: 'Name (z. B. „paper.tex“)'),
              ),
            ),
            const SizedBox(width: 7),
            AppButton(
              small: true,
              onPressed: () async {
                final picked = await pickTexFile();
                if (picked == null) return;
                texCtrl.text = picked.$2;
                if (nameCtrl.text.isEmpty) nameCtrl.text = picked.$1;
              },
              child: const Text('⭱ .tex laden'),
            ),
          ]),
          const SizedBox(height: 7),
          TextField(
            controller: texCtrl,
            minLines: 8,
            maxLines: 16,
            style: AppTextStyles.mono.copyWith(fontSize: 12.5, color: t.ink),
            decoration: const InputDecoration(hintText: 'LaTeX-Quelltext …'),
          ),
          const SizedBox(height: 8),
          Row(children: [
            AppButton(
              variant: AppButtonVariant.primary,
              small: true,
              onPressed: () {
                final text = texCtrl.text;
                if (text.trim().isEmpty) return;
                final name = nameCtrl.text.trim();
                closeAppModal();
                onSubmit(name.isNotEmpty ? name : 'material.tex', text);
              },
              child: const Text('Hinzufügen'),
            ),
          ]),
        ],
      );
    }),
  );
}

/// Σ-Ansicht eines LaTeX-Materials (max 20 000 Zeichen + „⧉ Kopieren").
void showTexViewModal(
  BuildContext context, {
  required String name,
  required String text,
}) {
  final shown = text.length > 20000 ? '${text.substring(0, 20000)}\n…' : text;
  showAppModal(
    context,
    title: Text('Σ ${name.isNotEmpty ? name : 'LaTeX-Material'}'),
    body: Builder(builder: (context) {
      final t = BookClothTokens.of(context);
      final screen = MediaQuery.sizeOf(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: BoxConstraints(maxHeight: screen.height * .55),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: t.surface2,
              border: Border.all(color: t.border),
              borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
            ),
            child: SingleChildScrollView(
              child: SelectableText(shown,
                  style: AppTextStyles.mono.copyWith(fontSize: 12, color: t.ink)),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            _CopyTexButton(text: text),
            const SizedBox(width: 8),
            Expanded(
              child: Text('übergeordnet verknüpfbar im View-Manager (✎)',
                  style: AppTextStyles.small.copyWith(color: t.muted)),
            ),
          ]),
        ],
      );
    }),
  );
}

class _CopyTexButton extends StatefulWidget {
  const _CopyTexButton({required this.text});

  final String text;

  @override
  State<_CopyTexButton> createState() => _CopyTexButtonState();
}

class _CopyTexButtonState extends State<_CopyTexButton> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      small: true,
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: widget.text));
        if (mounted) setState(() => _copied = true);
      },
      child: Text(_copied ? '✔ kopiert' : '⧉ Kopieren'),
    );
  }
}
