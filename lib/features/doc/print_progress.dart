/// Fortschritts-Dialog des PDF-Erzeugens (`#/doc` → „🖨 Als PDF drucken"):
/// nicht wegklickbares Overlay mit Spinner + laufender Schritt-Meldung
/// („Schriften einbetten …", „Bilder einbetten … (2/3)", „Kapitel 4/6
/// setzen …"). Der Aufrufer bekommt einen Handle, meldet Schritte über
/// [DocPrintProgressHandle.step] und schließt am Ende mit
/// [DocPrintProgressHandle.close].
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// Steuergriff des offenen Fortschritts-Dialogs.
class DocPrintProgressHandle {
  DocPrintProgressHandle._(this._message);

  final ValueNotifier<String> _message;
  VoidCallback? _pop;
  bool _closed = false;

  /// Aktuelle Schritt-Meldung austauschen.
  void step(String text) {
    if (!_closed) _message.value = text;
  }

  /// Dialog schließen (idempotent — auch im Fehlerpfad sicher aufrufbar).
  void close() {
    if (_closed) return;
    _closed = true;
    _pop?.call();
    _pop = null;
  }
}

/// Öffnet den Dialog und liefert sofort den Handle zurück.
DocPrintProgressHandle showDocPrintProgress(
  BuildContext context, {
  String initial = 'PDF wird vorbereitet …',
}) {
  final handle = DocPrintProgressHandle._(ValueNotifier<String>(initial));
  final navigator = Navigator.of(context, rootNavigator: true);
  var open = true;
  handle._pop = () {
    if (open) navigator.pop();
  };
  showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false, // Esc/Back schließt nicht — nur handle.close()
      child: _DocPrintProgressDialog(message: handle._message),
    ),
  ).whenComplete(() => open = false);
  return handle;
}

class _DocPrintProgressDialog extends StatelessWidget {
  const _DocPrintProgressDialog({required this.message});

  final ValueListenable<String> message;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Dialog(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BookClothTokens.radiusLg),
        side: BorderSide(color: t.borderStrong),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🖨 PDF wird erzeugt',
              style: AppTextStyles.h4.copyWith(color: t.ink),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: t.accent,
                  ),
                ),
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: ValueListenableBuilder<String>(
                    valueListenable: message,
                    builder: (context, value, _) => Text(
                      value,
                      style: AppTextStyles.small.copyWith(color: t.ink2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Titelseite, Kapitel, Abbildungen und Fußnoten werden gesetzt.',
              style: AppTextStyles.small
                  .copyWith(fontSize: 12, color: t.muted),
            ),
          ],
        ),
      ),
    );
  }
}
