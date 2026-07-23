/// Listen-/Detail-Split der Bibliothek in Prozent — Pendant zu
/// `--lib-list-w` + Store-Key `uiLibPct` (views_quellen.js:25-37):
/// geklemmt 18–60 %, `null` = Standard (34 %), Doppelklick = Reset.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/db/kv.dart';

part 'ui_lib_pct.g.dart';

@Riverpod(keepAlive: true)
class UiLibPct extends _$UiLibPct {
  @override
  Future<int?> build() async {
    final v = await ref.watch(kvStoreProvider).getJson(KvKeys.uiLibPct);
    final n = v is num ? v.toInt() : int.tryParse('$v');
    if (n == null || n == 0) return null;
    return n.clamp(18, 60);
  }

  /// Persistieren (gerundet) bzw. mit `null` auf Standard zurück.
  void set(int? pct) {
    final clamped = pct?.clamp(18, 60);
    state = AsyncData(clamped);
    ref.read(kvStoreProvider).setJson(KvKeys.uiLibPct, clamped);
  }
}
