/// Spalte 2 der Bibliothek — Suchleiste + Quellenliste (Port von
/// `renderLibList`, views_quellen.js:368-429).
///
/// Live-Suche über Titel+Autor+id+Container, 4 Sortierungen (persistiert),
/// Zeilen mit Art-Icon, Titel/Unterzeile, Zitierstellen-Zähler, Level-Balken
/// (54 px) und PDF-Flag (async `·` → `📄`/`—`, Rechtsquellen statisch `§`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/chips.dart';
import '../../../data/bundles/kind_labels.dart';
import '../../../data/db/kv.dart';
import '../../../data/models/models.dart';
import '../../../data/repos/file_store.dart';
import '../../../domain/js_compat.dart';
import '../state/file_store_tick.dart';
import '../state/quellen_filter.dart';
import '../state/quellen_kv.dart';
import 'lib_rail.dart' show quellenSmartFilter;

/// Bekannte Sammlungs-Keys (Fallback-Prüfung, js:386-391).
bool _collKnown(String coll) =>
    coll == 'alle' ||
    (coll.startsWith('kind:') && kindLabels.containsKey(coll.substring(5))) ||
    const {'offen', 'fertig', 'pdf-fehlt', 'notizen', 'custom'}.contains(coll);

class LibList extends ConsumerStatefulWidget {
  const LibList({
    super.key,
    required this.domain,
    this.openId,
    this.shrinkWrap = false,
  });

  final QuellenDomain domain;
  final String? openId;

  /// true in den gestapelten Breakpoints (≤1199): die Liste misst sich
  /// selbst und scrollt mit dem Dokument (kein eigener Scrollbereich).
  final bool shrinkWrap;

  @override
  ConsumerState<LibList> createState() => _LibListState();
}

class _LibListState extends ConsumerState<LibList> {
  late final TextEditingController _search = TextEditingController(
      text: ref.read(quellenFilterCtlProvider).value?.q ?? '');

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final domain = widget.domain;
    final filter = ref.watch(quellenFilterCtlProvider).value ?? const QuellenFilter();
    ref.watch(fileStoreTickProvider); // Store-Änderung → Liste neu (js:427)
    final files = ref.watch(fileStoreProvider).value;

    // Unbekannte Sammlung → Fallback „alle" inkl. Persistenz (js:386-391).
    var coll = filter.coll;
    final anyCustom = domain.sources.any((s) => s.custom);
    if (!_collKnown(coll) || (coll == 'custom' && !anyCustom)) {
      coll = 'alle';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(quellenFilterCtlProvider.notifier).setColl('alle');
      });
    }

    final rows = _filteredSorted(domain, files, coll, filter);

    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: widget.shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
        children: [
      // .lib-listbar
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _search,
              style: AppTextStyles.form.copyWith(color: t.ink),
              decoration: const InputDecoration(hintText: 'Titel, Autor, id …'),
              onChanged: (v) =>
                  ref.read(quellenFilterCtlProvider.notifier).setQ(v),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Sortierung',
            child: DropdownButton<String>(
              value: const {'zit', 'titel', 'jahr', 'status'}.contains(filter.sort)
                  ? filter.sort
                  : 'zit',
              isDense: true,
              style: AppTextStyles.form.copyWith(fontSize: 13.5, color: t.ink),
              items: const [
                DropdownMenuItem(value: 'zit', child: Text('Zitierstellen ↓')),
                DropdownMenuItem(value: 'titel', child: Text('Titel A–Z')),
                DropdownMenuItem(value: 'jahr', child: Text('Jahr ↓')),
                DropdownMenuItem(value: 'status', child: Text('Offene zuerst')),
              ],
              onChanged: (v) {
                if (v != null) {
                  ref.read(quellenFilterCtlProvider.notifier).setSort(v);
                }
              },
            ),
          ),
        ]),
      ),
      // .lib-rows
      () {
        final box = Container(
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(BookClothTokens.radius),
          ),
          clipBehavior: Clip.antiAlias,
          child: rows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(26),
                  child: Center(
                    child: Text('Keine Quellen passen zum Filter.',
                        style: AppTextStyles.small.copyWith(color: t.muted)),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: widget.shrinkWrap,
                  physics: widget.shrinkWrap
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  itemCount: rows.length,
                  itemBuilder: (context, i) => _LibRow(
                    source: rows[i],
                    domain: domain,
                    active: rows[i].id == widget.openId,
                  ),
                ),
        );
        return widget.shrinkWrap ? box : Expanded(child: box);
      }(),
    ]);
  }

  /// Filter + Sortierung (js:392-399) — Sortierungen JS-stabil.
  List<Source> _filteredSorted(
      QuellenDomain domain, FileStore? files, String coll, QuellenFilter filter) {
    final q = filter.q.toLowerCase();
    final rows = [
      for (final s in domain.sources)
        if (coll == 'alle' ||
            (coll.startsWith('kind:')
                ? s.kind == coll.substring(5)
                : quellenSmartFilter(coll, s, domain, files)))
          if (q.isEmpty ||
              '${s.title} ${s.author ?? ''} ${s.id} ${s.container ?? ''}'
                  .toLowerCase()
                  .contains(q))
            s,
    ];

    double done(Source s) {
      final c = domain.levels.countsFor(domain.levels.numsForSource(s.id));
      return c.total > 0 ? c.l3 / c.total : 1;
    }

    switch (filter.sort) {
      case 'titel':
        return stableSorted(
            rows, (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case 'jahr':
        return stableSorted(rows, (a, b) => (b.year ?? 0) - (a.year ?? 0));
      case 'status':
        return stableSorted(rows, (a, b) {
          final d = done(a).compareTo(done(b));
          return d != 0 ? d : b.citations.length - a.citations.length;
        });
      default: // 'zit'
        return stableSorted(rows, (a, b) => b.citations.length - a.citations.length);
    }
  }
}

/// Eine `.lib-row`: Icon · Titel/Unterzeile · N× + LvlBar(54) + pdfflag.
class _LibRow extends ConsumerStatefulWidget {
  const _LibRow({required this.source, required this.domain, required this.active});

  final Source source;
  final QuellenDomain domain;
  final bool active;

  @override
  ConsumerState<_LibRow> createState() => _LibRowState();
}

class _LibRowState extends ConsumerState<_LibRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final s = widget.source;
    final domain = widget.domain;
    final nums = domain.levels.numsForSource(s.id);
    final counts = domain.levels.countsFor(nums);
    final isDoc = domain.levels.positionType(s.id) == 'seite';
    final sub = [
      if ((s.author ?? '').isNotEmpty) s.author!,
      if (s.year != null) '${s.year}',
    ].join(' · ');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => context.go(Routes.quellenPath(s.id)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: widget.active
                ? t.accentSoft
                : _hover
                    ? t.surface2
                    : Colors.transparent,
            border: Border(bottom: BorderSide(color: t.border)),
          ),
          // aktiv: inset 2.5px 0 0 accent (app.css:751) — als Vordergrund-
          // Linie gemalt, damit der Inhalt nicht verrutscht.
          foregroundDecoration: widget.active
              ? BoxDecoration(
                  border: Border(left: BorderSide(color: t.accent, width: 2.5)))
              : null,
          child: Row(children: [
            Opacity(
              opacity: .85,
              child: Text(kindIcons[s.kind] ?? '📄',
                  style: const TextStyle(fontSize: 15, height: 1)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  s.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontFamilyFallback: AppFonts.fallback,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 1.3,
                    color: t.ink,
                  ),
                ),
                Text(
                  sub.isNotEmpty ? sub : (s.container ?? s.id),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontFamilyFallback: AppFonts.fallback,
                    fontSize: 12.5,
                    height: 1.3,
                    color: t.muted,
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            Text(
              '${s.citations.length}×',
              style: AppTextStyles.mono.copyWith(fontSize: 11.5, color: t.muted),
            ),
            const SizedBox(width: 7),
            SizedBox(
              width: 54,
              child: LvlBar(
                l1: counts.l1,
                l2: counts.l2,
                l3: counts.l3,
                total: counts.total,
                minWidth: 54,
              ),
            ),
            const SizedBox(width: 7),
            _PdfFlag(srcId: s.id, isDoc: isDoc),
          ]),
        ),
      ),
    );
  }
}

/// `.pdfflag`: Dokument-Quellen `·` → async `📄`/`—` (missing = warn);
/// Rechtsquellen statisch `§` (js:414-420).
class _PdfFlag extends ConsumerWidget {
  const _PdfFlag({required this.srcId, required this.isDoc});

  final String srcId;
  final bool isDoc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final style = TextStyle(
      fontFamily: AppFonts.ui,
      fontFamilyFallback: AppFonts.fallback,
      fontSize: 11,
      height: 1,
      color: t.muted,
    );

    if (!isDoc) {
      return SizedBox(width: 20, child: Text('§', textAlign: TextAlign.center, style: style));
    }

    return SizedBox(
      width: 20,
      child: FutureBuilder<bool?>(
        future: ref.watch(fileStoreProvider.future).then(
            (files) => files.detectPdf(srcId, ref.read(kvStoreProvider))),
        builder: (context, snap) {
          if (!snap.hasData && snap.connectionState != ConnectionState.done) {
            return Text('·', textAlign: TextAlign.center, style: style);
          }
          final ok = snap.data;
          return Tooltip(
            message: ok == true ? 'PDF verfügbar' : 'PDF fehlt',
            child: Text(
              ok == true ? '📄' : '—',
              textAlign: TextAlign.center,
              style: ok == false ? style.copyWith(color: t.warn) : style,
            ),
          );
        },
      ),
    );
  }
}
