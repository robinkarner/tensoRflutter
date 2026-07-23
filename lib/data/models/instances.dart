/// Instanz-System — eigene "Blickwinkel" auf die Arbeit
/// (`generated/instanzen.json` bzw. `PROJECT_INSTANZEN`).
///
/// Eine Instanz-Definition beschreibt den GPT-Auftrag ("Je Absatz: …"),
/// die Items sind die generierten Markdown-Inhalte je Absatz.
library;

import 'json_utils.dart';

/// Definition einer Instanz (z. B. "📡 Sensor-Brille").
class InstanzDef {
  /// Slug, z. B. "sensorblick".
  final String id;

  /// Chip-Label mit Emoji.
  final String label;

  /// CSS-Farb-Token als String ("var(--cat-tech)") ODER Hex-Wert —
  /// die Theme-Schicht übersetzt das in echte Farben.
  final String color;

  /// Der GPT-Auftrag dieser Instanz.
  final String desc;

  const InstanzDef({
    required this.id,
    this.label = '',
    this.color = '',
    this.desc = '',
  });

  factory InstanzDef.fromJson(Map<String, dynamic> json) => InstanzDef(
        id: asString(json['id']),
        label: asString(json['label']),
        color: asString(json['color']),
        desc: asString(json['desc']),
      );
}

/// Instanzen-Aggregat: Definitionen + Inhalte.
/// [items]: defId → (paragraphId → Markdown).
class Instanzen {
  final List<InstanzDef> defs;
  final Map<String, Map<String, String>> items;

  const Instanzen({this.defs = const [], this.items = const {}});

  /// Inhalt einer Instanz für einen Absatz (null wenn keiner existiert).
  String? item(String defId, String paragraphId) => items[defId]?[paragraphId];

  factory Instanzen.fromJson(Map<String, dynamic> json) => Instanzen(
        defs: asObjectList(json['defs'], InstanzDef.fromJson),
        items: asMap(json['items']).map(
          (defId, perPara) => MapEntry(
            defId,
            asMap(perPara).map((paraId, md) => MapEntry(paraId, asString(md))),
          ),
        ),
      );
}
