/// Bundle-Loader — lädt die statischen Daten-Assets der eingebauten Arbeit
/// (Pendant zu den `<script src="js/data/data_*.js">`-Tags der Web-App).
///
/// Die 1-zeiligen JS-Bundles wurden für Flutter zu reinem JSON gestrippt
/// (assets/data/bundles/*.json); inhaltlich sind sie identisch mit den
/// `window.DATA_*`-Globals inklusive des build_data-Merges (stellen,
/// Fallback-Dossiers, stats, file-Nulling).
///
/// Fehler werden je Datei gemeldet ([BundleLoadException] nennt den
/// Asset-Pfad) — eine kaputte Datei soll beim Boot als solche erkennbar
/// sein, nicht als diffuser Parse-Crash irgendwo in der App.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/json_utils.dart';
import '../models/models.dart';

part 'bundle_loader.g.dart';

/// Asset-Pfade der sechs Daten-Bundles.
abstract final class BundleAssets {
  static const thesis = 'assets/data/bundles/thesis.json';
  static const sections = 'assets/data/bundles/sections.json';
  static const sources = 'assets/data/bundles/sources.json';
  static const meta = 'assets/data/bundles/meta.json';
  static const figures = 'assets/data/bundles/figures.json';
  static const builtinProjects = 'assets/data/bundles/builtin_projects.json';

  static const all = [thesis, sections, sources, meta, figures, builtinProjects];
}

/// Laden/Parsen eines Bundles ist fehlgeschlagen — mit Datei-Zuordnung.
class BundleLoadException implements Exception {
  final String assetPath;
  final Object cause;

  const BundleLoadException(this.assetPath, this.cause);

  @override
  String toString() => 'Bundle nicht ladbar: $assetPath ($cause)';
}

/// Die sechs typisierten Bundles — das Rohmaterial der eingebauten Arbeit
/// (Pendant zu DATA_THESIS/SECTIONS/SOURCES/META/FIGURES + BUILTIN_PROJECTS).
class ThesisBundle {
  final Thesis thesis;

  /// Key = Section-ID mit Unterstrichen ("3_2_2_1"), wie in DATA_SECTIONS.
  final Map<String, SectionAnalyse> sections;
  final List<Source> sources;
  final DataMeta meta;
  final FiguresManifest figures;

  /// Eingebaute Zweit-Arbeiten (Sensors-Paper) — werden beim Boot in die
  /// Projekt-DB geseedet (F-C), hier nur typisiert bereitgestellt.
  final List<ProjectRecord> builtinProjects;

  const ThesisBundle({
    required this.thesis,
    required this.sections,
    required this.sources,
    required this.meta,
    required this.figures,
    required this.builtinProjects,
  });
}

/// Lädt und parst die Daten-Assets.
abstract final class BundleLoader {
  /// Alle sechs Bundles laden. [bundle] ist injizierbar (Tests laden über
  /// `rootBundle`, was in `flutter test` mit initialisiertem Binding
  /// funktioniert).
  static Future<ThesisBundle> load({AssetBundle? bundle}) async {
    final b = bundle ?? rootBundle;
    return ThesisBundle(
      thesis: Thesis.fromJson(await _loadMap(b, BundleAssets.thesis)),
      sections: asObjectMap(
        await _loadMap(b, BundleAssets.sections),
        SectionAnalyse.fromJson,
      ),
      sources: _guard(
        BundleAssets.sources,
        await _loadJson(b, BundleAssets.sources),
        (json) => asObjectList(json, Source.fromJson),
      ),
      meta: DataMeta.fromJson(await _loadMap(b, BundleAssets.meta)),
      figures: FiguresManifest.fromJson(await _loadMap(b, BundleAssets.figures)),
      builtinProjects: _guard(
        BundleAssets.builtinProjects,
        await _loadJson(b, BundleAssets.builtinProjects),
        (json) => asList(json)
            .map(asMapOrNull)
            .whereType<Map<String, dynamic>>()
            .map(ProjectRecord.fromJson)
            .toList(),
      ),
    );
  }

  /// Asset lesen + JSON dekodieren, Fehler mit Datei-Pfad ummanteln.
  static Future<Object?> _loadJson(AssetBundle b, String path) async {
    try {
      final text = await b.loadString(path);
      return json.decode(text);
    } catch (e) {
      throw BundleLoadException(path, e);
    }
  }

  /// Wie [_loadJson], erzwingt aber ein Objekt auf oberster Ebene.
  static Future<Map<String, dynamic>> _loadMap(AssetBundle b, String path) async {
    final decoded = await _loadJson(b, path);
    final map = asMapOrNull(decoded);
    if (map == null) {
      throw BundleLoadException(path, 'JSON-Objekt erwartet, ${decoded.runtimeType} erhalten');
    }
    return map;
  }

  /// Typisierung mit Datei-Zuordnung im Fehlerfall.
  static T _guard<T>(String path, Object? json, T Function(Object?) parse) {
    try {
      return parse(json);
    } catch (e) {
      throw BundleLoadException(path, e);
    }
  }
}

/// Die geladenen Bundles als Provider — einmal pro App-Lauf (keepAlive);
/// der explizite Provider-Reboot (E8) invalidiert auch diesen Knoten.
@Riverpod(keepAlive: true)
Future<ThesisBundle> thesisBundle(Ref ref) => BundleLoader.load();
