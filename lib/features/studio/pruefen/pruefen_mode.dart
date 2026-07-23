/// ◉ Analyse-Modus (intern „pruefen“, W4) — Port von `renderPruefenMode`
/// (:521-575).
///
/// Views-Leiste oben (S-3-Slot), dann je Absatz die [ParagraphCard] —
/// mit aktiver Text-/Graph-View als `para-row` (Karte + Instanz-Fenster,
/// S-3-Slot [StudioSlots.paraSide]); `dock-on` verbreitert den Inhalt auf
/// 1320 rechtsbündig, `fastread-on`/`srcview-on`/„clear“ steuern die
/// Markierungs-Darstellung. Aktiver Beleg öffnet seine Karte nach jedem
/// Render wieder; `focusPara` springt mit `.jump-flash` an die Karte.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../layout/dock_state.dart';
import '../layout/studio_header.dart';
import '../layout/studio_slots.dart';
import '../layout/studio_state.dart';
import 'paragraph_card.dart';

class PruefenMode extends ConsumerStatefulWidget {
  const PruefenMode({
    super.key,
    required this.sectionId,
    this.focusPara,
    this.scrollController,
  });

  final String sectionId;
  final String? focusPara;
  final ScrollController? scrollController;

  @override
  ConsumerState<PruefenMode> createState() => _PruefenModeState();
}

class _PruefenModeState extends ConsumerState<PruefenMode> {
  final Map<String, GlobalKey> _cardKeys = {};

  @override
  void initState() {
    super.initState();
    if (widget.focusPara != null) {
      // Karte öffnen + hinscrollen + kurz hervorheben (:563-571).
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFocus());
    }
  }

  void _scrollToFocus() {
    final key = _cardKeys[widget.focusPara];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          alignment: .5, duration: const Duration(milliseconds: 200));
    }
  }

  @override
  Widget build(BuildContext context) {
    final domain = ref.watch(studioDomainProvider);
    final unit = domain?.ctx.unitIndex[widget.sectionId]?.unit;
    if (domain == null || unit == null) return const SizedBox.shrink();

    final mode = ref.watch(dockModeForProvider(widget.sectionId));
    final clear = mode == 'clear';
    final defs = ref.watch(dockDefsProvider);
    final withSide = mode != null &&
        (mode == 'connections' || dockIsTextOf(defs, mode)) &&
        StudioSlots.paraSide != null;
    final fastreadOn = mode == 'schnell';
    final srcViewOn = mode == 'srcview';
    final fileSrc = ref.watch(studioFileProvider).srcId;

    // Aktiver Beleg: seine Karte öffnet nach jedem Render wieder (:555-560).
    final sel = ref.watch(studioSelectionProvider);
    String? openParaId;
    if (sel?.fn != null &&
        domain.ctx.fnIndex[sel!.fn!]?.sectionId == widget.sectionId) {
      openParaId = domain.ctx.fnIndex[sel.fn!]?.paragraphId;
    }

    final cards = <Widget>[];
    var first = true;
    for (final p in unit.paragraphs) {
      final key = _cardKeys.putIfAbsent(p.id, GlobalKey.new);
      final card = KeyedSubtree(
        key: key,
        child: ParagraphCard(
          sectionId: widget.sectionId,
          paragraph: p,
          clear: clear,
          srcViewSrcId: srcViewOn ? fileSrc : null,
          initiallyOpen: p.id == openParaId || p.id == widget.focusPara,
          jumpFlash: p.id == widget.focusPara,
        ),
      );
      if (withSide) {
        cards.add(_ParaRow(
          card: card,
          side: StudioSlots.paraSide!(
              context, widget.sectionId, p, mode, isFirst: first),
        ));
        first = false;
      } else {
        cards.add(card);
      }
    }

    // fastread-on wirkt über die Karten (Marks voll ausgemalt) — die Karten
    // lesen den Zustand nicht selbst, deshalb hier via InheritedWidget-frei:
    // ⚡ ist ein RichText-Options-Flag; wir reichen ihn über den Ableger.
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (StudioSlots.instanzBar != null)
          StudioSlots.instanzBar!(context, widget.sectionId),
        FastreadScope(
          fastread: fastreadOn,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cards,
          ),
        ),
        SectionNav(sectionId: widget.sectionId, mode: 'pruefen'),
      ],
    );

    if (!withSide) return content;
    // `.dock-on`: max-width 1320, rechtsbündig (app.css:1489).
    return Align(
      alignment: Alignment.topRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1320),
        child: content,
      ),
    );
  }
}

/// `para-row`: Karte + Instanz-Fenster teilen sich die Naht
/// (Grid `minmax(0,1fr) minmax(0, var(--ps-w, min(300px,34cqw)))`).
class _ParaRow extends ConsumerWidget {
  const _ParaRow({required this.card, required this.side});

  final Widget card;
  final Widget side;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(studioPrefsCtlProvider).value ?? StudioPrefs.defaults;
    return LayoutBuilder(
      builder: (context, constraints) {
        // @container ≤880px: stapelt vertikal (app.css:1525-1526).
        if (constraints.maxWidth <= 880) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [card, side],
          );
        }
        final psW = (prefs.psW?.toDouble() ??
                [300.0, constraints.maxWidth * .34].reduce((a, b) => a < b ? a : b))
            .clamp(200.0, 560.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: card),
            SizedBox(width: psW, child: side),
          ],
        );
      },
    );
  }
}

