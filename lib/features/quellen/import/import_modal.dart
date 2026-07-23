/// ⭱ Dateien importieren (PDF / ZIP) — Port von `importFilesModal`
/// (views_quellen.js:718-859): Mehrfachauswahl (wiederholbar), ZIPs werden
/// entpackt (Fehler je Eintrag als ✗-Zeile), Matching-Kaskade je Datei,
/// „kein stiller Verlust" (Unbestätigtes wandert in die Ablage).
///
/// `inbox: true` startet mit den bereits importierten, noch nicht
/// zugewiesenen Dateien aus der Ablage (Zuweisen-Dialog).
library;

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/modal.dart';
import '../../../data/bundles/indexes.dart';
import '../../../data/export/dateiauftrag.dart';
import '../../../data/models/models.dart';
import '../../../data/repos/file_store.dart';
import 'import_logic.dart';

/// Import-Modal öffnen. [onDone] läuft nach jeder Übernahme (Gastseite
/// leert den PDF-Status-Cache und zeichnet neu).
void showImportFilesModal(BuildContext context, {VoidCallback? onDone, bool inbox = false}) {
  showAppModal(
    context,
    title: const Text('⭱ Dateien importieren (PDF / ZIP)'),
    body: _ImportBody(onDone: onDone, preloadInbox: inbox),
  );
}

class _ImportBody extends ConsumerStatefulWidget {
  const _ImportBody({this.onDone, this.preloadInbox = false});

  final VoidCallback? onDone;
  final bool preloadInbox;

  @override
  ConsumerState<_ImportBody> createState() => _ImportBodyState();
}

class _ImportBodyState extends ConsumerState<_ImportBody> {
  final List<ImportItem> _items = [];
  bool _showAll = false;
  String _msg = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.preloadInbox) unawaited(_loadInbox());
  }

  /// Ablage-Dateien als vorbefüllte Items laden (js:852-857).
  Future<void> _loadInbox() async {
    final files = await ref.read(fileStoreProvider.future);
    final srcById = ref.read(srcByIdProvider);
    final sources = ref.read(activeRuntimeProvider)?.sources ?? const <Source>[];
    for (final name in files.listInbox()) {
      final data = await files.getInboxData(name);
      if (data == null) continue;
      _items.add(buildImportItem(name, data,
          srcById: srcById, sources: sources, fromInbox: true));
    }
    if (mounted) setState(() {});
  }

  /// Dateiauswahl — auch mehrfach; ZIPs via [readZip] (js:813-830).
  Future<void> _pick() async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'zip'],
      allowMultiple: true,
      withData: true,
    );
    if (res == null) return;
    final srcById = ref.read(srcByIdProvider);
    final sources = ref.read(activeRuntimeProvider)?.sources ?? const <Source>[];
    for (final f in res.files) {
      final data = f.bytes;
      if (data == null) continue;
      if (RegExp(r'\.zip$', caseSensitive: false).hasMatch(f.name)) {
        try {
          final entries = readZip(data);
          for (final en in entries) {
            if (en.error != null) {
              _items.add(ImportItem.error(en.name, en.error!));
            } else {
              _items.add(buildImportItem(en.name, en.data,
                  srcById: srcById, sources: sources));
            }
          }
          if (entries.isEmpty) _items.add(ImportItem.error(f.name, 'ZIP ist leer'));
        } on FormatException catch (e) {
          _items.add(ImportItem.error(f.name, e.message));
        }
      } else {
        _items.add(buildImportItem(f.name, data, srcById: srcById, sources: sources));
      }
    }
    if (mounted) setState(() {});
  }

  /// Übernahme (js:832-850): checked+sel → zuordnen, sonst → Ablage.
  Future<void> _go() async {
    setState(() => _busy = true);
    final files = await ref.read(fileStoreProvider.future);
    var assigned = 0, toInbox = 0;
    for (final it in _items) {
      if (it.err != null) continue;
      final sel = it.sel;
      if (it.checked && sel != null) {
        if (it.fromInbox) {
          await files.assignInbox(it.name, sel);
        } else if (it.data != null) {
          await files.putData(sel, it.data!);
        }
        files.pdfStatusCache[sel] = true;
        assigned++;
      } else if (!it.fromInbox && it.data != null) {
        await files.addInbox(it.name, it.data!);
        toInbox++;
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _msg = '✓ $assigned zugeordnet'
          '${toInbox > 0 ? ' · $toInbox in der Ablage (Zuweisen-Dialog)' : ''}';
      // Fehlerzeilen bleiben in der Liste stehen (js:847).
      _items.removeWhere((it) => it.err == null);
    });
    widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final counts = goCounts(_items);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'PDFs oder ganze ZIP-Archive laden — auch mehrfach. '),
            const TextSpan(
                text: 'Automatisch zugeordnet',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const TextSpan(
                text: ' werden nur eindeutig erkennbare Dateien (aus dem '
                    '⌗ Datei-Auftrag bzw. exakt nach Quellen-id benannt) — der '
                    'freie Dateiname selbst ist kein Erkennungsmerkmal. Alles '
                    'andere ist ein unbestätigter Vorschlag bzw. bleibt im '
                    'Dateiverzeichnis und ist über „📥 Aus Dateiverzeichnis“ '
                    'jeder Quelle zuweisbar.'),
          ]),
          style: AppTextStyles.small.copyWith(color: t.muted),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          AppButton(
            variant: AppButtonVariant.primary,
            small: true,
            onPressed: () => unawaited(_pick()),
            child: const Text('Dateien wählen'),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => setState(() => _showAll = !_showAll),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Checkbox(
                    value: _showAll,
                    onChanged: (v) => setState(() => _showAll = v ?? false),
                  ),
                ),
                const SizedBox(width: 6),
                Text('alle Quellen in der Auswahl zeigen (auch schon belegte)',
                    style: AppTextStyles.small.copyWith(color: t.ink2)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: _items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text('Noch keine Dateien gewählt.',
                      style: AppTextStyles.small.copyWith(color: t.muted)),
                )
              : SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    for (var i = 0; i < _items.length; i++) _row(t, i, _items[i]),
                  ]),
                ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          AppButton(
            variant: AppButtonVariant.primary,
            small: true,
            onPressed: (counts.n > 0 || counts.rest > 0) && !_busy
                ? () => unawaited(_go())
                : null,
            child: Text(goButtonLabel(counts.n, counts.rest)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_msg, style: AppTextStyles.small.copyWith(color: t.muted)),
          ),
        ]),
      ],
    );
  }

  /// Eine `.qs-row[.rich]`-Zeile: Checkbox · Name · MB · Status-Chip · Select.
  Widget _row(BookClothTokens t, int index, ImportItem it) {
    if (it.err != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('✗', style: AppTextStyles.small.copyWith(color: t.bad)),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: it.name,
                    style: AppTextStyles.mono.copyWith(fontSize: 12, color: t.ink)),
                TextSpan(text: ' ${it.err}', style: TextStyle(color: t.bad)),
              ]),
              style: AppTextStyles.small,
            ),
          ),
        ]),
      );
    }

    final chip = importChipFor(it);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: it.checked,
            onChanged: (v) => setState(() => it.checked = v ?? false),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 3, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(it.name,
                  style: AppTextStyles.mono.copyWith(fontSize: 12, color: t.ink)),
              Text('${(it.size / 1024 / 1024).toStringAsFixed(1)} MB',
                  style: AppTextStyles.small.copyWith(color: t.muted)),
              Tooltip(
                message: chip.tip,
                child: AppChip(
                  label: chip.label,
                  mini: true,
                  variant: switch (chip.cat) {
                    'ok' => AppChipVariant.ok,
                    'ki' => AppChipVariant.ki,
                    _ => AppChipVariant.warn,
                  },
                ),
              ),
            ]),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _srcSelect(t, it),
            ),
          ]),
        ),
      ]),
    );
  }

  /// Quellen-Select (js:739-745): Titel-sortiert; ohne `showAll` nur Quellen
  /// ohne Datei (plus die bereits gewählte).
  Widget _srcSelect(BookClothTokens t, ImportItem it) {
    final files = ref.watch(fileStoreProvider).value;
    final sources = [...(ref.watch(activeRuntimeProvider)?.sources ?? const <Source>[])]
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    final srcById = ref.watch(srcByIdProvider);
    bool has(String id) => files?.has(id) ?? false;

    final visible = [
      for (final s in sources)
        if (_showAll || !has(s.id) || s.id == it.sel) s,
    ];
    // Auswahl absichern — sonst wirft der DropdownButton bei fehlendem Wert.
    final value = visible.any((s) => s.id == it.sel) ? it.sel : null;

    return DropdownButton<String?>(
      value: value,
      isExpanded: true,
      isDense: true,
      hint: Text('— Quelle wählen —',
          style: AppTextStyles.form.copyWith(color: t.muted)),
      style: AppTextStyles.form.copyWith(fontSize: 13, color: t.ink),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('— Quelle wählen —')),
        for (final s in visible)
          DropdownMenuItem<String?>(
            value: s.id,
            child: Text(
              '${computeSrcShort(s.id, srcById[s.id])} — '
              '${s.title.length > 48 ? s.title.substring(0, 48) : s.title}'
              '${has(s.id) ? ' (Datei vorhanden)' : ''}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (v) => setState(() {
        it.sel = v;
        it.checked = v != null; // Select-Änderung setzt das Häkchen (js:773-777)
      }),
    );
  }
}
