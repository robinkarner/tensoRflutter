/// Verdrahtungs-Sweep (Gate 1) — verbindet die Welle-1-Pakete miteinander.
///
/// Das Studio-Gerüst (S-2) deklariert in [StudioSlots] die vertraglichen
/// Andockstellen; die Schwester-Pakete liefern die Bausteine, aber KEINES
/// darf die Registrierung beim App-Start selbst erzwingen (Eigner-Grenzen).
/// Diese Datei ist der eine Ort, an dem alles zusammenkommt:
///
///  * [wireAppSlots] — statische Slots (S-1-Quell-Karte/PDF-View/Figuren,
///    S-3-Editor/Views/RefMode via `wireStudioS3`, S-4-Quellen-Hooks via
///    `registerQuellenHooks`, ⌖ Referenzieren der Bibliothek → RefMode).
///  * [installAppWiring] — die reaktive Brücke: `levelsMarksForFnProvider`
///    (S-1, KV `pdfMarks`) speist [StudioSlots.marksForFn]; bei jeder
///    Markierungs-Änderung wird der Studio-Domänen-Graph invalidiert
///    (Pendant zu `refreshMarks()`/`onMarksChange` des Originals —
///    Levels-Kaskade, 🖍-Chips, Fußnoten-Dropdown ziehen nach).
///
/// Aufruf: `appBoot` (main.dart) ruft [installAppWiring] als ERSTEN Schritt —
/// damit leben alle Slots vor dem ersten Render jeder Ansicht.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/tokens.dart';
import 'core/theme/typography.dart';
import 'data/db/kv.dart';
import 'data/repos/file_store.dart';
import 'features/ai/ai.dart';
import 'features/pdf/pdf.dart';
import 'features/quellen/quellen.dart';
import 'features/studio/layout/studio_slots.dart';
import 'features/studio/layout/studio_state.dart';
import 'features/studio/refmode/ref_mode.dart';
import 'features/studio/views/wiring.dart';

bool _slotsWired = false;

/// Statische Slots aller Welle-1-Pakete füllen (idempotent).
void wireAppSlots() {
  if (_slotsWired) return;
  _slotsWired = true;

  // S-3: Editor-Modus, Instanz-Leiste/-Fenster, RefMode, Absatz-Doppelklick.
  wireStudioS3();
  // S-4: ✎-Link-Modal + „Quellenseite ↗" in der Quell-Karte (S-1).
  registerQuellenHooks();
  // K-3: ✦-Magic-Bar der Quellen-GPT-Dialoge (QuellenGptHooks.magicBar) +
  // ↻/➕-Direkt-Generierung der ✎-Views (InstanzGenerateHook).
  wireAiHooks();

  // ---- S-1 → S-2: Quellen-Spalte des Studios --------------------------------

  // sf-card: DIE eine Quell-Karte (`PdfEngine.assignPanel`, :1361-1365).
  StudioSlots.fileCard ??= (context, srcId, {required collapsed}) =>
      _StudioFileCard(srcId: srcId);

  // sf-view: PDF-Engine bzw. renderDocView (`mount()`, :1348-1404). Der
  // Generation-Key erzwingt den Re-Mount, wenn der Host `gen` hochzählt
  // (Quellwechsel/Datei-Zuordnung) — verspätete Lader alter Generationen
  // verschwinden mit ihrem Widget (Race-Schutz des Originals).
  StudioSlots.fileView ??= (context, srcId, {fn, startPage, required gen}) =>
      _StudioFileView(
        key: ValueKey('sfv|$srcId|$gen'),
        srcId: srcId,
        fn: fn,
        startPage: startPage,
      );

  // Abbildungs-/Tabellen-Karten (Lesen-/Analyse-Modus).
  StudioSlots.figureCard ??= (context, fig, {compact = false}) =>
      FigureCard(fig, compact: compact);
  StudioSlots.tableCard ??= (context, tab) => TableCard(tab);

  // ---- S-3 → S-4: ⌖ Referenzieren aus dem Quellen-Detail --------------------
  // Öffnet die Große Ansicht an der ERSTEN Zitierstelle der Quelle (das
  // Original verweist von der Bibliothek ins Studio, views_quellen.js:517 —
  // mit registriertem RefMode geht es direkt ins Vollbild).
  QuellenRefModeHook.open ??= (context, srcId) {
    final container = ProviderScope.containerOf(context, listen: false);
    final domain = container.read(studioDomainProvider);
    if (domain == null) return;
    final nums = domain.levels.numsForSource(srcId);
    if (nums.isEmpty) return;
    final entry = domain.ctx.fnIndex[nums.first];
    if (entry == null) return;
    openStudioRefMode(
      context,
      sectionId: entry.sectionId,
      paraId: entry.paragraphId,
      srcId: srcId,
      fn: nums.first,
    );
  };
}

/// Reaktive Verdrahtung — vom App-Boot ([Ref] von `appBoot`) registriert;
/// die Listener leben so lange wie der Boot-Provider (keepAlive) und werden
/// bei jedem Reboot frisch aufgesetzt.
void installAppWiring(Ref ref) {
  wireAppSlots();

  // Levels-Kaskade Stufe „PDF-Markierung" (CONTRACTS §13.4): die
  // MarksForFn-Funktion der PDF-Engine in den statischen Slot spiegeln.
  // Solange der Marks-Store lädt, bleibt sie null — die Kaskade überspringt
  // die Markierungs-Stufe wie das Original ohne geladenes Engine-Modul.
  StudioSlots.marksForFn = ref.read(levelsMarksForFnProvider);
  ref.listen(levelsMarksForFnProvider, (previous, next) {
    StudioSlots.marksForFn = next;
    // studioDomain liest den Slot beim Bau — Invalidierung zieht Levels,
    // 🖍-Chips, Checkliste und Fußnoten-Dropdown nach (refreshMarks-Pendant).
    ref.invalidate(studioDomainProvider);
  });
}

// ---------------------------------------------------------------------------
// sf-card: Quell-Karte der Studio-Spalte
// ---------------------------------------------------------------------------

/// `PdfEngine.assignPanel(cardHost, id, {collapsed: !!has || !!doc, …})`:
/// mit Datei/Dokument-Definition eingeklappt (nur Kopfzeile), ohne beides
/// aufgeklappt (Zuordnung/Download direkt sichtbar). Nach Zuordnung oder
/// Metadaten-Änderung wird die View-Generation hochgezählt (= `mount()`).
class _StudioFileCard extends ConsumerWidget {
  const _StudioFileCard({required this.srcId});

  final String srcId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(assignPanelDataProvider(srcId)).value;
    // Bis zur Datenlage bleibt der Karten-Slot leer (Original: cardHost
    // wird erst nach `detectPdf` befüllt) — der Einklapp-Startzustand
    // braucht `has`/`doc`.
    if (data == null) return const SizedBox.shrink();
    return AssignPanel(
      // Datenlage-Wechsel (Datei kommt/geht) setzt den Startzustand neu auf.
      key: ValueKey('sfcard|$srcId|${data.hasFile}|${data.doc != null}'),
      srcId: srcId,
      collapsed: data.hasFile || data.doc != null,
      onDone: () => ref.read(studioFileProvider.notifier).remount(),
      onMeta: () => ref.read(studioFileProvider.notifier).remount(),
    );
  }
}

// ---------------------------------------------------------------------------
// sf-view: PDF-Engine / Dokument-Ansicht
// ---------------------------------------------------------------------------

/// `Studio.file.ctl`-Adapter: reicht die Aufrufe des Gerüsts (Such-Chips,
/// Dropdown-goto, Spalten-Resize) an den [PdfEngineController] durch.
class _StudioPdfHandle implements StudioPdfHandle {
  _StudioPdfHandle(this.srcId, this._ctl);

  @override
  final String srcId;
  final PdfEngineController _ctl;

  @override
  void search(String term) => _ctl.search(term);

  @override
  void goto(Object page) => _ctl.goto(_pageInt(page) ?? 1);

  @override
  void refreshActive() => _ctl.refreshActive();

  @override
  void refresh() => _ctl.refresh();
}

/// Zahl aus dem Typ-Mix der Seitenangaben („14", 14, „S. 14" → nur echte
/// Zahlen zählen; sonst null).
int? _pageInt(Object? v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

class _StudioFileView extends ConsumerStatefulWidget {
  const _StudioFileView({
    super.key,
    required this.srcId,
    this.fn,
    this.startPage,
  });

  final String srcId;
  final int? fn;
  final Object? startPage;

  @override
  ConsumerState<_StudioFileView> createState() => _StudioFileViewState();
}

class _StudioFileViewState extends ConsumerState<_StudioFileView> {
  final PdfEngineController _ctl = PdfEngineController();
  _StudioPdfHandle? _handle;

  /// null = Prüfung läuft („Lade Datei …"), sonst das detectPdf-Ergebnis.
  bool? _has;
  SrcDocDef? _doc;

  @override
  void initState() {
    super.initState();
    _probe();
  }

  /// `PdfStore.has(id) || await U.detectPdf(id)` + `U.getSrcDoc(id)`
  /// (:1357-1359) — beides gehört zur Mount-Generation dieses Widgets.
  Future<void> _probe() async {
    final files = await ref.read(fileStoreProvider.future);
    final kv = ref.read(kvStoreProvider);
    final has =
        files.has(widget.srcId) ||
        ((await files.detectPdf(widget.srcId, kv)) ?? false);
    final doc = await kv.getSrcDoc(widget.srcId);
    if (!mounted) return;
    setState(() {
      _has = has;
      _doc = doc;
    });
  }

  @override
  void dispose() {
    // Nur den EIGENEN Controller austragen — eine jüngere Generation kann
    // sich bereits registriert haben (`gen !== Studio.file.gen`-Schutz).
    if (_handle != null && identical(StudioSlots.pdfHandle, _handle)) {
      StudioSlots.pdfHandle = null;
    }
    super.dispose();
  }

  // --- mount-Optionen (:1376-1396) -----------------------------------------

  /// Startseite: erste Markierung der Fußnote, sonst erfasste Seite, sonst 1.
  int? _startPage() {
    final fromHost = _pageInt(widget.startPage);
    if (fromHost != null) return fromHost;
    final fn = widget.fn;
    if (fn == null) return null;
    final marks = StudioSlots.marksForFn?.call(widget.srcId, fn) ?? const [];
    if (marks.isNotEmpty) {
      final p = _pageInt(marks.first.page);
      if (p != null) return p;
    }
    final domain = ref.read(studioDomainProvider);
    return _pageInt(domain?.levels.info(fn).seite) ?? 1;
  }

  /// Aktiver Beleg — live aus `Studio.file.fn` (Dropdown wechselt OHNE
  /// Re-Mount), Farbe aus der Levels-Palette, Label = Claim/Fußnotentext(60).
  ActiveBeleg? _getActive() {
    final fn = ref.read(studioFileProvider).fn;
    if (fn == null) return null; // nur Erwähnung: nichts erfassbar
    final domain = ref.read(studioDomainProvider);
    if (domain == null) return null;
    final bb = domain.ctx.findBeleg(fn);
    var label = bb?.claim ?? '';
    if (label.isEmpty) label = domain.ctx.fnIndex[fn]?.text ?? '';
    if (label.length > 60) label = label.substring(0, 60);
    return ActiveBeleg(
      fn: fn,
      farbe: domain.levels.farbeFor(widget.srcId, fn),
      label: label,
    );
  }

  /// Markieren übernimmt Zitat + Seite in den aktiven Beleg (Levels.save,
  /// herkunft 'manuell'); bei Fundstellen-Quellen bleibt `seite` leer.
  /// Dock/Karten/Dropdown ziehen reaktiv über den KV-Snapshot nach.
  void _onCapture(PdfCapture c) {
    final domain = ref.read(studioDomainProvider);
    if (domain == null) return;
    final posType = domain.levels.positionType(widget.srcId);
    domain.levels.save(c.fn, {
      'zitat': c.text,
      'seite': posType == 'seite' ? c.page : '',
      'herkunft': 'manuell',
    });
  }

  Widget _empty(BuildContext context, String text) {
    final t = BookClothTokens.of(context);
    // `.sf-empty` (app.css:480): 26/18, muted, 13.5, zentriert.
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 26),
      alignment: Alignment.topCenter,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTextStyles.small.copyWith(color: t.muted),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_has == null) return _empty(context, 'Lade Datei …');

    if (_has == false) {
      // Internetquelle/Bild im Betrachter zeigen; sonst leer (:1367-1372).
      if (_doc != null) return SrcDocView(srcId: widget.srcId);
      return const SizedBox.expand();
    }

    // PDF vorhanden: Engine mounten und den Controller als `Studio.file.ctl`
    // registrieren (jüngste Generation gewinnt — dieses Widget existiert nur
    // für die aktuelle `gen`).
    _handle ??= _StudioPdfHandle(widget.srcId, _ctl);
    StudioSlots.pdfHandle = _handle;
    return PdfEngineView(
      srcId: widget.srcId,
      page: _startPage(),
      fit: true,
      controller: _ctl,
      getActive: _getActive,
      onCapture: _onCapture,
      unavailablePlaceholder: _empty(
        context,
        'Die Markier-Engine konnte dieses PDF nicht rendern — „↗ Tab“ auf der Quellenseite nutzen.',
      ),
    );
  }
}
