/// KI-Connections — inhaltliche Absatz-zu-Absatz-Verbindungen aus
/// `generated/connections.json` (Format: `{ "connections": [...] }`).
///
/// Existiert nur bei Instanz-Arbeiten (W3): buildRuntime setzt
/// `DATA_META.connections`, das Bundle der eingebauten Arbeit hat keins —
/// dort versorgt sich connections.js über die 4-Quellen-Logik selbst.
library;

import 'json_utils.dart';

/// Endpunkt einer Verbindung: Abschnitt + Absatz.
class ConnectionSeite {
  final String sectionId;
  final String paraId;

  const ConnectionSeite({required this.sectionId, required this.paraId});

  factory ConnectionSeite.fromJson(Map<String, dynamic> json) =>
      ConnectionSeite(
        sectionId: asString(json['sectionId']),
        paraId: asString(json['paraId']),
      );
}

/// Eine KI-Verbindung. [typ]: folgerung | grundlage | aufgriff | vergleich
/// (offen gelesen — Realdaten sind der Vertrag).
class KiConnection {
  final String id;
  final String typ;
  final ConnectionSeite von;
  final ConnectionSeite nach;
  final String label;
  final String text;

  const KiConnection({
    required this.id,
    this.typ = '',
    required this.von,
    required this.nach,
    this.label = '',
    this.text = '',
  });

  factory KiConnection.fromJson(Map<String, dynamic> json) => KiConnection(
        id: asString(json['id']),
        typ: asString(json['typ']),
        von: ConnectionSeite.fromJson(asMap(json['von'])),
        nach: ConnectionSeite.fromJson(asMap(json['nach'])),
        label: asString(json['label']),
        text: asString(json['text']),
      );
}

/// Umschlag `{ "connections": [...] }` — so liegt es in der generierten
/// Datei UND in `DATA_META.connections`.
class KiConnections {
  final List<KiConnection> connections;

  const KiConnections({this.connections = const []});

  factory KiConnections.fromJson(Map<String, dynamic> json) => KiConnections(
        connections: asObjectList(json['connections'], KiConnection.fromJson),
      );
}
