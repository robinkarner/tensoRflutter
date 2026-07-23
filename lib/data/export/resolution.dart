/// Resolution-Format (Quellen-Durchlauf, `formatVersion: "1.0"`) —
/// Prüf- und Normalisierungslogik für importierte Nachlade-Analysen
/// (docs/resolution.schema.json + Format-Checker enhance.js:286-305).
///
/// Abweichung W10 (fixierte Entscheidung): Das JSON-Schema des Originals
/// kodiert `footnote ≤ 397` hart auf die EHDS-Arbeit — hier wird DYNAMISCH
/// gegen die Fußnotenzahl der aktiven Arbeit geprüft.
library;

import '../models/models.dart';

/// Ergebnis der Format-Prüfung — reine Daten (die UI der KI-Schicht baut
/// daraus ihre Meldung; das HTML des Originals ist Projektion).
class ResolutionCheck {
  /// Import sinnvoll möglich (mindestens eine Stelle mit Fußnoten-Nummer).
  final bool ok;

  /// Gesamtzahl der Stellen.
  final int stellen;

  /// Stellen mit Seite oder Fundstelle bzw. mit Zitat.
  final int mitPos;
  final int mitZitat;

  /// Stellen ohne `footnote`/`num` (nicht zuordenbar).
  final int ohneNum;

  /// Deutsche Hinweis-Texte (tolerierte Probleme, wie im Original).
  final List<String> probleme;

  const ResolutionCheck({
    required this.ok,
    required this.stellen,
    required this.mitPos,
    required this.mitZitat,
    required this.ohneNum,
    required this.probleme,
  });
}

/// Format-Prüfung — Port von `Enhance._checkQuellen` (enhance.js:286-305)
/// plus die dynamische Fußnoten-Obergrenze (W10). Wirft [FormatException]
/// bei fehlendem `stellen`-Array (Original-Text), sonst tolerant.
///
/// [footnoteCount] = Fußnotenzahl der AKTIVEN Arbeit (statt hartem 397).
ResolutionCheck checkResolution(
  Object? decoded, {
  String? activeSourceId,
  required int footnoteCount,
}) {
  final d = decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
  final stellenRaw = d['stellen'];
  if (stellenRaw is! List) {
    throw const FormatException('Feld "stellen" (Array) fehlt.');
  }

  var mitZitat = 0, mitPos = 0, ohneNum = 0, ausserhalb = 0;
  for (final raw in stellenRaw) {
    final s = raw is Map ? raw : null;
    // Wie der Checker: `footnote ?? num` — beide Feldnamen zulässig.
    final numRaw = s == null ? null : (s['footnote'] ?? s['num']);
    final fnNum = numRaw is int ? numRaw : int.tryParse('$numRaw');
    if (s == null || numRaw == null || fnNum == null) {
      ohneNum++;
      continue;
    }
    if (fnNum < 1 || fnNum > footnoteCount) ausserhalb++;
    if (_truthy(s['zitat'])) mitZitat++;
    if (_truthy(s['seite']) || _truthy(s['fundstelle'])) mitPos++;
  }

  final probleme = <String>[
    if (ohneNum > 0) '$ohneNum Stelle(n) ohne "footnote" (Fußnoten-Zuordnung fehlt)',
    if (d['sourceId'] != null && activeSourceId != null && d['sourceId'] != activeSourceId)
      'sourceId „${d['sourceId']}" ≠ aktive Quelle „$activeSourceId" — beim Übernehmen wird die aktive Quelle gesetzt',
    if (d['formatVersion'] == null) 'kein "formatVersion" (erwartet "1.0") — wird toleriert',
    // W10: dynamisch gegen die aktive Arbeit statt hart 397.
    if (ausserhalb > 0)
      '$ausserhalb Stelle(n) mit Fußnotennummer außerhalb 1..$footnoteCount — diese Arbeit hat $footnoteCount Fußnoten',
  ];

  return ResolutionCheck(
    ok: stellenRaw.length - ohneNum > 0,
    stellen: stellenRaw.length,
    mitPos: mitPos,
    mitZitat: mitZitat,
    ohneNum: ohneNum,
    probleme: probleme,
  );
}

/// Import-Normalisierung (Pendant zum Übernehmen-Pfad des quellen-Flows,
/// enhance.js:160-162): sourceId-Fallback auf die aktive Quelle,
/// generatedBy-Fallback `'gpt'`. Das ROHE JSON bleibt sonst unverändert —
/// gespeichert wird es 1:1 im Store `resolutions[sourceId]`.
Map<String, dynamic> normalizeResolutionForImport(
  Map<String, dynamic> json, {
  required String sourceId,
}) {
  final out = Map<String, dynamic>.from(json);
  final sid = out['sourceId'];
  if (sid == null || sid == '') out['sourceId'] = sourceId;
  final gb = out['generatedBy'];
  if (gb == null || gb == '') out['generatedBy'] = 'gpt';
  return out;
}

/// Typisierte Sicht auf ein gespeichertes Resolution-JSON (F-B-Modell) —
/// für Anzeige-Konsumenten; Persistenz läuft immer über das rohe JSON.
Resolution parseResolution(Map<String, dynamic> json) => Resolution.fromJson(json);

bool _truthy(Object? v) => v != null && v != false && v != 0 && v != '';
