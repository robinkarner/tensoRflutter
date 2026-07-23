/// `alert()`/`confirm()`-Pendants — die Browser-Dialoge des Originals als
/// kleine, token-gestylte Overlays. Bewusst über `showDialog` (nicht
/// showAppModal): sie erscheinen ÜBER einem offenen App-Modal, ohne es zu
/// schließen (genau wie native Browser-Dialoge).
library;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';

Widget _panel(BuildContext context, String text, List<Widget> actions) {
  final t = BookClothTokens.of(context);
  return Dialog(
    backgroundColor: t.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(BookClothTokens.radius),
      side: BorderSide(color: t.border),
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(text, style: AppTextStyles.small.copyWith(fontSize: 13.5, color: t.ink)),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              for (final (i, a) in actions.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                a,
              ],
            ]),
          ],
        ),
      ),
    ),
  );
}

/// `alert(text)` — eine OK-Schaltfläche.
Future<void> showAppAlert(BuildContext context, String text) =>
    showDialog<void>(
      context: context,
      builder: (context) => _panel(context, text, [
        AppButton(
          variant: AppButtonVariant.primary,
          small: true,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ]),
    );

/// `confirm(text)` — OK/Abbrechen, Ergebnis wie das Original (false bei ✕).
Future<bool> showAppConfirm(BuildContext context, String text) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => _panel(context, text, [
      AppButton(
        small: true,
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Abbrechen'),
      ),
      AppButton(
        variant: AppButtonVariant.primary,
        small: true,
        onPressed: () => Navigator.of(context).pop(true),
        child: const Text('OK'),
      ),
    ]),
  );
  return ok ?? false;
}
