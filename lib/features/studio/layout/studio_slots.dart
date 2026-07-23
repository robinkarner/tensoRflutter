/// Andockstellen des Studio-Arbeitsraums für die Parallel-Pakete S-1 (PDF)
/// und S-3 (Editor/Dock/Views/RefMode).
///
/// S-2 baut das Gerüst (3 Spalten, Modi Lesen/Analyse, Quellen-Spalten-HOST);
/// die hier deklarierten statischen Hooks sind die VERTRAGLICHEN Slots, die
/// die Schwester-Pakete beim App-Start füllen (Registrierung z. B. in einer
/// `wireStudio…()`-Funktion, aufgerufen vor dem ersten Studio-Render — der
/// Verdrahtungs-Sweep in Welle 3 zieht das zusammen). Solange ein Slot leer
/// ist, rendert das Gerüst eine funktionale, ruhige Rückfalldarstellung
/// (identisch zum Original ohne geladenes Modul, z. B. `typeof PdfEngine
/// !== 'undefined'`-Zweige).
library;

import 'package:flutter/material.dart';

import '../../../data/models/models.dart';
import '../../../domain/levels.dart' show MarksForFn;

/// Laufender PDF-Controller der Quellen-Spalte — Pendant zu
/// `Studio.file.ctl` (search/goto/refreshActive). S-1s gemountete View
/// registriert sich hier ([StudioSlots.pdfHandle]) und trägt sich beim
/// Dispose wieder aus.
abstract class StudioPdfHandle {
  /// Quelle, zu der dieser Controller gehört (Race-Schutz).
  String get srcId;

  /// Volltextsuche im PDF (zirkulär, Flash) — `ctl.search`.
  void search(String term);

  /// Zu einer Seite springen — `ctl.goto`.
  void goto(Object page);

  /// Aktiven Beleg (Farbe/Label) neu einlesen — `ctl.refreshActive`.
  void refreshActive();

  /// Layout nach Spalten-Resize auffrischen — `ctl.refresh`.
  void refresh();
}

/// Statische Slots (bewusst simpel — ein Registry-Objekt, keine Provider:
/// die Hooks sind Verdrahtung zwischen Paketen, kein reaktiver Zustand).
abstract final class StudioSlots {
  // ---- S-1: PDF-Engine ----------------------------------------------------

  /// Quell-Karte oben in der Quellen-Spalte (`PdfEngine.assignPanel`).
  /// [collapsed]: Datei/Definition vorhanden → nur Kopfzeile.
  static Widget Function(BuildContext, String srcId, {required bool collapsed})?
      fileCard;

  /// PDF-/Dokument-View (`PdfEngine.mount` bzw. `renderDocView`).
  /// [fn] = aktiver Beleg (Markier-Ziel), [startPage] = Einstiegsseite,
  /// [gen] = Generation-Token gegen Async-Races (nur der jüngste Mount darf
  /// den Slot behalten).
  static Widget Function(BuildContext, String srcId,
      {int? fn, Object? startPage, required int gen})? fileView;

  /// Laufender Controller der gemounteten Engine (`Studio.file.ctl`).
  static StudioPdfHandle? pdfHandle;

  /// PDF-Markierungen einer Fußnote (`PdfEngine.marksForFn`) — speist die
  /// Levels-Kaskade und die 🖍-Chips. Null = Engine (noch) nicht verdrahtet.
  static MarksForFn? marksForFn;

  /// Abbildungs-/Tabellen-Karten (`figureCard`/`tableCard`, S-1 figures/).
  static Widget Function(BuildContext, Figur fig, {bool compact})? figureCard;
  static Widget Function(BuildContext, Tabelle tab)? tableCard;

  // ---- S-3: Editor / Views / Dock / RefMode -------------------------------

  /// ✎-LaTeX-Modus (`renderEditorPane`).
  static Widget Function(BuildContext, String sectionId)? editorPane;

  /// Views-/Instanz-Leiste (`instanzBar`) über Lesen-/Analyse-Inhalt.
  static Widget Function(BuildContext, String sectionId)? instanzBar;

  /// Instanz-Fenster neben einer Absatzkarte (`paraSide`).
  /// [isFirst]: erster Absatz des Abschnitts (Graph zeigt dort zusätzlich
  /// „Abschnitt gesamt“).
  static Widget Function(BuildContext, String sectionId, Paragraph p,
      String mode, {required bool isFirst})? paraSide;

  /// Referenzierungsmodus („⌖ Große Ansicht“, `openRefMode`).
  static void Function(BuildContext, String sectionId, String paraId,
      {String? srcId, int? fn})? openRefMode;

  /// Beleg-Dock-Inhalt (`renderFileDock`-Körper). Ohne Registrierung nutzt
  /// die Spalte die S-2-Rückfalldarstellung (Vermutungs-Block + Checkliste).
  static Widget Function(BuildContext, String srcId, int? fn)? dockBody;

  /// Absatz-Doppelklick-Bearbeitung (`paraEditStart`) — S-3 (views/).
  static void Function(BuildContext, String sectionId, Paragraph p)?
      paraEditStart;
}
