/// Routenbaum als Daten — alle Pfade, Parameternamen und Pfad-Bauhilfen an
/// EINER Stelle (Pendant zur Hash-Konvention `#/bereich/p1/p2/p3` des
/// Original-Routers, app.js:210-248).
///
/// Die sechs Live-Bereiche (Master §1):
///
/// | Bereich  | Pfad                          | Parameter                  |
/// |----------|-------------------------------|----------------------------|
/// | Studio   | `/studio/:sec/:modus/:para`   | Abschnitt, Modus, Absatz   |
/// | Dokument | `/doc`                        | —                          |
/// | Quellen  | `/quellen/:id`                | Quellen-id                 |
/// | Wissen   | `/analyse/:tab/:arg`          | Tab, Tab-Argument          |
/// | Projekt  | `/projekt`                    | —                          |
/// | Hilfe    | `/hilfe/:topic`               | Hilfe-Thema                |
///
/// Alt-Routen (V1/V2) leiten weiter; Unbekanntes fällt aufs Studio zurück
/// (bewusst KEINE 404 — wie das Original). Auf dem Web bleibt die
/// Hash-URL-Strategie aktiv (Flutter-Web-Default), damit gespeicherte
/// `#/…`-Links aus der Web-App weiter funktionieren.
library;

/// Namen der Pfad-Parameter (zentral, damit Router und Screens
/// dieselben Strings benutzen).
abstract final class RouteParams {
  static const sec = 'sec';
  static const modus = 'modus';
  static const para = 'para';
  static const id = 'id';
  static const tab = 'tab';
  static const arg = 'arg';
  static const topic = 'topic';
}

/// Die Studio-Modi als Routen-Segmente (Dossier 03; W4: intern heißt der
/// Analyse-Modus `pruefen`, nur das LABEL ist „◉ Analyse“).
abstract final class StudioModes {
  static const lesen = 'lesen';
  static const pruefen = 'pruefen';
  static const editor = 'editor';
}

/// Alle Pfade + Pfad-Bauhilfen.
abstract final class Routes {
  // --- Live-Bereiche ---
  static const studio = '/studio';
  static const doc = '/doc';
  static const quellen = '/quellen';
  static const analyse = '/analyse';
  static const projekt = '/projekt';
  static const hilfe = '/hilfe';

  // --- Alt-Routen (V1/V2), nur als Redirect-Quellen (app.js:236-239) ---
  static const legacyHome = '/home';
  static const legacyLesen = '/lesen';
  static const legacyEditor = '/editor';
  static const legacyExplorer = '/explorer';
  static const legacyZusammenfassung = '/zusammenfassung';

  // --- Pfad-Bauhilfen (Parameter werden URL-kodiert) ---

  /// `/studio[/<sec>[/<modus>[/<para>]]]` — der Absatz-Anker ist das
  /// vierte Segment (app.js:228).
  static String studioPath({String? sec, String? modus, String? para}) {
    if (sec == null || sec.isEmpty) return studio;
    final b = StringBuffer(studio)..write('/${Uri.encodeComponent(sec)}');
    if (modus != null && modus.isNotEmpty) {
      b.write('/${Uri.encodeComponent(modus)}');
      if (para != null && para.isNotEmpty) {
        b.write('/${Uri.encodeComponent(para)}');
      }
    }
    return b.toString();
  }

  /// `/quellen[/<id>]`.
  static String quellenPath([String? id]) =>
      (id == null || id.isEmpty) ? quellen : '$quellen/${Uri.encodeComponent(id)}';

  /// `/analyse[/<tab>[/<arg>]]`.
  static String analysePath({String? tab, String? arg}) {
    if (tab == null || tab.isEmpty) return analyse;
    final b = StringBuffer(analyse)..write('/${Uri.encodeComponent(tab)}');
    if (arg != null && arg.isNotEmpty) b.write('/${Uri.encodeComponent(arg)}');
    return b.toString();
  }

  /// `/hilfe[/<topic>]`.
  static String hilfePath([String? topic]) => (topic == null || topic.isEmpty)
      ? hilfe
      : '$hilfe/${Uri.encodeComponent(topic)}';

  /// Erstes Pfadsegment („Bereich“) einer Location — Grundlage der
  /// Topbar-Active-Logik (app.js:221-222).
  static String viewOf(String location) {
    final path = Uri.parse(location).path;
    final segs = path.split('/').where((s) => s.isNotEmpty).toList();
    return segs.isEmpty ? 'studio' : segs.first;
  }
}
