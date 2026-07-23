/// Paket S-1 — PDF-Engine: öffentliche Andockfläche für S-2/S-3/S-4.
///
/// Kernbausteine:
///  * [PdfEngineView] + [PdfEngineController] — der Viewer (Endlos-Scroll,
///    Marks, Suche, Zoom, Tastatur); `viewOnly`/`compact`/`data` wie das
///    Original-`mount` (Dossier 05 §2).
///  * [AssignPanel] (+[AssignPanelAction], [AssignPanelHooks]) — DIE eine
///    Quell-Karte (4 Datei-Zustände, 5-Tab-Material-Switch, ⭳ Download,
///    Kandidaten-Erkennung).
///  * [SrcDocView] — Nicht-PDF-Quelle (Link-Karte / Bild) im Viewerbereich.
///  * Marks: [pdfMarksProvider] (CRUD auf KV `pdfMarks`, Datenform 1:1) und
///    [levelsMarksForFnProvider] — die `Levels.marksForFn`-Verdrahtung.
///  * [FigureCard]/[TableCard] — Abbildungs-/Tabellen-Karten (FigStore).
library;

export 'assign_panel/assign_dialogs.dart'
    show showDossierModal, showNoteModal, showUrlModal;
export 'assign_panel/assign_panel.dart';
export 'assign_panel/assign_panel_data.dart';
export 'assign_panel/candidates.dart';
export 'assign_panel/download_engine.dart';
export 'assign_panel/src_head.dart';
export 'assign_panel/src_kv.dart';
export 'figures/figure_card.dart';
export 'marks/mark_dialogs.dart';
export 'marks/mark_overlay.dart' show markColorOf, kMarkFallbackColor;
export 'marks/pdf_mark.dart';
export 'marks/pdf_marks_store.dart';
export 'marks/selection_rects.dart';
export 'search/pdf_text_search.dart';
export 'viewer/ocr_bar.dart';
export 'viewer/pdf_engine_toolbar.dart' show ActiveBeleg;
export 'viewer/pdf_engine_view.dart';
export 'viewer/src_doc_view.dart';
export 'viewer/viewer_geometry.dart';
