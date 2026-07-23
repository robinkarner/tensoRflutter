/// Anhang „PDF der Quelle" im Detailpanel — Port von `renderDetailPdf`
/// (views_studio.js:1652-1697): NUR der Viewer (derselbe wie im Studio —
/// Markierungen sichtbar, Suche), die komplette Zuordnung lebt EINMAL oben
/// im Quell-Kopf (AssignPanel) — keine Doppelung.
///
/// Abweichung: „↗ Tab" öffnet statt eines Browser-Tabs den großen
/// Modal-Viewer (Flutter hat kein window.open; gleicher Zweck: das PDF in
/// voller Größe ansehen).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/modal.dart';
import '../../../core/widgets/notice.dart';
import '../../../data/db/kv.dart';
import '../../../data/repos/file_store.dart';
import '../../pdf/viewer/pdf_engine_view.dart';
import '../state/quellen_kv.dart';

class DetailPdf extends ConsumerWidget {
  const DetailPdf({super.key, required this.srcId, this.fnNum});

  final String srcId;

  /// Erste Zitierstelle der Quelle — bestimmt die Startseite über
  /// `Levels.info(fn).seite`.
  final int? fnNum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final domain = ref.watch(quellenDomainProvider);
    final isDoc = domain?.levels.positionType(srcId) != 'fundstelle';
    final seiteRaw = fnNum != null ? domain?.levels.info(fnNum!).seite : null;
    final seite = seiteRaw is int
        ? seiteRaw
        : (seiteRaw is String ? int.tryParse(seiteRaw) : null);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!isDoc)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Notice(
            variant: NoticeVariant.info,
            child: Text.rich(
              TextSpan(children: [
                const TextSpan(
                    text: 'Rechtstext/Online-Quelle: Der Nachweis läuft über die '),
                const TextSpan(
                    text: 'Fundstelle', style: TextStyle(fontWeight: FontWeight.w700)),
                const TextSpan(
                    text: ' (Art/§/Abschnitt) + Link. Zusätzlich kann eine '
                        'PDF-Fassung zugeordnet oder der Text hinterlegt werden '
                        '— beides ist im Splitscreen markierbar.'),
              ]),
              style: AppTextStyles.small.copyWith(color: t.ink2),
            ),
          ),
        ),
      _PdfZone(srcId: srcId, seite: seite),
    ]);
  }
}

class _PdfZone extends ConsumerStatefulWidget {
  const _PdfZone({required this.srcId, this.seite});

  final String srcId;
  final int? seite;

  @override
  ConsumerState<_PdfZone> createState() => _PdfZoneState();
}

class _PdfZoneState extends ConsumerState<_PdfZone> {
  late Future<bool?> _has = _detect();

  Future<bool?> _detect() => ref
      .read(fileStoreProvider.future)
      .then((files) => files.detectPdf(widget.srcId, ref.read(kvStoreProvider)));

  @override
  void didUpdateWidget(_PdfZone old) {
    super.didUpdateWidget(old);
    if (old.srcId != widget.srcId) _has = _detect();
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return FutureBuilder<bool?>(
      future: _has,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Text('…', style: AppTextStyles.small.copyWith(color: t.muted));
        }
        if (snap.data != true) {
          return Text(
            'Keine Datei zugeordnet — Zuordnung oben im Kopf (⭳ Download · '
            '⭱ Datei lokal wählen · 📥 Aus Dateiverzeichnis).',
            style: AppTextStyles.small.copyWith(color: t.muted),
          );
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              const AppChip(label: '✓ Datei zugeordnet', variant: AppChipVariant.ok),
              const Spacer(),
              AppButton(
                small: true,
                tooltip: 'PDF in voller Größe öffnen',
                onPressed: () => unawaited(_openBig()),
                child: const Text('↗ Tab'),
              ),
            ]),
          ),
          // Eingebetteter Viewer: fit + kompakt, kein aktiver Beleg —
          // ansehen/suchen, Markierungen sichtbar (views_studio.js:1686-1690).
          PdfEngineView(
            srcId: widget.srcId,
            page: widget.seite ?? 1,
            compact: true,
            fit: true,
          ),
        ]);
      },
    );
  }

  /// „↗ Tab": großer Viewer im Modal (window.open-Ersatz).
  Future<void> _openBig() async {
    final files = await ref.read(fileStoreProvider.future);
    final data = await files.getData(widget.srcId);
    if (!mounted || data == null) return;
    final screen = MediaQuery.sizeOf(context);
    showAppModal(
      context,
      title: Text('📄 ${widget.srcId}.pdf'),
      maxWidth: screen.width * .92,
      scrollableBody: false,
      body: SizedBox(
        height: screen.height * .72,
        child: PdfEngineView(
          srcId: widget.srcId,
          data: data,
          page: widget.seite,
          fit: true,
        ),
      ),
    );
  }
}
