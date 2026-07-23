/// Bildsystem — Port von `figureCard`/`tableCard`/`showLightbox`
/// (figures.js:58-110): Abbildungen der Arbeit an ihren Absätzen.
/// Priorität: statisches Asset (`fig.file`) → hochgeladenes Bild aus dem
/// FigStore → Platzhalter mit Upload (nach Upload sofortiges Re-Render).
/// Bild-Klick öffnet die Lightbox (Klick/Escape schließt); Tabellen aus dem
/// Manifest werden als echte Tabellen gesetzt. Der „Quelle ↗"-Link führt
/// zur Quellenseite (`/quellen/&lt;id&gt;`).
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/lightbox.dart';
import '../../../data/bundles/indexes.dart';
import '../../../data/models/models.dart';
import '../../../data/repos/fig_store.dart';

/// `figure.fig-card` bzw. `.fig-missing`-Platzhalter.
class FigureCard extends ConsumerStatefulWidget {
  const FigureCard(this.fig, {super.key, this.compact = false, this.onQuelleTap});

  final Figur fig;

  /// compact: Bild max-height 280 (Peek-Popover, figures.js:64).
  final bool compact;

  /// „Quelle ↗"-Link (Navigation nach `/quellen/<id>` macht der Aufrufer).
  final void Function(String srcId)? onQuelleTap;

  @override
  ConsumerState<FigureCard> createState() => _FigureCardState();
}

class _FigureCardState extends ConsumerState<FigureCard> {
  StreamSubscription<void>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final fig = widget.fig;
    final figStore = ref.watch(figStoreProvider).value;

    // Live-Aktualisierung: Upload anderswo → Karte wechselt zum Bild.
    if (figStore != null && _sub == null) {
      _sub = figStore.changes.listen((_) {
        if (mounted) setState(() {});
      });
    }

    if (fig.file != null && fig.file!.isNotEmpty) {
      return _card(t, Image.asset('assets/${fig.file}', fit: BoxFit.contain));
    }
    if (figStore != null && figStore.has(fig.id)) {
      return FutureBuilder(
        future: figStore.getImage(fig.id),
        builder: (context, snap) {
          final img = snap.data;
          if (img == null) return _missing(t, figStore);
          return _card(t, Image.memory(img.$1, fit: BoxFit.contain));
        },
      );
    }
    return _missing(t, figStore);
  }

  /// `.fig-card`: Bild auf fig-bg (immer hell) + fig-cap-Unterschrift.
  Widget _card(BookClothTokens t, Widget image) {
    final fig = widget.fig;
    final srcById = ref.watch(srcByIdProvider);
    final hasQuelle = fig.quelle != null && srcById.containsKey(fig.quelle);

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 16, 0, 18),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(BookClothTokens.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        MouseRegion(
          cursor: SystemMouseCursors.zoomIn,
          child: GestureDetector(
            onTap: () => showLightbox(
              context,
              image: image,
              caption: '${fig.nummer} — ${fig.titel}',
            ),
            child: Container(
              color: t.figBg,
              padding: const EdgeInsets.all(10),
              constraints:
                  BoxConstraints(maxHeight: widget.compact ? 280 : 460),
              child: image,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          decoration:
              BoxDecoration(border: Border(top: BorderSide(color: t.border))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: fig.nummer,
                  style: TextStyle(fontWeight: FontWeight.w700, color: t.ink),
                ),
                TextSpan(text: ' — ${fig.titel}'),
              ]),
              style: AppTextStyles.small.copyWith(fontSize: 13, color: t.ink2),
            ),
            if (fig.credit.isNotEmpty || hasQuelle)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (fig.credit.isNotEmpty)
                      Text(fig.credit,
                          style: AppTextStyles.small
                              .copyWith(fontSize: 11.5, color: t.muted)),
                    if (hasQuelle) ...[
                      Text('·',
                          style: AppTextStyles.small
                              .copyWith(fontSize: 11.5, color: t.muted)),
                      FigureCardLink(
                        label: 'Quelle ↗',
                        onTap: () => widget.onQuelleTap?.call(fig.quelle!),
                      ),
                    ],
                  ],
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  /// `.fig-missing`: gestrichelter Platzhalter mit Upload.
  Widget _missing(BookClothTokens t, FigStore? figStore) {
    final fig = widget.fig;
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        margin: const EdgeInsets.fromLTRB(0, 16, 0, 18),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.surface2,
          border: Border.all(color: t.borderStrong, width: 1.5),
          borderRadius: BorderRadius.circular(BookClothTokens.radius),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Eyebrow('🖼 ${fig.nummer} — Abbildung nicht hinterlegt'),
          const SizedBox(height: 6),
          Text(fig.titel,
              style: AppTextStyles.small.copyWith(
                  fontSize: 13, fontWeight: FontWeight.w700, color: t.ink)),
          const SizedBox(height: 4),
          Text(
            fig.beschreibung.isNotEmpty ? fig.beschreibung : fig.credit,
            style: AppTextStyles.small.copyWith(color: t.muted),
          ),
          const SizedBox(height: 10),
          AppButton(
            small: true,
            onPressed: figStore == null ? null : () => _upload(figStore),
            child: const Text('Bild einfügen (PNG/JPG/WebP/SVG)'),
          ),
        ]),
      ),
      // Eck-Quadrat des Platzhalters (fig-missing::before, app.css:1108).
      Positioned(
        top: 16 - 1.5,
        left: -1.5,
        child: Container(width: 7, height: 7, color: t.accent),
      ),
    ]);
  }

  Future<void> _upload(FigStore figStore) async {
    final res = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = res?.files.firstOrNull;
    final Uint8List? bytes = file?.bytes;
    if (bytes == null) return;
    await figStore.put(widget.fig.id, bytes);
    if (mounted) setState(() {});
  }
}

/// Verdrahtung des „Quelle ↗"-Links: [FigureCard] rendert den Link nur,
/// wenn die Quelle existiert; der Tap läuft über [FigureCardLink], damit
/// der GestureRecognizer sauber verwaltet wird.
class FigureCardLink extends StatelessWidget {
  const FigureCardLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(label,
            style: AppTextStyles.small.copyWith(fontSize: 11.5, color: t.accentInk)),
      ),
    );
  }
}

/// `tableCard` — Manifest-Tabelle als echte Tabelle (figures.js:94-103):
/// thead aus `kopf`, tbody aus `zeilen`, erste Zelle jeder Zeile 600.
class TableCard extends StatelessWidget {
  const TableCard(this.tab, {super.key});

  final Tabelle tab;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);

    TableRow row(List<String> cells, {bool head = false}) => TableRow(
          decoration: head
              ? BoxDecoration(color: t.surface2)
              : BoxDecoration(
                  border: Border(top: BorderSide(color: t.border))),
          children: [
            for (var i = 0; i < cells.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  cells[i],
                  style: AppTextStyles.small.copyWith(
                    fontSize: 13,
                    fontWeight:
                        head || i == 0 ? FontWeight.w600 : FontWeight.w400,
                    color: head ? t.ink2 : t.ink,
                  ),
                ),
              ),
          ],
        );

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 16, 0, 18),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(BookClothTokens.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 300),
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                children: [
                  row(tab.kopf, head: true),
                  for (final z in tab.zeilen) row(z),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          decoration:
              BoxDecoration(border: Border(top: BorderSide(color: t.border))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: tab.nummer,
                  style: TextStyle(fontWeight: FontWeight.w700, color: t.ink),
                ),
                TextSpan(text: ' — ${tab.titel}'),
              ]),
              style: AppTextStyles.small.copyWith(fontSize: 13, color: t.ink2),
            ),
            if (tab.credit.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(tab.credit,
                    style: AppTextStyles.small
                        .copyWith(fontSize: 11.5, color: t.muted)),
              ),
          ]),
        ),
      ]),
    );
  }
}
