/// Nicht-PDF-Quelle im Betrachterbereich — Port von `PdfEngine.renderDocView`
/// (pdfengine.js:229-255): Internetquelle als Link-Karte (öffnet im neuen
/// Tab) oder Bild-Quelle. Der Aufrufer (S-3/S-4) prüft vorher selbst, ob
/// ein `srcDoc` definiert ist (AssignPanelState.doc bzw. [SrcKv.getSrcDoc])
/// — ohne Definition rendert dieses Widget einen leeren Platzhalter.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../data/db/kv.dart';
import '../../../data/repos/file_store.dart';
import '../assign_panel/src_kv.dart';

class SrcDocView extends ConsumerWidget {
  const SrcDocView({super.key, required this.srcId});

  final String srcId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<SrcDocDef?>(
      future: ref.watch(kvStoreProvider).getSrcDoc(srcId),
      builder: (context, snap) {
        final doc = snap.data;
        if (doc == null) return const SizedBox.shrink();
        if (doc.isLink) return _LinkView(url: doc.url ?? '');
        if (doc.isImage) return _ImageView(srcId: srcId);
        return const SizedBox.shrink();
      },
    );
  }
}

/// `.doc-view.link`: 🌐-Karte mit URL + „↗ Im neuen Tab öffnen".
class _LinkView extends StatelessWidget {
  const _LinkView({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🌐', style: TextStyle(fontSize: 44, height: 1)),
          const SizedBox(height: 10),
          Text(
            'Internetquelle',
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontFamilyFallback: AppFonts.fallback,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              height: 1.2,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SelectableText(
              url,
              textAlign: TextAlign.center,
              style: AppTextStyles.mono.copyWith(fontSize: 12.5, color: t.accentInk),
            ),
          ),
          const SizedBox(height: 14),
          AppButton(
            variant: AppButtonVariant.primary,
            onPressed: () => launchUrl(Uri.parse(url),
                mode: LaunchMode.externalApplication),
            child: const Text('↗ Im neuen Tab öffnen'),
          ),
          const SizedBox(height: 10),
          Text(
            'Kein PDF — Zitat & Fundstelle erfasst du im Beleg (rechts unten) von Hand.',
            textAlign: TextAlign.center,
            style: AppTextStyles.small.copyWith(color: t.muted),
          ),
        ],
      ),
    );
  }
}

/// `.doc-view.image`: Bild-Quelle aus dem FileStore (`img:<srcId>`).
class _ImageView extends ConsumerWidget {
  const _ImageView({required this.srcId});

  final String srcId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final store = ref.watch(fileStoreProvider).value;
    if (store == null) {
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        child: Text('Lade Bild …',
            style: AppTextStyles.small.copyWith(color: t.muted)),
      );
    }
    return FutureBuilder(
      future: store.getImage(srcId),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(20),
            child: Text('Lade Bild …',
                style: AppTextStyles.small.copyWith(color: t.muted)),
          );
        }
        final img = snap.data;
        if (img == null) {
          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(20),
            child: Text('Bild fehlt — in der Quell-Karte neu wählen.',
                style: AppTextStyles.small.copyWith(color: t.muted)),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: t.border),
                borderRadius: BorderRadius.circular(8),
                boxShadow: t.shadow1,
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.memory(img.$1, fit: BoxFit.contain),
            ),
          ),
        );
      },
    );
  }
}
