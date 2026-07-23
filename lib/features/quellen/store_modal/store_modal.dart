/// 🗄 Quellen- & Dateispeicher — das Topbar-Modal (Port von `storeModal`,
/// views_quellen.js:207-288): EIN zentraler Ort für den gesamten Datei-/
/// Quellen-Bestand — alle Quellen mit Datei-Status, die nicht zugeordneten
/// Dateien (Ablage) samt „→ zuweisen" UND die Rückrichtung „＋ Quelle aus
/// Datei erstellen". Von überall erreichbar (Topbar 🗄 Speicher).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/modal.dart';
import '../../../data/bundles/indexes.dart';
import '../../../data/models/models.dart';
import '../../../data/repos/file_store.dart';
import '../import/import_modal.dart';
import '../import/new_source_modal.dart';
import '../quellen.dart' show registerQuellenHooks;
import '../state/file_store_tick.dart';
import '../util/dialogs.dart';

/// Speicher-Modal öffnen (Topbar-Anker `#storeBtn`, app.js:141).
void showStoreModal(BuildContext context) {
  // Der Speicher ist von überall erreichbar — auch hier die Quell-Karten-
  // Andockstellen sicherstellen (idempotent).
  registerQuellenHooks();
  showAppModal(
    context,
    title: const Text('🗄 Quellen- & Dateispeicher'),
    body: const _StoreBody(),
  );
}

class _StoreBody extends ConsumerWidget {
  const _StoreBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    ref.watch(fileStoreTickProvider); // Store-Änderung → neu zeichnen (js:286)
    final files = ref.watch(fileStoreProvider).value;
    final sources = ref.watch(activeRuntimeProvider)?.sources ?? const <Source>[];
    final srcById = ref.watch(srcByIdProvider);

    final inbox = files?.listInbox() ?? const <String>[];
    final inStore = [
      for (final s in sources)
        if (files?.has(s.id) ?? false) s,
    ];

    String short(String id) => computeSrcShort(id, srcById[id]);

    // Quellen: mit Datei zuerst, dann Kurzname (js:254).
    final sorted = [...sources]..sort((a, b) {
        final ha = (files?.has(a.id) ?? false) ? 1 : 0;
        final hb = (files?.has(b.id) ?? false) ? 1 : 0;
        if (ha != hb) return hb - ha;
        return short(a.id).toLowerCase().compareTo(short(b.id).toLowerCase());
      });

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
        'Der gesamte Datei- und Quellenbestand an einem Ort — von überall '
        'erreichbar. Dateien werden lokal im Browser gehalten '
        '(${files?.count() ?? 0} im Speicher · ${inbox.length} unzugeordnet).',
        style: AppTextStyles.small.copyWith(color: t.muted),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
        child: Row(children: [
          AppButton(
            variant: AppButtonVariant.primary,
            small: true,
            onPressed: () => showImportFilesModal(
              context,
              inbox: true,
              onDone: () =>
                  ref.read(fileStoreProvider).value?.resetStatusCache(),
            ),
            child: const Text('＋ Dateien laden'),
          ),
          const SizedBox(width: 6),
          AppButton(
            small: true,
            onPressed: () => showNewSourceModal(
              context,
              onCreated: (id) => context.go(Routes.quellenPath(id)),
            ),
            child: const Text('＋ Neue Quelle'),
          ),
          const Spacer(),
          AppButton(
            variant: AppButtonVariant.ghost,
            small: true,
            tooltip: 'Alle im Browser gespeicherten PDFs + Ablage löschen '
                '(alle Arbeiten)',
            onPressed: () => unawaited(_clearAll(context, ref)),
            child: const Text('🗑 Speicher leeren'),
          ),
        ]),
      ),

      // ---- Ablage ----
      Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Eyebrow(
            'Nicht zugeordnete Dateien${inbox.isNotEmpty ? ' · ${inbox.length}' : ''}'),
      ),
      if (inbox.isEmpty)
        Text(
          'Keine unzugeordneten Dateien. Über „＋ Dateien laden" PDFs in den '
          'Speicher legen — passende werden automatisch der richtigen Quelle '
          'zugeordnet, der Rest erscheint hier.',
          style: AppTextStyles.small.copyWith(color: t.muted),
        )
      else
        for (final name in inbox)
          _InboxRow(name: name, sources: sources, srcById: srcById),

      // ---- Quellen ----
      Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Eyebrow(
            'Quellen${inStore.isNotEmpty ? ' · ${inStore.length}/${sources.length} mit Datei' : ''}'),
      ),
      ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .4),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final s in sorted)
              _SrcRow(
                source: s,
                short: short(s.id),
                hasFile: files?.has(s.id) ?? false,
              ),
          ]),
        ),
      ),
    ]);
  }

  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final files = await ref.read(fileStoreProvider.future);
    final n = files.count() + files.listInbox().length;
    if (n == 0 || !context.mounted) return;
    final ok = await showAppConfirm(
      context,
      'Dateispeicher wirklich leeren?\n\n$n Datei(en) inkl. Ablage werden für '
      'ALLE Arbeiten gelöscht. Repo-Dateien (sources/…) bleiben.',
    );
    if (!ok) return;
    await files.clearAll();
  }
}

/// Eine Ablage-Zeile `.st-file`: Name · Select · → zuweisen ·
/// ＋ Quelle aus Datei · 🗑.
class _InboxRow extends ConsumerStatefulWidget {
  const _InboxRow({
    required this.name,
    required this.sources,
    required this.srcById,
  });

  final String name;
  final List<Source> sources;
  final Map<String, Source> srcById;

  @override
  ConsumerState<_InboxRow> createState() => _InboxRowState();
}

class _InboxRowState extends ConsumerState<_InboxRow> {
  String? _sel;
  bool _selPrimed = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final name = widget.name;

    // Sicherer Treffer belegt das Select vor (js:220-226).
    final m = matchFilename(name, widget.sources);
    if (!_selPrimed) {
      _selPrimed = true;
      if (m != null && m.sure) _sel = m.id;
    }
    String short(String id) => computeSrcShort(id, widget.srcById[id]);
    final options = [...widget.sources]..sort(
        (a, b) => short(a.id).toLowerCase().compareTo(short(b.id).toLowerCase()));
    final selValid = options.any((s) => s.id == _sel) ? _sel : null;

    final display = name.length > 40 ? '${name.substring(0, 39)}…' : name;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: t.surface2,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Tooltip(
          message: name,
          child: Text(
            '📄 $display',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontFamilyFallback: AppFonts.fallback,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              height: 1.3,
              color: t.ink,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 180, maxWidth: 300),
              child: Tooltip(
                message: 'Zielquelle wählen'
                    '${m != null && m.sure ? ' — sicherer Treffer: ${short(m.id)}' : m != null ? ' — evtl. ${short(m.id)}?' : ''}',
                child: DropdownButton<String?>(
                  value: selValid,
                  isExpanded: true,
                  isDense: true,
                  hint: Text('— Quelle wählen —',
                      style: AppTextStyles.form.copyWith(color: t.muted)),
                  style: AppTextStyles.form.copyWith(fontSize: 13, color: t.ink),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('— Quelle wählen —')),
                    for (final s in options)
                      DropdownMenuItem<String?>(
                        value: s.id,
                        child: Text(
                          '${short(s.id)} — ${s.title.length > 48 ? s.title.substring(0, 48) : s.title}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _sel = v),
                ),
              ),
            ),
            AppButton(
              variant: AppButtonVariant.primary,
              small: true,
              tooltip: 'Datei der gewählten Quelle zuweisen',
              onPressed: selValid == null
                  ? null
                  : () => unawaited(() async {
                        final files = await ref.read(fileStoreProvider.future);
                        await files.assignInbox(name, selValid);
                        files.resetStatusCache();
                      }()),
              child: const Text('→ zuweisen'),
            ),
            AppButton(
              small: true,
              tooltip: 'Neue Quelle aus dieser Datei erstellen und die Datei '
                  'gleich zuweisen',
              onPressed: () => showSourceFromFileModal(
                context,
                name: name,
                // Nach Anlegen+Zuweisen wieder zurück in den Speicher —
                // das Ein-Modal-System hat das Store-Modal geschlossen.
                onDone: () => showStoreModal(context),
              ),
              child: const Text('＋ Quelle aus Datei'),
            ),
            AppButton(
              variant: AppButtonVariant.ghost,
              small: true,
              tooltip: 'Aus der Ablage entfernen',
              onPressed: () => unawaited(() async {
                final ok = await showAppConfirm(
                    context, '„$name“ aus der Ablage entfernen?');
                if (!ok) return;
                final files = await ref.read(fileStoreProvider.future);
                await files.removeInbox(name);
              }()),
              child: const Text('🗑'),
            ),
          ],
        ),
      ]),
    );
  }
}

/// Eine Quellen-Zeile `.st-src`: Status-Punkt (9 px rund, grün = Datei) ·
/// Kurzname + Untertitel · Tag rechts; Klick → Quellenseite + Modal zu.
class _SrcRow extends StatefulWidget {
  const _SrcRow({
    required this.source,
    required this.short,
    required this.hasFile,
  });

  final Source source;
  final String short;
  final bool hasFile;

  @override
  State<_SrcRow> createState() => _SrcRowState();
}

class _SrcRowState extends State<_SrcRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final s = widget.source;
    final tag = widget.hasFile
        ? '✓ Datei'
        : s.custom
            ? '＋ manuell'
            : 'kein PDF';
    final title = s.title.length > 60 ? s.title.substring(0, 60) : s.title;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () {
          closeAppModal();
          GoRouterHelper(context).go(Routes.quellenPath(s.id));
        },
        child: Tooltip(
          message: 'Zur Quellenseite',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: _hover ? t.surface2 : Colors.transparent,
              borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
            ),
            child: Row(children: [
              // Status-Punkt: RUND, weil Dateizuordnung ≙ Belegfähigkeit.
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.hasFile ? t.good : Colors.transparent,
                  border: widget.hasFile
                      ? null
                      : Border.all(color: t.borderStrong, width: 1.5),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: widget.short,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(
                      text: '  $title',
                      style: TextStyle(color: t.muted, fontSize: 12),
                    ),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontFamilyFallback: AppFonts.fallback,
                    fontSize: 13,
                    height: 1.3,
                    color: t.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                tag,
                style: AppTextStyles.small.copyWith(
                  fontSize: 11.5,
                  color: widget.hasFile ? t.good : t.muted,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
