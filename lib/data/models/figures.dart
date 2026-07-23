/// Abbildungs-/Tabellen-Manifest — Pendant zu `window.DATA_FIGURES`
/// (Bundle `figures.json`): 4 Figuren + 2 Tabellen der eingebauten Arbeit,
/// verankert am jeweiligen Platzhalter-Absatz.
library;

import 'json_utils.dart';

/// Eine Abbildung. [file] ist null, wenn die Bilddatei fehlt — die App
/// zeigt dann einen Platzhalter mit Upload (FigStore).
class Figur {
  /// z. B. "abb-3-3-2"; die Anzeige-Nummer ist separat ("Abb. 3.1").
  final String id;
  final String nummer;
  final String sectionId;
  final String paragraphId;

  /// Asset-Pfad ("figures/abb-3-3-2-acm.png", .png/.webp) oder null.
  final String? file;
  final String titel;
  final String credit;

  /// Quellen-ID der Bildquelle (lt. Doku auch null möglich).
  final String? quelle;
  final String beschreibung;

  const Figur({
    required this.id,
    this.nummer = '',
    this.sectionId = '',
    this.paragraphId = '',
    this.file,
    this.titel = '',
    this.credit = '',
    this.quelle,
    this.beschreibung = '',
  });

  factory Figur.fromJson(Map<String, dynamic> json) => Figur(
        id: asString(json['id']),
        nummer: asString(json['nummer']),
        sectionId: asString(json['sectionId']),
        paragraphId: asString(json['paragraphId']),
        file: asStringOrNull(json['file']),
        titel: asString(json['titel']),
        credit: asString(json['credit']),
        quelle: asStringOrNull(json['quelle']),
        beschreibung: asString(json['beschreibung']),
      );
}

/// Eine Tabelle (hat KEIN file/quelle/beschreibung, dafür kopf/zeilen).
class Tabelle {
  final String id;
  final String nummer;
  final String sectionId;
  final String paragraphId;
  final String titel;
  final String credit;

  /// Spaltenköpfe.
  final List<String> kopf;

  /// Zeilen als Listen von Zellen-Strings.
  final List<List<String>> zeilen;

  const Tabelle({
    required this.id,
    this.nummer = '',
    this.sectionId = '',
    this.paragraphId = '',
    this.titel = '',
    this.credit = '',
    this.kopf = const [],
    this.zeilen = const [],
  });

  factory Tabelle.fromJson(Map<String, dynamic> json) => Tabelle(
        id: asString(json['id']),
        nummer: asString(json['nummer']),
        sectionId: asString(json['sectionId']),
        paragraphId: asString(json['paragraphId']),
        titel: asString(json['titel']),
        credit: asString(json['credit']),
        kopf: asStringList(json['kopf']),
        zeilen: asList(json['zeilen']).map(asStringList).toList(),
      );
}

/// Das komplette Manifest (`{figuren, tabellen}`).
class FiguresManifest {
  final List<Figur> figuren;
  final List<Tabelle> tabellen;

  const FiguresManifest({this.figuren = const [], this.tabellen = const []});

  static const empty = FiguresManifest();

  factory FiguresManifest.fromJson(Map<String, dynamic> json) =>
      FiguresManifest(
        figuren: asObjectList(json['figuren'], Figur.fromJson),
        tabellen: asObjectList(json['tabellen'], Tabelle.fromJson),
      );
}
