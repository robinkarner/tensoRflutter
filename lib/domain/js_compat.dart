/// Kleine JS-Semantik-Helfer für die 1:1-Ports der Domänenlogik.
///
/// Die Originale verlassen sich an vielen Stellen auf JavaScript-Eigenheiten
/// (Truthiness, `||`-Fallbacks, stabiles `Array.sort`). Statt diese Semantik
/// an jeder Stelle neu zu erfinden, bündelt diese Datei sie einmal — mit
/// Namen, die im Port sofort verraten, dass hier bewusst JS-Verhalten
/// nachgebildet wird.
library;

/// JS-Truthiness: `null`, `false`, `0`, `NaN` und `''` sind falsy; alles
/// andere (auch leere Maps/Listen — anders als man in Dart erwarten würde!)
/// ist truthy. Wichtig u. a. für die Import-Semantik des Belegstands
/// („`{}` überschreibt, `null`/fehlend lässt den Bestand stehen“).
bool jsTruthy(Object? v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num) return v != 0 && !v.isNaN;
  if (v is String) return v.isNotEmpty;
  return true;
}

/// JS-`a || b`: liefert [a], wenn truthy, sonst [b].
Object? jsOr(Object? a, Object? b) => jsTruthy(a) ? a : b;

/// Stabiles Sortieren (Merge-Sort) — JS `Array.sort` ist in modernen Engines
/// stabil, Darts `List.sort` NICHT. Überall dort verwenden, wo Score-Ties
/// die Original-Reihenfolge behalten müssen (Connections-Kandidaten,
/// Mentions-Kandidaten, Rang-Sortierung).
List<T> stableSorted<T>(Iterable<T> list, int Function(T a, T b) compare) {
  final items = List<T>.of(list);
  if (items.length < 2) return items;
  final buffer = List<T>.of(items);
  _mergeSort(items, buffer, 0, items.length, compare);
  return items;
}

void _mergeSort<T>(
  List<T> items,
  List<T> buffer,
  int start,
  int end,
  int Function(T a, T b) compare,
) {
  if (end - start < 2) return;
  final mid = (start + end) ~/ 2;
  _mergeSort(items, buffer, start, mid, compare);
  _mergeSort(items, buffer, mid, end, compare);
  var i = start, j = mid, k = start;
  while (i < mid && j < end) {
    // <= hält bei Gleichstand die linke (frühere) Seite vorn → stabil.
    buffer[k++] = compare(items[i], items[j]) <= 0 ? items[i++] : items[j++];
  }
  while (i < mid) {
    buffer[k++] = items[i++];
  }
  while (j < end) {
    buffer[k++] = items[j++];
  }
  for (var x = start; x < end; x++) {
    items[x] = buffer[x];
  }
}
