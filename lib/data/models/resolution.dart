/// Resolution — Nachlade-Analyse eines Quell-PDFs
/// (docs/resolution.schema.json, formatVersion "1.0").
///
/// Pflicht sind nur formatVersion, sourceId und stellen[].footnote — alles
/// andere darf fehlen (teilgefüllte Dateien sind ausdrücklich erlaubt).
/// W10: Das JSON-Schema kodiert `footnote ≤ 397` hart auf die EHDS-Arbeit;
/// die Validierung gegen die tatsächliche Fußnotenzahl der aktiven Arbeit
/// übernimmt die Import-Schicht dynamisch.
library;

import 'json_utils.dart';

/// Datei-Angaben der analysierten Quelle.
class ResolutionDatei {
  final String? name;
  final int? seiten;

  const ResolutionDatei({this.name, this.seiten});

  factory ResolutionDatei.fromJson(Map<String, dynamic> json) =>
      ResolutionDatei(
        name: asStringOrNull(json['name']),
        seiten: asIntOrNull(json['seiten']),
      );

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (seiten != null) 'seiten': seiten,
      };
}

/// Eine belegte Stelle. [status]: bestaetigt | teilweise | nicht_gefunden.
class ResolutionStelle {
  /// Pflicht: globale Fußnotennummer.
  final int footnote;

  /// PHYSISCHE PDF-Seite (nicht gedruckte Seite!) — null erlaubt.
  final int? seite;

  /// Wörtliches Zitat aus der Quelle.
  final String? zitat;

  /// Optionale Einordnung/Abweichung.
  final String? kommentar;
  final String? status;

  const ResolutionStelle({
    required this.footnote,
    this.seite,
    this.zitat,
    this.kommentar,
    this.status,
  });

  factory ResolutionStelle.fromJson(Map<String, dynamic> json) =>
      ResolutionStelle(
        footnote: asInt(json['footnote']),
        seite: asIntOrNull(json['seite']),
        zitat: asStringOrNull(json['zitat']),
        kommentar: asStringOrNull(json['kommentar']),
        status: asStringOrNull(json['status']),
      );

  Map<String, dynamic> toJson() => {
        'footnote': footnote,
        'seite': seite,
        if (zitat != null) 'zitat': zitat,
        if (kommentar != null) 'kommentar': kommentar,
        if (status != null) 'status': status,
      };
}

/// Die komplette Resolution einer Quelle.
class Resolution {
  static const currentFormatVersion = '1.0';

  final String formatVersion;
  final String sourceId;

  /// Frei: "claude" | "gpt" | "manuell" | …
  final String? generatedBy;

  /// ISO-Datum YYYY-MM-DD.
  final String? erstellt;
  final ResolutionDatei? datei;

  /// Markdown.
  final String? zusammenfassung;
  final List<ResolutionStelle> stellen;

  const Resolution({
    this.formatVersion = currentFormatVersion,
    required this.sourceId,
    this.generatedBy,
    this.erstellt,
    this.datei,
    this.zusammenfassung,
    this.stellen = const [],
  });

  factory Resolution.fromJson(Map<String, dynamic> json) => Resolution(
        formatVersion: asString(json['formatVersion'], currentFormatVersion),
        sourceId: asString(json['sourceId']),
        generatedBy: asStringOrNull(json['generatedBy']),
        erstellt: asStringOrNull(json['erstellt']),
        datei: asMapOrNull(json['datei']) == null
            ? null
            : ResolutionDatei.fromJson(asMap(json['datei'])),
        zusammenfassung: asStringOrNull(json['zusammenfassung']),
        stellen: asObjectList(json['stellen'], ResolutionStelle.fromJson),
      );

  Map<String, dynamic> toJson() => {
        'formatVersion': formatVersion,
        'sourceId': sourceId,
        if (generatedBy != null) 'generatedBy': generatedBy,
        if (erstellt != null) 'erstellt': erstellt,
        if (datei != null) 'datei': datei!.toJson(),
        if (zusammenfassung != null) 'zusammenfassung': zusammenfassung,
        'stellen': [for (final s in stellen) s.toJson()],
      };
}
