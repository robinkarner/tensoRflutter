/// AssignPanel — DIE eine Quell-Karte für überall (Port von
/// `PdfEngine.assignPanel`, pdfengine.js:334-780): oben IMMER die volle
/// Identität (Chips · Titel · Autoren · DOI · Tags), darunter die
/// Kernaktionen (📚 Dossier · ↗ offizielle Seite · ✎ · 📝 · Extras),
/// darunter der Datei-Block mit VIER Zuständen:
///   ✓ Datei zugeordnet · 🌐 Internetquelle · 🖼 Bild · ▣ keine Datei
/// (5-Tab-Material-Switch 📄 PDF · 🌐 Website · 🖼 Bild · 📝 Text · Σ LaTeX,
/// ⭳ Download-Engine, ⭱ Datei lokal, 📥 Aus Dateiverzeichnis,
/// Kandidaten-Erkennung mit viewOnly-Vorschau) — und die Material-Liste.
///
/// Einklappbar nach oben (`details.src-panel`): eingeklappt bleibt nur die
/// Kopfzeile (Titel · Autoren · Datei-Status) stehen.
library;

import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/color_mix.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/lightbox.dart';
import '../../../core/widgets/modal.dart';
import '../../../data/db/kv.dart';
import '../../../data/repos/file_store.dart';
import '../viewer/pdf_engine_view.dart';
import 'assign_dialogs.dart';
import 'assign_panel_data.dart';
import 'candidates.dart';
import 'download_engine.dart';
import 'src_head.dart';
import 'src_kv.dart';

/// Zusatzknopf des Gastgebers (z. B. „🤖 Ergänzung" / „🗑" bei manuellen
/// Quellen) — `opts.extraActions`-Pendant.
class AssignPanelAction {
  final String label;
  final String? title;
  final void Function(VoidCallback refresh) onTap;

  const AssignPanelAction({required this.label, this.title, required this.onTap});
}

/// Andockstellen anderer Pakete (typeof-Guard-Pendants des Originals).
abstract final class AssignPanelHooks {
  /// ✎ „Offizielle Seite — Link ändern" — registriert S-4 (linkEditModal,
  /// views_quellen.js:642; Guard pdfengine.js:563). null ⇒ Knopf ohne Wirkung.
  static void Function(BuildContext context, String srcId, VoidCallback onDone)?
      linkEditModal;

  /// Navigation zur Quellenseite (Dossier-Modal „Quellenseite ↗").
  static void Function(BuildContext context, String srcId)? openQuellenseite;
}

class AssignPanel extends ConsumerStatefulWidget {
  const AssignPanel({
    super.key,
    required this.srcId,
    this.onDone,
    this.onCancel,
    this.onMeta,
    this.onToggle,
    this.collapsed,
    this.extraActions = const [],
  });

  final String srcId;

  /// Nach erfolgreicher Datei-Zuordnung (Gastseite rendert neu).
  final VoidCallback? onDone;

  /// „↩ zurück" — nur mit Callback sichtbar.
  final VoidCallback? onCancel;

  /// Nach Metadaten-Änderung (Link/Doc-Typ/Text).
  final VoidCallback? onMeta;

  /// Einklapp-Zustand geändert (true = offen).
  final ValueChanged<bool>? onToggle;

  /// Start-Einklapp-Zustand (default offen).
  final bool? collapsed;

  final List<AssignPanelAction> extraActions;

  @override
  ConsumerState<AssignPanel> createState() => _AssignPanelState();
}

class _AssignPanelState extends ConsumerState<AssignPanel> {
  late bool _collapsed = widget.collapsed ?? false;
  int _candIdx = 0;
  bool _ablageOpen = false;

  /// Material-Switch: 'pdf' | 'web' | 'img' | 'txt' | 'tex' — Standard PDF.
  String _matTab = 'pdf';
  bool _dlBusy = false;
  String? _altSel;

  final _webCtrl = TextEditingController();
  final _txtCtrl = TextEditingController();
  final _texNameCtrl = TextEditingController();
  final _texCtrl = TextEditingController();
  bool _txtPrimed = false;

  @override
  void dispose() {
    _webCtrl.dispose();
    _txtCtrl.dispose();
    _texNameCtrl.dispose();
    _texCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Aktionen
  // ---------------------------------------------------------------------

  void _refresh() =>
      ref.read(assignPanelDataProvider(widget.srcId).notifier).refresh();

  /// finish() (pdfengine.js:344-348): Status-Cache setzen, Gastseite
  /// benachrichtigen, neu zeichnen.
  Future<void> _finish() async {
    final files = await ref.read(fileStoreProvider.future);
    files.pdfStatusCache[widget.srcId] = true;
    widget.onDone?.call();
    _refresh();
  }

  void _metaChanged() {
    widget.onMeta?.call();
    _refresh();
  }

  Future<List<(String, Uint8List)>> _pickFiles({
    FileType type = FileType.custom,
    List<String>? extensions,
    bool multiple = true,
  }) async {
    final res = await FilePicker.pickFiles(
      type: type,
      allowedExtensions: type == FileType.custom ? extensions : null,
      allowMultiple: multiple,
      withData: true,
    );
    if (res == null) return const [];
    return [
      for (final f in res.files)
        if (f.bytes != null) (f.name, f.bytes!),
    ];
  }

  /// Erste Datei wird Haupt-PDF (umbenannt zu `<srcId>.pdf`), weitere
  /// werden Extra-Material (pdfengine.js:544-550).
  Future<void> _pickMainPdf() async {
    final fs = await _pickFiles(extensions: ['pdf']);
    if (fs.isEmpty) return;
    final files = await ref.read(fileStoreProvider.future);
    await files.addFiles([('${widget.srcId}.pdf', fs.first.$2)]);
    for (final f in fs.skip(1)) {
      await _addExtraPdf(f.$1, f.$2);
    }
    await _finish();
  }

  Future<void> _addExtraPdf(String name, Uint8List data) async {
    final key = FileKeys.extra(widget.srcId);
    final files = await ref.read(fileStoreProvider.future);
    await files.addFiles([('$key.pdf', data)]);
    await ref
        .read(kvStoreProvider)
        .addSrcExtra(widget.srcId, SrcExtra(kind: 'pdf', key: key, name: name));
  }

  Future<void> _addExtraImg(String name, Uint8List data) async {
    final key = FileKeys.extra(widget.srcId);
    final files = await ref.read(fileStoreProvider.future);
    await files.putImage(key, data);
    await ref
        .read(kvStoreProvider)
        .addSrcExtra(widget.srcId, SrcExtra(kind: 'image', key: key, name: name));
  }

  Future<void> _setImage(String name, Uint8List data) async {
    final files = await ref.read(fileStoreProvider.future);
    await files.putImage(widget.srcId, data);
    await ref
        .read(kvStoreProvider)
        .setSrcDoc(widget.srcId, const SrcDocDef(kind: 'image'));
    _metaChanged();
  }

  /// Bilder-Auswahl (matimg/matimg2): erstes Bild wird Quell-Ansicht, wenn
  /// weder Datei noch Definition existiert; Rest → Material (js:675-682).
  Future<void> _onImgPick(AssignPanelState st) async {
    final fs = await _pickFiles(type: FileType.image);
    if (fs.isEmpty) return;
    var rest = fs;
    if (!st.hasFile && st.doc == null) {
      await _setImage(fs.first.$1, fs.first.$2);
      rest = fs.skip(1).toList();
    }
    for (final f in rest) {
      await _addExtraImg(f.$1, f.$2);
    }
    _refresh();
  }

  Future<void> _onMatPdfPick(AssignPanelState st) async {
    final fs = await _pickFiles(extensions: ['pdf']);
    if (fs.isEmpty) return;
    var rest = fs;
    if (!st.hasFile) {
      final files = await ref.read(fileStoreProvider.future);
      await files.addFiles([('${widget.srcId}.pdf', fs.first.$2)]);
      files.pdfStatusCache[widget.srcId] = true;
      rest = fs.skip(1).toList();
    }
    for (final f in rest) {
      await _addExtraPdf(f.$1, f.$2);
    }
    _refresh();
  }

  Future<String?> _pickTextFile() async {
    final fs = await _pickFiles(extensions: ['txt', 'md'], multiple: false);
    if (fs.isEmpty) return null;
    return _decodeText(fs.first.$2);
  }

  Future<(String, String)?> _pickTexFile() async {
    final fs = await _pickFiles(extensions: ['tex', 'txt'], multiple: false);
    if (fs.isEmpty) return null;
    return (fs.first.$1, _decodeText(fs.first.$2));
  }

  static String _decodeText(Uint8List data) {
    try {
      return utf8.decode(data);
    } catch (_) {
      return latin1.decode(data);
    }
  }

  Future<void> _tryDownload() async {
    setState(() => _dlBusy = true);
    try {
      final st = await ref.read(assignPanelDataProvider(widget.srcId).future);
      final engine = await ref.read(downloadEngineProvider.future);
      final r = await engine.tryDownload(widget.srcId, st.dlLink);
      if (!mounted) return;
      if (r.ok) {
        await _finish();
      } else {
        _refresh();
      }
    } finally {
      if (mounted) setState(() => _dlBusy = false);
    }
  }

  Future<void> _confirmCandidate(AssignCandidate cand) async {
    // Nur bei ECHTER Übernahme abschließen — sonst würde der Status-Cache
    // fälschlich „Datei vorhanden" melden (vergifteter Cache, js:741-744).
    final files = await ref.read(fileStoreProvider.future);
    final ok = await files.assignInbox(cand.name, widget.srcId);
    if (ok) {
      await _finish();
    } else {
      _refresh();
    }
  }

  Future<void> _takeAlt(String value) async {
    final files = await ref.read(fileStoreProvider.future);
    if (value.startsWith('inbox:')) {
      final ok = await files.assignInbox(value.substring(6), widget.srcId);
      if (!ok) {
        _refresh();
        return;
      }
    } else if (value.startsWith('src:')) {
      final data = await files.getData(value.substring(4));
      if (data == null) {
        _refresh();
        return;
      }
      await files.putData(widget.srcId, data);
    } else {
      return;
    }
    await _finish();
  }

  Future<void> _openExtra(SrcExtra x) async {
    final files = await ref.read(fileStoreProvider.future);
    if (x.isPdf && x.key != null) {
      final data = await files.getData(x.key!);
      if (!mounted || data == null) return;
      showAppModal(
        context,
        title: Text('📄 ${x.label}'),
        scrollableBody: false,
        body: PdfEngineView(
          srcId: widget.srcId,
          data: data,
          compact: true,
          viewOnly: true,
        ),
      );
    } else if (x.isImage && x.key != null) {
      final img = await files.getImage(x.key!);
      if (!mounted || img == null) return;
      showLightbox(context, image: Image.memory(img.$1), caption: x.label);
    } else if (x.isTex) {
      if (!mounted) return;
      showTexViewModal(context,
          name: x.name ?? 'LaTeX-Material', text: x.text ?? '');
    }
  }

  Future<void> _deleteExtra(int index, SrcExtra x) async {
    final files = await ref.read(fileStoreProvider.future);
    if (x.isPdf && x.key != null) await files.removeFile(x.key!);
    if (x.isImage && x.key != null) await files.removeImage(x.key!);
    await ref.read(kvStoreProvider).removeSrcExtra(widget.srcId, index);
    _refresh();
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final async = ref.watch(assignPanelDataProvider(widget.srcId));
    final st = async.value;

    if (st == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.borderStrong),
          borderRadius: BorderRadius.circular(BookClothTokens.radius),
        ),
        child: Text('Lade Quelle …',
            style: AppTextStyles.small.copyWith(color: t.muted)),
      );
    }

    if (_candIdx >= st.candidates.length) _candIdx = 0;
    if (!_txtPrimed) {
      _txtCtrl.text = st.srcText;
      _txtPrimed = true;
    }

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.borderStrong),
        borderRadius: BorderRadius.circular(BookClothTokens.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _summaryBar(t, st),
          if (!_collapsed) ...[
            Divider(height: 1, color: t.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 4, 15, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  SrcHead(source: st.source),
                  if (srcTagsFor(st.source, st.fileSearch).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 5, runSpacing: 5, children: [
                      for (final tag in srcTagsFor(st.source, st.fileSearch).take(5))
                        SrcTagChip(tag),
                    ]),
                  ],
                  const SizedBox(height: 11),
                  _actionsRow(t, st),
                  const SizedBox(height: 12),
                  _fileBlock(t, st),
                  ..._matSection(t, st),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// `summary.sp-bar`: ▸-Caret · „Quelle" (offen) bzw. Titel+Sub (zu) ·
  /// Datei-Status-Chip rechts.
  Widget _summaryBar(BookClothTokens t, AssignPanelState st) {
    final s = st.source;
    final sumSub = [
      if (s.author != null && s.author!.isNotEmpty) s.author!,
      if (s.year != null) '${s.year}',
    ].join(' · ');

    return Tooltip(
      message: 'Quell-Karte ein-/ausklappen',
      child: InkWell(
        onTap: () {
          setState(() => _collapsed = !_collapsed);
          widget.onToggle?.call(!_collapsed);
        },
        hoverColor: t.surface2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Row(
            children: [
              AnimatedRotation(
                turns: _collapsed ? 0 : .25,
                duration: const Duration(milliseconds: 130),
                child: Text('▸',
                    style: TextStyle(fontSize: 10, height: 1, color: t.muted)),
              ),
              const SizedBox(width: 9),
              if (!_collapsed)
                const Eyebrow('Quelle')
              else
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.title.isNotEmpty ? s.title : s.id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.serif,
                          fontFamilyFallback: AppFonts.fallback,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                          color: t.ink,
                        ),
                      ),
                      if (sumSub.isNotEmpty)
                        Text(
                          sumSub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            color: t.muted,
                            fontFamily: AppFonts.ui,
                            fontFamilyFallback: AppFonts.fallback,
                          ),
                        ),
                    ],
                  ),
                ),
              if (!_collapsed) const Spacer(),
              const SizedBox(width: 9),
              _statusChip(st),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(AssignPanelState st) {
    if (st.hasFile) {
      return const AppChip(label: '✓ Datei', variant: AppChipVariant.ok, mini: true);
    }
    if (st.doc?.isLink ?? false) {
      return const AppChip(
          label: '🌐 Internetquelle', variant: AppChipVariant.ok, mini: true);
    }
    if (st.doc?.isImage ?? false) {
      return const AppChip(label: '🖼 Bild', variant: AppChipVariant.ok, mini: true);
    }
    if (st.hasText) {
      return const AppChip(label: '📝 Text', variant: AppChipVariant.ok, mini: true);
    }
    return const AppChip(
        label: '▣ keine Datei', variant: AppChipVariant.warn, mini: true);
  }

  /// `.sp-actions`: 📚 Dossier · ↗ offizielle Seite · ✎ · 📝 · Extras.
  Widget _actionsRow(BookClothTokens t, AssignPanelState st) {
    final s = st.source;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        AppButton(
          small: true,
          tooltip: 'Dossier dieser Quelle (Kerninhalte, Rolle in der Arbeit)',
          onPressed: () => showDossierModal(
            context,
            source: s,
            onQuellenseite: AssignPanelHooks.openQuellenseite == null
                ? null
                : () => AssignPanelHooks.openQuellenseite!(context, s.id),
          ),
          child: Text('📚 Dossier${s.dossierFallback ? ' ✦' : ''}'),
        ),
        if (st.links.official != null)
          AppButton(
            small: true,
            tooltip:
                'Offizielle Seite (DOI/Verlag/EUR-Lex/RIS) öffnen: ${st.links.official}',
            onPressed: () => launchUrl(Uri.parse(st.links.official!),
                mode: LaunchMode.externalApplication),
            child: const Text('↗ offizielle Seite'),
          ),
        AppButton(
          small: true,
          tooltip: 'Link zur offiziellen Seite ändern',
          onPressed: AssignPanelHooks.linkEditModal == null
              ? null
              : () => AssignPanelHooks.linkEditModal!(
                  context, widget.srcId, _metaChanged),
          child: const Text('✎'),
        ),
        AppButton(
          small: true,
          tooltip: 'Eigene Notizen zu dieser Quelle — bleiben lokal im Browser',
          onPressed: () async {
            final kv = ref.read(kvStoreProvider);
            final note = await kv.getSrcNote(widget.srcId);
            if (!mounted) return;
            showNoteModal(
              context,
              titel: s.title.isNotEmpty ? s.title : s.id,
              initial: note,
              onSave: (text) async {
                await kv.setSrcNote(widget.srcId, text);
                _refresh(); // 📝-Marker nachziehen, Modal bleibt offen
              },
            );
          },
          child: Text('📝${st.hasNote ? ' ✎' : ''}'),
        ),
        for (final a in widget.extraActions)
          AppButton(
            small: true,
            tooltip: a.title,
            onPressed: () => a.onTap(_metaChanged),
            child: Text(a.label),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Datei-Block (4 Zustände)
  // ---------------------------------------------------------------------

  Widget _fileBlock(BookClothTokens t, AssignPanelState st) {
    if (st.hasFile) return _fileBlockHas(t);
    if (st.doc?.isLink ?? false) return _fileBlockLink(t, st);
    if (st.doc?.isImage ?? false) return _fileBlockImage(t, st);
    return _fileBlockMissing(t, st);
  }

  /// a) `✓ Datei zugeordnet` — schlanke Zeile auf good-Tinte.
  Widget _fileBlockHas(BookClothTokens t) {
    return _CorneredBox(
      cornerColor: t.good,
      decoration: BoxDecoration(
        color: t.good.alphaPct(6),
        border: Border.all(color: t.good.alphaPct(40)),
        borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      child: Row(children: [
        const AppChip(label: '✓ Datei zugeordnet', variant: AppChipVariant.ok),
        const Spacer(),
        AppButton(
          small: true,
          tooltip:
              'Zuordnung lösen — erst danach sind Ersetzen/Neuwahl wieder wählbar',
          onPressed: () async {
            final files = await ref.read(fileStoreProvider.future);
            final ok = await files.removeFile(widget.srcId);
            if (ok) files.pdfStatusCache[widget.srcId] = false;
            widget.onDone?.call();
            _refresh();
          },
          child: const Text('Zuordnung entfernen'),
        ),
        if (widget.onCancel != null) ...[
          const SizedBox(width: 6),
          AppButton(
            variant: AppButtonVariant.ghost,
            small: true,
            onPressed: widget.onCancel,
            child: const Text('↩ zurück'),
          ),
        ],
      ]),
    );
  }

  /// b) `🌐 Internetquelle`.
  Widget _fileBlockLink(BookClothTokens t, AssignPanelState st) {
    final url = st.doc?.url ?? '';
    return _CorneredBox(
      cornerColor: null,
      decoration: BoxDecoration(
        color: t.accent.alphaPct(6),
        border: Border.all(color: t.accent.alphaPct(40)),
        borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const AppChip(label: '🌐 Internetquelle', variant: AppChipVariant.ok),
          const Spacer(),
          AppButton(
            small: true,
            tooltip: 'Link ändern',
            onPressed: () => _askLink(url),
            child: const Text('✎ Link'),
          ),
          const SizedBox(width: 6),
          AppButton(
            small: true,
            tooltip: 'Definition entfernen — wieder „keine Datei',
            onPressed: () => _docDel(st),
            child: const Text('↺ zurücksetzen'),
          ),
        ]),
        const SizedBox(height: 8),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () =>
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            child: Tooltip(
              message: 'Im neuen Tab öffnen',
              child: Text('$url ↗',
                  style:
                      AppTextStyles.mono.copyWith(fontSize: 12.5, color: t.accentInk)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Kein PDF — Zitat & Fundstelle unten im Beleg von Hand erfassen (aus der Seite kopieren).',
          style: AppTextStyles.small.copyWith(color: t.muted),
        ),
      ]),
    );
  }

  /// c) `🖼 Bild`.
  Widget _fileBlockImage(BookClothTokens t, AssignPanelState st) {
    return _CorneredBox(
      cornerColor: null,
      decoration: BoxDecoration(
        color: t.accent.alphaPct(6),
        border: Border.all(color: t.accent.alphaPct(40)),
        borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const AppChip(label: '🖼 Bild', variant: AppChipVariant.ok),
          const Spacer(),
          AppButton(
            small: true,
            onPressed: () async {
              final fs = await _pickFiles(type: FileType.image, multiple: false);
              if (fs.isNotEmpty) await _setImage(fs.first.$1, fs.first.$2);
            },
            child: const Text('✎ Bild ändern'),
          ),
          const SizedBox(width: 6),
          AppButton(
            small: true,
            tooltip: 'Definition entfernen',
            onPressed: () => _docDel(st),
            child: const Text('↺ zurücksetzen'),
          ),
        ]),
        const SizedBox(height: 9),
        if (st.hasImage)
          FutureBuilder(
            future: ref
                .read(fileStoreProvider.future)
                .then((f) => f.getImage(widget.srcId)),
            builder: (context, snap) => snap.data == null
                ? const SizedBox.shrink()
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(snap.data!.$1),
                  ),
          )
        else
          Text('Bild fehlt — neu wählen.',
              style: AppTextStyles.small.copyWith(color: t.muted)),
      ]),
    );
  }

  Future<void> _docDel(AssignPanelState st) async {
    if (st.doc?.isImage ?? false) {
      final files = await ref.read(fileStoreProvider.future);
      await files.removeImage(widget.srcId);
    }
    await ref.read(kvStoreProvider).clearSrcDoc(widget.srcId);
    _metaChanged();
  }

  void _askLink(String? current) {
    showUrlModal(
      context,
      title: '🌐 Internetquelle',
      hint: 'Link zur Online-Quelle (Website, Online-Artikel, Datensatz …). '
          'Öffnet im neuen Tab; Zitat & Fundstelle erfasst du unten im Beleg von Hand.',
      buttonLabel: 'Übernehmen',
      initial: current,
      onSubmit: (url) async {
        await ref
            .read(kvStoreProvider)
            .setSrcDoc(widget.srcId, SrcDocDef(kind: 'link', url: url));
        _metaChanged();
      },
    );
  }

  void _askExtraLink() {
    showUrlModal(
      context,
      title: '🌐 Website als Material',
      hint: 'Link zu Website, Online-Artikel, Datensatz … — landet in der '
          'Material-Liste dieser Quelle.',
      buttonLabel: 'Hinzufügen',
      onSubmit: (url) async {
        await ref.read(kvStoreProvider).addSrcExtra(
              widget.srcId,
              SrcExtra(
                kind: 'link',
                url: url,
                name: url.replaceFirst(RegExp(r'^https?://'), ''),
              ),
            );
        _refresh();
      },
    );
  }

  /// d) `▣ keine Datei`: Material-Switch + Tab-Inhalt + Ablage + Kandidat.
  Widget _fileBlockMissing(BookClothTokens t, AssignPanelState st) {
    final cand = st.candidates.isNotEmpty ? st.candidates[_candIdx] : null;
    return _CorneredBox(
      cornerColor: t.accent,
      decoration: BoxDecoration(
        color: t.surface2,
        border: Border.all(color: t.borderStrong, width: 1.5,
            style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _matSwitch(t, st),
        const SizedBox(height: 10),
        ..._matTabContent(t, st),
        if (widget.onCancel != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            AppButton(
              variant: AppButtonVariant.ghost,
              small: true,
              onPressed: widget.onCancel,
              child: const Text('↩ zurück'),
            ),
          ]),
        ],
        if (_matTab == 'pdf' && _ablageOpen && st.nAlt > 0) ...[
          const SizedBox(height: 10),
          _ablageBox(t, st),
        ],
        if (_matTab == 'pdf' && cand != null) ...[
          const SizedBox(height: 14),
          _candidateBox(t, st, cand),
        ],
      ]),
    );
  }

  /// `.mat-switch`: 5 Tabs + Status rechts.
  Widget _matSwitch(BookClothTokens t, AssignPanelState st) {
    Widget tab(String key, String label, String tip) {
      final on = _matTab == key;
      return Tooltip(
        message: tip,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => setState(() => _matTab = key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: on ? t.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                boxShadow: on ? t.shadow1 : null,
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontFamilyFallback: AppFonts.fallback,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  height: 1,
                  color: on ? t.ink : t.ink2,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final state = st.hasText
        ? '📝 Text hinterlegt'
        : st.extras.isNotEmpty
            ? 'Material (${st.extras.length})'
            : 'keine Datei';

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.bgDeep,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(children: [
        Expanded(
          child: Wrap(spacing: 3, runSpacing: 3, children: [
            tab('pdf', '📄 PDF',
                'PDF-Datei(en) — das Haupt-PDF bekommt die volle Markier-Suite'),
            tab('web', '🌐 Website', 'Website/Link als Quelle — kein PDF nötig'),
            tab('img', '🖼 Bild', 'Bild als Quelle (Scan, Abbildung, Foto)'),
            tab('txt', '📝 Text',
                'Quellentext hinterlegen — markierbare Text-Ansicht (Rechtstexte, Online-Artikel)'),
            tab('tex', 'Σ LaTeX',
                'LaTeX-Material — kann Views übergeordnet verknüpfen (View-Manager ✎)'),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 6, left: 6),
          child: Text(
            state,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontFamilyFallback: AppFonts.fallback,
              fontWeight: FontWeight.w600,
              fontSize: 10.5,
              height: 1,
              color: t.muted,
            ),
          ),
        ),
      ]),
    );
  }

  List<Widget> _matTabContent(BookClothTokens t, AssignPanelState st) {
    switch (_matTab) {
      case 'web':
        return [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _webCtrl,
                style: AppTextStyles.form.copyWith(color: t.ink),
                decoration: const InputDecoration(
                    hintText: 'https://… (Website, Online-Artikel, Datensatz)'),
                onSubmitted: (_) => _webGo(),
              ),
            ),
            const SizedBox(width: 7),
            AppButton(
              variant: AppButtonVariant.primary,
              small: true,
              onPressed: _webGo,
              child: const Text('Übernehmen'),
            ),
          ]),
          const SizedBox(height: 7),
          Text(
            'Öffnet im neuen Tab; Zitat & Fundstelle erfasst du unten im Beleg von Hand.',
            style: AppTextStyles.small.copyWith(color: t.muted),
          ),
        ];
      case 'img':
        return [
          _AdOptTile(
            icon: '🖼',
            title: 'Bild wählen',
            sub: 'Abbildung, Scan — mehrere möglich',
            tooltip:
                'Bild als Quell-Material (Abbildung, Scan, Foto) — mehrere möglich',
            onTap: () => _onImgPick(st),
          ),
          const SizedBox(height: 7),
          Text(
            'Das erste Bild wird als Quell-Ansicht hinterlegt, weitere landen im Material.',
            style: AppTextStyles.small.copyWith(color: t.muted),
          ),
        ];
      case 'txt':
        return [
          TextField(
            controller: _txtCtrl,
            minLines: 5,
            maxLines: 12,
            style: AppTextStyles.mono.copyWith(fontSize: 12.5, color: t.ink),
            decoration: const InputDecoration(
                hintText:
                    'Quellentext hier einfügen (Rechtstext, Online-Artikel, Kapitel …)'),
          ),
          const SizedBox(height: 7),
          Row(children: [
            AppButton(
              small: true,
              onPressed: () async {
                final text = await _pickTextFile();
                if (text == null) return;
                await ref.read(kvStoreProvider).setSrcText(widget.srcId, text);
                _txtPrimed = false;
                _metaChanged();
              },
              child: const Text('⭱ .txt/.md laden'),
            ),
            const SizedBox(width: 7),
            AppButton(
              variant: AppButtonVariant.primary,
              small: true,
              onPressed: () async {
                await ref
                    .read(kvStoreProvider)
                    .setSrcText(widget.srcId, _txtCtrl.text);
                _metaChanged();
              },
              child: const Text('Übernehmen'),
            ),
          ]),
          const SizedBox(height: 7),
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Wird als '),
              const TextSpan(
                  text: 'markierbare Text-Ansicht',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const TextSpan(
                  text: ' dieser Quelle hinterlegt — ideal, wenn es kein PDF gibt.'),
            ]),
            style: AppTextStyles.small.copyWith(color: t.muted),
          ),
        ];
      case 'tex':
        return [
          Row(children: [
            SizedBox(
              width: 190,
              child: TextField(
                controller: _texNameCtrl,
                style: AppTextStyles.form.copyWith(color: t.ink),
                decoration:
                    const InputDecoration(hintText: 'Name (z. B. „paper.tex“)'),
              ),
            ),
            const SizedBox(width: 7),
            AppButton(
              small: true,
              onPressed: () async {
                final picked = await _pickTexFile();
                if (picked == null) return;
                _addTexMat(picked.$1, picked.$2, nameFromField: true);
              },
              child: const Text('⭱ .tex laden'),
            ),
          ]),
          const SizedBox(height: 7),
          TextField(
            controller: _texCtrl,
            minLines: 5,
            maxLines: 12,
            style: AppTextStyles.mono.copyWith(fontSize: 12.5, color: t.ink),
            decoration:
                const InputDecoration(hintText: 'LaTeX-Quelltext hier einfügen …'),
          ),
          const SizedBox(height: 7),
          Row(children: [
            AppButton(
              variant: AppButtonVariant.primary,
              small: true,
              onPressed: () => _addTexMat(_texNameCtrl.text, _texCtrl.text),
              child: const Text('Als Material hinzufügen'),
            ),
          ]),
          const SizedBox(height: 7),
          Text.rich(
            TextSpan(children: [
              const TextSpan(
                  text: 'Σ LaTeX kann Views übergeordnet verknüpfen: ',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const TextSpan(
                  text: 'im View-Manager (✎ in der Views-Leiste) eine View mit '
                      'dieser Quelle verknüpfen — die Generierung nutzt dieses '
                      'Material dann als übergeordnete Textbasis.'),
            ]),
            style: AppTextStyles.small.copyWith(color: t.muted),
          ),
        ];
      default: // 'pdf'
        return [
          // ⭳ Download-Zeile: Button + kleiner ↗-Link + Status.
          Wrap(spacing: 7, runSpacing: 7, crossAxisAlignment: WrapCrossAlignment.center, children: [
            AppButton(
              small: true,
              tooltip: st.dlLink != null
                  ? 'Download-Engine: Datei über den gefundenen Link laden — '
                      'bei Erfolg sofort zugeordnet (jederzeit änderbar)'
                  : 'nicht verfügbar — kein öffentlicher Datei-Link bekannt',
              onPressed:
                  st.dlLink != null && !_dlBusy ? () => unawaited(_tryDownload()) : null,
              child: const Text('⭳ Download'),
            ),
            if (st.dlLink != null)
              AppButton(
                variant: AppButtonVariant.ghost,
                small: true,
                tooltip: 'Gefundener Download-Link — von Hand laden, falls der '
                    'automatische Download blockiert ist: ${st.dlLink}',
                onPressed: () => launchUrl(Uri.parse(st.dlLink!),
                    mode: LaunchMode.externalApplication),
                child: const Text('↗',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              )
            else
              const Opacity(
                opacity: .4,
                child: AppButton(
                  variant: AppButtonVariant.ghost,
                  small: true,
                  tooltip: 'nicht verfügbar — kein Datei-Link gefunden',
                  child: Text('↗', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            _dlStatusWidget(t, st),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            AppButton(
              variant: AppButtonVariant.primary,
              small: true,
              tooltip: 'PDF-Datei(en) lokal wählen — die erste wird das Haupt-PDF '
                  '(markierbar), weitere landen als zusätzliches Material',
              onPressed: () => unawaited(_pickMainPdf()),
              child: const Text('⭱ Datei lokal wählen'),
            ),
            AppButton(
              variant: AppButtonVariant.primary,
              small: true,
              tooltip: st.nAlt > 0
                  ? 'Bereits importierte Dateien durchsehen und zuordnen'
                  : 'nicht verfügbar — Dateiverzeichnis ist leer',
              onPressed: st.nAlt > 0
                  ? () => setState(() => _ablageOpen = !_ablageOpen)
                  : null,
              child: Text(
                  '📥 Aus Dateiverzeichnis${st.nAlt > 0 ? ' (${st.nAlt})' : ''}'),
            ),
          ]),
        ];
    }
  }

  void _webGo() {
    var v = _webCtrl.text.trim();
    if (v.isEmpty) return;
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(v)) {
      v = 'https://$v';
    }
    unawaited(ref
        .read(kvStoreProvider)
        .setSrcDoc(widget.srcId, SrcDocDef(kind: 'link', url: v))
        .then((_) => _metaChanged()));
  }

  void _addTexMat(String name, String text, {bool nameFromField = false}) {
    if (text.trim().isEmpty) return;
    final effective = nameFromField && _texNameCtrl.text.trim().isNotEmpty
        ? _texNameCtrl.text.trim()
        : name.trim();
    unawaited(ref
        .read(kvStoreProvider)
        .addSrcExtra(
          widget.srcId,
          SrcExtra(
            kind: 'tex',
            name: effective.isNotEmpty ? effective : 'material.tex',
            text: text,
          ),
        )
        .then((_) => _refresh()));
  }

  Widget _dlStatusWidget(BookClothTokens t, AssignPanelState st) {
    if (_dlBusy) {
      return Text('⏳ lädt …', style: AppTextStyles.small.copyWith(color: t.muted));
    }
    final dl = st.dlStatus;
    if (dl != null) {
      return AppChip(
        label: '${dl.ok ? '✓' : '✗'} ${dl.note}',
        variant: dl.ok ? AppChipVariant.ok : AppChipVariant.warn,
        mini: true,
      );
    }
    final problem = st.fileSearch?.problem;
    if (problem != null && problem.isNotEmpty) {
      return SrcTagChip(SrcTag(
          cat: 'problem',
          label: '⚠ keine zugängliche Datei gefunden — $problem'));
    }
    if (st.dlLink == null) {
      return Text('nicht verfügbar — kein Datei-Link gefunden',
          style: AppTextStyles.small.copyWith(fontSize: 12.5, color: t.muted));
    }
    return Text('noch nicht versucht',
        style: AppTextStyles.small.copyWith(fontSize: 12.5, color: t.muted));
  }

  /// `.ai-ablage`: Auswahl aus Inbox + bereits zugewiesenen Dateien.
  Widget _ablageBox(BookClothTokens t, AssignPanelState st) {
    // Auswahl validieren — nach einer Übernahme kann der Eintrag weg sein.
    final valid = {
      for (final n in st.inbox) 'inbox:$n',
      for (final id in st.assignedOthers) 'src:$id',
    };
    final sel = valid.contains(_altSel) ? _altSel : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Eyebrow('📥 Aus Dateiverzeichnis wählen'),
        const SizedBox(height: 6),
        Wrap(spacing: 7, runSpacing: 7, crossAxisAlignment: WrapCrossAlignment.center, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: DropdownButton<String>(
              value: sel,
              hint: Text('— Datei wählen —',
                  style: AppTextStyles.form.copyWith(color: t.muted)),
              isDense: true,
              items: [
                for (final n in st.inbox)
                  DropdownMenuItem(
                    value: 'inbox:$n',
                    child: Text('📥 $n', overflow: TextOverflow.ellipsis),
                  ),
                if (st.assignedOthers.isNotEmpty)
                  const DropdownMenuItem(
                    value: 'hdr:assigned',
                    enabled: false,
                    child: Text('— bereits zugewiesen (Kopie verwenden) —'),
                  ),
                for (final id in st.assignedOthers)
                  DropdownMenuItem(
                    value: 'src:$id',
                    child: Text('$id.pdf', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _altSel = v),
            ),
          ),
          AppButton(
            variant: AppButtonVariant.primary,
            small: true,
            onPressed: sel == null
                ? null
                : () {
                    _altSel = null;
                    unawaited(_takeAlt(sel));
                  },
            child: const Text('übernehmen'),
          ),
        ]),
      ]),
    );
  }

  /// `.ai-candidate`: unbestätigte Vermutung mit viewOnly-Vorschau.
  Widget _candidateBox(BookClothTokens t, AssignPanelState st, AssignCandidate cand) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.warn),
        borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          const AppChip(
              label: 'Vermutlich passende Datei — unbestätigt, nicht übernommen',
              variant: AppChipVariant.warn),
          Text(cand.name,
              style: AppTextStyles.mono.copyWith(fontSize: 12, color: t.ink)),
          AppChip(
              label: cand.why,
              variant: cand.sure ? AppChipVariant.ok : AppChipVariant.ki,
              mini: true),
        ]),
        const SizedBox(height: 8),
        _CandidatePreview(srcId: widget.srcId, name: cand.name),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          AppButton(
            variant: AppButtonVariant.primary,
            small: true,
            onPressed: () => unawaited(_confirmCandidate(cand)),
            child: const Text('✓ Übernehmen'),
          ),
          if (st.candidates.length > 1)
            AppButton(
              small: true,
              onPressed: () => setState(() => _candIdx++),
              child: Text(
                  'andere Vermutung (${_candIdx + 1}/${st.candidates.length}) ▸'),
            ),
          AppButton(
            small: true,
            tooltip: 'Diese Datei nicht mehr für diese Quelle vorschlagen',
            onPressed: () async {
              await ref.read(kvStoreProvider).dismissCandidate(widget.srcId, cand.name);
              setState(() => _candIdx = 0);
              _refresh();
            },
            child: const Text('✗ passt nicht'),
          ),
        ]),
      ]),
    );
  }

  // ---------------------------------------------------------------------
  // Material-Liste
  // ---------------------------------------------------------------------

  List<Widget> _matSection(BookClothTokens t, AssignPanelState st) {
    final hasMain = st.hasFile || st.doc != null;
    final rows = <Widget>[
      for (var i = 0; i < st.extras.length; i++) _matRow(t, i, st.extras[i]),
    ];
    if (!hasMain && rows.isEmpty) return const [];

    return [
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: t.surface2,
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Eyebrow.bar(hasMain
                ? 'Material dieser Quelle — flexibel erweitern'
                : 'Weiteres Material'),
          ),
          for (final r in rows) Padding(padding: const EdgeInsets.only(bottom: 4), child: r),
          if (hasMain) ...[
            const SizedBox(height: 2),
            _matAddRow(t, st),
          ],
        ]),
      ),
    ];
  }

  /// `.mat-row`: Icon · Name · ↗/👁 · ✕.
  Widget _matRow(BookClothTokens t, int index, SrcExtra x) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 5, 6, 5),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Text(x.icon, style: const TextStyle(fontSize: 13, height: 1)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            x.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontFamilyFallback: AppFonts.fallback,
              fontWeight: FontWeight.w500,
              fontSize: 12.5,
              height: 1.3,
              color: t.ink,
            ),
          ),
        ),
        _IconBtn(
          label: x.isTex ? '👁' : '↗',
          tooltip: x.isLink
              ? 'Im neuen Tab öffnen'
              : x.isTex
                  ? 'LaTeX ansehen/kopieren'
                  : 'Öffnen (neuer Tab)',
          onTap: () {
            if (x.isLink && x.url != null) {
              launchUrl(Uri.parse(x.url!), mode: LaunchMode.externalApplication);
            } else {
              unawaited(_openExtra(x));
            }
          },
        ),
        const SizedBox(width: 4),
        _IconBtn(
          label: '✕',
          tooltip: 'Aus dem Material entfernen',
          onTap: () => unawaited(_deleteExtra(index, x)),
        ),
      ]),
    );
  }

  /// `.mat-addrow`: 5 Hinzufüge-Kacheln (ad-opt sm).
  Widget _matAddRow(BookClothTokens t, AssignPanelState st) {
    return Wrap(spacing: 7, runSpacing: 7, children: [
      _AdOptTile(
        small: true,
        icon: '📄',
        title: 'PDF',
        sub: 'mehrere möglich',
        tooltip: 'Weitere PDF-Datei(en) hinzufügen',
        onTap: () => _onMatPdfPick(st),
      ),
      _AdOptTile(
        small: true,
        icon: '🌐',
        title: 'Website',
        sub: 'Link',
        tooltip: 'Website/Link hinzufügen',
        onTap: () {
          // Ohne Haupt-Material definiert 🌐 die Quelle, sonst Material
          // (pdfengine.js:674).
          if (!st.hasFile && st.doc == null) {
            _askLink(null);
          } else {
            _askExtraLink();
          }
        },
      ),
      _AdOptTile(
        small: true,
        icon: '🖼',
        title: 'Bild',
        sub: 'Scan, Abbildung',
        tooltip: 'Bild hinzufügen',
        onTap: () => _onImgPick(st),
      ),
      _AdOptTile(
        small: true,
        icon: '📝',
        title: 'Text',
        sub: 'markierbar${st.hasText ? ' · ✓' : ''}',
        tooltip:
            'Quellentext hinterlegen/ändern — markierbare Text-Ansicht',
        onTap: () => showSrcTextModal(
          context,
          initial: st.srcText,
          pickTextFile: _pickTextFile,
          onSubmit: (text) async {
            await ref.read(kvStoreProvider).setSrcText(widget.srcId, text);
            _txtPrimed = false;
            _metaChanged();
          },
        ),
      ),
      _AdOptTile(
        small: true,
        icon: 'Σ',
        title: 'LaTeX',
        sub: 'für Views',
        tooltip: 'LaTeX-Material — kann Views übergeordnet verknüpfen (View-Manager ✎)',
        onTap: () => showTexMaterialModal(
          context,
          pickTexFile: _pickTexFile,
          onSubmit: (name, text) async {
            await ref.read(kvStoreProvider).addSrcExtra(
                widget.srcId, SrcExtra(kind: 'tex', name: name, text: text));
            _refresh();
          },
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Bausteine
// ---------------------------------------------------------------------------

/// Kasten mit dem 7×7-Eck-Quadrat bei (−1.5,−1.5) (sp-file::before).
class _CorneredBox extends StatelessWidget {
  const _CorneredBox({
    required this.child,
    required this.decoration,
    required this.padding,
    this.cornerColor,
  });

  final Widget child;
  final BoxDecoration decoration;
  final EdgeInsets padding;
  final Color? cornerColor;

  @override
  Widget build(BuildContext context) {
    final box = Container(decoration: decoration, padding: padding, child: child);
    if (cornerColor == null) return box;
    return Stack(clipBehavior: Clip.none, children: [
      box,
      Positioned(
        top: -1.5,
        left: -1.5,
        child: Container(width: 7, height: 7, color: cornerColor),
      ),
    ]);
  }
}

/// `.ad-opt[.sm]`: Hinzufüge-Kachel mit Icon + Titel + small-Zeile.
class _AdOptTile extends StatefulWidget {
  const _AdOptTile({
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
    this.tooltip,
    this.small = false,
  });

  final String icon;
  final String title;
  final String sub;
  final VoidCallback onTap;
  final String? tooltip;
  final bool small;

  @override
  State<_AdOptTile> createState() => _AdOptTileState();
}

class _AdOptTileState extends State<_AdOptTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final tile = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: widget.small
              ? const EdgeInsets.symmetric(horizontal: 9, vertical: 6)
              : const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: _hover ? t.accentSoft : t.surface,
            border: Border.all(color: _hover ? t.accent : t.borderStrong),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(widget.icon,
                style: TextStyle(fontSize: widget.small ? 14 : 16, height: 1)),
            SizedBox(width: widget.small ? 7 : 9),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontFamilyFallback: AppFonts.fallback,
                    fontWeight: FontWeight.w600,
                    fontSize: widget.small ? 12 : 12.5,
                    height: 1.25,
                    color: t.ink,
                  ),
                ),
                Text(
                  widget.sub,
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontFamilyFallback: AppFonts.fallback,
                    fontSize: widget.small ? 10.5 : 11,
                    height: 1.3,
                    color: t.muted,
                  ),
                ),
              ],
            ),
          ]),
        ),
      ),
    );
    if (widget.tooltip == null) return tile;
    return Tooltip(message: widget.tooltip!, child: tile);
  }
}

/// `.sf-iconbtn` (26×26) in der Material-Zeile.
class _IconBtn extends StatefulWidget {
  const _IconBtn({required this.label, required this.onTap, this.tooltip});

  final String label;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final btn = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hover ? t.surface3 : Colors.transparent,
            border: Border.all(color: _hover ? t.accent : t.border),
            borderRadius: BorderRadius.circular(BookClothTokens.radiusXs),
          ),
          child: Text(widget.label,
              style: TextStyle(fontSize: 12, height: 1, color: _hover ? t.ink : t.ink2)),
        ),
      ),
    );
    if (widget.tooltip == null) return btn;
    return Tooltip(message: widget.tooltip!, child: btn);
  }
}

/// Unbestätigte Kandidaten-Vorschau: Banner + gestrichelte warn-Umrandung +
/// eingebetteter compact/viewOnly-Viewer (Scroll-Deckel 340/420 px je nach
/// Containerbreite — app.css:1284-1288).
class _CandidatePreview extends ConsumerStatefulWidget {
  const _CandidatePreview({required this.srcId, required this.name});

  final String srcId;
  final String name;

  @override
  ConsumerState<_CandidatePreview> createState() => _CandidatePreviewState();
}

class _CandidatePreviewState extends ConsumerState<_CandidatePreview> {
  late Future<Uint8List?> _future = _load();

  Future<Uint8List?> _load() => ref
      .read(fileStoreProvider.future)
      .then((f) => f.getInboxData(widget.name));

  @override
  void didUpdateWidget(_CandidatePreview old) {
    super.didUpdateWidget(old);
    if (old.name != widget.name) _future = _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snap) {
        Widget inner;
        if (snap.connectionState != ConnectionState.done) {
          inner = Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text('Lade Vorschau …',
                  style: AppTextStyles.small.copyWith(color: t.muted)),
            ),
          );
        } else if (snap.data == null) {
          inner = Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text(
                'Vorschau nicht möglich — Datei ggf. über „Alternativen“ übernehmen.',
                style: AppTextStyles.small.copyWith(color: t.muted),
              ),
            ),
          );
        } else {
          inner = LayoutBuilder(
            builder: (context, c) => PdfEngineView(
              srcId: widget.srcId,
              data: snap.data,
              compact: true,
              viewOnly: true,
              maxScrollHeight: c.maxWidth >= 560 ? 420 : 340,
            ),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: t.surface2,
            borderRadius: BorderRadius.circular(BookClothTokens.radiusXs),
            border: Border.all(color: t.warn, width: 2, style: BorderStyle.solid),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
              color: t.warnSoft,
              child: Text(
                'VORSCHAU — UNBESTÄTIGT · NICHT ÜBERNOMMEN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontFamilyFallback: AppFonts.fallback,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  height: 1,
                  letterSpacing: .08 * 10,
                  color: t.warn,
                ),
              ),
            ),
            inner,
          ]),
        );
      },
    );
  }
}
