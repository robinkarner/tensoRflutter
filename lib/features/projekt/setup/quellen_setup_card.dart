/// „Quellen-Setup — Dateien besorgen“ — Port der Setup-Karte
/// (views_projekt.js:76-199): je Quelle eine Zeile mit Status (✓/✗/·),
/// Identität, Fehler-/Erfolgs-Chips und den vier Wegen ⭳ laden · ↗ Link
/// von Hand · 📄 Datei-Panel (Inline-AssignPanel, nur EINS offen) ·
/// ✎ Quellenseite. Dazu „✓ alle übernehmen“ (inkl. `https://`-Platzhalter-
/// Randfall), „⭳ Alle laden“ (sequentiell mit Live-Redraw und Fehlerliste)
/// und „⭱ Import (PDF/ZIP)“.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/color_mix.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/chips.dart';
import '../../../data/bundles/kind_labels.dart';
import '../../../data/db/kv.dart';
import '../../../data/models/models.dart';
import '../../../data/repos/file_store.dart';
import '../../../data/repos/project_repository.dart' show EffectiveSrcLinks;
import '../../pdf/pdf.dart';
import '../../quellen/quellen.dart';
import '../../quellen/state/quellen_kv.dart' show quellenKvProvider;
import '../dashboard/dash_card.dart';
import '../dashboard/projekt_state.dart';

class QuellenSetupCard extends ConsumerStatefulWidget {
  const QuellenSetupCard({super.key, required this.domain});

  final QuellenDomain domain;

  @override
  ConsumerState<QuellenSetupCard> createState() => _QuellenSetupCardState();
}

class _QuellenSetupCardState extends ConsumerState<QuellenSetupCard> {
  /// Quelle mit offenem Inline-Zuordnungspanel (nur EINS gleichzeitig,
  /// views_projekt.js:140-152).
  String? _assignOpen;

  /// Einzel-Downloads in Arbeit (Knopf „⏳“).
  final Set<String> _dlBusy = {};

  /// „⭳ Alle laden“ läuft (Knopf gesperrt).
  bool _dlAllBusy = false;

  /// #qsDlMsg — Fortschritts-/Abschlussmeldung.
  String _dlMsg = '';

  // ref.read: die Getter laufen auch in Event-Handlern (Downloads) — die
  // Rebuild-Abhängigkeit auf den Schnappschuss hält build() selbst über
  // `ref.watch(quellenKvProvider)`.
  Map<String, Object?> get _overrides =>
      ref.read(quellenKvProvider.notifier).readMap(KvKeys.linkOverrides);

  Map<String, Object?> get _dlStatus =>
      ref.read(quellenKvProvider.notifier).readMap(KvKeys.dlStatus);

  /// „✓ alle übernehmen“ (#qsAll): alle offenen Vorschläge als Override —
  /// die Statistik (#pLinks/#qsCount) zieht reaktiv nach.
  void _takeOverAll() {
    final next = takeOverAllLinks(_overrides, widget.domain.sources);
    ref.read(quellenKvProvider.notifier).put(KvKeys.linkOverrides, next);
  }

  /// Einzel-⭳ (views_projekt.js:133-139).
  Future<void> _downloadOne(Source s, String? dlLink) async {
    setState(() => _dlBusy.add(s.id));
    final engine = await ref.read(downloadEngineProvider.future);
    await engine.tryDownload(s.id, dlLink);
    await ref.read(projektDetectedPdfsProvider.notifier).recount();
    if (mounted) setState(() => _dlBusy.remove(s.id));
  }

  /// „⭳ Alle laden“ (views_projekt.js:175-196): Zielliste = alle Quellen
  /// ohne Datei (Speicher UND Asset geprüft), dann bewusst SEQUENTIELL mit
  /// Live-Redraw nach jedem Versuch; Fehler bleiben in der Liste markiert.
  Future<void> _downloadAll() async {
    if (_dlAllBusy) return;
    setState(() => _dlAllBusy = true);
    final files = await ref.read(fileStoreProvider.future);
    final kv = ref.read(kvStoreProvider);
    final engine = await ref.read(downloadEngineProvider.future);

    final targets = <String>[];
    for (final s in widget.domain.sources) {
      if (files.has(s.id) || (await files.detectPdf(s.id, kv) ?? false)) continue;
      targets.add(s.id);
    }
    var okN = 0, failN = 0;
    for (var i = 0; i < targets.length; i++) {
      if (!mounted) return;
      setState(() => _dlMsg = '⏳ ${i + 1}/${targets.length} — ${targets[i]} …');
      final src = widget.domain.ctx.srcById[targets[i]];
      final links = src == null
          ? const EffectiveSrcLinks()
          : srcLinksFromSnapshot(_overrides, src);
      final r = await engine.tryDownload(targets[i], dlLinkFor(links));
      if (r.ok) {
        okN++;
      } else {
        failN++;
      }
      // Live-Redraw: dlStatus-Write + FileStore-Änderung treiben die Zeilen
      // reaktiv — die Meldung genügt hier als setState.
    }
    await ref.read(projektDetectedPdfsProvider.notifier).recount();
    if (!mounted) return;
    setState(() {
      _dlMsg = targets.isNotEmpty
          ? 'fertig: ✓ $okN geladen & zugeordnet · ✗ $failN fehlgeschlagen (siehe Liste)'
          : 'nichts zu laden — alle Dateien sind schon da';
      _dlAllBusy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final domain = widget.domain;
    final sources = domain.sources;
    ref.watch(quellenKvProvider); // linkOverrides/dlStatus live
    final files = ref.watch(fileStoreProvider).value;
    final detected =
        ref.watch(projektDetectedPdfsProvider).value ?? const <String>{};

    final overrides = _overrides;
    final open = [
      for (final s in sources)
        if (!srcLinksFromSnapshot(overrides, s).isOverride) s,
    ].length;

    return ProjektCard(
      eyebrow: 'Quellen-Setup — Dateien besorgen',
      eyebrowTrailing: Row(
        spacing: 8,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            open > 0
                ? '$open von ${sources.length} Links offen'
                : 'alle ${sources.length} Links geprüft ✓',
            style: AppTextStyles.small.copyWith(color: t.muted),
          ),
          AppButton(
            small: true,
            tooltip: 'Alle offenen Link-Vorschläge als geprüft übernehmen',
            onPressed: _takeOverAll,
            child: const Text('✓ alle übernehmen'),
          ),
        ],
      ),
      children: [
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(children: [
            TextSpan(
                text: '⭳ Alle laden',
                style: TextStyle(fontWeight: FontWeight.w700, color: t.ink2)),
            const TextSpan(
                text: ' versucht jede fehlende Datei über den gefundenen '
                    'Download-Link — Erfolg wird sofort zugeordnet, was '
                    'scheitert, steht deutlich in der Liste (dann: ↗ Link von '
                    'Hand laden oder ⭱ Datei lokal wählen im 📄-Panel).'),
          ]),
          style: AppTextStyles.small.copyWith(color: t.muted),
        ),
        const SizedBox(height: 8),
        Row(
          spacing: 8,
          children: [
            AppButton(
              variant: AppButtonVariant.primary,
              small: true,
              tooltip: 'Alle fehlenden Dateien nacheinander über die '
                  'gefundenen Links laden — Erfolge werden sofort zugeordnet, '
                  'Fehler in der Liste markiert',
              onPressed: _dlAllBusy ? null : _downloadAll,
              child: const Text('⭳ Alle laden'),
            ),
            AppButton(
              small: true,
              tooltip: 'Heruntergeladene PDFs oder ZIPs importieren — '
                  'passende Dateien werden automatisch zugeordnet',
              onPressed: () => showImportFilesModal(context, onDone: () {
                ref.read(projektDetectedPdfsProvider.notifier).recount();
              }),
              child: const Text('⭱ Import (PDF/ZIP)'),
            ),
            Expanded(
              child: Text(_dlMsg,
                  style: AppTextStyles.small.copyWith(color: t.muted)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // `.qs-rows`: max-height 420px, eigener Scroll.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, s) in sources.indexed) ...[
                  _SetupRow(
                    source: s,
                    links: srcLinksFromSnapshot(overrides, s),
                    dlStatus: _dlStatusFor(s.id),
                    hasFile: (files?.has(s.id) ?? false) || detected.contains(s.id),
                    busy: _dlBusy.contains(s.id),
                    last: i == sources.length - 1,
                    onDownload: _downloadOne,
                    assignOpen: _assignOpen == s.id,
                    onToggleAssign: () => setState(() =>
                        _assignOpen = _assignOpen == s.id ? null : s.id),
                  ),
                  // Inline statt Popup: Zuordnungspanel direkt unter der
                  // Quellzeile (`.qs-assign-host`, padding 8/0/12).
                  if (_assignOpen == s.id)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
                      child: AssignPanel(
                        srcId: s.id,
                        onDone: () {
                          setState(() => _assignOpen = null);
                          ref
                              .read(projektDetectedPdfsProvider.notifier)
                              .recount();
                        },
                        onCancel: () => setState(() => _assignOpen = null),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  ({bool ok, String note})? _dlStatusFor(String id) {
    final v = _dlStatus[id];
    if (v is! Map) return null;
    return (ok: v['ok'] == true, note: v['note']?.toString() ?? '');
  }
}

// ---------------------------------------------------------------------------
// Eine Setup-Zeile (.qs-row.rich)
// ---------------------------------------------------------------------------

class _SetupRow extends StatelessWidget {
  const _SetupRow({
    required this.source,
    required this.links,
    required this.dlStatus,
    required this.hasFile,
    required this.busy,
    required this.last,
    required this.onDownload,
    required this.assignOpen,
    required this.onToggleAssign,
  });

  final Source source;
  final EffectiveSrcLinks links;
  final ({bool ok, String note})? dlStatus;
  final bool hasFile;
  final bool busy;

  /// letzte Zeile → keine Unterlinie (`.qs-row:last-child`).
  final bool last;
  final void Function(Source s, String? dlLink) onDownload;
  final bool assignOpen;
  final VoidCallback onToggleAssign;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final s = source;
    final dl = dlStatus;
    final dlLink = dlLinkFor(links);
    final failed = !hasFile && dl != null && !dl.ok;

    // Statuszeichen: ✓ Datei da · ✗ Download gescheitert · · offen.
    final (st, stColor) = hasFile
        ? ('✓', t.good)
        : failed
            ? ('✗', t.bad)
            : ('·', t.ki);

    final sub = [
      if (s.author != null && s.author!.isNotEmpty) s.author!,
      if (s.year != null) '${s.year}',
      if ((s.container ?? s.longTitle) != null) (s.container ?? s.longTitle)!,
    ].join(' · ');

    return Container(
      padding: EdgeInsets.fromLTRB(failed ? 7 : 4, 8, 4, 8),
      decoration: BoxDecoration(
        // `.qs-row.dl-fail`: 3px-Leiste links + bad-4%-Fond (app.css:135).
        color: failed ? t.bad.mix(Colors.transparent, 4) : null,
        border: Border(
          bottom: last ? BorderSide.none : BorderSide(color: t.border),
          left: failed ? BorderSide(color: t.bad, width: 3) : BorderSide.none,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 9,
        children: [
          SizedBox(
            width: 16,
            child: Text(
              st,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                height: 1.4,
                color: stColor,
                fontFamilyFallback: AppFonts.fallback,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: s.title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const TextSpan(text: ' '),
                    TextSpan(
                      text: s.id,
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontFamilyFallback: AppFonts.fallback,
                        fontSize: 10.5,
                        color: t.ink2,
                      ),
                    ),
                    if (s.custom) ...[
                      const TextSpan(text: ' '),
                      const WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: AppChip(
                            label: 'manuell',
                            variant: AppChipVariant.warn,
                            mini: true),
                      ),
                    ],
                  ]),
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontFamilyFallback: AppFonts.fallback,
                    fontSize: 14,
                    height: 1.4,
                    color: t.ink,
                  ),
                ),
                Text(
                  '${sub.isNotEmpty ? sub : (kindLabels[s.kind] ?? '')}'
                  '${s.doi != null ? ' · DOI ${s.doi}' : ''}'
                  ' · ${s.citations.length} Zitierstellen',
                  style: AppTextStyles.small.copyWith(color: t.muted),
                ),
                if (failed)
                  AppChip(
                      label: '✗ ${dl.note}',
                      variant: AppChipVariant.warn,
                      mini: true)
                else if (dl != null && dl.ok && hasFile)
                  const AppChip(
                      label: '✓ geladen & zugeordnet',
                      variant: AppChipVariant.ok,
                      mini: true),
              ],
            ),
          ),
          Row(
            spacing: 4,
            children: [
              AppButton(
                small: true,
                tooltip: hasFile
                    ? 'Datei schon zugeordnet — ändern über 📄'
                    : dlLink != null
                        ? 'Über den gefundenen Link laden — bei Erfolg sofort zugeordnet'
                        : 'nicht verfügbar — kein öffentlicher Datei-Link bekannt',
                onPressed: dlLink != null && !hasFile && !busy
                    ? () => onDownload(s, dlLink)
                    : null,
                child: Text(busy ? '⏳' : '⭳'),
              ),
              AppButton(
                variant: AppButtonVariant.ghost,
                small: true,
                tooltip: dlLink != null
                    ? 'Gefundenen Download-Link von Hand öffnen: $dlLink'
                    : 'nicht verfügbar — kein Datei-Link gefunden',
                onPressed:
                    dlLink != null ? () => launchUrl(Uri.parse(dlLink)) : null,
                child: const Text('↗'),
              ),
              AppButton(
                small: true,
                tooltip: 'Datei zuordnen: ⭱ lokal wählen · 📥 aus '
                    'Dateiverzeichnis · prüfen/ersetzen/entfernen',
                onPressed: onToggleAssign,
                child: const Text('📄'),
              ),
              AppButton(
                small: true,
                tooltip: 'Quellenseite: Links, Dossier, GPT-Durchlauf',
                onPressed: () => context.go(Routes.quellenPath(s.id)),
                child: const Text('✎'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
