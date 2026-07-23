/// ✦ Durchlauf — der Referenzierungsdurchlauf einer Quelle als EIN Dialog:
/// Prompt kopieren + Antwort (Resolution-JSON) importieren.
///
/// Pendant zu `Enhance.pasteModal('quellen')` (views_projekt.js:203-216 /
/// enhance.js quellen-Flow) — vorerst der ⧉/⭱-Weg über data/export
/// (checkResolution/normalizeResolutionForImport); der Magic-Knopf
/// „Mit Claude ausführen" dockt in K-3 über [QuellenGptHooks.magicBar] an.
///
/// Format-Vorschau live (350 ms Debounce): „Format erkannt:
/// Quellen-Durchlauf · N Stellen (x mit Seite/Fundstelle, y mit Zitat)."
/// plus tolerierte Probleme (W10: Fußnoten-Obergrenze dynamisch).
library;

import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/kv.dart';
import '../../../data/export/resolution.dart';
import '../../../data/models/models.dart';
import '../../../data/repos/project_repository.dart';
import '../import/gpt_prompts.dart';
import '../state/quellen_kv.dart';
import '../util/gpt_dialog.dart';

/// Durchlauf-Dialog öffnen. [onImported] läuft nach der Übernahme
/// (Panel-Refresh — KEIN Reboot nötig, resolutions ist reiner Store-Key).
void showDurchlaufModal(
  BuildContext context,
  WidgetRef ref, {
  required Source source,
  VoidCallback? onImported,
}) {
  final domain = ref.read(quellenDomainProvider);
  if (domain == null) return;
  final levels = domain.levels;
  final posType = levels.positionType(source.id);
  final fnCount = domain.ctx.fnIndex.length;
  final arbeitTitel = domain.runtime.thesis.meta.title;

  String check(String text) {
    final decoded = jsonDecode(text);
    final c = checkResolution(decoded,
        activeSourceId: source.id, footnoteCount: fnCount);
    final head = 'Format erkannt: Quellen-Durchlauf · ${c.stellen} Stellen '
        '(${c.mitPos} mit Seite/Fundstelle, ${c.mitZitat} mit Zitat).';
    return c.probleme.isEmpty
        ? head
        : '$head\n${c.probleme.map((p) => '⚠ $p').join('\n')}';
  }

  showQuellenGptDialog(
    context,
    title: '✦ Durchlauf — ${domain.ctx.srcShort(source.id)}',
    what: 'Ein Durchlauf schlägt für jede Zitierstelle dieser Quelle die '
        'konkrete Fundstelle vor (Seite/Art/§ + Suchbegriffe + Zitat). '
        'Prompt kopieren, Antwort direkt hier importieren — die geprüften '
        'Fundstellen fließen als Belege an die Fußnoten. Von Hand erfasste '
        'Belege (Seite/Zitat) gewinnen immer.',
    buildPrompt: () {
      // Links synchron aus dem Schnappschuss auflösen — die linkOverrides
      // liegen im QuellenKv (Live-Kohärenz), Kaskade wie U.srcLinks.
      final overrides =
          ref.read(quellenKvProvider.notifier).readMap(KvKeys.linkOverrides);
      final ov = overrides[source.id];
      final links = effectiveSrcLinks(
        source,
        ov is Map ? Map<String, dynamic>.from(ov) : const <String, dynamic>{},
      );
      return gptPromptForSource(
        source,
        positionType: posType,
        links: links,
        arbeitTitel: arbeitTitel,
      );
    },
    placeholder: '{"formatVersion":"1.0","sourceId":"${source.id}","stellen":[…]}',
    checkPreview: check,
    onImport: (text) {
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        throw const FormatException('JSON-Objekt erwartet.');
      }
      final c = checkResolution(decoded,
          activeSourceId: source.id, footnoteCount: fnCount);
      if (!c.ok) {
        throw const FormatException(
            'Keine Stelle mit "footnote" — Import nicht möglich.');
      }
      final normalized = normalizeResolutionForImport(
        decoded.map((k, v) => MapEntry('$k', v)),
        sourceId: source.id,
      );
      // resolutions[srcId] = rohes (normalisiertes) JSON — 1:1-Ablage.
      final kvNotifier = ref.read(quellenKvProvider.notifier);
      final all = Map<String, Object?>.from(kvNotifier.readMap(KvKeys.resolutions));
      all[source.id] = normalized;
      kvNotifier.put(KvKeys.resolutions, all);
      onImported?.call();
      return '${c.stellen} Stellen übernommen';
    },
  );
}
