/// Zustand der Wissen-Welt: die Analysemodus-Linse (`wissenLens`, GLOBAL —
/// nicht projekt-gescoped, Dossier 06 §3) und die Kennzahlen-Sicht.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/bundles/indexes.dart';
import '../../../data/db/kv.dart';
import '../../../data/models/models.dart';

part 'wissen_state.g.dart';

/// Store-Key der Linse (nicht in PROJECT_KEYS → automatisch global).
const String wissenLensKey = 'wissenLens';

/// `U.storeGet('wissenLens', 'erklaerung')` + Persistenz beim Klick
/// (views_analyse.js:129/143).
@Riverpod(keepAlive: true)
class WissenLens extends _$WissenLens {
  @override
  Future<String> build() async {
    final v = await ref.watch(kvStoreProvider).getJson(wissenLensKey, 'erklaerung');
    return (v is String && v.isNotEmpty) ? v : 'erklaerung';
  }

  void set(String id) {
    state = AsyncData(id);
    ref.read(kvStoreProvider).setJson(wissenLensKey, id);
  }
}

/// Kennzahlen: `DATA_META.stats` der aktiven Arbeit — Stats werden NIE
/// gespeichert, immer berechnet (Dossier 10 §9.9): fehlen sie im Meta
/// (z. B. frisch importierte Arbeit), rechnet [ThesisRuntime.computeStats]
/// sie hier deterministisch nach.
@Riverpod(keepAlive: true)
StatsMeta? wissenStats(Ref ref) {
  final runtime = ref.watch(activeRuntimeProvider);
  if (runtime == null) return null;
  final stats = runtime.meta.stats;
  if (stats != null) return stats;
  final fussnoten = ref.watch(fnIndexProvider).length;
  return ThesisRuntime.computeStats(
    thesis: runtime.thesis,
    sections: runtime.sections,
    sources: runtime.sources,
    fussnoten: fussnoten,
  );
}
