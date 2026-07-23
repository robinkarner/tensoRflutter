/// ⌗ Datei-Auftrag — ZIP `datei-auftrag.zip` erzeugen und sichern
/// (Port von `exportDateiAuftrag`, views_quellen.js:867-903).
///
/// Inhalt (bit-kompatibel über data/export): `auftrag.json` (alle Quellen
/// ohne Datei, je mit stabilem `ts-`-Referenz-Hash + Metadaten + Links)
/// und die zeichengenaue `ANLEITUNG.txt`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/bundles/indexes.dart';
import '../../../data/export/dateiauftrag.dart';
import '../../../data/models/models.dart';
import '../../../data/repos/file_store.dart';
import '../../../data/repos/project_repository.dart';
import '../util/save_file.dart';

/// Auftrag bauen + Sichern-Dialog. Liefert true, wenn gesichert.
Future<bool> exportDateiauftragZip(WidgetRef ref) async {
  final files = await ref.read(fileStoreProvider.future);
  final sources = ref.read(activeRuntimeProvider)?.sources ?? const <Source>[];
  final bytes = await ref.read(projectRepositoryProvider).exportDateiauftrag(
        sources: sources,
        hasFile: files.has,
      );
  return saveBytesFile(Dateiauftrag.zipName, bytes);
}
