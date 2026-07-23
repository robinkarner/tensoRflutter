/// S-3-Verdrahtung: registriert die Editor-/Views-/Dock-/RefMode-Bausteine
/// an den vertraglichen [StudioSlots] des S-2-Gerüsts.
///
/// Idempotent — mehrfacher Aufruf ist harmlos. Aufruf-Anker: `wireAppSlots()`
/// (lib/app_wiring.dart) ruft [wireStudioS3] beim App-Start, vor dem ersten
/// Studio-Render; die `#/doc`-Ansicht ruft die Funktion zusätzlich defensiv
/// auf (harmlos dank Idempotenz).
library;

import 'para_edit.dart';
import 'para_side.dart';
import 'instanz_bar.dart';
import '../editor/editor_pane.dart';
import '../layout/studio_slots.dart';
import '../refmode/ref_mode.dart';

/// Alle S-3-Slots füllen. Der Beleg-Dock-Slot ([StudioSlots.dockBody])
/// bleibt bewusst leer: die S-2-Standardfüllung ([FileDockBody]) IST der
/// vollständige `renderFileDock`-Port — es gibt nichts zu ersetzen.
void wireStudioS3() {
  StudioSlots.editorPane ??=
      (context, sectionId) => EditorPane(sectionId: sectionId);

  StudioSlots.instanzBar ??=
      (context, sectionId) => InstanzBar(sectionId: sectionId);

  StudioSlots.paraSide ??= (context, sectionId, p, mode, {required isFirst}) =>
      buildParaSide(context, sectionId, p, mode, isFirst: isFirst);

  StudioSlots.openRefMode ??= (context, sectionId, paraId, {srcId, fn}) =>
      openStudioRefMode(context,
          sectionId: sectionId, paraId: paraId, srcId: srcId, fn: fn);

  StudioSlots.paraEditStart ??=
      (context, sectionId, p) => startParaEdit(context, sectionId, p);
}
