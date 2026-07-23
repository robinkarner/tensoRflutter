/// 🤖 Ergänzung — EIN Dialog: Prompt + Antwort-Import für manuell angelegte
/// Quellen (Port von `ergModal`, views_quellen.js:469-500).
///
/// Das externe Modell findet die Quelle und trägt die Voranalyse nach;
/// die Antwort fließt in Metadaten, Dossier und Referenzierungsvorschläge.
/// Nach erfolgreichem Import läuft beim Schließen der E8-Reboot (Original:
/// `location.reload()`).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/bundles/indexes.dart';
import '../../../data/db/kv.dart';
import '../../../data/models/models.dart';
import '../../../data/repos/project_repository.dart';
import '../state/quellen_kv.dart';
import '../util/gpt_dialog.dart';
import 'ergaenzung_logic.dart';
import 'gpt_prompts.dart';

/// Ergänzungs-Dialog öffnen.
void showErgaenzungModal(
  BuildContext context,
  WidgetRef ref, {
  required Source source,
}) {
  final meta = ref.read(activeRuntimeProvider)?.thesis.meta ?? const ThesisMeta(title: '');
  final titleShort =
      source.title.length > 60 ? source.title.substring(0, 60) : source.title;
  Future<void>? pending;

  showQuellenGptDialog(
    context,
    title: '🤖 Ergänzung — $titleShort',
    what: 'Der Prompt lässt ein externes GPT-Modell die Quelle finden und die '
        'Voranalyse nachtragen. Die Antwort fließt in Metadaten, Dossier und '
        'Referenzierungsvorschläge dieser Quelle.',
    buildPrompt: () => gptErgaenzungsPrompt(source, meta),
    placeholder:
        '{"sourceId":"${source.id}","meta":{…},"dossier":"…","stellen":[…]}',
    onImport: (text) {
      final parsed = parseErgaenzung(source.id, jsonDecode(text));
      final kv = ref.read(kvStoreProvider);
      final repo = ref.read(projectRepositoryProvider);
      // Persistenz asynchron anstoßen; der Reboot beim Schließen wartet
      // darauf (das Original schreibt synchron in localStorage).
      pending = () async {
        await repo.saveCustomSource(parsed.patch);
        if (parsed.official != null) {
          await setSrcLink(kv, source.id, 'official', parsed.official);
        }
        if (parsed.file != null) {
          await setSrcLink(kv, source.id, 'file', parsed.file);
        }
      }();
      return 'übernommen';
    },
    // onDone → Reboot (Pendant zu location.reload, js:499).
    onDone: () => unawaited(() async {
      await pending;
      await ref.read(projectBootProvider.notifier).reboot();
    }()),
  );
}
