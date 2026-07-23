/// Gemeinsame Helfer der Golden-Tests: Fixture-Laden, Daten-Kontext der
/// eingebauten Arbeit aus den Bundles, JSON-Deep-Vergleich mit Pfadangabe.
///
/// Die Fixtures entstehen mit `node tools/golden_gen.mjs` aus den
/// ORIGINAL-JS-Modulen (js/*.js) — identische Eingabe muss identisches JSON
/// liefern. Weiche Stellen sind einzeln dokumentiert (siehe die jeweiligen
/// Tests), alles andere wird strikt verglichen.
library;

import 'dart:convert';
import 'dart:io';

import 'package:thesor/data/models/models.dart';
import 'package:thesor/domain/domain.dart';

/// Fixierte Uhr des Generators (tools/golden_gen.mjs, FIXED_NOW).
const int fixedNowMs = 1753222000000;

Object? loadFixture(String name) =>
    jsonDecode(File('test/domain/fixtures/$name').readAsStringSync());

/// Roh-Datendatei aus den Assets (z. B. die .tex-Quelltexte der Arbeiten).
String readAssetData(String name) =>
    File('assets/data/$name').readAsStringSync();

Map<String, dynamic> loadFixtureMap(String name) =>
    loadFixture(name) as Map<String, dynamic>;

DomainContext? _cachedCtx;

/// Daten-Kontext der eingebauten EHDS-Arbeit aus den Asset-Bundles —
/// dieselben Daten, die der Generator über js/data/data_*.js lädt.
DomainContext builtinContext() {
  if (_cachedCtx != null) return _cachedCtx!;
  Object? bundle(String name) =>
      jsonDecode(File('assets/data/bundles/$name.json').readAsStringSync());
  final thesis = Thesis.fromJson(bundle('thesis') as Map<String, dynamic>);
  final sources = [
    for (final s in bundle('sources') as List) Source.fromJson(s as Map<String, dynamic>),
  ];
  final sections = {
    for (final e in (bundle('sections') as Map<String, dynamic>).entries)
      e.key: SectionAnalyse.fromJson(e.value as Map<String, dynamic>),
  };
  final meta = DataMeta.fromJson(bundle('meta') as Map<String, dynamic>);
  return _cachedCtx = DomainContext.build(
    thesis: thesis,
    sources: sources,
    sections: sections,
    meta: meta,
  );
}

/// Erste Abweichung zweier JSON-Strukturen als Pfad-Beschreibung — oder
/// null bei Gleichheit. Zahlen werden wertgleich verglichen (JS kennt keinen
/// int/double-Unterschied).
String? jsonDiff(Object? a, Object? b, [String path = r'$']) {
  if (a == null && b == null) return null;
  if (a is num && b is num) {
    return a == b ? null : '$path: $a != $b';
  }
  if (a is String || a is bool || a == null || b == null) {
    return a == b ? null : '$path: ${_short(a)} != ${_short(b)}';
  }
  if (a is List && b is List) {
    if (a.length != b.length) return '$path: Listenlänge ${a.length} != ${b.length}';
    for (var i = 0; i < a.length; i++) {
      final d = jsonDiff(a[i], b[i], '$path[$i]');
      if (d != null) return d;
    }
    return null;
  }
  if (a is Map && b is Map) {
    for (final k in a.keys) {
      if (!b.containsKey(k)) return '$path: Key "$k" fehlt rechts';
    }
    for (final k in b.keys) {
      if (!a.containsKey(k)) return '$path: Key "$k" fehlt links';
    }
    for (final k in a.keys) {
      final d = jsonDiff(a[k], b[k], '$path.$k');
      if (d != null) return d;
    }
    return null;
  }
  return '$path: Typen ${a.runtimeType} vs ${b.runtimeType} (${_short(a)} vs ${_short(b)})';
}

String _short(Object? v) {
  final s = jsonEncode(v);
  return s.length > 120 ? '${s.substring(0, 120)}…' : s;
}
