/// Analyse-/Meta-Modelle — Pendant zu `window.DATA_META` (Bundle `meta.json`):
/// Kapitel-Zusammenfassungen, Gesamt (Executive Summary, roter Faden,
/// Ergebnisse, Timeline), Fazit (Findings + Kapitel-Fluss), 4 Bewertungs-
/// Dokumente, deterministische Statistiken, Erklärbuch, Instanzen.
///
/// W2 (Master §8): PROJEKT-FORMAT.md ist an drei Stellen veraltet —
/// charts.js + Realdaten sind der Vertrag. Deshalb lesen [TimelineEvent]
/// (kategorie/status statt `typ`) und [KapitelFlussKante] (from/to-Strings
/// statt von/nach-Zahlen) beide Varianten tolerant.
library;

import 'connections.dart';
import 'instances.dart';
import 'json_utils.dart';

/// Das komplette Meta-Aggregat (`window.DATA_META`).
class DataMeta {
  /// Kapitel-Zusammenfassungen, Key = Kapitelnummer als String ("1".."6").
  final Map<String, KapitelMeta> kapitel;
  final GesamtMeta? gesamt;
  final FazitMeta? fazit;
  final AnalyseDocs analyse;
  final StatsMeta? stats;

  /// Komplettes Erklärbuch als Markdown-String (null wenn keins).
  final String? erklaerbuch;

  /// Instanz-Definitionen + Inhalte (nur Sensors-Arbeit; sonst null).
  final Instanzen? instanzen;

  /// KI-Connections — existiert NUR bei Instanz-Arbeiten (W3: buildRuntime
  /// setzt es, das Bundle der eingebauten Arbeit hat KEIN solches Feld).
  /// Alle Konsumenten müssen null-tolerant sein.
  final KiConnections? connections;

  const DataMeta({
    this.kapitel = const {},
    this.gesamt,
    this.fazit,
    this.analyse = const AnalyseDocs(),
    this.stats,
    this.erklaerbuch,
    this.instanzen,
    this.connections,
  });

  factory DataMeta.fromJson(Map<String, dynamic> json) => DataMeta(
        kapitel: asObjectMap(json['kapitel'], KapitelMeta.fromJson),
        gesamt: asMapOrNull(json['gesamt']) == null
            ? null
            : GesamtMeta.fromJson(asMap(json['gesamt'])),
        fazit: asMapOrNull(json['fazit']) == null
            ? null
            : FazitMeta.fromJson(asMap(json['fazit'])),
        analyse: AnalyseDocs.fromJson(asMap(json['analyse'])),
        stats: asMapOrNull(json['stats']) == null
            ? null
            : StatsMeta.fromJson(asMap(json['stats'])),
        erklaerbuch: asStringOrNull(json['erklaerbuch']),
        instanzen: asMapOrNull(json['instanzen']) == null
            ? null
            : Instanzen.fromJson(asMap(json['instanzen'])),
        connections: asMapOrNull(json['connections']) == null
            ? null
            : KiConnections.fromJson(asMap(json['connections'])),
      );
}

// ---------------------------------------------------------------------------
// Kapitel-Zusammenfassung (generated/chapters/kapitel-<n>.json)
// ---------------------------------------------------------------------------

/// Begriff mit Erklärung ("EHDS" → "European Health Data Space — …").
class Begriff {
  final String begriff;
  final String erklaerung;

  const Begriff({required this.begriff, this.erklaerung = ''});

  factory Begriff.fromJson(Map<String, dynamic> json) => Begriff(
        begriff: asString(json['begriff']),
        erklaerung: asString(json['erklaerung']),
      );
}

/// Frist eines Kapitels — [datum] ist ein FREIER String ("26. März 2029",
/// "2029/2031"), kein ISO-Datum!
class KapitelFrist {
  final String datum;
  final String was;

  const KapitelFrist({required this.datum, this.was = ''});

  factory KapitelFrist.fromJson(Map<String, dynamic> json) => KapitelFrist(
        datum: asString(json['datum']),
        was: asString(json['was']),
      );
}

/// Abschnitts-Kurzreferenz eines Kapitels (id + titel + Einzeiler).
class AbschnittRef {
  final String id;
  final String titel;
  final String einzeiler;

  const AbschnittRef({required this.id, this.titel = '', this.einzeiler = ''});

  factory AbschnittRef.fromJson(Map<String, dynamic> json) => AbschnittRef(
        id: asString(json['id']),
        titel: asString(json['titel']),
        einzeiler: asString(json['einzeiler']),
      );
}

/// Kapitel-Verbindungen: worauf baut es auf, wem liefert es zu (Kapitel-IDs).
class KapitelVerbindungen {
  final List<String> bautAuf;
  final List<String> liefertFuer;

  const KapitelVerbindungen({this.bautAuf = const [], this.liefertFuer = const []});

  factory KapitelVerbindungen.fromJson(Map<String, dynamic> json) =>
      KapitelVerbindungen(
        bautAuf: asStringList(json['bautAuf']),
        liefertFuer: asStringList(json['liefertFuer']),
      );
}

/// Zusammenfassung eines Kapitels. [chapter]/[title] sind im EHDS-Bundle
/// vorhanden, fehlen aber bei Sensors-Kapiteln — daher nullable; ebenso
/// [verbindungen] (Sensors hat keine).
class KapitelMeta {
  final int? chapter;
  final String? title;

  /// Markdown.
  final String kurzfassung;

  /// 4–8 Kernaussagen-Strings.
  final List<String> kernaussagen;
  final List<Begriff> begriffe;
  final List<KapitelFrist> fristen;
  final List<AbschnittRef> abschnitte;
  final KapitelVerbindungen? verbindungen;

  /// Ein Satz: was das Kapitel zum Fazit beiträgt.
  final String fazitBeitrag;

  const KapitelMeta({
    this.chapter,
    this.title,
    this.kurzfassung = '',
    this.kernaussagen = const [],
    this.begriffe = const [],
    this.fristen = const [],
    this.abschnitte = const [],
    this.verbindungen,
    this.fazitBeitrag = '',
  });

  factory KapitelMeta.fromJson(Map<String, dynamic> json) => KapitelMeta(
        chapter: asIntOrNull(json['chapter']),
        title: asStringOrNull(json['title']),
        kurzfassung: asString(json['kurzfassung']),
        kernaussagen: asStringList(json['kernaussagen']),
        begriffe: asObjectList(json['begriffe'], Begriff.fromJson),
        fristen: asObjectList(json['fristen'], KapitelFrist.fromJson),
        abschnitte: asObjectList(json['abschnitte'], AbschnittRef.fromJson),
        verbindungen: asMapOrNull(json['verbindungen']) == null
            ? null
            : KapitelVerbindungen.fromJson(asMap(json['verbindungen'])),
        fazitBeitrag: asString(json['fazitBeitrag']),
      );
}

// ---------------------------------------------------------------------------
// Gesamt (generated/chapters/gesamt.json)
// ---------------------------------------------------------------------------

/// Schritt des roten Fadens. [schritt] ist optional (Sensors ohne).
class RoterFadenSchritt {
  final int? schritt;
  final int? kapitel;
  final String label;
  final String text;

  const RoterFadenSchritt({this.schritt, this.kapitel, this.label = '', this.text = ''});

  factory RoterFadenSchritt.fromJson(Map<String, dynamic> json) =>
      RoterFadenSchritt(
        schritt: asIntOrNull(json['schritt']),
        kapitel: asIntOrNull(json['kapitel']),
        label: asString(json['label']),
        text: asString(json['text']),
      );
}

/// Eintrag im Ergebnisse-Grid. [frist] nur bei Lücken (optional).
class ErgebnisEintrag {
  final String titel;
  final String text;
  final String? frist;

  const ErgebnisEintrag({this.titel = '', this.text = '', this.frist});

  factory ErgebnisEintrag.fromJson(Map<String, dynamic> json) =>
      ErgebnisEintrag(
        titel: asString(json['titel']),
        text: asString(json['text']),
        frist: asStringOrNull(json['frist']),
      );
}

/// Die drei Ergebnis-Spalten des Überblicks.
class Ergebnisse {
  final List<ErgebnisEintrag> positiv;
  final List<ErgebnisEintrag> luecken;
  final List<ErgebnisEintrag> spannungen;

  const Ergebnisse({
    this.positiv = const [],
    this.luecken = const [],
    this.spannungen = const [],
  });

  factory Ergebnisse.fromJson(Map<String, dynamic> json) => Ergebnisse(
        positiv: asObjectList(json['positiv'], ErgebnisEintrag.fromJson),
        luecken: asObjectList(json['luecken'], ErgebnisEintrag.fromJson),
        spannungen: asObjectList(json['spannungen'], ErgebnisEintrag.fromJson),
      );
}

/// Fristen-Timeline-Event. Render-Vertrag ist charts.js:142-160:
/// `kategorie == 'at'` → 🇦🇹 Österreich (sonst 🇪🇺 EU),
/// `status == 'erledigt'` → gefüllter Punkt "✔ erledigt" (sonst "○ offen").
///
/// W2: Die Doku nennt stattdessen ein Feld `typ` — Fremd-Dateien mit dem
/// Alt-Format werden tolerant gelesen (kategorie/status bleiben dann leer
/// und rendern wie im Original als EU/offen-Default).
class TimelineEvent {
  /// ISO-Datum ("2025-03-26").
  final String datum;
  final String label;

  /// "eu" | "at" (offen gelesen).
  final String kategorie;

  /// "erledigt" | "offen" (offen gelesen).
  final String status;

  const TimelineEvent({
    this.datum = '',
    this.label = '',
    this.kategorie = '',
    this.status = '',
  });

  /// Vertragslogik von charts.js: NUR exakt 'at' zählt als Österreich.
  bool get isAt => kategorie == 'at';

  /// Vertragslogik von charts.js: NUR exakt 'erledigt' zählt als erledigt.
  bool get isErledigt => status == 'erledigt';

  factory TimelineEvent.fromJson(Map<String, dynamic> json) => TimelineEvent(
        datum: asString(json['datum']),
        label: asString(json['label']),
        kategorie: asString(json['kategorie']),
        status: asString(json['status']),
      );
}

/// Gesamt-Überblick der Arbeit. [einSatz] ist optional (Sensors hat keins).
class GesamtMeta {
  final String? einSatz;

  /// Markdown.
  final String executiveSummary;
  final List<RoterFadenSchritt> roterFaden;
  final Ergebnisse ergebnisse;
  final List<TimelineEvent> timeline;

  const GesamtMeta({
    this.einSatz,
    this.executiveSummary = '',
    this.roterFaden = const [],
    this.ergebnisse = const Ergebnisse(),
    this.timeline = const [],
  });

  factory GesamtMeta.fromJson(Map<String, dynamic> json) => GesamtMeta(
        einSatz: asStringOrNull(json['einSatz']),
        executiveSummary: asString(json['executiveSummary']),
        roterFaden: asObjectList(json['roterFaden'], RoterFadenSchritt.fromJson),
        ergebnisse: Ergebnisse.fromJson(asMap(json['ergebnisse'])),
        timeline: asObjectList(json['timeline'], TimelineEvent.fromJson),
      );
}

// ---------------------------------------------------------------------------
// Fazit (generated/fazit-connections.json)
// ---------------------------------------------------------------------------

/// Ein Fazit-Finding ("f1".."f13"): verknüpft einen Fazit-Absatz mit den
/// Herleitungs-Abschnitten. [typ]: positiv | luecke | spannung | ausblick.
class FazitFinding {
  final String id;
  final String label;
  final String typ;
  final String beschreibung;

  /// Absatz im Fazit-Kapitel, z. B. "6.0-p2".
  final String fazitParagraphId;

  /// Herleitungs-Sektionen (Unit-IDs).
  final List<String> abschnitte;

  /// Freie Fristen-Strings.
  final List<String> fristen;

  const FazitFinding({
    required this.id,
    this.label = '',
    this.typ = '',
    this.beschreibung = '',
    this.fazitParagraphId = '',
    this.abschnitte = const [],
    this.fristen = const [],
  });

  factory FazitFinding.fromJson(Map<String, dynamic> json) => FazitFinding(
        id: asString(json['id']),
        label: asString(json['label']),
        typ: asString(json['typ']),
        beschreibung: asString(json['beschreibung']),
        fazitParagraphId: asString(json['fazitParagraphId']),
        abschnitte: asStringList(json['abschnitte']),
        fristen: asStringList(json['fristen']),
      );
}

/// Kante des Kapitel-Fluss-Graphen. Render-Vertrag charts.js:30-60:
/// [from]/[to] sind Kapitel-IDs als STRINGS ("1".."6").
///
/// W2: Die Doku nennt `von`/`nach` mit Zahlen — beim Lesen tolerieren wir
/// beide Varianten (von/nach als Fallback, Zahlen → Strings).
class KapitelFlussKante {
  final String from;
  final String to;
  final String label;

  const KapitelFlussKante({required this.from, required this.to, this.label = ''});

  factory KapitelFlussKante.fromJson(Map<String, dynamic> json) =>
      KapitelFlussKante(
        from: asString(json['from'] ?? json['von']),
        to: asString(json['to'] ?? json['nach']),
        label: asString(json['label']),
      );
}

/// Fazit-Aggregat: Findings, Rahmen-Absätze, Kapitel-Fluss.
class FazitMeta {
  final List<FazitFinding> findings;

  /// Fazit-Absätze ohne Finding (Rahmentext), z. B. ["6.0-p1"].
  final List<String> rahmen;
  final List<KapitelFlussKante> kapitelFluss;

  const FazitMeta({
    this.findings = const [],
    this.rahmen = const [],
    this.kapitelFluss = const [],
  });

  factory FazitMeta.fromJson(Map<String, dynamic> json) => FazitMeta(
        findings: asObjectList(json['findings'], FazitFinding.fromJson),
        rahmen: asStringList(json['rahmen']),
        kapitelFluss:
            asObjectList(json['kapitelFluss'], KapitelFlussKante.fromJson),
      );
}

// ---------------------------------------------------------------------------
// Analyse-Dokumente (generated/analyse/*.json)
// ---------------------------------------------------------------------------

/// Bewertungs-Kriterium der Standards-Analyse.
/// [note]: stark | solide | ausbaufaehig (| schwach lt. Doku, kommt in
/// Realdaten nie vor — L5).
class AnalyseKriterium {
  final String name;
  final String note;
  final String text;

  const AnalyseKriterium({this.name = '', this.note = '', this.text = ''});

  factory AnalyseKriterium.fromJson(Map<String, dynamic> json) =>
      AnalyseKriterium(
        name: asString(json['name']),
        note: asString(json['note']),
        text: asString(json['text']),
      );
}

/// Punkt eines Analyse-Dokuments. [typ]: staerke | schwaeche | hinweis.
class AnalysePunkt {
  final String typ;
  final String text;

  const AnalysePunkt({this.typ = '', this.text = ''});

  factory AnalysePunkt.fromJson(Map<String, dynamic> json) => AnalysePunkt(
        typ: asString(json['typ']),
        text: asString(json['text']),
      );
}

/// Ein Analyse-Dokument (struktur/quellen/inhalt — und standards, das
/// zusätzlich verdikt/kriterien/verbesserung trägt).
class AnalyseDoc {
  final String titel;

  /// Markdown-Verdikt (nur standards).
  final String? verdikt;
  final String markdown;
  final List<AnalyseKriterium> kriterien;
  final List<AnalysePunkt> punkte;
  final List<String> verbesserung;

  const AnalyseDoc({
    this.titel = '',
    this.verdikt,
    this.markdown = '',
    this.kriterien = const [],
    this.punkte = const [],
    this.verbesserung = const [],
  });

  factory AnalyseDoc.fromJson(Map<String, dynamic> json) => AnalyseDoc(
        titel: asString(json['titel']),
        verdikt: asStringOrNull(json['verdikt']),
        markdown: asString(json['markdown']),
        kriterien: asObjectList(json['kriterien'], AnalyseKriterium.fromJson),
        punkte: asObjectList(json['punkte'], AnalysePunkt.fromJson),
        verbesserung: asStringList(json['verbesserung']),
      );
}

/// Die vier Bewertungs-Dokumente (alle optional — neue Arbeiten starten leer).
class AnalyseDocs {
  final AnalyseDoc? standards;
  final AnalyseDoc? struktur;
  final AnalyseDoc? quellen;
  final AnalyseDoc? inhalt;

  const AnalyseDocs({this.standards, this.struktur, this.quellen, this.inhalt});

  factory AnalyseDocs.fromJson(Map<String, dynamic> json) {
    AnalyseDoc? doc(String key) {
      final m = asMapOrNull(json[key]);
      return m == null ? null : AnalyseDoc.fromJson(m);
    }

    return AnalyseDocs(
      standards: doc('standards'),
      struktur: doc('struktur'),
      quellen: doc('quellen'),
      inhalt: doc('inhalt'),
    );
  }
}

// ---------------------------------------------------------------------------
// Statistiken (deterministisch — NIE speichern, immer berechnen; das Bundle
// liefert sie fertig, Instanz-Arbeiten berechnen sie beim Runtime-Aufbau)
// ---------------------------------------------------------------------------

/// Top-Quelle der Zitier-Statistik.
class TopSource {
  final String id;
  final String title;
  final String kind;
  final int cites;

  const TopSource({required this.id, this.title = '', this.kind = '', this.cites = 0});

  factory TopSource.fromJson(Map<String, dynamic> json) => TopSource(
        id: asString(json['id']),
        title: asString(json['title']),
        kind: asString(json['kind']),
        cites: asInt(json['cites']),
      );
}

/// Kennzahlen der Arbeit (`DATA_META.stats`).
class StatsMeta {
  final int quellen;
  final int fussnoten;
  final int absaetze;
  final int saetze;
  final int belege;

  /// Fußnoten/Absätze je Kapitel, Key = Kapitelnummer als String.
  final Map<String, int> fnPerChapter;
  final Map<String, int> paraPerChapter;

  /// Quellen-Anzahl je Art.
  final Map<String, int> byKind;

  /// Anzeige-Labels je Art (Bundle-Variante, siehe indexes.kindLabels/W5).
  final Map<String, String> kindLabels;

  /// Top 10 meistzitierte Quellen.
  final List<TopSource> topSources;

  const StatsMeta({
    this.quellen = 0,
    this.fussnoten = 0,
    this.absaetze = 0,
    this.saetze = 0,
    this.belege = 0,
    this.fnPerChapter = const {},
    this.paraPerChapter = const {},
    this.byKind = const {},
    this.kindLabels = const {},
    this.topSources = const [],
  });

  factory StatsMeta.fromJson(Map<String, dynamic> json) {
    Map<String, int> intMap(Object? v) => asMap(v)
        .map((k, val) => MapEntry(k, asInt(val)));
    return StatsMeta(
      quellen: asInt(json['quellen']),
      fussnoten: asInt(json['fussnoten']),
      absaetze: asInt(json['absaetze']),
      saetze: asInt(json['saetze']),
      belege: asInt(json['belege']),
      fnPerChapter: intMap(json['fnPerChapter']),
      paraPerChapter: intMap(json['paraPerChapter']),
      byKind: intMap(json['byKind']),
      kindLabels: asMap(json['kindLabels'])
          .map((k, val) => MapEntry(k, asString(val))),
      topSources: asObjectList(json['topSources'], TopSource.fromJson),
    );
  }
}
