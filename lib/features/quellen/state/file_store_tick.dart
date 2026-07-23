/// Datei-Speicher-Puls — Pendant zu `PdfStore.onChange(fn, anchor)`:
/// Widgets, die bei jeder Store-Änderung neu zeichnen sollen (Liste,
/// Rail-Ablage-Zähler, Speicher-Modal), watchen diesen Stream-Provider.
/// Das DOM-Anker-Autocleanup des Originals übernimmt Riverpod (dispose).
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/repos/file_store.dart';

part 'file_store_tick.g.dart';

@Riverpod(keepAlive: true)
Stream<int> fileStoreTick(Ref ref) async* {
  final files = await ref.watch(fileStoreProvider.future);
  var i = 0;
  yield i;
  await for (final _ in files.changes) {
    yield ++i;
  }
}
