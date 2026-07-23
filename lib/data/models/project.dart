/// Projekt-/Arbeits-Modelle — Pendant zu `window.BUILTIN_PROJECTS` (Bundle
/// `builtin_projects.json`), den IndexedDB-Records (`ehds-projects.projects`)
/// und dem Export-Format `thesis-studio-projekt` v1.
///
/// Kernentscheidung (E7, Bit-Kompatibilität): Der [ProjectRecord] behält das
/// ROHE JSON als kanonische Wahrheit und legt typisierte Sichten nur lazy
/// darüber. Damit überleben unbekannte Felder aus Fremd-Exporten jeden
/// Roundtrip, und der Export bleibt byte-für-byte reproduzierbar.
library;

import 'connections.dart';
import 'figures.dart';
import 'instances.dart';
import 'json_utils.dart';
import 'meta.dart';
import 'section_analysis.dart';
import 'source.dart';
import 'thesis.dart';

/// Eintrag des In-App-Quellenregisters (`registry`). Achtung: [aliases]
/// sind hier Regex-STRINGS (nicht RegExp-Objekte wie im Build-Tool) —
/// zur Nutzung per [compileAliases] kompilieren.
class RegistryEntry {
  final String id;
  final String kind;
  final String? author;
  final int? year;
  final String title;
  final String? container;
  final String? doi;
  final String? url;

  /// Direkt-PDF-Link (string|null).
  final String? file;

  /// Regex-Strings für das Fußnoten-Matching.
  final List<String> aliases;

  const RegistryEntry({
    required this.id,
    this.kind = '',
    this.author,
    this.year,
    this.title = '',
    this.container,
    this.doi,
    this.url,
    this.file,
    this.aliases = const [],
  });

  factory RegistryEntry.fromJson(Map<String, dynamic> json) => RegistryEntry(
        id: asString(json['id']),
        kind: asString(json['kind']),
        author: asStringOrNull(json['author']),
        year: asIntOrNull(json['year']),
        title: asString(json['title']),
        container: asStringOrNull(json['container']),
        doi: asStringOrNull(json['doi']),
        url: asStringOrNull(json['url']),
        file: asStringOrNull(json['file']),
        aliases: asStringList(json['aliases']),
      );

  /// Aliasse als [RegExp] (case-insensitive wie im Original-Matching);
  /// ungültige Patterns werden still übersprungen (Fehlertoleranz).
  List<RegExp> compileAliases() {
    final out = <RegExp>[];
    for (final a in aliases) {
      try {
        out.add(RegExp(a, caseSensitive: false));
      } on FormatException {
        // Kaputtes Fremd-Pattern — Alias wird schlicht nie matchen.
      }
    }
    return out;
  }
}

/// Die `parsed`-Schicht eines Projekts: deterministischer Parser-Output
/// (Ground Truth) — Struktur, flache Fußnotenliste, Quellen mit rohen
/// Zitierstellen.
class ParsedData {
  final Thesis thesis;
  final List<FlatFootnote> footnotes;
  final List<Source> sources;

  const ParsedData({
    required this.thesis,
    this.footnotes = const [],
    this.sources = const [],
  });

  factory ParsedData.fromJson(Map<String, dynamic> json) => ParsedData(
        thesis: Thesis.fromJson(asMap(json['thesis'])),
        footnotes: asObjectList(json['footnotes'], FlatFootnote.fromJson),
        sources: asObjectList(json['sources'], Source.fromJson),
      );
}

/// Die `generated`-Schicht eines Projekts: GPT-Voranalyse. Neue Arbeiten
/// starten leer (`{sections:{},sources:{},chapters:{},gesamt:null,…}`) —
/// alle Felder sind entsprechend optional.
class GeneratedData {
  /// Key = Section-ID mit Unterstrichen ("3_2_1").
  final Map<String, SectionAnalyse> sections;

  /// Map sourceId → Dossier (Map, nicht Array!).
  final Map<String, SourceDossier> sources;

  /// Key = Kapitelnummer als String.
  final Map<String, KapitelMeta> chapters;
  final GesamtMeta? gesamt;
  final FazitMeta? fazit;
  final AnalyseDocs analyse;
  final KiConnections? connections;
  final Instanzen? instanzen;

  /// Vorgeneriertes Erklärbuch (Markdown) oder null.
  final String? erklaerbuch;

  const GeneratedData({
    this.sections = const {},
    this.sources = const {},
    this.chapters = const {},
    this.gesamt,
    this.fazit,
    this.analyse = const AnalyseDocs(),
    this.connections,
    this.instanzen,
    this.erklaerbuch,
  });

  factory GeneratedData.fromJson(Map<String, dynamic> json) => GeneratedData(
        sections: asObjectMap(json['sections'], SectionAnalyse.fromJson),
        sources: asObjectMap(json['sources'], SourceDossier.fromJson),
        chapters: asObjectMap(json['chapters'], KapitelMeta.fromJson),
        gesamt: asMapOrNull(json['gesamt']) == null
            ? null
            : GesamtMeta.fromJson(asMap(json['gesamt'])),
        fazit: asMapOrNull(json['fazit']) == null
            ? null
            : FazitMeta.fromJson(asMap(json['fazit'])),
        analyse: AnalyseDocs.fromJson(asMap(json['analyse'])),
        connections: asMapOrNull(json['connections']) == null
            ? null
            : KiConnections.fromJson(asMap(json['connections'])),
        instanzen: asMapOrNull(json['instanzen']) == null
            ? null
            : Instanzen.fromJson(asMap(json['instanzen'])),
        erklaerbuch: asStringOrNull(json['erklaerbuch']),
      );
}

/// Ein komplettes Projekt (eine "Arbeit"): Builtin, DB-Record oder Import.
///
/// Das rohe JSON ist die kanonische Wahrheit ([raw], [toJson] gibt es
/// unverändert zurück); [parsed]/[generated]/[registry] sind lazy geparste
/// typisierte Sichten darauf.
class ProjectRecord {
  /// Export-Umschlag-Konstanten (projects.js:268).
  static const exportFormat = 'thesis-studio-projekt';
  static const exportVersion = 1;

  /// ID der virtuellen Default-Arbeit (nie in der DB).
  static const defaultId = 'default';

  final Map<String, dynamic> raw;

  ProjectRecord.fromJson(Map<String, dynamic> json) : raw = json;

  /// Import eines `thesis-studio-projekt`-Exports mit den Original-
  /// Validierungen und deutschen Fehlertexten (projects.js:270-274).
  /// Der Umschlag (format/version) bleibt wie im Original im Record —
  /// beim Re-Export überschreiben die Konstanten ihn ohnehin.
  factory ProjectRecord.fromExportJson(Map<String, dynamic> json) {
    final thesis = asMapOrNull(asMap(json['parsed'])['thesis']);
    if (json['format'] != exportFormat || thesis == null) {
      throw const FormatException(
          'Unbekanntes Format — erwartet "thesis-studio-projekt" mit parsed.thesis.');
    }
    final chapters = thesis['chapters'];
    if (chapters is! List || chapters.isEmpty) {
      throw const FormatException(
          'Arbeit unvollständig — parsed.thesis.chapters fehlt/leer.');
    }
    return ProjectRecord.fromJson(json);
  }

  String get id => asString(raw['id']);
  String get name => asString(raw['name']);

  /// ISO-Zeitstempel der Anlage.
  String get created => asString(raw['created']);

  /// Nur eingebaute Arbeiten tragen builtin/builtinVersion.
  bool get builtin => asBool(raw['builtin']);
  int get builtinVersion => asInt(raw['builtinVersion']);

  /// Verhindert, dass ein Builtin-Update den Stand überschreibt.
  bool get userModified => asBool(raw['userModified']);

  /// Kompletter LaTeX-Quelltext (Ground Truth).
  String get tex => asString(raw['tex']);

  List<RegistryEntry> get registry =>
      _registry ??= asObjectList(raw['registry'], RegistryEntry.fromJson);
  List<RegistryEntry>? _registry;

  ParsedData get parsed => _parsed ??= ParsedData.fromJson(asMap(raw['parsed']));
  ParsedData? _parsed;

  GeneratedData get generated =>
      _generated ??= GeneratedData.fromJson(asMap(raw['generated']));
  GeneratedData? _generated;

  FiguresManifest get figures =>
      _figures ??= FiguresManifest.fromJson(asMap(raw['figures']));
  FiguresManifest? _figures;

  /// Roh-Passthrough — Persistenz/Export bleiben bit-kompatibel, unbekannte
  /// Felder aus Fremd-Exporten gehen nie verloren.
  Map<String, dynamic> toJson() => raw;

  /// Export-Umschlag `{format, version, ...rec}` (projects.js:267-269;
  /// Spread-Semantik: Record-Felder überschreiben den Umschlag — bei einem
  /// re-importierten Record stehen dort ohnehin dieselben Werte).
  Map<String, dynamic> toExportJson() =>
      {'format': exportFormat, 'version': exportVersion, ...raw};
}
