/// Import-Logik der „🤖 Ergänzung" — Whitelist-Übernahme der GPT-Antwort in
/// einen customSources-Patch (Port von views_quellen.js:475-497).
///
/// Regeln:
///  * Nur bekannte meta-Felder werden übernommen; die Ziel-id ist NIE
///    überschreibbar (`patch.id = srcId` steht fest).
///  * `dossier`/`zitierweise` nur als String, `keyPoints`/`stellen` müssen
///    Arrays sein (sonst [FormatException] mit Original-Text).
///  * `stellen` → `vermuteteStellen` (nur Objekt-Einträge).
///  * `meta.official`/`meta.file` werden separat als Link-Overrides
///    zurückgegeben (der Aufrufer schreibt sie via setSrcLink).
library;

/// Ergebnis der Whitelist-Übernahme.
class ErgaenzungImport {
  /// Patch für `Projects.saveCustomSource` (enthält immer `id`).
  final Map<String, dynamic> patch;

  /// `meta.official` (nur wenn String) — Link-Override „official".
  final String? official;

  /// `meta.file` (nur wenn String) — Link-Override „file".
  final String? file;

  const ErgaenzungImport({required this.patch, this.official, this.file});
}

/// Whitelist der übernehmbaren meta-Felder (js:481).
const List<String> ergaenzungMetaWhitelist = [
  'title', 'author', 'year', 'container', 'doi', 'url', 'kind', 'longTitle',
];

/// GPT-Antwort prüfen und in den Patch verwandeln. Wirft [FormatException]
/// mit den wörtlichen deutschen Meldungen des Originals.
ErgaenzungImport parseErgaenzung(String srcId, Object? decoded) {
  if (decoded is! Map) {
    throw const FormatException('JSON-Objekt erwartet.');
  }
  final d = decoded.map((k, v) => MapEntry('$k', v));

  final metaRaw = d['meta'];
  final meta = metaRaw is Map
      ? metaRaw.map((k, v) => MapEntry('$k', v))
      : <String, Object?>{};

  final patch = <String, dynamic>{'id': srcId};
  for (final k in ergaenzungMetaWhitelist) {
    final v = meta[k];
    if (v != null && v != '') patch[k] = v;
  }
  if (d['dossier'] is String) patch['dossier'] = d['dossier'];
  if (d.containsKey('keyPoints')) {
    if (d['keyPoints'] is! List) {
      throw const FormatException('"keyPoints" muss ein Array sein.');
    }
    patch['keyPoints'] = d['keyPoints'];
  }
  if (d['zitierweise'] is String) patch['zitierweise'] = d['zitierweise'];
  if (d.containsKey('stellen')) {
    if (d['stellen'] is! List) {
      throw const FormatException('"stellen" muss ein Array sein.');
    }
    patch['vermuteteStellen'] = [
      for (final v in d['stellen'] as List)
        if (v is Map) v,
    ];
  }

  return ErgaenzungImport(
    patch: patch,
    official: meta['official'] is String ? meta['official'] as String : null,
    file: meta['file'] is String ? meta['file'] as String : null,
  );
}
