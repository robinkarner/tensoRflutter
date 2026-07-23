/// Struktur-Modelle der geparsten Arbeit — Pendant zu `window.DATA_THESIS`
/// (Bundle `thesis.json` = deterministischer Output von tools/parse_thesis.js).
///
/// Die Hierarchie: Thesis → Chapter ("1".."6", Sensors auch "0") → Unit
/// (Level 2–4, Baum über `children`, "X.0" = Kapitel-Intro mit `isIntro`) →
/// Paragraph (`<unitId>-p<n>`) → FootnoteRef (global nummeriert 1..N).
/// Der Absatztext ist die Ground Truth der App; Fußnotenmarker stehen inline
/// als `[^N]` im Text.
library;

import 'json_utils.dart';

/// Kopfdaten der Arbeit (`thesis.json → meta`).
class ThesisMeta {
  /// Titel der Arbeit, z. B. "Primärnutzung von Gesundheitsdaten im EHDS".
  final String title;

  /// Untertitel — kann leer sein (Sensors-Paper: "").
  final String subtitle;
  final String author;
  final String university;

  /// Freies Datum als String, z. B. "15. Juli 2026" — kein ISO-Format!
  final String date;

  /// Erwarteter Pfad zum Arbeits-PDF, z. B. "sources/thesis.pdf".
  final String? thesisPdf;

  /// Gedruckte Seite + [pageOffset] = physische PDF-Seite (EHDS: 10).
  final int pageOffset;

  const ThesisMeta({
    required this.title,
    this.subtitle = '',
    this.author = '',
    this.university = '',
    this.date = '',
    this.thesisPdf,
    this.pageOffset = 0,
  });

  factory ThesisMeta.fromJson(Map<String, dynamic> json) => ThesisMeta(
        title: asString(json['title']),
        subtitle: asString(json['subtitle']),
        author: asString(json['author']),
        university: asString(json['university']),
        date: asString(json['date']),
        thesisPdf: asStringOrNull(json['thesisPdf']),
        pageOffset: asInt(json['pageOffset']),
      );
}

/// Die komplette geparste Arbeit (`window.DATA_THESIS`).
class Thesis {
  final ThesisMeta meta;
  final List<Chapter> chapters;

  const Thesis({required this.meta, required this.chapters});

  factory Thesis.fromJson(Map<String, dynamic> json) => Thesis(
        meta: ThesisMeta.fromJson(asMap(json['meta'])),
        chapters: asObjectList(json['chapters'], Chapter.fromJson),
      );
}

/// Ein Kapitel ("1".."6"; das Sensors-Paper hat zusätzlich "0" = Abstract).
class Chapter {
  final String id;
  final int num;
  final String title;

  /// Gedruckte Seite / physische PDF-Seite — beide können fehlen (null).
  final int? page;
  final int? pdfPage;
  final List<Unit> sections;

  const Chapter({
    required this.id,
    required this.num,
    required this.title,
    this.page,
    this.pdfPage,
    this.sections = const [],
  });

  factory Chapter.fromJson(Map<String, dynamic> json) => Chapter(
        id: asString(json['id']),
        num: asInt(json['num']),
        title: asString(json['title']),
        page: asIntOrNull(json['page']),
        pdfPage: asIntOrNull(json['pdfPage']),
        sections: asObjectList(json['sections'], Unit.fromJson),
      );
}

/// Eine Struktur-Einheit (Section/Subsection/Subsubsection, Level 2–4).
/// IDs sind punktgetrennt ("1.1", "3.2.2.1"); "X.0" ist der Kapitel-Intro-
/// Abschnitt (dann [isIntro] = true, Anzeige-Titel "Überblick").
class Unit {
  final String id;
  final String title;

  /// 2 = \section, 3 = \subsection, 4 = \subsubsection.
  final int level;
  final int? page;
  final int? pdfPage;

  /// Nur bei "X.0"-Überblickssektionen gesetzt (im Bundle-JSON fehlt das
  /// Feld sonst komplett — deshalb Default false, nicht nullable).
  final bool isIntro;
  final List<Paragraph> paragraphs;
  final List<Unit> children;

  const Unit({
    required this.id,
    required this.title,
    required this.level,
    this.page,
    this.pdfPage,
    this.isIntro = false,
    this.paragraphs = const [],
    this.children = const [],
  });

  factory Unit.fromJson(Map<String, dynamic> json) => Unit(
        id: asString(json['id']),
        title: asString(json['title']),
        level: asInt(json['level'], 2),
        page: asIntOrNull(json['page']),
        pdfPage: asIntOrNull(json['pdfPage']),
        isIntro: asBool(json['isIntro']),
        paragraphs: asObjectList(json['paragraphs'], Paragraph.fromJson),
        children: asObjectList(json['children'], Unit.fromJson),
      );
}

/// Die vier Absatz-Typen. Unbekannte Werte fallen auf [text] zurück,
/// der Roh-String bleibt in [Paragraph.type] erhalten.
enum ParagraphType {
  text,
  list,
  table,
  figure;

  static ParagraphType parse(String? raw) => switch (raw) {
        'list' => ParagraphType.list,
        'table' => ParagraphType.table,
        'figure' => ParagraphType.figure,
        _ => ParagraphType.text,
      };
}

/// Ein Absatz der Arbeit. Bei `type == list` steht der Inhalt in [items]
/// (Strings, können `[^N]`-Marker enthalten) und [text] ist leer; bei
/// table/figure ist [text] die Platzhalter-Beschreibung aus `[TABELLE: …]`.
class Paragraph {
  /// `<unitId>-p<n>`, n ab 1 je Unit — z. B. "1.1-p2".
  final String id;

  /// Roh-Wert aus dem JSON (für Roundtrips/Fremd-Daten).
  final String type;

  /// Fließtext mit inline `[^N]`-Markern (Pflicht bei text/table/figure).
  final String text;

  /// Listenpunkte (nur bei `type == list`).
  final List<String> items;

  /// Fußnoten in Marker-Reihenfolge des Textes.
  final List<FootnoteRef> footnotes;

  const Paragraph({
    required this.id,
    this.type = 'text',
    this.text = '',
    this.items = const [],
    this.footnotes = const [],
  });

  ParagraphType get typeEnum => ParagraphType.parse(type);
  bool get isText => typeEnum == ParagraphType.text;

  factory Paragraph.fromJson(Map<String, dynamic> json) => Paragraph(
        id: asString(json['id']),
        type: asString(json['type'], 'text'),
        text: asString(json['text']),
        items: asStringList(json['items']),
        footnotes: asObjectList(json['footnotes'], FootnoteRef.fromJson),
      );
}

/// Eine Fußnote, wie sie am Absatz hängt. [num] ist global eindeutig über
/// die ganze Arbeit (Reihenfolge im .tex); [sources] sind die per
/// Alias-Matching zugeordneten Quellen-IDs (0..n, Mehrfachquellen möglich).
class FootnoteRef {
  final int num;

  /// Bereinigter Fußnotentext. Sensors-Sonderfall: bei \cite-basierten
  /// Arbeiten steht hier nur der Citekey (z. B. "abowd_towards_1999").
  final String text;
  final List<String> sources;

  const FootnoteRef({required this.num, this.text = '', this.sources = const []});

  factory FootnoteRef.fromJson(Map<String, dynamic> json) => FootnoteRef(
        num: asInt(json['num']),
        text: asString(json['text']),
        sources: asStringList(json['sources']),
      );
}

/// Flacher Fußnoten-Eintrag aus `parsed/footnotes.json` bzw.
/// `ProjectRecord.parsed.footnotes` — trägt zusätzlich den Fundort.
class FlatFootnote {
  final int num;
  final String text;
  final String sectionId;
  final String paragraphId;

  const FlatFootnote({
    required this.num,
    this.text = '',
    this.sectionId = '',
    this.paragraphId = '',
  });

  factory FlatFootnote.fromJson(Map<String, dynamic> json) => FlatFootnote(
        num: asInt(json['num']),
        text: asString(json['text']),
        sectionId: asString(json['sectionId']),
        paragraphId: asString(json['paragraphId']),
      );
}
