/// 🗂 Arbeiten-Menü — Port von `projektArbeitenCard()`
/// (views_projekt.js:271-338), gehostet im works-pop der Topbar:
/// Instanz-Liste mit ●/○-Radio (Aktivieren = E8-Reboot statt
/// `location.reload()`), ＋ Neue Arbeit aus .tex, je Arbeit
/// 🤖 Gesamt-Prompt / ⭱ Analysen / ⭳ Export / 🗑 Löschen (mit Tombstone),
/// ⭱ Arbeit importieren (.json) mit Drei-Wege-Kollisionsdialog
/// (OK = überschreiben, Abbrechen = Kopie).
library;

import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../data/export/projekt_format.dart';
import '../../../data/models/models.dart';
import '../../../data/repos/project_repository.dart';
import '../../quellen/util/dialogs.dart';
import '../../quellen/util/save_file.dart';
import 'import_analysen_modal.dart';
import 'master_prompt.dart';
import 'neue_arbeit_modal.dart';

part 'works_menu.g.dart';

/// Instanz-Liste aus der DB (`Projects.list()`); der Boot-Watch lädt sie
/// nach jedem Projektwechsel/Reboot frisch. keepAlive, weil das Menü
/// mehrmals pro Sitzung auf- und zugeht (Popover wird je Öffnung neu
/// gebaut — Original zeichnet die Karte ebenfalls je Öffnung neu).
@Riverpod(keepAlive: true)
Future<List<ProjectRecord>> worksList(Ref ref) async {
  await ref.watch(projectBootProvider.future);
  return ref.watch(projectRepositoryProvider).list();
}

/// Karteninhalt des works-pop — die Popover-Hülle (Position/Schatten/Scroll)
/// stellt die Topbar.
class WorksMenuCard extends ConsumerWidget {
  const WorksMenuCard({super.key, required this.onDismiss});

  /// Schließt das Popover (vor Navigation/Reboot).
  final VoidCallback onDismiss;

  /// `Projects.setActive`-Pendant: Popover zu, nach `#/projekt` navigieren,
  /// dann E8-Reboot über den app-weiten Container (überlebt das Popover).
  static Future<void> _activate(BuildContext context, VoidCallback onDismiss, String id) async {
    // Container + Router VOR dem Schließen greifen — das Popover (samt
    // context) verschwindet mit onDismiss.
    final container = ProviderScope.containerOf(context, listen: false);
    final router = GoRouter.of(context);
    onDismiss();
    router.go(Routes.projekt);
    await container.read(projectBootProvider.notifier).activateProject(id);
    container.invalidate(worksListProvider);
  }

  /// „⭱ Arbeit importieren (.json)“ (views_projekt.js:325-331).
  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final f = res?.files.firstOrNull;
    if (f == null || f.bytes == null || !context.mounted) return;
    try {
      final rec = await ref.read(projectRepositoryProvider).importProject(
            utf8.decode(f.bytes!),
            confirmOverwrite: (id, existingName) => showAppConfirm(
              context,
              'Eine Arbeit mit der id „$id“ („$existingName“) existiert '
              'bereits.\nÜberschreiben? (Abbrechen = als Kopie importieren)',
            ),
          );
      if (!context.mounted) return;
      await _activate(context, onDismiss, rec.id);
    } catch (err) {
      if (!context.mounted) return;
      await showAppAlert(context,
          'Import fehlgeschlagen: ${err is FormatException ? err.message : err}');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final list = ref.watch(worksListProvider);
    final activeId =
        ref.watch(projectBootProvider).value?.activeId ?? ProjectRecord.defaultId;

    return Padding(
      // `.card`-Innenmaß: var(--space-4) var(--space-5) ≈ 16/18.
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(child: Eyebrow('Arbeiten (Instanzen)')),
              AppButton(
                variant: AppButtonVariant.primary,
                small: true,
                onPressed: () => showNeueArbeitModal(context, ref),
                child: const Text('＋ Neue Arbeit aus .tex'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // .pj-list — async („Lade …“-Platzhalter wie das Original).
          switch (list) {
            AsyncData(:final value) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Zeile 1 ist immer die virtuelle Default-Arbeit — im
                  // Original „eingebaut · js/data-Bundles“; hier liegen die
                  // Bundles als Flutter-Assets (assets/data), der Untertitel
                  // ist minimal an die App-Realität angepasst.
                  _WorkRow(
                    id: ProjectRecord.defaultId,
                    name: 'EHDS-Bachelorarbeit',
                    sub: 'eingebaut · assets/data-Bundles',
                    rec: null,
                    active: activeId == ProjectRecord.defaultId,
                    onDismiss: onDismiss,
                  ),
                  for (final rec in value)
                    _WorkRow(
                      id: rec.id,
                      name: rec.name,
                      sub: _recSub(rec),
                      rec: rec,
                      active: activeId == rec.id,
                      onDismiss: onDismiss,
                    ),
                  const SizedBox(height: 6),
                  Row(children: [
                    AppButton(
                      small: true,
                      onPressed: () => _import(context, ref),
                      child: const Text('⭱ Arbeit importieren (.json)'),
                    ),
                  ]),
                ],
              ),
            _ => Text('Lade …', style: AppTextStyles.small.copyWith(color: t.muted)),
          },
          const SizedBox(height: 8),
          Text(
            'Jede Arbeit hat ihren eigenen Prüfstand (Belege, Markierungen, '
            'Notizen). PDFs werden über die Quellen-id geteilt.',
            style: AppTextStyles.small.copyWith(color: t.muted),
          ),
        ],
      ),
    );
  }

  /// Untertitel-Muster „N Kapitel · M Fußnoten · K Abschnitte analysiert“
  /// (views_projekt.js:321-323).
  static String _recSub(ProjectRecord rec) {
    final st = rec.parsed.thesis.chapters.length;
    final fn = rec.parsed.footnotes.length;
    final gen = rec.generated.sections.length;
    return '$st Kapitel · $fn Fußnoten · $gen Abschnitte analysiert';
  }
}

// ---------------------------------------------------------------------------
// Eine Zeile der Instanz-Liste (.pj-row)
// ---------------------------------------------------------------------------

class _WorkRow extends ConsumerStatefulWidget {
  const _WorkRow({
    required this.id,
    required this.name,
    required this.sub,
    required this.rec,
    required this.active,
    required this.onDismiss,
  });

  final String id;
  final String name;
  final String sub;

  /// null = die virtuelle Default-Zeile (ohne Aktionen).
  final ProjectRecord? rec;
  final bool active;
  final VoidCallback onDismiss;

  @override
  ConsumerState<_WorkRow> createState() => _WorkRowState();
}

class _WorkRowState extends ConsumerState<_WorkRow> {
  /// 🤖-Knopf zeigt nach der Kopie 1800 ms „✔ kopiert (inkl. LaTeX)“
  /// (views_projekt.js:296-300).
  bool _copied = false;
  Timer? _copyTimer;

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  Future<void> _copyPrompt(ProjectRecord rec) async {
    await Clipboard.setData(ClipboardData(text: masterPromptWithTex(rec.tex)));
    if (!mounted) return;
    setState(() => _copied = true);
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  /// 🗑 (views_projekt.js:303-316): confirm → remove (+Tombstone bei
  /// Builtins über das Repository) → aktiv? Wechsel auf default : Redraw.
  Future<void> _delete(ProjectRecord rec) async {
    final ok = await showAppConfirm(
      context,
      'Arbeit „${rec.name}“ wirklich löschen? Der Prüfstand im Browser bleibt '
      'erhalten, die Arbeit selbst wird entfernt.',
    );
    if (!ok || !mounted) return;
    await ref.read(projectRepositoryProvider).removeWithTombstone(rec);
    if (!mounted) return;
    if (widget.active) {
      await WorksMenuCard._activate(
          context, widget.onDismiss, ProjectRecord.defaultId);
    } else {
      ref.invalidate(worksListProvider);
    }
  }

  /// ⭱ Analysen: Redraw über den app-weiten Container — das Popover kann
  /// beim Schließen des Modals bereits weg sein.
  void _openImportAnalysen(ProjectRecord rec) {
    final container = ProviderScope.containerOf(context, listen: false);
    showImportAnalysenModal(
      context,
      rec: rec,
      onDone: () => container.invalidate(worksListProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final rec = widget.rec;

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 9,
        children: [
          // ●/○-Radio (`button.pj-pick`): Klick aktiviert, aktiv = accent.
          Tooltip(
            message: widget.active
                ? 'Aktive Arbeit'
                : '„${widget.name}“ aktivieren',
            child: MouseRegion(
              cursor: widget.active
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.active
                    ? null
                    : () => WorksMenuCard._activate(
                        context, widget.onDismiss, widget.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    widget.active ? '●' : '○',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1,
                      color: widget.active ? t.accent : t.muted,
                      fontFamilyFallback: AppFonts.fallback,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // .bd: Name [chip „eingebaut“] + Untertitel.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  spacing: 6,
                  children: [
                    Flexible(
                      child: Text(
                        widget.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontFamilyFallback: AppFonts.fallback,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          height: 1.3,
                          color: t.ink,
                        ),
                      ),
                    ),
                    if (rec?.builtin ?? false)
                      const AppChip(label: 'eingebaut', mini: true),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  widget.sub,
                  style: AppTextStyles.small.copyWith(color: t.muted),
                ),
              ],
            ),
          ),
          // .acts — nur für echte Records (nie für die Default-Zeile).
          if (rec != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 250),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.end,
                children: [
                  AppButton(
                    small: true,
                    tooltip: 'Gesamt-Prompt für das externe GPT-Modell: '
                        'Formatvorgabe + Notation + komplettes LaTeX',
                    onPressed: () => _copyPrompt(rec),
                    child: Text(
                        _copied ? '✔ kopiert (inkl. LaTeX)' : '🤖 Gesamt-Prompt'),
                  ),
                  AppButton(
                    small: true,
                    tooltip: 'Generierte Analyse-Dateien importieren '
                        '(sections/…, kapitel-…, registry.json, …)',
                    onPressed: () => _openImportAnalysen(rec),
                    child: const Text('⭱ Analysen'),
                  ),
                  AppButton(
                    small: true,
                    tooltip: 'Arbeit als JSON exportieren',
                    onPressed: () => saveTextFile(
                        '${rec.id}.thesis-studio.json', exportProjectJson(rec)),
                    child: const Text('⭳ Export'),
                  ),
                  AppButton(
                    small: true,
                    tooltip: 'Arbeit löschen',
                    onPressed: () => _delete(rec),
                    child: const Text('🗑 Löschen'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
