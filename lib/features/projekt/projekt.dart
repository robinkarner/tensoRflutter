/// Projekt-Welt (K-2) — Barrel.
///
/// Andockflächen für andere Pakete:
///  * [WorksMenuCard] — der Inhalt des 🗂-works-pop der Topbar
///    (`projektArbeitenCard`-Pendant; die Popover-Hülle stellt die Topbar).
///  * [showNeueArbeitModal] / [showImportAnalysenModal] — die beiden
///    Arbeiten-Modals (auch aus cmdk/K-4 aufrufbar).
///  * [masterPrompt] / [masterPromptWithTex] — der Vertragstext der
///    GPT-Pipeline (nutzt auch K-3 für den „alles kochen“-Flow).
///  * [createFromTex] / [applyRegistry] — Arbeiten-Aktionen ohne UI.
library;

export 'arbeiten/import_analysen_modal.dart' show showImportAnalysenModal;
export 'arbeiten/master_prompt.dart';
export 'arbeiten/neue_arbeit_modal.dart' show showNeueArbeitModal;
export 'arbeiten/works_actions.dart';
export 'arbeiten/works_menu.dart' show WorksMenuCard, worksListProvider;
export 'dashboard/projekt_page.dart' show ProjektPage;
export 'screen.dart' show ProjektScreen;
