/// Belegstand-Format `ehds-belegstand` v2 — DAS Backup-/Austauschformat des
/// gesamten Prüfstands (levels.js:192-247). Bit-Kompatibilität ist Pflicht
/// (E7): bestehende Exporte der Web-App müssen sich verlustfrei laden lassen
/// und umgekehrt.
///
/// Eigenheiten, die exakt erhalten bleiben:
///  * Feld-Reihenfolge und -Namen wie im Original; einzige Umbenennung:
///    Export-Feld `notes` ↔ Store-Key `srcNotes` (W7).
///  * `importState` prüft NUR `format` (nicht die Version) und übernimmt
///    jeden Bereich einzeln mit Truthy-Semantik: `{}` ist truthy und
///    überschreibt, `null`/fehlend lässt den Bestand stehen.
///  * JSON mit Einrückung 1 (`JSON.stringify(…, null, 1)`).
///
/// Hinweis: levels.js exportiert 22 Datenbereiche (das Dossier spricht von
/// „21" — Zählfehler dort; der Code ist der Vertrag).
library;

import 'dart:convert';

import '../db/kv.dart';

/// Ein Export-Bereich: Export-Feldname, Store-Key und der Default, mit dem
/// das Original exportiert (`storeGet(key, default)`).
class _Area {
  final String field;
  final String storeKey;
  final Object? exportDefault;

  const _Area(this.field, this.storeKey, this.exportDefault);
}

/// leeres Objekt / leeres Array als wiederverwendbare Defaults
const Map<String, dynamic> _obj = {};
const List<Object?> _arr = [];

abstract final class Belegstand {
  static const format = 'ehds-belegstand';
  static const version = 2;

  /// Die 22 Bereiche in exakter Export-Reihenfolge (levels.js:197-218).
  static const List<_Area> _areas = [
    _Area('belegLevels', KvKeys.belegLevels, _obj),
    _Area('annotations', KvKeys.annotations, _obj),
    _Area('resolutions', KvKeys.resolutions, _obj),
    _Area('pdfManual', KvKeys.pdfManual, _obj),
    _Area('linkOverrides', KvKeys.linkOverrides, _obj),
    // Die eine Umbenennung im Format (W7): notes ↔ srcNotes.
    _Area('notes', KvKeys.srcNotes, _obj),
    _Area('srcTexts', KvKeys.srcTexts, _obj),
    _Area('pdfMarks', KvKeys.pdfMarks, _obj),
    _Area('kiConnections', KvKeys.kiConnections, null),
    _Area('customSources', KvKeys.customSources, _arr),
    _Area('textMentions', KvKeys.textMentions, _obj),
    _Area('fileSearch', KvKeys.fileSearch, _obj),
    _Area('dlStatus', KvKeys.dlStatus, _obj),
    _Area('paraDock', KvKeys.paraDock, _obj),
    _Area('paraEdits', KvKeys.paraEdits, _obj),
    _Area('dockBySection', KvKeys.dockBySection, _obj),
    _Area('marksExtra', KvKeys.marksExtra, _obj),
    _Area('notebook', KvKeys.notebook, null),
    _Area('texEdits', KvKeys.texEdits, _obj),
    _Area('fnEdits', KvKeys.fnEdits, _obj),
    _Area('belegSpans', KvKeys.belegSpans, _obj),
    _Area('titleEdits', KvKeys.titleEdits, _obj),
  ];

  /// Gesamt-Prüfstand als JSON-String (Pendant zu `Levels.exportState`).
  /// [now] ist injizierbar für deterministische Tests.
  static Future<String> exportState(KvStore kv, {DateTime? now}) async {
    final out = <String, Object?>{
      'format': format,
      'version': version,
      'exportiert': (now ?? DateTime.now()).toUtc().toIso8601String(),
    };
    for (final a in _areas) {
      out[a.field] = await kv.getJson(a.storeKey, a.exportDefault);
    }
    return const JsonEncoder.withIndent(' ').convert(out);
  }

  /// Import (Pendant zu `Levels.importState`): wirft bei fremdem Format,
  /// überschreibt jeden truthy Bereich einzeln, Rückgabe = Anzahl der
  /// belegLevels-Einträge im Import.
  static Future<int> importState(KvStore kv, String jsonText) async {
    final decoded = json.decode(jsonText);
    final d = decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
    if (d['format'] != format) {
      throw const FormatException('Unbekanntes Format — erwartet "ehds-belegstand".');
    }
    for (final a in _areas) {
      final v = d[a.field];
      if (_truthy(v)) await kv.setJson(a.storeKey, v);
    }
    final levels = d['belegLevels'];
    return levels is Map ? levels.length : 0;
  }

  /// JS-Truthy-Semantik: `{}`/`[]` sind truthy (überschreiben!), `null`,
  /// `false`, `0` und `''` nicht.
  static bool _truthy(Object? v) =>
      v != null && v != false && v != 0 && v != '';
}
