/// Daten-Schnappschuss der Quell-Karte — alles, was `draw()` des Originals
/// (pdfengine.js:350-380) je Neuzeichnung einliest, als EIN Provider-Family-
/// Zustand. Mutationen laufen über die KV-/Store-APIs und invalidieren den
/// Provider (das Pendant zum kompletten Re-Render von `draw()`).
library;

import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/bundles/indexes.dart';
import '../../../data/db/database.dart';
import '../../../data/db/kv.dart';
import '../../../data/models/models.dart';
import '../../../data/repos/file_store.dart';
import '../../../data/repos/project_repository.dart';
import 'candidates.dart';
import 'download_engine.dart';
import 'src_kv.dart';

part 'assign_panel_data.g.dart';

/// Alles, was die Karte zum Zeichnen braucht.
class AssignPanelState {
  final Source source;
  final EffectiveSrcLinks links;
  final FileSearchInfo? fileSearch;

  /// PDF vorhanden (Store ODER gebündeltes Asset — `has || detectPdf`).
  final bool hasFile;
  final List<AssignCandidate> candidates;

  /// Ablage-Dateinamen (Inbox).
  final List<String> inbox;

  /// Bereits zugewiesene Blob-ids ANDERER Quellen (Kopie verwendbar).
  final List<String> assignedOthers;
  final String? dlLink;
  final DlStatus? dlStatus;
  final SrcDocDef? doc;
  final bool hasImage;
  final String srcText;
  final List<SrcExtra> extras;
  final bool hasNote;

  const AssignPanelState({
    required this.source,
    required this.links,
    this.fileSearch,
    required this.hasFile,
    this.candidates = const [],
    this.inbox = const [],
    this.assignedOthers = const [],
    this.dlLink,
    this.dlStatus,
    this.doc,
    this.hasImage = false,
    this.srcText = '',
    this.extras = const [],
    this.hasNote = false,
  });

  bool get hasText => srcText.isNotEmpty;

  /// Zahl der Alternativen für „📥 Aus Dateiverzeichnis (n)".
  int get nAlt => inbox.length + assignedOthers.length;
}

@riverpod
class AssignPanelData extends _$AssignPanelData {
  @override
  Future<AssignPanelState> build(String srcId) async {
    final kv = ref.watch(kvStoreProvider);
    final repo = ref.watch(projectRepositoryProvider);
    final files = await ref.watch(fileStoreProvider.future);

    // Store-Änderungen (Import, Zuordnung anderswo) zeichnen die Karte neu.
    final sub = files.changes.listen((_) => ref.invalidateSelf());
    ref.onDispose(sub.cancel);

    final source = ref.watch(srcByIdProvider)[srcId] ??
        Source.fromJson({'id': srcId, 'title': srcId});
    final links = await repo.srcLinks(source);
    final hasFile = files.has(srcId) || (await files.detectPdf(srcId, kv) ?? false);

    // „bereits zugewiesen (Kopie verwenden)": alle plain Blob-Keys außer
    // dieser Quelle (pdfengine.js:359); ~x-Materialschlüssel bleiben außen
    // vor (im Original landen sie mit in der Liste — hier bewusst gefiltert,
    // Material-Kopien wären ohne Namenskontext irreführend).
    final allKeys = await ref.watch(appDatabaseProvider).fileBlobsDao.allKeys();
    final assignedOthers = [
      for (final id in allKeys)
        if (!FileKeys.isInbox(id) &&
            !FileKeys.isImg(id) &&
            id != srcId &&
            !id.contains('~x'))
          id,
    ]..sort();

    final candidates = hasFile
        ? const <AssignCandidate>[]
        : findCandidates(
            srcId: srcId,
            srcHash: srcHashOfSource(source),
            inbox: files.listInbox(),
            dismissed: await kv.getDismissed(srcId),
          );

    // Dokument-Typ zählt nur ohne Datei (pdfengine.js:380).
    final doc = hasFile ? null : await kv.getSrcDoc(srcId);

    return AssignPanelState(
      source: source,
      links: links,
      fileSearch: await kv.getFileSearch(srcId),
      hasFile: hasFile,
      candidates: candidates,
      inbox: files.listInbox(),
      assignedOthers: assignedOthers,
      dlLink: dlLinkFor(links),
      dlStatus: await kv.getDlStatus(srcId),
      doc: doc,
      hasImage: files.hasImage(srcId),
      srcText: await kv.getSrcText(srcId),
      extras: await kv.getSrcExtras(srcId),
      hasNote: (await kv.getSrcNote(srcId)).isNotEmpty,
    );
  }

  /// Re-Render anstoßen (nach jeder Mutation — `draw()`-Pendant).
  void refresh() => ref.invalidateSelf();
}
