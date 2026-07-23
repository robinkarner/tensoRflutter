/// Spalte 1 der Bibliothek — Sammlungen + Werkzeuge (Port von
/// `renderLibRail`, views_quellen.js:46-144).
///
/// Sammlungen: 📚 Alle · 7 Typen (KIND_LABELS) · 4 Smart-Filter
/// (◌ offen / ✓ fertig / 📄 PDF fehlt / ✎ Notizen) · ＋ Manuell ergänzt
/// (nur wenn vorhanden). Werkzeuge: ＋ Quelle, Belegstand ⭳ Sichern /
/// ⭱ Laden, ⭱ Import (PDF/ZIP), ⌗ Datei-Auftrag, 📥 Ablage (N),
/// 🗑 Dateispeicher leeren.
///
/// Der Legacy-Ordner (File-System-Access) entfällt — im Original bereits
/// nur Altbestand (Dossier 04 §9.5).
library;

import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../data/bundles/kind_labels.dart';
import '../../../data/models/models.dart';
import '../../../data/repos/file_store.dart';
import '../../../data/repos/project_repository.dart';
import '../import/dateiauftrag_export.dart';
import '../import/import_modal.dart';
import '../import/new_source_modal.dart';
import '../state/file_store_tick.dart';
import '../state/quellen_filter.dart';
import '../state/quellen_kv.dart';
import '../util/dialogs.dart';
import '../util/save_file.dart';

/// Smart-Filter der Rail (`Quellen._smart`, js:49-56) — [files] darf null
/// sein (Store lädt noch), dann zählt nur der Levels-Stand.
bool quellenSmartFilter(
  String coll,
  Source s,
  QuellenDomain domain,
  FileStore? files,
) {
  switch (coll) {
    case 'pdf-fehlt':
      return domain.levels.positionType(s.id) == 'seite' &&
          !(files?.has(s.id) ?? false) &&
          files?.pdfStatusCache[s.id] != true;
    case 'offen':
      final c = domain.levels.countsFor(domain.levels.numsForSource(s.id));
      return c.l3 < c.total;
    case 'fertig':
      final c = domain.levels.countsFor(domain.levels.numsForSource(s.id));
      return c.total > 0 && c.l3 == c.total;
    case 'notizen':
      return domain.note(s.id).isNotEmpty;
    case 'custom':
      return s.custom;
    default:
      return true;
  }
}

class LibRail extends ConsumerStatefulWidget {
  const LibRail({super.key, required this.domain, this.onCreated});

  final QuellenDomain domain;

  /// Nach ＋ Quelle: Navigation zur neuen Quellenseite.
  final void Function(String id)? onCreated;

  @override
  ConsumerState<LibRail> createState() => _LibRailState();
}

class _LibRailState extends ConsumerState<LibRail> {
  /// `#qPdfMsg` — Meldung unter den Datei-Werkzeugen.
  String _pdfMsg = '';

  // -------------------------------------------------------------------
  // Aktionen
  // -------------------------------------------------------------------

  /// ⭳ Sichern (js:95): kompletter Belegstand als JSON.
  Future<void> _exportBelegstand() async {
    await saveTextFile('ehds-belegstand.json', widget.domain.levels.exportState());
  }

  /// ⭱ Laden (js:96-101): Datei wählen → importState → Reboot (statt reload).
  Future<void> _importBelegstand() async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final bytes = res?.files.firstOrNull?.bytes;
    if (bytes == null) return;
    try {
      widget.domain.levels.importState(utf8.decode(bytes));
      await ref.read(projectBootProvider.notifier).reboot();
    } catch (err) {
      if (!mounted) return;
      final msg = err is FormatException ? err.message : '$err';
      await showAppAlert(context, 'Import fehlgeschlagen: $msg');
    }
  }

  /// 🗑 Dateispeicher leeren (js:105-113).
  Future<void> _storeReset() async {
    final files = await ref.read(fileStoreProvider.future);
    final n = files.count() + files.listInbox().length;
    if (!mounted) return;
    final ok = await showAppConfirm(
      context,
      'Dateispeicher wirklich leeren?\n\n$n im Browser gespeicherte Datei(en) '
      'inkl. Ablage werden gelöscht — für ALLE Arbeiten (auch Mobile Sensors). '
      'Repo-Dateien (sources/…) bleiben. Belege/Markierungen bleiben ebenfalls '
      'erhalten, verweisen aber ggf. auf andere Seiten, wenn eine neuere '
      'Fassung geladen wird.',
    );
    if (!ok) return;
    await files.clearAll();
    if (!mounted) return;
    setState(() => _pdfMsg =
        '✓ Dateispeicher geleert — neueste Dateien über ⭳ Download je Quelle '
        'oder ⭱ Import laden.');
  }

  void _afterImport() {
    // `U.pdfStatusCache = {}` + Neuzeichnen (js:103) — die Liste hängt am
    // fileStoreTick, der Cache-Reset genügt hier.
    ref.read(fileStoreProvider).value?.resetStatusCache();
  }

  // -------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final sources = widget.domain.sources;
    final filter = ref.watch(quellenFilterCtlProvider).value ?? const QuellenFilter();
    ref.watch(fileStoreTickProvider); // Ablage-Zähler live
    final files = ref.watch(fileStoreProvider).value;
    final inboxN = files?.listInbox().length ?? 0;

    int kindCount(String k) => sources.where((s) => s.kind == k).length;
    final customN = sources.where((s) => s.custom).length;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Padding(
        padding: EdgeInsets.only(top: 2, bottom: 6),
        child: Eyebrow('Bibliothek'),
      ),
      _coll(t, filter, 'alle', '📚 Alle Quellen', '${sources.length}'),
      const Padding(
        padding: EdgeInsets.only(top: 12, bottom: 6),
        child: Eyebrow('Typen'),
      ),
      for (final e in kindLabels.entries)
        _coll(t, filter, 'kind:${e.key}',
            '${kindIcons[e.key] ?? ''} ${e.value}', '${kindCount(e.key)}'),
      const Padding(
        padding: EdgeInsets.only(top: 12, bottom: 6),
        child: Eyebrow('Status'),
      ),
      _coll(t, filter, 'offen', '◌ Nicht fertig belegt', ''),
      _coll(t, filter, 'fertig', '✓ Vollständig belegt', ''),
      _coll(t, filter, 'pdf-fehlt', '📄 PDF fehlt', ''),
      _coll(t, filter, 'notizen', '✎ Mit Notizen', ''),
      if (customN > 0)
        _coll(t, filter, 'custom', '＋ Manuell ergänzt', '$customN'),

      // ---- .lib-tools ----
      const SizedBox(height: 6),
      _NewSourceButton(t: t, onCreated: widget.onCreated),
      const Padding(
        padding: EdgeInsets.only(top: 12, bottom: 6),
        child: Eyebrow('Belegstand'),
      ),
      _tool(
        t,
        '⭳ Sichern',
        tip: 'Alles Erfasste (Status, Zitate, Positionen, Links, Notizen) '
            'als JSON sichern',
        onTap: () => unawaited(_exportBelegstand()),
      ),
      _tool(
        t,
        '⭱ Laden',
        tip: 'Gesicherten Belegstand laden',
        onTap: () => unawaited(_importBelegstand()),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 12, bottom: 6),
        child: Eyebrow('Dateien (PDF)'),
      ),
      _tool(
        t,
        '⭱ Import (PDF/ZIP)',
        tip: 'PDFs oder ZIP-Archive laden — passende Dateien werden '
            'automatisch zugeordnet',
        onTap: () => showImportFilesModal(context, onDone: _afterImport),
      ),
      _tool(
        t,
        '⌗ Datei-Auftrag',
        tip: 'Datei-Auftrag als ZIP: auftrag.json mit Metadaten + Links — '
            'extern (Mensch/KI/Download-Engine) besorgen, zurückliefern, hier '
            'importieren → automatische Zuordnung',
        onTap: () => unawaited(exportDateiauftragZip(ref)),
      ),
      if (inboxN > 0)
        _tool(
          t,
          '📥 Ablage ($inboxN)',
          tip: 'Importierte Dateien, die noch keiner Quelle zugewiesen sind',
          onTap: () =>
              showImportFilesModal(context, onDone: _afterImport, inbox: true),
        ),
      _tool(
        t,
        '🗑 Dateispeicher leeren',
        tip: 'Alle im Browser gespeicherten PDFs + Ablage löschen (alle '
            'Arbeiten, z. B. auch Mobile Sensors) — danach überall den '
            'neuesten Stand frisch laden (⭳ Download / ⭱ Import)',
        onTap: () => unawaited(_storeReset()),
      ),
      if (_pdfMsg.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(_pdfMsg,
              style: AppTextStyles.small.copyWith(color: t.muted)),
        ),
    ]);
  }

  /// Ein Sammlungs-Knopf `.lib-coll` (+ `.cnt`-Zähler rechts).
  Widget _coll(BookClothTokens t, QuellenFilter filter, String key,
      String label, String count) {
    final active = filter.coll == key;
    return _HoverBox(
      onTap: () => ref.read(quellenFilterCtlProvider.notifier).setColl(key),
      builder: (hover) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? t.accentSoft
              : hover
                  ? t.surface2
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontFamilyFallback: AppFonts.fallback,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
                height: 1.3,
                color: active ? t.accentInk : t.ink2,
              ),
            ),
          ),
          Text(
            count,
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontFamilyFallback: AppFonts.fallback,
              fontWeight: FontWeight.w600,
              fontSize: 10.5,
              height: 1,
              color: t.muted,
            ),
          ),
        ]),
      ),
    );
  }

  /// Ein Werkzeug-Knopf `.btn.btn-sm` in voller Rail-Breite.
  Widget _tool(BookClothTokens t, String label,
      {required String tip, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Tooltip(
        message: tip,
        child: _HoverBox(
          onTap: onTap,
          builder: (hover) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: hover ? t.surface2 : t.surface,
              border: Border.all(color: hover ? t.ink.withValues(alpha: .26) : t.borderStrong),
              borderRadius: BorderRadius.circular(BookClothTokens.radiusXs),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontFamilyFallback: AppFonts.fallback,
                fontWeight: FontWeight.w500,
                fontSize: 13,
                height: 1.2,
                color: t.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ＋ Quelle — `.lib-tools .btn-primary` ist bewusst NUR Outline
/// (transparent + accent-line-Border, app.css:125-126).
class _NewSourceButton extends StatelessWidget {
  const _NewSourceButton({required this.t, this.onCreated});

  final BookClothTokens t;
  final void Function(String id)? onCreated;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Neue Quelle manuell anlegen — mit Ergänzungs-Prompt für die '
          'GPT-Voranalyse',
      child: _HoverBox(
        onTap: () => showNewSourceModal(context, onCreated: onCreated),
        builder: (hover) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: hover ? t.accentSoft : Colors.transparent,
            border: Border.all(color: t.accentLine),
            borderRadius: BorderRadius.circular(BookClothTokens.radiusXs),
          ),
          child: Text(
            '＋ Quelle',
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontFamilyFallback: AppFonts.fallback,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              height: 1.2,
              color: t.accentInk,
            ),
          ),
        ),
      ),
    );
  }
}

/// Kleiner Hover-Helfer (MouseRegion + GestureDetector).
class _HoverBox extends StatefulWidget {
  const _HoverBox({required this.onTap, required this.builder});

  final VoidCallback onTap;
  final Widget Function(bool hover) builder;

  @override
  State<_HoverBox> createState() => _HoverBoxState();
}

class _HoverBoxState extends State<_HoverBox> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: widget.builder(_hover),
      ),
    );
  }
}
