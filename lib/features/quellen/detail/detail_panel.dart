/// Spalte 3 der Bibliothek — das Detailpanel (Port von `renderLibDetail` +
/// `libDetailPlaceholder`, views_quellen.js:432-638).
///
/// Kopf = EIN Quell-Fenster: exakt dieselbe Karte wie im Studio —
/// Identität + Aktionen + Datei-Block leben EINMAL in [AssignPanel]; hier
/// kommen nur die Zusatzknöpfe für manuell angelegte Quellen dazu
/// (🤖 Ergänzung · 🗑). Darunter die Aktionszeile ⌖ Referenzieren ·
/// ⧉ Zitierweise · ✦ Durchlauf und die einklappbaren Sektionen.
library;

import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../data/db/kv.dart';
import '../../../data/models/models.dart';
import '../../../data/repos/project_repository.dart';
import '../../pdf/assign_panel/assign_panel.dart';
import '../../pdf/assign_panel/assign_panel_data.dart';
import '../import/ergaenzung_modal.dart';
import '../state/quellen_kv.dart';
import '../util/dialogs.dart';
import 'detail_pdf.dart';
import 'detail_sections.dart';
import 'durchlauf_modal.dart';

/// Andockstelle für S-3: ⌖ Referenzieren öffnet die Große Ansicht
/// (Referenzierungs-Vollbild) dieser Quelle. Solange nicht registriert,
/// springt der Knopf zur ersten Zitierstelle im Studio (Analyse-Modus) —
/// das ist auch der Weg des Originals („Referenzieren läuft über das
/// Studio", views_quellen.js:517).
abstract final class QuellenRefModeHook {
  static void Function(BuildContext context, String srcId)? open;
}

/// Leeres Panel ohne gewählte Quelle (`libDetailPlaceholder`, js:432-443).
class LibDetailPlaceholder extends StatelessWidget {
  const LibDetailPlaceholder({super.key, required this.domain});

  final QuellenDomain domain;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final allNums = domain.levels.allNums();
    final c = domain.levels.countsFor(allNums);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Eyebrow('Bibliothek'),
      const SizedBox(height: 6),
      Text('${domain.sources.length} Quellen · ${allNums.length} Zitierstellen.',
          style: AppTextStyles.small.copyWith(color: t.ink)),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: LvlBar(l1: c.l1, l2: c.l2, l3: c.l3, total: c.total),
      ),
      Text('${c.l3} belegt · ${c.l2} Original · ${c.l1} vermutet',
          style: AppTextStyles.small.copyWith(color: t.muted)),
      const SizedBox(height: 14),
      Text(
        'Links eine Quelle wählen. Dateien aus dem ⌗ Datei-Auftrag (extern '
        'besorgen → ZIP zurückgeben) ordnet der ⭱ Import automatisch der '
        'richtigen Quelle zu.',
        style: AppTextStyles.small.copyWith(color: t.muted),
      ),
    ]);
  }
}

/// Detailpanel einer Quelle.
class LibDetail extends ConsumerWidget {
  const LibDetail({super.key, required this.srcId});

  final String srcId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final domain = ref.watch(quellenDomainProvider);
    final s = domain?.ctx.srcById[srcId];
    if (domain == null || s == null) {
      // Unbekannte id — der Router-Aufrufer hat bereits auf die Bibliothek
      // zurückgeleitet; hier nur nichts rendern.
      return const SizedBox.shrink();
    }

    final nums = domain.levels.numsForSource(srcId);
    final isDoc = domain.levels.positionType(srcId) == 'seite';
    final isLaw = s.kind == 'recht-eu' || s.kind == 'recht-at';
    final srcText = domain.srcText(srcId);
    final mentions = domain.mentions.forSource(srcId);
    final vermutete = _vermuteteStellen(ref, srcId);

    void refresh() {
      ref.invalidate(assignPanelDataProvider(srcId));
      ref.invalidate(quellenKvProvider);
    }

    return Column(
      key: ValueKey('libd-$srcId'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- Kopf: die EINE Quell-Karte ----
        AssignPanel(
          srcId: srcId,
          onDone: refresh,
          onMeta: refresh,
          extraActions: s.custom
              ? [
                  AssignPanelAction(
                    label: '🤖 Ergänzung',
                    title: 'Ergänzung: externes GPT-Modell findet die Quelle und '
                        'trägt die Voranalyse nach — Prompt + Import in EINEM Dialog',
                    onTap: (_) => showErgaenzungModal(context, ref, source: s),
                  ),
                  AssignPanelAction(
                    label: '🗑',
                    title: 'Manuell angelegte Quelle entfernen',
                    onTap: (_) => unawaited(_deleteSource(context, ref, s)),
                  ),
                ]
              : const [],
        ),

        // ---- Aktionszeile ⌖ · ⧉ · ✦ ----
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _ActionRow(source: s, domain: domain, onImported: refresh),
        ),

        // ---- Sektionen (.libd-body) ----
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            if (s.custom && vermutete.isNotEmpty)
              VermuteteStellenSection(stellen: vermutete),
            if (isLaw) RegisterSection(source: s),
            // ZUERST der Anhang (PDF der Quelle) — derselbe Viewer wie im
            // Studio, danach die Zitierstellen (js:552-556).
            LibdSection(
              title: 'Anhang — PDF der Quelle',
              trailing: isLaw
                  ? const AppChip(label: 'konsolidierte Fassung', mini: true)
                  : null,
              initiallyOpen: isDoc,
              body: DetailPdf(
                  srcId: srcId, fnNum: nums.isNotEmpty ? nums.first : null),
            ),
            ZitierstellenSection(source: s, levels: domain.levels),
            if (mentions.isNotEmpty)
              MentionsSection(srcId: srcId, mentions: mentions),
            SrcTextSection(
              srcId: srcId,
              text: srcText,
              initiallyOpen: !isDoc && srcText.isEmpty,
              pickTextFile: _pickTextFile,
            ),
          ],
        ),
      ],
    );
  }

  /// vermuteteStellen kommen ROH aus dem customSources-Store — das
  /// Source-Modell trägt sie nicht (Fromcustom verwirft Unbekanntes).
  List<Map<String, Object?>> _vermuteteStellen(WidgetRef ref, String srcId) {
    final raw = ref.watch(quellenKvProvider).value?[KvKeys.customSources];
    if (raw is! List) return const [];
    for (final e in raw) {
      if (e is Map && e['id'] == srcId) {
        final vs = e['vermuteteStellen'];
        if (vs is List) {
          return [
            for (final v in vs)
              if (v is Map) v.map((k, val) => MapEntry('$k', val)),
          ];
        }
      }
    }
    return const [];
  }

  /// 🗑 Quelle löschen (js:501-506): confirm → remove → Bibliothek + Reboot.
  Future<void> _deleteSource(BuildContext context, WidgetRef ref, Source s) async {
    final ok =
        await showAppConfirm(context, 'Quelle „${s.title}“ wirklich entfernen?');
    if (!ok) return;
    await ref.read(projectRepositoryProvider).removeCustomSource(s.id);
    if (context.mounted) context.go(Routes.quellen);
    await ref.read(projectBootProvider.notifier).reboot();
  }

  static Future<String?> _pickTextFile() async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
      withData: true,
    );
    final bytes = res?.files.firstOrNull?.bytes;
    if (bytes == null) return null;
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }
}

// ---------------------------------------------------------------------------
// Aktionszeile ⌖ Referenzieren · ⧉ Zitierweise · ✦ Durchlauf
// ---------------------------------------------------------------------------

class _ActionRow extends ConsumerStatefulWidget {
  const _ActionRow({
    required this.source,
    required this.domain,
    required this.onImported,
  });

  final Source source;
  final QuellenDomain domain;
  final VoidCallback onImported;

  @override
  ConsumerState<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends ConsumerState<_ActionRow> {
  bool _copied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.source;
    final firstCite = s.stellen.isNotEmpty ? s.stellen.first : null;
    final zitierweise = s.zitierweise ?? Source.defaultZitierweise(s);

    return Wrap(spacing: 6, runSpacing: 6, children: [
      AppButton(
        small: true,
        tooltip: 'Referenzieren: die Zitierstellen dieser Quelle in der '
            'Großen Ansicht durchgehen (Zitat + Position sichern)',
        onPressed: QuellenRefModeHook.open != null
            ? () => QuellenRefModeHook.open!(context, s.id)
            : firstCite != null
                ? () => context.go(Routes.studioPath(
                      sec: firstCite.sectionId,
                      modus: StudioModes.pruefen,
                      para: firstCite.paragraphId.isNotEmpty
                          ? firstCite.paragraphId
                          : null,
                    ))
                : null,
        child: const Text('⌖ Referenzieren'),
      ),
      AppButton(
        small: true,
        tooltip: 'Zitierweise kopieren',
        onPressed: () => unawaited(_copyZitierweise(zitierweise)),
        child: Text(_copied ? '✔ kopiert' : '⧉ Zitierweise'),
      ),
      AppButton(
        small: true,
        tooltip: 'Referenzierungsdurchlauf: Prompt kopieren, Antwort einfügen '
            '— Fundstelle + Zitat je Zitierstelle',
        onPressed: () => showDurchlaufModal(context, ref,
            source: s, onImported: widget.onImported),
        child: const Text('✦ Durchlauf'),
      ),
    ]);
  }

  Future<void> _copyZitierweise(String zitierweise) async {
    await Clipboard.setData(ClipboardData(text: zitierweise));
    if (!mounted) return;
    setState(() => _copied = true);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _copied = false);
    });
  }
}
