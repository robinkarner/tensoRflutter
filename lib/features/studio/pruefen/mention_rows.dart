/// Erwähnungs-Workflow — Port des `drawMents`-Blocks in `buildResolution`
/// (:947-1025): Status-Maschine offen → bestätigt/verworfen, offen/bestätigt
/// → Beleg-Zusammenführung (⇒ Beleg [n]), alles ↺-reversibel; mehrdeutige
/// Stellen mit Kandidaten-Auswahl (die Auswahl bestimmt das Merge-Ziel).
///
/// Zusammengeführte Erwähnungen erscheinen hier nur, wenn ihre Ziel-Fußnote
/// in diesem Absatz KEINE Beleg-Zeile hat (sonst lebt das ↺ dort).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../data/bundles/indexes.dart';
import '../../../data/models/models.dart';
import '../../../domain/mentions.dart';
import '../layout/studio_state.dart';

class MentionRows extends ConsumerStatefulWidget {
  const MentionRows({
    super.key,
    required this.sectionId,
    required this.paragraph,
    required this.belegNums,
  });

  final String sectionId;
  final Paragraph paragraph;
  final Set<int> belegNums;

  @override
  ConsumerState<MentionRows> createState() => _MentionRowsState();
}

class _MentionRowsState extends ConsumerState<MentionRows> {
  /// Kandidaten-Auswahl je Stelle — überlebt das Neuzeichnen der Liste
  /// (`chosenByKey`, :956).
  final Map<String, String> _chosenByKey = {};

  void _check(String srcId) {
    final domain = ref.read(studioDomainProvider);
    final nums = domain?.levels.numsForSource(srcId) ?? const [];
    studioFileShow(ref, context, srcId, nums.isNotEmpty ? nums.first : null,
        sectionId: widget.sectionId);
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final domain = ref.watch(studioDomainProvider);
    if (domain == null) return const SizedBox.shrink();

    // Zusammengeführte nur, wenn die Ziel-Fußnote hier keine Zeile hat (:961).
    final list = [
      for (final mt in domain.mentions.forPara(widget.sectionId, widget.paragraph))
        if (mt.status != 'beleg' || !widget.belegNums.contains(mt.fn ?? -1)) mt,
    ];
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
          child: Text(
            'QUELLEN-ERWÄHNUNGEN IM TEXT',
            style: AppTextStyles.eyebrow.copyWith(color: t.muted),
          ),
        ),
        for (final mt in list) _row(context, t, domain, mt),
      ],
    );
  }

  Widget _row(BuildContext context, BookClothTokens t, StudioDomain domain,
      Mention mt) {
    final srcById = ref.watch(srcByIdProvider);
    final s2 = srcById[mt.srcId];
    final multi = mt.candidates.length > 1;
    var chosen = mt.srcId;
    final remembered = _chosenByKey[mt.key];
    if (remembered != null && mt.candidates.any((c) => c.srcId == remembered)) {
      chosen = remembered;
    }
    final mergeFn = (mt.status == 'offen' || mt.status == 'bestaetigt')
        ? domain.mentions.mergeTarget(
            widget.paragraph,
            RawMention(
              srcId: chosen,
              start: mt.start,
              end: mt.end,
              snippet: mt.snippet,
              candidates: mt.candidates,
            ),
          )
        : null;

    String short(String id) => domain.ctx.srcShort(id);

    final st = mt.status == 'bestaetigt' || mt.status == 'beleg'
        ? '❞'
        : mt.status == 'verworfen'
            ? '·'
            : '✦';

    final bodyStyle = AppTextStyles.small.copyWith(fontSize: 13, color: t.ink, height: 1.55);
    final mutSmall = AppTextStyles.small.copyWith(fontSize: 12, color: t.muted);

    Widget body;
    switch (mt.status) {
      case 'offen':
        body = Wrap(
          spacing: 4,
          runSpacing: 3,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text.rich(
              TextSpan(children: [
                const TextSpan(
                    text: 'Erkannt: ',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: '„${mt.snippet}“ → '),
              ]),
              style: bodyStyle,
            ),
            if (multi)
              _CandSelect(
                candidates: mt.candidates,
                chosen: chosen,
                labelOf: (id) =>
                    '${short(id)} — ${(srcById[id]?.title ?? '').length > 48 ? (srcById[id]?.title ?? '').substring(0, 48) : (srcById[id]?.title ?? '')}',
                onChanged: (id) => setState(() => _chosenByKey[mt.key] = id),
              )
            else
              Text(short(mt.srcId),
                  style: bodyStyle.copyWith(fontWeight: FontWeight.w700)),
            Text(
              '${multi ? '' : '${(s2?.title ?? '').length > 60 ? (s2?.title ?? '').substring(0, 60) : (s2?.title ?? '')} — '}im Text genannt, ohne Fußnote',
              style: mutSmall,
            ),
          ],
        );
      case 'bestaetigt':
        body = Text.rich(
          TextSpan(children: [
            TextSpan(
                text: short(mt.srcId),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const TextSpan(text: ' — bestätigte Erwähnung '),
            TextSpan(text: '„${mt.snippet}“', style: mutSmall),
          ]),
          style: bodyStyle,
        );
      case 'beleg':
        body = Text.rich(
          TextSpan(children: [
            TextSpan(
                text: short(mt.srcId),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: ' — mit Beleg [${mt.fn}] zusammengeführt '),
            TextSpan(
                text: '„${mt.snippet}“ · Fußnote nicht in dieser Liste',
                style: mutSmall),
          ]),
          style: bodyStyle,
        );
      default: // verworfen
        body = Text('verworfen: „${mt.snippet}“', style: mutSmall);
    }

    void setStatus(String status) {
      domain.mentions.setStatus(mt.key, status, chosen);
    }

    final acts = <Widget>[
      if (mergeFn != null)
        AppButton(
          small: true,
          tooltip:
              'Gleiche Quelle wie Beleg [$mergeFn] — zusammenführen: Text-Nennung und Fußnote zeigen auf DENSELBEN Beleg, die Satzspanne dazwischen zählt zum Zitat (↺ jederzeit trennbar)',
          onPressed: () {
            final fnTarget = domain.mentions.mergeTarget(
              widget.paragraph,
              RawMention(
                srcId: chosen,
                start: mt.start,
                end: mt.end,
                snippet: mt.snippet,
                candidates: mt.candidates,
              ),
            );
            if (fnTarget == null) return;
            domain.mentions.setStatus(mt.key, 'beleg', chosen, fnTarget);
          },
          child: Text('⇒ Beleg [$mergeFn]'),
        ),
      if (mt.status != 'verworfen')
        AppButton(
          small: true,
          variant: mt.status == 'bestaetigt' || mt.status == 'beleg'
              ? AppButtonVariant.solid
              : AppButtonVariant.primary,
          tooltip: 'Quelle (PDF) rechts in der Quellen-Spalte öffnen',
          onPressed: () => _check(chosen),
          child: const Text('Prüfen'),
        ),
      if (mt.status == 'offen') ...[
        AppButton(
          small: true,
          variant: AppButtonVariant.primary,
          onPressed: () => setStatus('bestaetigt'),
          child: const Text('✓ Bestätigen'),
        ),
        AppButton(
          small: true,
          tooltip: 'Nicht diese Quelle / keine Referenz',
          onPressed: () => setStatus('verworfen'),
          child: const Text('✗'),
        ),
      ],
      if (mt.status == 'bestaetigt')
        AppButton(
          small: true,
          tooltip: 'Bestätigung zurücknehmen',
          onPressed: () => setStatus('offen'),
          child: const Text('↺'),
        ),
      if (mt.status == 'beleg')
        AppButton(
          small: true,
          tooltip:
              'Zusammenführung lösen — wieder eigene (bestätigte) Erwähnungs-Instanz',
          onPressed: () => setStatus('bestaetigt'),
          child: const Text('↺'),
        ),
      if (mt.status == 'verworfen')
        AppButton(
          small: true,
          tooltip: 'Wieder vorschlagen',
          onPressed: () => setStatus('offen'),
          child: const Text('↺'),
        ),
    ];

    final row = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(9, 6, 9, 6),
      decoration: BoxDecoration(
        color: t.surface2,
        border: Border.all(
            color: mt.status == 'offen' ? t.accentLine : t.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 14,
            child: Text(
              st,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: mt.status == 'bestaetigt' ? t.good : t.ki,
                fontFamilyFallback: AppFonts.fallback,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: body),
          const SizedBox(width: 8),
          Wrap(spacing: 4, runSpacing: 4, children: acts),
        ],
      ),
    );

    if (mt.status == 'verworfen') {
      return Opacity(opacity: .6, child: row);
    }
    return Tooltip(
      message: 'Klicken: Quelle (PDF) rechts in der Quellen-Spalte prüfen',
      waitDuration: const Duration(milliseconds: 700),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _check(chosen),
          child: row,
        ),
      ),
    );
  }
}

/// Kandidaten-Auswahl (`select.m-cand`) bei mehrdeutigen Erwähnungen.
class _CandSelect extends StatelessWidget {
  const _CandSelect({
    required this.candidates,
    required this.chosen,
    required this.labelOf,
    required this.onChanged,
  });

  final List<MentionCandidate> candidates;
  final String chosen;
  final String Function(String id) labelOf;
  final void Function(String id) onChanged;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Tooltip(
      message: '${candidates.length} mögliche Quellen — Auswahl prüfen und bestätigen',
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.accentLine),
          borderRadius: BorderRadius.circular(6),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: chosen,
            isDense: true,
            style: AppTextStyles.small
                .copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: t.ink),
            dropdownColor: t.surface,
            borderRadius: BorderRadius.circular(6),
            items: [
              for (final c in candidates)
                DropdownMenuItem(
                  value: c.srcId,
                  child: Text(labelOf(c.srcId),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    );
  }
}
