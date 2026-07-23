/// Das Bibliotheks-Gerüst — Port von `renderQuellen` (views_quellen.js:13-43)
/// und dem CSS-Grid `.lib` (app.css:713-793):
///
/// 4-Spur-Grid `220px · minmax(280px, var(--lib-list-w,34%)) · 7px ·
/// minmax(360px,1fr)`, gap 14. Der Listen-/Detail-Split ist in % verstellbar
/// (18–60, persistiert als `uiLibPct`; Doppelklick = Standard 34 %).
/// Breakpoints: ≤1199 zweispaltig `205px 1fr` (Detail rutscht in voller
/// Breite unter die Liste, kein Resizer); ≤720 einspaltig gestapelt.
///
/// Rail und Detail sind eigenständige Scrollbereiche mit Topbar-Offset
/// (das Sticky-Pendant: max-height `100vh − Topbar − 30px`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/resizable.dart';
import '../detail/detail_panel.dart';
import '../state/quellen_kv.dart';
import '../state/ui_lib_pct.dart';
import 'lib_list.dart';
import 'lib_rail.dart';

class QuellenPage extends ConsumerStatefulWidget {
  const QuellenPage({super.key, this.openId});

  final String? openId;

  @override
  ConsumerState<QuellenPage> createState() => _QuellenPageState();
}

class _QuellenPageState extends ConsumerState<QuellenPage> {
  /// Live-Prozent während des Drags (null = gespeicherter/CSS-Wert).
  double? _livePct;

  void _openSource(String id) => context.go(Routes.quellenPath(id));

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final domain = ref.watch(quellenDomainProvider);
    if (domain == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text('Lade …', style: AppTextStyles.small.copyWith(color: t.muted)),
        ),
      );
    }

    // `openId && !SRC_BY_ID[openId]` → Placeholder (js:15).
    var openId = widget.openId;
    if (openId != null && !domain.ctx.srcById.containsKey(openId)) openId = null;

    final size = MediaQuery.sizeOf(context);
    // Sticky-Pendant: max-height calc(100vh − topbar − 30px) (app.css:719).
    final columnH = size.height - BookClothTokens.topbarH - 30;

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      if (w <= 720) return _stacked(domain, openId, rail: false);
      if (w <= 1199) return _stacked(domain, openId, rail: true);
      return _wide(t, domain, openId, w, columnH);
    });
  }

  // -------------------------------------------------------------------
  // ≥1200: 4-Spur-Grid mit Resizer
  // -------------------------------------------------------------------

  Widget _wide(BookClothTokens t, QuellenDomain domain, String? openId,
      double totalW, double columnH) {
    final storedPct = ref.watch(uiLibPctProvider).value;
    final pct = (_livePct ?? storedPct?.toDouble() ?? 34).clamp(18.0, 60.0);
    // minmax(280px, listW%): die Liste unterschreitet 280 px nie.
    final listW = (totalW * pct / 100).clamp(280.0, double.infinity);

    return SizedBox(
      height: columnH,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 220,
          height: columnH,
          child: SingleChildScrollView(
            child: LibRail(domain: domain, onCreated: _openSource),
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: listW,
          height: columnH,
          child: LibList(domain: domain, openId: openId),
        ),
        const SizedBox(width: 14),
        // Drag-Griff (7 px, Doppelklick = Standard; js:26-37).
        Tooltip(
          message: 'Breite ziehen · Doppelklick = Standard',
          child: SizedBox(
            height: columnH,
            child: ResizerHandle(
              read: () => listW,
              apply: (px) {
                if (px == null) {
                  setState(() => _livePct = null);
                  return;
                }
                setState(() =>
                    _livePct = (100 * px / (totalW <= 0 ? 1 : totalW)).clamp(18.0, 60.0));
              },
              persist: (px) {
                final live = _livePct;
                _livePct = null;
                ref
                    .read(uiLibPctProvider.notifier)
                    .set(px == null || live == null ? null : live.round());
              },
              min: 240,
              max: (totalW - 620).clamp(240.0, double.infinity),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 360),
            child: _detailCard(t, domain, openId, height: columnH),
          ),
        ),
      ]),
    );
  }

  // -------------------------------------------------------------------
  // ≤1199 / ≤720: gestapelt (Detail unter der Liste, Seite scrollt)
  // -------------------------------------------------------------------

  Widget _stacked(QuellenDomain domain, String? openId, {required bool rail}) {
    final t = BookClothTokens.of(context);
    final list = LibList(domain: domain, openId: openId, shrinkWrap: true);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (rail)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 205, child: LibRail(domain: domain, onCreated: _openSource)),
          const SizedBox(width: 14),
          Expanded(child: list),
        ])
      else ...[
        LibRail(domain: domain, onCreated: _openSource),
        const SizedBox(height: 14),
        list,
      ],
      const SizedBox(height: 14),
      _detailCard(t, domain, openId),
    ]);
  }

  /// `.card.lib-detail`: surface-Karte, padding 18/20; im breiten Layout mit
  /// eigenem Scrollbereich.
  Widget _detailCard(BookClothTokens t, QuellenDomain domain, String? openId,
      {double? height}) {
    final body = openId == null
        ? LibDetailPlaceholder(domain: domain)
        : LibDetail(srcId: openId);

    final card = Container(
      height: height,
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(BookClothTokens.radius),
        boxShadow: t.shadow1,
      ),
      clipBehavior: Clip.antiAlias,
      child: height == null
          ? Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 18), child: body)
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: body,
            ),
    );
    return card;
  }
}
