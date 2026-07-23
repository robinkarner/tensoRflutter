/// Bibliotheks-Filter — Pendant zu `Quellen.filter` (views_quellen.js:9-11):
/// Suchtext (nur Sitzung), Sammlung (`qColl`, global persistiert) und
/// Sortierung (`qSort`, global persistiert).
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/db/kv.dart';

part 'quellen_filter.g.dart';

/// Der Filterzustand als unveränderlicher Wert.
class QuellenFilter {
  /// Live-Suchtext (case-insensitiv über title+author+id+container).
  final String q;

  /// `"alle"` | `"kind:<k>"` | `"offen"` | `"fertig"` | `"pdf-fehlt"` |
  /// `"notizen"` | `"custom"`.
  final String coll;

  /// `"zit"` | `"titel"` | `"jahr"` | `"status"`.
  final String sort;

  const QuellenFilter({this.q = '', this.coll = 'alle', this.sort = 'zit'});

  QuellenFilter copyWith({String? q, String? coll, String? sort}) =>
      QuellenFilter(
        q: q ?? this.q,
        coll: coll ?? this.coll,
        sort: sort ?? this.sort,
      );
}

@Riverpod(keepAlive: true)
class QuellenFilterCtl extends _$QuellenFilterCtl {
  @override
  Future<QuellenFilter> build() async {
    final kv = ref.watch(kvStoreProvider);
    final coll = await kv.getJson(KvKeys.qColl, 'alle');
    final sort = await kv.getJson(KvKeys.qSort, 'zit');
    return QuellenFilter(
      coll: coll is String && coll.isNotEmpty ? coll : 'alle',
      sort: sort is String && sort.isNotEmpty ? sort : 'zit',
    );
  }

  QuellenFilter get _cur => state.value ?? const QuellenFilter();

  void setQ(String q) => state = AsyncData(_cur.copyWith(q: q));

  /// Sammlung wechseln — persistiert `qColl` (views_quellen.js:89).
  void setColl(String coll) {
    state = AsyncData(_cur.copyWith(coll: coll));
    ref.read(kvStoreProvider).setJson(KvKeys.qColl, coll);
  }

  /// Sortierung wechseln — persistiert `qSort` (views_quellen.js:426).
  void setSort(String sort) {
    state = AsyncData(_cur.copyWith(sort: sort));
    ref.read(kvStoreProvider).setJson(KvKeys.qSort, sort);
  }
}
