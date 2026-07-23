/// Quellen-Welt (S-4) — Barrel + Paket-Verdrahtung.
///
/// [registerQuellenHooks] hängt die Quellen-Dialoge in die Andockstellen
/// der Quell-Karte (features/pdf, `AssignPanelHooks`) — das Pendant zu den
/// `typeof linkEditModal`-Guards des Originals (pdfengine.js:563):
///
///  * ✎ „Offizielle Seite — Link ändern" → [showLinkEditModal],
///  * „Quellenseite ↗" (Dossier-Modal) → Navigation `#/quellen/<id>`.
///
/// Die Registrierung ist idempotent und läuft automatisch mit, sobald
/// irgendein Quellen-Einstieg berührt wird ([QuellenScreen], storeModal);
/// `wireAppSlots()` (lib/app_wiring.dart) ruft sie zusätzlich beim
/// App-Start, damit die ✎-Knöpfe der Studio-Quellspalte auch VOR dem
/// ersten Bibliotheksbesuch leben.
library;

import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/widgets/modal.dart';
import '../pdf/assign_panel/assign_panel.dart';
import 'detail/link_edit_modal.dart';

export 'detail/detail_panel.dart' show LibDetail, LibDetailPlaceholder, QuellenRefModeHook;
export 'detail/link_edit_modal.dart' show showLinkEditModal;
export 'import/import_modal.dart' show showImportFilesModal;
export 'import/new_source_modal.dart' show showNewSourceModal, showSourceFromFileModal;
export 'library/lib_page.dart' show QuellenPage;
export 'screen.dart' show QuellenScreen;
export 'state/quellen_kv.dart' show QuellenDomain, quellenDomainProvider;
export 'store_modal/store_modal.dart' show showStoreModal;
export 'util/gpt_dialog.dart' show QuellenGptHooks, QuellenMagicBarBuilder;

bool _hooksRegistered = false;

/// Andockstellen registrieren (idempotent, beliebig oft aufrufbar).
void registerQuellenHooks() {
  if (_hooksRegistered) return;
  _hooksRegistered = true;

  AssignPanelHooks.linkEditModal = (context, srcId, onDone) =>
      showLinkEditModal(context, srcId: srcId, onDone: onDone);

  AssignPanelHooks.openQuellenseite = (context, srcId) {
    closeAppModal();
    GoRouterHelper(context).go(Routes.quellenPath(srcId));
  };
}
