/// ✎ Offizielle Seite — Link ändern (Port von `linkEditModal`,
/// views_quellen.js:642-654). EIN Dialog, genutzt von der Quellenseite UND
/// der Quell-Karte überall (AssignPanelHooks-Registrierung in quellen.dart —
/// deshalb nur [BuildContext], die Provider kommen aus dem Scope).
///
/// Leer + Übernehmen stellt den automatischen Vorschlag (DOI→doi.org bzw.
/// url) wieder her.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/modal.dart';
import '../../../data/bundles/indexes.dart';
import '../../../data/db/kv.dart';
import '../../../data/models/models.dart';
import '../../../data/repos/project_repository.dart';
import '../state/quellen_kv.dart';

void showLinkEditModal(
  BuildContext context, {
  required String srcId,
  VoidCallback? onDone,
}) {
  // Nur Lese-Zugriffe — der Container des umgebenden ProviderScope genügt
  // (so ist der Dialog auch aus S-1/S-2-Widgets ohne WidgetRef aufrufbar).
  final ref = ProviderScope.containerOf(context, listen: false);
  final source = ref.read(srcByIdProvider)[srcId] ??
      Source.fromJson({'id': srcId, 'title': srcId});

  unawaited(() async {
    final links = await ref.read(projectRepositoryProvider).srcLinks(source);
    if (!context.mounted) return;

    final ctrl =
        TextEditingController(text: links.isOverride ? (links.official ?? '') : '');
    void submit() {
      final value = ctrl.text.trim();
      closeAppModal();
      unawaited(setSrcLink(ref.read(kvStoreProvider), srcId, 'official', value)
          .then((_) => onDone?.call()));
    }

    showAppModal(
      context,
      title: const Text('↗ Offizielle Seite — Link ändern'),
      onClose: ctrl.dispose,
      body: Builder(builder: (context) {
        final t = BookClothTokens.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'DOI/Verlag/EUR-Lex/RIS. Leer + Übernehmen stellt den '
              'automatischen Vorschlag wieder her.',
              style: AppTextStyles.small.copyWith(color: t.muted),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.url,
              style: AppTextStyles.form.copyWith(color: t.ink),
              decoration: const InputDecoration(hintText: 'https://…'),
              onSubmitted: (_) => submit(),
            ),
            if (!links.isOverride && (links.official ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Aktueller Vorschlag: '),
                  TextSpan(
                    text: links.official,
                    style: AppTextStyles.mono.copyWith(fontSize: 12, color: t.ink2),
                  ),
                ]),
                style: AppTextStyles.small.copyWith(color: t.muted),
              ),
            ],
            const SizedBox(height: 10),
            Row(children: [
              AppButton(
                variant: AppButtonVariant.primary,
                small: true,
                onPressed: submit,
                child: const Text('Übernehmen'),
              ),
            ]),
          ],
        );
      }),
    );
  }());
}
