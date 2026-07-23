/// Zustand der Projekt-/Status-Seite: die asynchrone PDF-Zählung
/// (`countPdfs()`, views_projekt.js:43-50) und die Link-Statistik.
///
/// Grundlage ist der Quellen-Fachzustand (`quellenDomainProvider` /
/// `quellenKvProvider`, S-4) — er liefert Levels, Quellen in
/// Bundle-Reihenfolge und den synchronen KV-Schnappschuss (linkOverrides,
/// dlStatus, resolutions, kiConnections). Der FileStore-`changes`-Stream
/// ist das `PdfStore.onChange`-Pendant: jede Datei-Änderung leert den
/// Status-Cache und zählt neu.
library;

import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/db/kv.dart';
import '../../../data/models/models.dart';
import '../../../data/repos/file_store.dart';
import '../../../data/repos/project_repository.dart';
import '../../quellen/state/quellen_kv.dart';

part 'projekt_state.g.dart';

/// Quellen, deren Beleg-Position eine PDF-Seite ist (`docSources`,
/// views_projekt.js:31) — Artikel/Report-Dokumente.
List<Source> projektDocSources(QuellenDomain domain) => [
      for (final s in domain.sources)
        if (domain.levels.positionType(s.id) == 'seite') s,
    ];

/// ids der Dokument-Quellen mit vorhandener PDF (Speicher ODER gebündeltes
/// Asset — `await U.detectPdf(id)`). Speist die Statkachel „PDFs vorhanden“
/// UND den asynchronen Zeilen-Nachtrag des Quellen-Setups
/// (views_projekt.js:154-166).
@Riverpod(keepAlive: true)
class ProjektDetectedPdfs extends _$ProjektDetectedPdfs {
  @override
  Future<Set<String>> build() async {
    final domain = ref.watch(quellenDomainProvider);
    final files = await ref.watch(fileStoreProvider.future);
    final kv = ref.watch(kvStoreProvider);

    // PdfStore.onChange-Pendant (an der Statkachel verankert, :50): Cache
    // leeren + neu zählen.
    final sub = files.changes.listen((_) {
      files.resetStatusCache();
      ref.invalidateSelf();
    });
    ref.onDispose(sub.cancel);

    if (domain == null) return const {};
    final out = <String>{};
    for (final s in projektDocSources(domain)) {
      if (await files.detectPdf(s.id, kv) ?? false) out.add(s.id);
    }
    return out;
  }

  /// Import-Callback-Pendant (`U.pdfStatusCache = {}` + countPdfs).
  Future<void> recount() async {
    (await ref.read(fileStoreProvider.future)).resetStatusCache();
    ref.invalidateSelf();
  }
}

/// Effektive Links einer Quelle synchron aus dem KV-Schnappschuss
/// (`U.srcLinks`-Pendant für die Setup-Zeilen).
EffectiveSrcLinks srcLinksFromSnapshot(
    Map<String, Object?> linkOverrides, Source s) {
  final ov = linkOverrides[s.id];
  return effectiveSrcLinks(
    s,
    ov is Map ? ov.map((k, v) => MapEntry('$k', v)) : const <String, dynamic>{},
  );
}

/// „✓ alle übernehmen“ (`takeOver`, views_projekt.js:94-99) für ALLE noch
/// offenen Quellen: übernimmt `official`/`file` als Override; hat eine
/// Quelle GAR keine Links, wird der Platzhalter `official = 'https://'`
/// gesetzt (zählt als „geprüft“ — der dokumentierte Randfall).
/// Liefert die neue linkOverrides-Map (der Aufrufer schreibt sie über
/// `QuellenKv.put` in einem Rutsch).
Map<String, Object?> takeOverAllLinks(
    Map<String, Object?> linkOverrides, Iterable<Source> sources) {
  final next = {...linkOverrides};
  for (final s in sources) {
    final links = srcLinksFromSnapshot(next, s);
    if (links.isOverride) continue;
    final entryRaw = next[s.id];
    final entry = entryRaw is Map
        ? entryRaw.map((k, v) => MapEntry('$k', v))
        : <String, Object?>{};
    if (links.official != null && links.official!.isNotEmpty) {
      entry['official'] = links.official;
    }
    if (links.file != null && links.file!.isNotEmpty) {
      entry['file'] = links.file;
    }
    if (entry.isEmpty) entry['official'] = 'https://';
    next[s.id] = entry;
  }
  return next;
}
