/// ◱ „LaTeX ansehen“-Modal der `#/doc`-Ansicht (views_studio.js:469-477):
/// das generierte Gesamtdokument (KB-Angabe) in einer Mono-Textfläche
/// (11.5px, min. 340px hoch), darunter „⧉ Kopieren“ (wird zu „✔ kopiert“)
/// und „⭳ .tex laden“.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/modal.dart';
import '../studio/editor/tex_save.dart';

Future<void> showLatexViewModal(BuildContext context, String tex) {
  return showAppModal<void>(
    context,
    title: const Text('◱ Generiertes LaTeX-Dokument'),
    body: _LatexViewBody(tex: tex),
  );
}

class _LatexViewBody extends StatefulWidget {
  const _LatexViewBody({required this.tex});

  final String tex;

  @override
  State<_LatexViewBody> createState() => _LatexViewBodyState();
}

class _LatexViewBodyState extends State<_LatexViewBody> {
  late final TextEditingController _ctl =
      TextEditingController(text: widget.tex);
  bool _copied = false;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final kb = (widget.tex.length / 1024).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Das komplette Dokument ($kb KB) — kopieren oder herunterladen und '
          'lokal zu PDF kompilieren.',
          style: AppTextStyles.small.copyWith(color: t.muted),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 340, maxHeight: 340),
          child: TextField(
            controller: _ctl,
            readOnly: true,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontFamilyFallback: AppFonts.fallback,
              fontSize: 11.5,
              height: 1.5,
              color: t.ink,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: t.surface,
              contentPadding: const EdgeInsets.all(10),
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
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            AppButton(
              small: true,
              variant: AppButtonVariant.primary,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: widget.tex));
                if (mounted) setState(() => _copied = true);
              },
              child: Text(_copied ? '✔ kopiert' : '⧉ Kopieren'),
            ),
            const SizedBox(width: 6),
            AppButton(
              small: true,
              onPressed: () => saveTexFile('thesis.tex', widget.tex),
              child: const Text('⭳ .tex laden'),
            ),
          ],
        ),
      ],
    );
  }
}
