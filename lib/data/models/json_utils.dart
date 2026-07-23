/// Tolerante JSON-Lesehilfen für alle Datenmodelle.
///
/// Grundhaltung (Master §8, W2): Die Realdaten sind der Vertrag, die Doku ist
/// teils veraltet, und importierte Fremd-Dateien können abweichen. Deshalb
/// lesen alle Modelle defensiv: falsche Typen werden konvertiert statt zu
/// werfen, fehlende Felder fallen auf sinnvolle Defaults zurück, unbekannte
/// Felder werden ignoriert (bzw. beim ProjectRecord im Roh-JSON mitgeführt).
library;

/// Wert als String oder `null` — Zahlen werden mitgenommen (z. B. `year`
/// könnte in Fremd-Dateien als String ODER Zahl auftauchen).
String? asStringOrNull(Object? v) {
  if (v == null) return null;
  if (v is String) return v;
  return v.toString();
}

/// Wert als String mit Fallback `''`.
String asString(Object? v, [String fallback = '']) =>
    asStringOrNull(v) ?? fallback;

/// Wert als int oder `null` — akzeptiert num und numerische Strings.
int? asIntOrNull(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

/// Wert als int mit Fallback.
int asInt(Object? v, [int fallback = 0]) => asIntOrNull(v) ?? fallback;

/// Wert als bool — truthy-Semantik des Originals (JS) nachgebildet:
/// `true`, `1`, `"true"` gelten als wahr.
bool asBool(Object? v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v.toLowerCase() == 'true';
  return fallback;
}

/// Wert als `Map<String, dynamic>` oder `null`.
Map<String, dynamic>? asMapOrNull(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
  return null;
}

/// Wert als `Map<String, dynamic>` mit leerem Fallback.
Map<String, dynamic> asMap(Object? v) => asMapOrNull(v) ?? const {};

/// Wert als rohe Liste (leer bei allem anderen).
List<Object?> asList(Object? v) => v is List ? List<Object?>.from(v) : const [];

/// Liste von Strings (Nicht-Strings werden konvertiert, nulls verworfen).
List<String> asStringList(Object? v) =>
    asList(v).map(asStringOrNull).whereType<String>().toList();

/// Liste typisierter Objekte: wendet [fromJson] auf jedes Map-Element an,
/// überspringt alles, was keine Map ist (kaputte Fremd-Daten).
List<T> asObjectList<T>(Object? v, T Function(Map<String, dynamic>) fromJson) =>
    asList(v).map(asMapOrNull).whereType<Map<String, dynamic>>().map(fromJson).toList();

/// Map von String → typisiertes Objekt (Nicht-Map-Werte werden übersprungen).
Map<String, T> asObjectMap<T>(
  Object? v,
  T Function(Map<String, dynamic>) fromJson,
) {
  final out = <String, T>{};
  for (final entry in asMap(v).entries) {
    final m = asMapOrNull(entry.value);
    if (m != null) out[entry.key] = fromJson(m);
  }
  return out;
}
