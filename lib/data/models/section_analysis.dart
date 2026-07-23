/// GPT-Voranalyse je Abschnitt — Pendant zu `window.DATA_SECTIONS`
/// (Bundle `sections.json`, Keys = Section-IDs mit Unterstrichen: "3_2_2_1").
///
/// Für jeden Absatz: Kernaussage, Satz-Zerlegung (wörtlicher Text inkl.
/// `[^N]`-Marker, einfache Erklärung, Kategorien, Markierungen, Wichtigkeit)
/// und Belege (genau 1 je Fußnote: Claim, Fundstellen-Vermutung, Suchhinweis).
///
/// Invarianten (von tools/build_data.js validiert):
/// - join(sentences.text, ' ') == Absatztext (whitespace-normalisiert);
///   bei Abweichung trägt der Absatz `_reconstruct: "abweichend"`.
/// - mark.snippet ist wörtlicher Teilstring seines Satzes.
///
/// Enum-Werte bewusst offen gehalten (Dossier 10 §7.4): Die Realdaten
/// enthalten mehr Kategorien als die Doku nennt (`kontext`, `schlag`, `abk`),
/// und Sensors-Sätze haben weder `kategorien` noch `wichtig`.
library;

import 'json_utils.dart';

/// Auflösung eines Abschnitts (`DATA_SECTIONS["1_1"]`).
class SectionAnalyse {
  /// Punkt-Notation, z. B. "1.1" (der Map-Key nutzt Unterstriche).
  final String sectionId;
  final List<ParagraphAnalyse> paragraphs;

  const SectionAnalyse({required this.sectionId, this.paragraphs = const []});

  factory SectionAnalyse.fromJson(Map<String, dynamic> json) => SectionAnalyse(
        sectionId: asString(json['sectionId']),
        paragraphs: asObjectList(json['paragraphs'], ParagraphAnalyse.fromJson),
      );
}

/// Analyse eines Absatzes (1:1 zum Paragraph über die id).
class ParagraphAnalyse {
  final String id;

  /// Gleiche 4 Typen wie beim geparsten Absatz (text|list|table|figure).
  final String type;

  /// Immer vorhanden: die Kernaussage des Absatzes in einem Satz.
  final String kernaussage;

  /// Nur bei table/figure-Absätzen (3/233 in der EHDS-Arbeit).
  final String? beschreibung;

  /// Nur Sensors-Paper: deutsche Übersetzung des englischen Absatzes.
  final String? uebersetzung;

  /// Je Satz des Originalabsatzes; bei list je Item; bei table/figure leer.
  final List<SentenceAnalyse> sentences;

  /// Genau 1 Eintrag je Fußnote des Absatzes.
  final List<Beleg> belege;

  /// true, wenn build_data die Satz-Rekonstruktion als abweichend markiert
  /// hat (`_reconstruct: "abweichend"`) — UI darf das anzeigen.
  final bool reconstructDivergent;

  const ParagraphAnalyse({
    required this.id,
    this.type = 'text',
    this.kernaussage = '',
    this.beschreibung,
    this.uebersetzung,
    this.sentences = const [],
    this.belege = const [],
    this.reconstructDivergent = false,
  });

  factory ParagraphAnalyse.fromJson(Map<String, dynamic> json) =>
      ParagraphAnalyse(
        id: asString(json['id']),
        type: asString(json['type'], 'text'),
        kernaussage: asString(json['kernaussage']),
        beschreibung: asStringOrNull(json['beschreibung']),
        uebersetzung: asStringOrNull(json['uebersetzung']),
        sentences: asObjectList(json['sentences'], SentenceAnalyse.fromJson),
        belege: asObjectList(json['belege'], Beleg.fromJson),
        reconstructDivergent: json['_reconstruct'] == 'abweichend',
      );
}

/// Wichtigkeits-Ampel eines Satzes. Fehlt bei Sensors-Sätzen komplett →
/// dort ist [SentenceAnalyse.wichtig] null.
enum SatzWichtig {
  kern,
  stuetz,
  kontext;

  /// Tolerantes Parsen — unbekannte/fehlende Werte werden null.
  static SatzWichtig? parse(String? raw) => switch (raw) {
        'kern' => SatzWichtig.kern,
        'stuetz' => SatzWichtig.stuetz,
        'kontext' => SatzWichtig.kontext,
        _ => null,
      };
}

/// Ein Satz der GPT-Zerlegung.
class SentenceAnalyse {
  /// WÖRTLICH inkl. `[^N]`-Marker — join aller Satz-Texte ergibt den
  /// Absatztext (Invariante, siehe Library-Doc).
  final String text;

  /// Erklärung in einfacher Sprache.
  final String einfach;

  /// Satz-Kategorien (offenes Enum: these, tech, frist, akteur, norm,
  /// luecke, zahl, kontext — Realdaten sind der Vertrag).
  final List<String> kategorien;
  final List<Mark> marks;

  /// Roh-Wert von `wichtig` (null bei Sensors), typisiert via [wichtigEnum].
  final String? wichtig;

  const SentenceAnalyse({
    required this.text,
    this.einfach = '',
    this.kategorien = const [],
    this.marks = const [],
    this.wichtig,
  });

  SatzWichtig? get wichtigEnum => SatzWichtig.parse(wichtig);

  factory SentenceAnalyse.fromJson(Map<String, dynamic> json) =>
      SentenceAnalyse(
        text: asString(json['text']),
        einfach: asString(json['einfach']),
        kategorien: asStringList(json['kategorien']),
        marks: asObjectList(json['marks'], Mark.fromJson),
        wichtig: asStringOrNull(json['wichtig']),
      );
}

/// Eine Markierung in einem Satz: [snippet] ist wörtlicher Teilstring des
/// Satztextes (inkl. Sonderzeichen wie „ “ — ü exakt erhalten!),
/// [kategorie] das offene Mark-Enum (these, tech, frist, akteur, norm,
/// luecke, zahl, schlag, abk — KEIN kontext).
class Mark {
  final String snippet;
  final String kategorie;

  const Mark({required this.snippet, required this.kategorie});

  factory Mark.fromJson(Map<String, dynamic> json) => Mark(
        snippet: asString(json['snippet']),
        kategorie: asString(json['kategorie']),
      );
}

/// Beleg-Vermutung zu einer Fußnote des Absatzes.
class Beleg {
  /// Globale Fußnotennummer.
  final int num;

  /// Quellen-IDs der Fußnote.
  final List<String> quellen;

  /// Was die Fußnote inhaltlich belegt.
  final String claim;

  /// Vermutete Fundstelle aus dem Fußnotentext (Seite/Art/§).
  final String fundstelle;

  /// Hilfe für die Volltextsuche im Quell-PDF.
  final String suchHinweis;

  const Beleg({
    required this.num,
    this.quellen = const [],
    this.claim = '',
    this.fundstelle = '',
    this.suchHinweis = '',
  });

  factory Beleg.fromJson(Map<String, dynamic> json) => Beleg(
        num: asInt(json['num']),
        quellen: asStringList(json['quellen']),
        claim: asString(json['claim']),
        fundstelle: asString(json['fundstelle']),
        suchHinweis: asString(json['suchHinweis']),
      );
}
