/// Quellen-Modelle — Pendant zu `window.DATA_SOURCES` (Bundle `sources.json`,
/// 74 Einträge) sowie zum Dossier-Format `generated/sources/<id>.json`.
///
/// Eine Quelle vereint drei Schichten (tools/build_data.js merged sie):
/// 1. Registry-Metadaten (id, kind, author, year, …, citations roh),
/// 2. Dossier (handgeschrieben oder Fallback, `dossierFallback: true`),
/// 3. Link-Vorschläge + `stellen` (= citations ⨝ belege).
library;

import 'json_utils.dart';

/// Quellen-Art. Steuert die Beleglogik der App (PROJEKT-FORMAT.md:42-44):
/// Rechtsquellen/Online/Normen werden über Fundstellen (Art/§/ErwGr) belegt,
/// alle anderen über PDF-Seiten.
enum SourceKind {
  artikel,
  konferenz,
  norm,
  report,
  online,
  rechtEu('recht-eu'),
  rechtAt('recht-at');

  /// Der JSON-Wert ('recht-eu' etc. mit Bindestrich).
  final String key;
  const SourceKind([String? key]) : key = key ?? '';

  String get jsonKey => key.isEmpty ? name : key;

  /// Tolerantes Parsen — unbekannte Arten werden null (der Roh-String
  /// bleibt in [Source.kind] erhalten).
  static SourceKind? parse(String? raw) {
    for (final k in SourceKind.values) {
      if (k.jsonKey == raw) return k;
    }
    return null;
  }

  /// Sonderlogik: Beleg über Fundstelle (Art/§) statt PDF-Seite?
  bool get zitiertNachFundstelle => switch (this) {
        SourceKind.rechtEu ||
        SourceKind.rechtAt ||
        SourceKind.online ||
        SourceKind.norm =>
          true,
        _ => false,
      };
}

/// Link-Vorschläge einer Quelle (`links`): offizielle Plattform +
/// Direktlink zur Datei. `vorschlag` kennzeichnet pre-KI-Vorschläge im UI;
/// Nutzer-Overrides leben separat im Store (`linkOverrides`).
class SourceLinks {
  final String? official;
  final String? file;
  final bool vorschlag;

  const SourceLinks({this.official, this.file, this.vorschlag = true});

  factory SourceLinks.fromJson(Map<String, dynamic> json) => SourceLinks(
        official: asStringOrNull(json['official']),
        file: asStringOrNull(json['file']),
        vorschlag: asBool(json['vorschlag'], true),
      );

  Map<String, dynamic> toJson() =>
      {'official': official, 'file': file, 'vorschlag': vorschlag};
}

/// Rohe Zitierstelle (`citations`): eine Fußnote, die diese Quelle nennt.
class Citation {
  final int footnote;
  final String sectionId;
  final String paragraphId;
  final String footnoteText;

  const Citation({
    required this.footnote,
    this.sectionId = '',
    this.paragraphId = '',
    this.footnoteText = '',
  });

  factory Citation.fromJson(Map<String, dynamic> json) => Citation(
        footnote: asInt(json['footnote']),
        sectionId: asString(json['sectionId']),
        paragraphId: asString(json['paragraphId']),
        footnoteText: asString(json['footnoteText']),
      );
}

/// Angereicherte Zitierstelle (`stellen` = citations ⨝ belege):
/// claim/fundstelle/suchHinweis sind `''`, wenn kein Beleg existiert.
class Stelle {
  final int footnote;
  final String sectionId;
  final String paragraphId;
  final String footnoteText;
  final String claim;
  final String fundstelle;
  final String suchHinweis;

  const Stelle({
    required this.footnote,
    this.sectionId = '',
    this.paragraphId = '',
    this.footnoteText = '',
    this.claim = '',
    this.fundstelle = '',
    this.suchHinweis = '',
  });

  factory Stelle.fromJson(Map<String, dynamic> json) => Stelle(
        footnote: asInt(json['footnote']),
        sectionId: asString(json['sectionId']),
        paragraphId: asString(json['paragraphId']),
        footnoteText: asString(json['footnoteText']),
        claim: asString(json['claim']),
        fundstelle: asString(json['fundstelle']),
        suchHinweis: asString(json['suchHinweis']),
      );

  /// Baut die Anreicherung aus roher Zitierstelle + Beleg-Daten nach
  /// (Pendant zu build_data.js:103-114 bzw. projects.js:171-175).
  factory Stelle.fromCitation(Citation c,
          {String claim = '', String fundstelle = '', String suchHinweis = ''}) =>
      Stelle(
        footnote: c.footnote,
        sectionId: c.sectionId,
        paragraphId: c.paragraphId,
        footnoteText: c.footnoteText,
        claim: claim,
        fundstelle: fundstelle,
        suchHinweis: suchHinweis,
      );
}

/// Eine Quelle der Bibliothek (Element von `DATA_SOURCES`).
class Source {
  final String id;

  /// Roh-Wert der Art (offen für Fremd-Daten), typisiert via [kindEnum].
  final String kind;
  final String? author;
  final int? year;
  final String title;

  /// Vollzitat für Rechtsakte (15/74).
  final String? longTitle;

  /// Zeitschrift/Sammelband (nur Artikel, 21/74).
  final String? container;
  final String? doi;
  final String? url;

  /// Direkt-PDF-Link — nur bei Instanz-Arbeiten (Registry/parsed.sources),
  /// im Bundle der eingebauten Arbeit nicht vorhanden.
  final String? file;

  /// Erwarteter PDF-Pfad, z. B. "sources/dsgvo.pdf".
  final String? expectedFile;
  final List<Citation> citations;
  final List<Stelle> stellen;

  /// Markdown-Dossier (handgeschrieben oder automatischer Fallback).
  final String dossier;
  final List<String> keyPoints;
  final String? zitierweise;
  final String? hinweisOhnePdf;

  /// true bei automatisch generiertem Fallback-Dossier (66/74).
  final bool dossierFallback;
  final SourceLinks links;

  /// true bei manuell hinzugefügten Quellen (Chip "＋ manuell").
  final bool custom;

  const Source({
    required this.id,
    this.kind = '',
    this.author,
    this.year,
    this.title = '',
    this.longTitle,
    this.container,
    this.doi,
    this.url,
    this.file,
    this.expectedFile,
    this.citations = const [],
    this.stellen = const [],
    this.dossier = '',
    this.keyPoints = const [],
    this.zitierweise,
    this.hinweisOhnePdf,
    this.dossierFallback = false,
    this.links = const SourceLinks(),
    this.custom = false,
  });

  SourceKind? get kindEnum => SourceKind.parse(kind);

  /// Beleg über Fundstelle (Art/§) statt PDF-Seite? (recht-eu/at, online, norm)
  bool get zitiertNachFundstelle => kindEnum?.zitiertNachFundstelle ?? false;

  factory Source.fromJson(Map<String, dynamic> json) => Source(
        id: asString(json['id']),
        kind: asString(json['kind']),
        author: asStringOrNull(json['author']),
        year: asIntOrNull(json['year']),
        title: asString(json['title']),
        longTitle: asStringOrNull(json['longTitle']),
        container: asStringOrNull(json['container']),
        doi: asStringOrNull(json['doi']),
        url: asStringOrNull(json['url']),
        file: asStringOrNull(json['file']),
        expectedFile: asStringOrNull(json['expectedFile']),
        citations: asObjectList(json['citations'], Citation.fromJson),
        stellen: asObjectList(json['stellen'], Stelle.fromJson),
        dossier: asString(json['dossier']),
        keyPoints: asStringList(json['keyPoints']),
        zitierweise: asStringOrNull(json['zitierweise']),
        hinweisOhnePdf: asStringOrNull(json['hinweisOhnePdf']),
        dossierFallback: asBool(json['dossierFallback']),
        links: SourceLinks.fromJson(asMap(json['links'])),
        custom: asBool(json['custom']),
      );

  /// Manuell hinzugefügte Quelle aus dem `customSources`-Store in eine
  /// vollwertige [Source] verwandeln — Pendant zu Projects.mergeCustomSources
  /// (projects.js:245-253): leere citations/stellen, Fallback-Dossier wenn
  /// keins mitgegeben, Link-Kaskade `official > doi.org/&lt;doi&gt; > url`.
  factory Source.fromCustom(Map<String, dynamic> c) {
    final base = Source.fromJson(c);
    final official = asStringOrNull(c['official']) ??
        (base.doi != null ? 'https://doi.org/${base.doi}' : base.url);
    return Source(
      id: base.id,
      kind: base.kind,
      author: base.author,
      year: base.year,
      title: base.title,
      longTitle: base.longTitle,
      container: base.container,
      doi: base.doi,
      url: base.url,
      file: base.file,
      expectedFile: base.expectedFile,
      citations: const [],
      stellen: const [],
      dossier: base.dossier.isNotEmpty ? base.dossier : fallbackDossier(base),
      keyPoints: const [],
      zitierweise: defaultZitierweise(base),
      hinweisOhnePdf: base.hinweisOhnePdf,
      dossierFallback: base.dossier.isEmpty,
      links: SourceLinks(
        official: official,
        file: asStringOrNull(c['file']),
        vorschlag: asStringOrNull(c['official']) == null,
      ),
      custom: true,
    );
  }

  /// Standard-Zitierweise `"Autor (Jahr): Titel"` — Pendant zum Fallback in
  /// projects.js:179 (auch mit leeren Teilen, exakt wie das Original).
  static String defaultZitierweise(Source s) =>
      '${s.author ?? ''} (${s.year?.toString() ?? ''}): ${s.title.isNotEmpty ? s.title : s.id}';

  /// Automatisches Kurz-Dossier für Instanz-Arbeiten und Custom-Quellen —
  /// wortgetreuer Port von Projects.fallbackDossier (projects.js:226-238).
  /// (W5: Die ausführliche build_data.js-Variante existiert nur zur Build-
  /// Zeit; das Bundle der eingebauten Arbeit enthält sie bereits fertig.)
  static String fallbackDossier(Source src) {
    final secs = <String>{
      for (final c in src.citations)
        if (c.sectionId.isNotEmpty) c.sectionId,
    }.toList();
    final bold = src.longTitle ?? (src.title.isNotEmpty ? src.title : src.id);
    final head = [
      '**$bold**',
      if (src.author != null) ' — ${src.author}',
      if (src.year != null) ' (${src.year})',
      if (src.container != null) ', ${src.container}',
      '.',
    ].join();
    return [
      '## Was ist diese Quelle?',
      head,
      '',
      '## Zitierstellen',
      src.citations.isNotEmpty
          ? '${src.citations.length} Zitierstellen'
              '${secs.isNotEmpty ? ' in ${secs.take(8).join(', ')}' : ''}.'
          : 'Noch keine Zitierstellen zugeordnet (Registry/Ergänzungs-Prompt).',
      '',
      '*Automatisch erzeugtes Kurz-Dossier — per GPT-Analyse ersetzbar.*',
    ].join('\n');
  }
}

/// Quell-Dossier aus `generated/sources/<id>.json` bzw.
/// `ProjectRecord.generated.sources[id]` (Map, nicht Array!).
class SourceDossier {
  final String sourceId;
  final String dossier;
  final List<String> keyPoints;
  final String? zitierweise;
  final String? hinweisOhnePdf;

  const SourceDossier({
    required this.sourceId,
    this.dossier = '',
    this.keyPoints = const [],
    this.zitierweise,
    this.hinweisOhnePdf,
  });

  factory SourceDossier.fromJson(Map<String, dynamic> json) => SourceDossier(
        sourceId: asString(json['sourceId']),
        dossier: asString(json['dossier']),
        keyPoints: asStringList(json['keyPoints']),
        zitierweise: asStringOrNull(json['zitierweise']),
        hinweisOhnePdf: asStringOrNull(json['hinweisOhnePdf']),
      );
}
