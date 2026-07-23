/// Markierungs-Dialoge: Popover (Zitat · Kommentar · Löschen) und der
/// Chooser bei überlappenden Markierungen — Ports von `markPopover`
/// (pdfengine.js:1168-1190) und `markChooser` (js:1252-1265).
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/modal.dart';
import 'mark_overlay.dart';
import 'pdf_mark.dart';
import 'pdf_marks_store.dart';

/// Popover an einer Markierung: Zitat als Blockquote in Belegfarbe,
/// Kommentar-Textarea, „Speichern" / „Markierung löschen".
void showMarkPopover(
  BuildContext context,
  WidgetRef ref, {
  required String srcId,
  required PdfMark mark,
  VoidCallback? onMarksChange,
}) {
  final t = BookClothTokens.of(context);
  final notifier = ref.read(pdfMarksProvider.notifier);
  final textCtrl = TextEditingController(text: mark.comment?.text ?? '');
  final hex = markColorOf(mark.farbe);

  showAppModal(
    context,
    title: Text('Markierung ${mark.fn != null ? '[${mark.fn}]' : ''} — S. ${mark.page}'),
    onClose: textCtrl.dispose,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (mark.zitat.isNotEmpty)
          Container(
            padding: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: hex, width: 3)),
            ),
            child: Text(
              '„${mark.zitat}“',
              style: AppTextStyles.body.copyWith(fontSize: 13, color: t.ink),
            ),
          ),
        const SizedBox(height: 10),
        Text('Kommentar', style: AppTextStyles.small.copyWith(color: t.ink2)),
        const SizedBox(height: 4),
        TextField(
          controller: textCtrl,
          minLines: 3,
          maxLines: 8,
          style: AppTextStyles.form.copyWith(color: t.ink),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            AppButton(
              variant: AppButtonVariant.primary,
              small: true,
              onPressed: () {
                final text = textCtrl.text.trim();
                // Kommentar setzen/löschen; Default-Position rechts neben dem
                // ersten Rechteck: x = rects[0].x+w+0.02, max 0.9 (js:1180).
                final first = mark.rects.isNotEmpty ? mark.rects.first : null;
                final comment = text.isEmpty
                    ? null
                    : MarkComment(
                        x: mark.comment?.x ??
                            min(0.9, (first != null ? first.x + first.w : 0.85) + 0.02),
                        y: mark.comment?.y ?? (first?.y ?? 0.1),
                        text: text,
                      ).toJson();
                notifier.updateMark(srcId, mark.id, {'comment': comment});
                closeAppModal();
                onMarksChange?.call();
              },
              child: const Text('Speichern'),
            ),
            const SizedBox(width: 6),
            AppButton(
              small: true,
              onPressed: () {
                notifier.removeMark(srcId, mark.id);
                closeAppModal();
                onMarksChange?.call();
              },
              child: const Text('Markierung löschen'),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Mehrere Markierungen an derselben Stelle: Auswahl-Dialog mit Farb-Punkt,
/// `[fn]` und Zitat-Auszug (90 Zeichen) je Zeile.
void showMarkChooser(
  BuildContext context,
  WidgetRef ref, {
  required String srcId,
  required List<PdfMark> hits,
  VoidCallback? onMarksChange,
}) {
  final t = BookClothTokens.of(context);

  showAppModal(
    context,
    title: Text('${hits.length} Markierungen an dieser Stelle'),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final m in hits)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _MarkRow(
              mark: m,
              onTap: () {
                closeAppModal();
                showMarkPopover(context, ref,
                    srcId: srcId, mark: m, onMarksChange: onMarksChange);
              },
            ),
          ),
        const SizedBox(height: 2),
        Text(
          'Eine Markierung wählen, um Zitat/Kommentar zu bearbeiten oder sie zu löschen.',
          style: AppTextStyles.small.copyWith(color: t.muted),
        ),
      ],
    ),
  );
}

/// `.mk-row`: Farb-Dot (9 px rund) · [fn] · „Zitat…" — Hover accent-soft.
class _MarkRow extends StatefulWidget {
  const _MarkRow({required this.mark, required this.onTap});

  final PdfMark mark;
  final VoidCallback onTap;

  @override
  State<_MarkRow> createState() => _MarkRowState();
}

class _MarkRowState extends State<_MarkRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final m = widget.mark;
    final zitat = m.zitat.length > 90 ? '${m.zitat.substring(0, 90)}…' : m.zitat;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hover ? t.accentSoft : t.surface,
            border: Border.all(color: _hover ? t.accentLine : t.borderStrong),
            borderRadius: BorderRadius.circular(BookClothTokens.radius),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // `.bc-dot`: 9×9 RUND (Belegstatus-Konvention).
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: markColorOf(m.farbe),
                  boxShadow: const [
                    BoxShadow(color: Color(0x14000000), spreadRadius: 1),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '[${m.fn ?? '—'}]',
                style: AppTextStyles.small.copyWith(
                  fontWeight: FontWeight.w700,
                  color: t.ink,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '„$zitat“',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.small.copyWith(color: t.ink2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
