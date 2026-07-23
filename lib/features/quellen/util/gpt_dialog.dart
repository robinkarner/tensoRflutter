/// Standard-GPT-Dialog der Quellen-Welt — das `U.gptModal`-Muster
/// (util.js:779-802) als wiederverwendbares Widget: Erklärtext, ⧉ Prompt
/// kopieren, Antwort-Textarea, „⭱ Übernehmen" mit Import-Callback.
///
/// Anker für K-3 (Magic-Bar „Mit Claude ausführen"): [QuellenGptDialog.magicBar]
/// — die KI-Schicht registriert dort ihren Magic-Knopf; er erscheint dann
/// oberhalb des Prompt-Bereichs und schreibt seine Antwort über den
/// gelieferten Callback direkt ins Antwortfeld. Bis dahin bleibt der Dialog
/// der reine ⧉-Kopieren-/⭱-Einfügen-Weg (funktioniert ohne API-Key —
/// Grundprinzip aller KI-Funktionen der App).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/modal.dart';

/// Signatur des K-3-Magic-Slots: baut die Magic-Bar für [prompt];
/// [onAnswer] übergibt die Modell-Antwort an den Dialog (Antwortfeld).
typedef QuellenMagicBarBuilder = Widget Function(
  BuildContext context,
  String prompt,
  ValueChanged<String> onAnswer,
);

/// GPT-Dialog öffnen. [onImport] verarbeitet die Antwort und liefert die
/// Erfolgsmeldung (z. B. „übernommen") — Fehler ([FormatException] o. Ä.)
/// erscheinen als ✗-Meldung im Dialog. [onDone] läuft NACH erfolgreichem
/// Import beim Schließen (Original: onDone → location.reload()).
/// [checkPreview] liefert optional eine Format-Vorschau, die live unter dem
/// Antwortfeld erscheint (Format-Checker-Pendant, 350 ms Debounce).
void showQuellenGptDialog(
  BuildContext context, {
  required String title,
  required String what,
  required String Function() buildPrompt,
  required String placeholder,
  required String Function(String text) onImport,
  VoidCallback? onDone,
  String Function(String text)? checkPreview,
}) {
  var imported = false;
  showAppModal(
    context,
    title: Text(title),
    onClose: () {
      if (imported) onDone?.call();
    },
    body: _GptDialogBody(
      what: what,
      buildPrompt: buildPrompt,
      placeholder: placeholder,
      onImport: (text) {
        final msg = onImport(text);
        imported = true;
        return msg;
      },
      checkPreview: checkPreview,
    ),
  );
}

class _GptDialogBody extends StatefulWidget {
  const _GptDialogBody({
    required this.what,
    required this.buildPrompt,
    required this.placeholder,
    required this.onImport,
    this.checkPreview,
  });

  final String what;
  final String Function() buildPrompt;
  final String placeholder;
  final String Function(String text) onImport;
  final String Function(String text)? checkPreview;

  /// K-3-Andockstelle: Magic-Bar über dem Prompt-Bereich (null = keine).
  static QuellenMagicBarBuilder? magicBar;

  @override
  State<_GptDialogBody> createState() => _GptDialogBodyState();
}

class _GptDialogBodyState extends State<_GptDialogBody> {
  final _answerCtrl = TextEditingController();
  Timer? _copyTimer;
  Timer? _checkTimer;
  bool _copied = false;
  String _msg = '';
  bool _msgError = false;
  String _preview = '';

  @override
  void dispose() {
    _copyTimer?.cancel();
    _checkTimer?.cancel();
    _answerCtrl.dispose();
    super.dispose();
  }

  Future<void> _copyPrompt() async {
    await Clipboard.setData(ClipboardData(text: widget.buildPrompt()));
    if (!mounted) return;
    setState(() => _copied = true);
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _onAnswerChanged(String text) {
    final check = widget.checkPreview;
    if (check == null) return;
    // Format-Checker mit 350 ms Debounce (Enhance.pasteModal-Signatur).
    _checkTimer?.cancel();
    _checkTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      String out;
      try {
        out = text.trim().isEmpty ? '' : check(text);
      } on FormatException catch (e) {
        out = '✗ ${e.message}';
      } catch (e) {
        out = '✗ $e';
      }
      setState(() => _preview = out);
    });
  }

  void _import() {
    final text = _answerCtrl.text.trim();
    if (text.isEmpty) {
      setState(() {
        _msg = '✗ Antwort einfügen.';
        _msgError = true;
      });
      return;
    }
    try {
      final result = widget.onImport(text);
      setState(() {
        _msg = '✓ $result';
        _msgError = false;
      });
    } on FormatException catch (e) {
      setState(() {
        _msg = '✗ ${e.message}';
        _msgError = true;
      });
    } catch (e) {
      setState(() {
        _msg = '✗ $e';
        _msgError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final magic = _GptDialogBody.magicBar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.what, style: AppTextStyles.small.copyWith(color: t.muted)),
        const SizedBox(height: 10),
        if (magic != null) ...[
          magic(context, widget.buildPrompt(), (answer) {
            _answerCtrl.text = answer;
            _onAnswerChanged(answer);
          }),
          const SizedBox(height: 10),
        ],
        Wrap(spacing: 6, runSpacing: 6, children: [
          AppButton(
            small: true,
            tooltip: 'Prompt in die Zwischenablage kopieren — in ein externes '
                'GPT-Modell einfügen, Antwort unten zurückgeben',
            onPressed: _copyPrompt,
            child: Text(_copied ? '✔ kopiert' : '⧉ Prompt kopieren'),
          ),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: _answerCtrl,
          minLines: 5,
          maxLines: 14,
          style: AppTextStyles.mono.copyWith(fontSize: 12, color: t.ink),
          decoration: InputDecoration(hintText: widget.placeholder),
          onChanged: _onAnswerChanged,
        ),
        if (_preview.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            _preview,
            style: AppTextStyles.small.copyWith(
              color: _preview.startsWith('✗') ? t.bad : t.ink2,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Row(children: [
          AppButton(
            variant: AppButtonVariant.primary,
            small: true,
            onPressed: _import,
            child: const Text('⭱ Übernehmen'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _msg,
              style: AppTextStyles.small.copyWith(color: _msgError ? t.bad : t.good),
            ),
          ),
        ]),
      ],
    );
  }
}

/// Registrierung der K-3-Magic-Bar (Anker; siehe Klassendoku oben).
abstract final class QuellenGptHooks {
  static set magicBar(QuellenMagicBarBuilder? builder) =>
      _GptDialogBody.magicBar = builder;

  static QuellenMagicBarBuilder? get magicBar => _GptDialogBody.magicBar;
}
