/// Store-Abstraktion der Domänenschicht — das Pendant zu `U.storeGet` /
/// `U.storeSet` (util.js:206-211), auf das Levels/Connections/Mentions/
/// Editor zugreifen.
///
/// Die Domänenlogik kennt nur LOGISCHE Keys (`belegLevels`, `kiConnections`,
/// `textMentions`, `texEdits`, `belegSpans`, …). Das Projekt-Scoping
/// (`ehds.[<projekt>.]<key>` mit PROJECT_KEYS-Whitelist) ist Sache der
/// KV-Schicht (F-C), die dieses Interface implementiert. Werte sind
/// JSON-artige Dart-Objekte (Map/List/String/num/bool/null) — exakt das,
/// was `jsonDecode` liefert; damit bleiben alle Export-Formate bitgleich.
library;

/// Synchroner Key-Value-Store mit JSON-Werten. Lesefehler liefern wie im
/// Original still `null` (die Aufrufer haben überall Fallbacks).
abstract class DomainStore {
  /// JSON-dekodierter Wert oder `null`, wenn der Key fehlt.
  Object? read(String key);

  /// Wert setzen (JSON-artig). `null` löscht den Key — das entspricht dem
  /// Original, wo `storeSet` mit `null` praktisch nie vorkommt und ein
  /// gelöschter Eintrag beim Lesen ohnehin zum Fallback wird.
  void write(String key, Object? value);
}

/// In-Memory-Implementierung für Tests und als Default vor dem DB-Boot.
class MemoryDomainStore implements DomainStore {
  final Map<String, Object?> values = {};

  MemoryDomainStore([Map<String, Object?>? initial]) {
    if (initial != null) values.addAll(initial);
  }

  @override
  Object? read(String key) => values[key];

  @override
  void write(String key, Object? value) {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

/// Bequeme typisierte Lesehilfen mit Fallback-Semantik von `storeGet`.
extension DomainStoreReads on DomainStore {
  /// Map-Wert (z. B. `belegLevels`, `textMentions`) — Fallback `{}`.
  Map<String, Object?> readMap(String key) {
    final v = read(key);
    if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
    return <String, Object?>{};
  }

  /// Listen-Wert (z. B. `customSources`) — Fallback `[]`.
  List<Object?> readList(String key) {
    final v = read(key);
    return v is List ? List<Object?>.from(v) : <Object?>[];
  }
}
