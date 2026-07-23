/// Verdrahtung des RichText-Builders mit der Studio-Datenwelt: Resolver
/// (Levels/Quellen/Xref-Ziele), Erwähnungs-Konvertierung und die
/// Satzspannen-Berechnung der Overlay-Highlights (Ersatz der Custom
/// Highlight API — `showBelegSpan` :1134, `applySrcView` :581,
/// `applyStyleCheck` :610).
library;

import '../../../core/richtext/richtext_builder.dart';
import '../../../data/models/models.dart';
import '../../../domain/domain.dart';
import 'studio_slots.dart';
import 'studio_state.dart';

/// Resolver über die Studio-Domäne (null-tolerant vor dem Boot).
RichTextResolver richResolverFor(StudioDomain? domain) {
  if (domain == null) return RichTextResolver.empty;
  return RichTextResolver(
    levelOf: (fn) => domain.levels.info(fn).level,
    fnPrimarySource: (fn) {
      final srcs = domain.ctx.fnIndex[fn]?.sources;
      return (srcs != null && srcs.isNotEmpty) ? srcs.first : null;
    },
    srcShort: domain.ctx.srcShort,
    matchSource: domain.matcher.match,
    hasSection: (id) => domain.ctx.unitIndex[id] != null,
  );
}

/// `Mentions.forPara`-Ergebnis → Renderer-Eingabe.
List<RichMention> richMentions(Iterable<Mention> mentions) => [
      for (final mt in mentions)
        RichMention(
          snippet: mt.snippet,
          start: mt.start,
          status: mt.status,
          srcId: mt.srcId,
          fn: mt.fn,
          candidateCount: mt.candidates.length,
        ),
    ];

/// Belegspanne einer Fußnote im Absatz als Highlight (Ersatz von
/// `showBelegSpan`): gespeicherter `belegSpans`-Wert + Erwähnungs-Heuristik.
/// Liefert Spanne + Highlight oder null.
(BelegSpanResult, RichHighlight)? belegSpanHighlight(
  StudioDomain domain,
  Map<String, Object?> snapshot,
  String sectionId,
  Paragraph p,
  int fnNum,
) {
  if (!p.isText) return null;
  final spans = snapshot['belegSpans'];
  int? storedBack;
  if (spans is Map) {
    final v = spans['$fnNum'];
    if (v is num) storedBack = v.toInt();
  }
  final span = belegSpan(
    p.text,
    fnNum,
    storedBack: storedBack,
    mentions: [
      for (final mt in domain.mentions.forPara(sectionId, p))
        BelegSpanMention(status: mt.status, fn: mt.fn, start: mt.start),
    ],
  );
  if (span == null) return null;
  return (
    span,
    RichHighlight(span.sents[span.from].start, span.sents[span.to].end,
        RichHighlightKind.belegSpan),
  );
}

/// ◘ Quelle-View: alle Sätze, deren Fußnoten die aktive Quelle enthalten —
/// satzgenau über die Voranalyse-Sätze; „nachgeschärft“ (strong), wo Zitat
/// erfasst oder die Phrase im PDF markiert ist (`applySrcView`, :581-606).
List<RichHighlight> srcViewHighlights(
  StudioDomain domain,
  String sectionId,
  Paragraph p,
  String srcId,
) {
  final gp = domain.genPara(sectionId, p.id);
  if (gp == null || !p.isText) return const [];
  final out = <RichHighlight>[];
  final markerRe = RegExp(r'\[\^(\d+)\]');
  var from = 0;
  for (final sen in gp.sentences) {
    final text = sen.text;
    if (text.isEmpty) continue;
    // Satz im (ggf. bearbeiteten) Absatztext wiederfinden — fortlaufender
    // Anker, damit identische Sätze ihre eigene Stelle treffen.
    final idx = p.text.indexOf(text, from);
    if (idx == -1) continue;
    from = idx + text.length;
    final fns = [
      for (final m in markerRe.allMatches(text)) int.parse(m.group(1)!),
    ];
    if (fns.isEmpty) continue;
    final mine = [
      for (final n in fns)
        if ((domain.ctx.fnIndex[n]?.sources ?? const []).contains(srcId)) n,
    ];
    if (mine.isEmpty) continue;
    final marks = StudioSlots.marksForFn;
    final sharp = mine.any((n) =>
        (domain.levels.info(n).zitat ?? '').isNotEmpty ||
        (marks != null && marks(srcId, n).isNotEmpty));
    out.add(RichHighlight(
      idx,
      idx + text.length,
      sharp ? RichHighlightKind.srcViewStrong : RichHighlightKind.srcView,
    ));
  }
  return out;
}

/// 🤖 Stil-Check: auffällige Sätze als `gpt-style`-Highlights
/// (`applyStyleCheck`, :610-623).
List<RichHighlight> styleCheckHighlights(Paragraph p) {
  if (!p.isText) return const [];
  return [
    for (final s in const StyleCheck().analyzePara(p.text))
      RichHighlight(s.start, s.end, RichHighlightKind.gptStyle),
  ];
}
