/// Quellen-Picker — Port von `sourcePickerModal` (:1217-1248): die GANZE
/// Quellenauswahl, durchsuchbar über Kürzel/Titel/Autor/id, gruppiert in
/// „Belege dieses Abschnitts“ und „Alle Quellen“. Auch vom Editor (S-3)
/// nutzbar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/modal.dart';
import '../../../data/bundles/indexes.dart';
import '../../../data/repos/file_store.dart';
import 'studio_state.dart';

/// Öffnet den Picker; [onPick] erhält die gewählte Quellen-id (das Modal
/// schließt sich davor — wie `U.closeModal(); onPick(id)`).
Future<void> showSourcePickerModal(
  BuildContext context,
  WidgetRef ref, {
  String? sectionId,
  String? currentId,
  required void Function(String id) onPick,
}) {
  final domain = ref.read(studioDomainProvider);
  final bySrc = (sectionId != null ? domain?.sectionSources(sectionId) : null) ??
      const <String, List<int>>{};
  final all = domain?.runtime.sources ?? const [];
  final fileStore = ref.read(fileStoreProvider).value;

  return showAppModal<void>(
    context,
    title: const Text('Quelle wählen'),
    body: _PickerBody(
      bySrc: bySrc,
      currentId: currentId,
      onPick: (id) {
        closeAppModal();
        onPick(id);
      },
      totalCount: all.length,
      hasFile: (id) => fileStore?.has(id) ?? false,
      numsForSource: (id) => domain?.levels.numsForSource(id) ?? const [],
    ),
  );
}

class _PickerBody extends ConsumerStatefulWidget {
  const _PickerBody({
    required this.bySrc,
    required this.currentId,
    required this.onPick,
    required this.totalCount,
    required this.hasFile,
    required this.numsForSource,
  });

  final Map<String, List<int>> bySrc;
  final String? currentId;
  final void Function(String id) onPick;
  final int totalCount;
  final bool Function(String id) hasFile;
  final List<int> Function(String id) numsForSource;

  @override
  ConsumerState<_PickerBody> createState() => _PickerBodyState();
}

class _PickerBodyState extends ConsumerState<_PickerBody> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final srcById = ref.watch(srcByIdProvider);
    final runtime = ref.watch(activeRuntimeProvider);
    final sources = runtime?.sources ?? const [];

    final nq = _query.toLowerCase().trim();
    bool match(String id) {
      if (nq.isEmpty) return true;
      final s = srcById[id];
      final short = ref.read(srcShortProvider(id));
      return '$short ${s?.title ?? ''} ${s?.author ?? ''} $id'
          .toLowerCase()
          .contains(nq);
    }

    final sec = [
      for (final id in widget.bySrc.keys)
        if (srcById.containsKey(id) && match(id)) id,
    ];
    final rest = [
      for (final s in sources)
        if (!widget.bySrc.containsKey(s.id) && match(s.id)) s.id,
    ]..sort((a, b) => ref
        .read(srcShortProvider(a))
        .compareTo(ref.read(srcShortProvider(b))));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Die ganze Quellenauswahl — nicht nur die Belege dieses Abschnitts. '
          'Wählen öffnet die Quelle rechts in der Quellen-Spalte.',
          style: AppTextStyles.small.copyWith(color: t.muted),
        ),
        const SizedBox(height: 8),
        TextField(
          autofocus: true,
          onChanged: (v) => setState(() => _query = v),
          style: AppTextStyles.form.copyWith(color: t.ink),
          decoration: InputDecoration(
            isDense: true,
            hintText:
                '🔍 Alle ${widget.totalCount} Quellen durchsuchen (Kürzel · Titel · Autor) …',
            hintStyle: AppTextStyles.form.copyWith(color: t.muted),
            filled: true,
            fillColor: t.surface2,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: t.borderStrong),
              borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: t.accent, width: 2),
              borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (sec.isNotEmpty) ...[
          _group(t, 'Belege dieses Abschnitts'),
          for (final id in sec) _row(context, t, id),
        ],
        _group(
          t,
          'Alle Quellen · ${rest.length}${nq.isNotEmpty ? ' Treffer' : ''}',
        ),
        if (rest.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Text('Keine weiteren.',
                style: AppTextStyles.small.copyWith(color: t.muted)),
          )
        else
          for (final id in rest) _row(context, t, id),
      ],
    );
  }

  Widget _group(BookClothTokens t, String label) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 10, 2, 4),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontFamilyFallback: AppFonts.fallback,
            fontWeight: FontWeight.w600,
            fontSize: 11,
            letterSpacing: .06 * 11,
            color: t.muted,
          ),
        ),
      );

  Widget _row(BuildContext context, BookClothTokens t, String id) {
    final s = ref.read(srcByIdProvider)[id];
    final short = ref.read(srcShortProvider(id));
    final nBel = widget.bySrc[id]?.length ?? 0;
    final tag = nBel > 0
        ? '$nBel Beleg${nBel > 1 ? 'e' : ''}'
        : widget.numsForSource(id).isNotEmpty
            ? 'Erwähnung'
            : widget.hasFile(id)
                ? '✓ Datei'
                : '';
    final current = id == widget.currentId;

    return _PickerRow(
      icon: kindIcons[s?.kind] ?? '📄',
      short: short,
      title: (s?.title ?? '').length > 72
          ? (s?.title ?? '').substring(0, 72)
          : (s?.title ?? ''),
      tag: tag,
      current: current,
      tooltip: s?.title ?? id,
      onTap: () => widget.onPick(id),
    );
  }
}

class _PickerRow extends StatefulWidget {
  const _PickerRow({
    required this.icon,
    required this.short,
    required this.title,
    required this.tag,
    required this.current,
    required this.tooltip,
    required this.onTap,
  });

  final String icon;
  final String short;
  final String title;
  final String tag;
  final bool current;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_PickerRow> createState() => _PickerRowState();
}

class _PickerRowState extends State<_PickerRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: widget.current
                  ? t.accentSoft
                  : _hover
                      ? t.surface2
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
            ),
            child: Row(
              children: [
                Text(widget.icon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.short,
                          style: AppTextStyles.small
                              .copyWith(fontWeight: FontWeight.w700, color: t.ink)),
                      if (widget.title.isNotEmpty)
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.small
                              .copyWith(fontSize: 12, color: t.muted),
                        ),
                    ],
                  ),
                ),
                if (widget.tag.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: t.surface3,
                      borderRadius:
                          BorderRadius.circular(BookClothTokens.radiusPill),
                    ),
                    child: Text(widget.tag,
                        style: AppTextStyles.small
                            .copyWith(fontSize: 11, color: t.ink2)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
