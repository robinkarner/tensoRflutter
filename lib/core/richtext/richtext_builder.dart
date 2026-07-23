/// Rich-Text-Renderer — Ersatz der U+0001-Sentinel-Pipeline von `U.richText`
/// (util.js:114-186) plus der vier Custom-Highlights (`beleg-span`,
/// `gpt-style`, `src-view`, `src-view-strong`), die es in Flutter nicht gibt
/// (Master §7 Risiko 2).
///
/// Arbeitsweise: Statt HTML-String-Chirurgie wird der ROHE Absatztext (mit
/// `[^N]`-Markern) in Segmente zerlegt. Die Fußnoten-Marker werden dabei wie
/// im Original zuerst durch Sentinels ersetzt, damit Marks/Erwähnungen/Xrefs
/// sie nie zerschneiden. Die Einfüge-REIHENFOLGE ist verhaltensrelevant und
/// exakt übernommen:
///   1. Marker → Sentinels (Chips entstehen zum Schluss daraus),
///   2. Marks — längste Snippets zuerst, Teilstrings bereits gesetzter
///      Snippets werden übersprungen, nur das ERSTE Vorkommen zählt;
///      Kategorie `norm` nur, wenn der Matcher eine echte Register-Quelle
///      findet (sonst verworfen),
///   3. Erwähnungen — nach `start` sortiert, mit fortlaufendem Suchanker
///      (identische Snippets treffen je ihre EIGENE Stelle),
///   4. Querverweise („Abschnitt 3.2“/„Kapitel 5“) auf noch freiem Text,
///   5. Sentinels → Fußnoten-Chips ([FnChip] als WidgetSpan).
///
/// Die Highlights (Satzspannen) kommen als Roh-Offsets herein und werden als
/// Hintergrund über die Segmente gelegt — `U.domRangeFor` entfällt komplett.
///
/// Der `lit`-Toggle (Klick auf Mark/Quellen-Mark/Erwähnung hebt hervor;
/// bei Quellen-Bezug öffnet der Aufrufer die Quelle) lebt im [RichTextView].
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../data/models/section_analysis.dart' show Mark;
import '../theme/color_mix.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'categories.dart';

// ---------------------------------------------------------------------------
// Eingabe-Modelle
// ---------------------------------------------------------------------------

/// Chip-Stil: `chip` (Prüfen — mit Quellen-Kurzname) | `mini` (Lesen).
enum FnStyle { chip, mini }

/// Erwähnungs-Eingabe (aus `Mentions.forPara`) — nur die Felder, die der
/// Renderer braucht.
class RichMention {
  final String snippet;
  final int start;

  /// 'beleg' (zusammengeführt) | 'bestaetigt' | 'offen'.
  final String status;
  final String srcId;
  final int? fn;
  final int candidateCount;

  const RichMention({
    required this.snippet,
    required this.start,
    required this.status,
    required this.srcId,
    this.fn,
    this.candidateCount = 1,
  });
}

/// Satz-/Bereichs-Hervorhebung (Roh-Offsets im Text MIT Markern).
enum RichHighlightKind { belegSpan, gptStyle, srcView, srcViewStrong }

class RichHighlight {
  final int start;
  final int end;
  final RichHighlightKind kind;

  const RichHighlight(this.start, this.end, this.kind);
}

/// Nachschlage-Funktionen aus der Datenwelt — hält den Builder Riverpod-frei
/// und testbar (features/studio verdrahtet die echten Provider).
class RichTextResolver {
  /// Beleg-Stufe einer Fußnote (Levels.info(n).level; 0 ohne Levels).
  final int Function(int fn) levelOf;

  /// Erste Quelle einer Fußnote (FN_INDEX[n].sources[0]) oder null.
  final String? Function(int fn) fnPrimarySource;

  /// Kurzname einer Quelle (U.srcShort).
  final String Function(String srcId) srcShort;

  /// „norm“-Mark → echte Register-Quelle oder null (U.matchSourceInText).
  final String? Function(String snippet) matchSource;

  /// Existiert der Abschnitt? (UNIT_INDEX-Check für Xrefs.)
  final bool Function(String sectionId) hasSection;

  const RichTextResolver({
    required this.levelOf,
    required this.fnPrimarySource,
    required this.srcShort,
    required this.matchSource,
    required this.hasSection,
  });

  /// Leerer Resolver (Tests/Fallbacks): Stufe 0, keine Quellen, keine Xrefs.
  static final RichTextResolver empty = RichTextResolver(
    levelOf: (_) => 0,
    fnPrimarySource: (_) => null,
    srcShort: (id) => id,
    matchSource: (_) => null,
    hasSection: (_) => false,
  );
}

/// Render-Optionen — Pendant zu den `opts` von `U.richText`.
class RichTextOptions {
  final List<Mark> marks;

  /// Aktive Kategorien (null = alle) — Set der `cats`-Keys.
  final Set<String>? activeCats;
  final FnStyle fnStyle;

  /// Quellen-Kurzname im Chip (Default: true bei [FnStyle.chip]).
  final bool? showSrc;

  /// Querverweise als Links rendern (Pendant zu `xrefBase != null`).
  final bool xrefs;
  final List<RichMention> mentions;
  final List<RichHighlight> highlights;

  /// ⚡-Schnelllesen: alle Marks voll ausgemalt (`.fastread`/`.fastread-on`).
  final bool fastread;

  const RichTextOptions({
    this.marks = const [],
    this.activeCats,
    this.fnStyle = FnStyle.chip,
    this.showSrc,
    this.xrefs = false,
    this.mentions = const [],
    this.highlights = const [],
    this.fastread = false,
  });

  bool get effectiveShowSrc => showSrc ?? fnStyle == FnStyle.chip;
}

// ---------------------------------------------------------------------------
// Segment-Modell (pure Zwischenform — direkt testbar)
// ---------------------------------------------------------------------------

/// Dekoration eines Textsegments (höchstens EINE — wie im Original, wo sich
/// die eingefügten Tags nie überlappen).
sealed class RichDeco {
  const RichDeco();
}

/// `mark.hl` — Kategorie-Mark. [decoId] identifiziert das zusammengehörige
/// Vorkommen (für den lit-Toggle über Segmentgrenzen).
class MarkDeco extends RichDeco {
  final String kategorie;
  final int decoId;
  const MarkDeco(this.kategorie, this.decoId);
}

/// `.mk-src` — Quellen-Mark (Kategorie `norm`, echte Register-Quelle).
class SrcMarkDeco extends RichDeco {
  final String srcId;
  final int decoId;
  const SrcMarkDeco(this.srcId, this.decoId);
}

/// `.mention` — Text-Erwähnung.
class MentionDeco extends RichDeco {
  final RichMention mention;
  final int decoId;
  const MentionDeco(this.mention, this.decoId);
}

/// `a.xref` — Querverweis. [target] ist die Abschnitts-ID („Kapitel N“ → N.0).
class XrefDeco extends RichDeco {
  final String word; // „Abschnitt“ | „Kapitel“
  final String num;
  final String target;
  const XrefDeco(this.word, this.num, this.target);
}

sealed class RichSegment {
  const RichSegment();
}

/// Fußnoten-Chip an dieser Stelle.
class FnSegment extends RichSegment {
  final int num;
  const FnSegment(this.num);
}

/// Textlauf mit optionaler Dekoration + Highlight-Menge.
class TextSegment extends RichSegment {
  final String text;
  final RichDeco? deco;
  final Set<RichHighlightKind> highlights;

  const TextSegment(this.text, {this.deco, this.highlights = const {}});
}

// ---------------------------------------------------------------------------
// Pipeline
// ---------------------------------------------------------------------------

final RegExp _markerRe = RegExp(r'\[\^(\d+)\]');
final RegExp _xrefRe = RegExp(r'\b(Abschnitt|Kapitel)\s+(\d+(?:\.\d+)*)\b');

class _Marker {
  final int num;
  final int rawStart, rawEnd; // Offsets im Rohtext
  final int start, end; // Offsets im Sentinel-Text
  const _Marker(this.num, this.rawStart, this.rawEnd, this.start, this.end);
}

class _Prepared {
  final String stripped; // Text mit Sentinels statt Markern
  final List<_Marker> markers;
  const _Prepared(this.stripped, this.markers);
}

/// Schritt 1: `[^N]` → `\x01<laufindex>\x01` (Sentinel-Trick, util.js:120).
_Prepared _prepare(String raw) {
  final b = StringBuffer();
  final markers = <_Marker>[];
  var pos = 0;
  var i = 0;
  for (final m in _markerRe.allMatches(raw)) {
    b.write(raw.substring(pos, m.start));
    final start = b.length;
    b.write('$i');
    markers.add(_Marker(int.parse(m.group(1)!), m.start, m.end, start, b.length));
    pos = m.end;
    i++;
  }
  b.write(raw.substring(pos));
  return _Prepared(b.toString(), markers);
}

/// Roh-Offset → Sentinel-Offset (für Highlights, deren Spannen auf dem
/// Rohtext mit Markern berechnet werden). [_Marker.start]/[_Marker.end]
/// sind bereits Sentinel-Offsets (inkl. aller vorherigen Verschiebungen).
int _mapRawOffset(List<_Marker> markers, int rawPos) {
  var delta = 0;
  for (final m in markers) {
    if (rawPos <= m.rawStart) break;
    if (rawPos >= m.rawEnd) {
      delta += (m.end - m.start) - (m.rawEnd - m.rawStart);
    } else {
      // Position IM Marker → aufs Sentinel-Ende klemmen (der Chip gehört
      // ganz zur Spanne — wie das Satzende inkl. Marker in splitSentences).
      return m.end;
    }
  }
  return rawPos + delta;
}

class _Placed {
  final int start;
  final int end;
  final RichDeco deco;
  const _Placed(this.start, this.end, this.deco);
}

/// Die reine Segment-Berechnung — Herzstück, ohne Widgets (Unit-testbar).
List<RichSegment> computeRichSegments(
  String? text,
  RichTextOptions opts,
  RichTextResolver res,
) {
  final raw = text ?? '';
  final prep = _prepare(raw);
  final s = prep.stripped;
  final placed = <_Placed>[];
  var decoSeq = 0;

  // --- 2. Marks (längste zuerst; Teilstring bereits gesetzter überspringen;
  //        erstes Vorkommen; norm nur mit echter Quelle) --------------------
  final use = [
    for (final m in opts.marks)
      if (opts.activeCats == null || opts.activeCats!.contains(m.kategorie)) m,
  ]..sort((a, b) => b.snippet.length - a.snippet.length);
  final done = <String>[];
  for (final m in use) {
    final snip = m.snippet;
    if (snip.isEmpty || done.any((d) => d.contains(snip))) continue;
    final idx = s.indexOf(snip);
    if (idx == -1) continue;
    // Überlappung mit bereits gesetzten Marks vermeiden (das Original setzt
    // Tags in den String ein — ein zweiter Treffer im selben Bereich würde
    // dort das erste, unveränderte Vorkommen weiter vorn treffen; auf dem
    // unveränderten Text heißt das: belegte Bereiche sind tabu).
    if (placed.any((p) => idx < p.end && idx + snip.length > p.start)) continue;
    if (m.kategorie == 'norm') {
      final srcId = res.matchSource(snip);
      if (srcId == null) continue;
      placed.add(_Placed(idx, idx + snip.length, SrcMarkDeco(srcId, decoSeq++)));
    } else {
      placed.add(_Placed(idx, idx + snip.length, MarkDeco(m.kategorie, decoSeq++)));
    }
    done.add(snip);
  }

  // --- 3. Erwähnungen (nach start sortiert, fortlaufender Anker) -----------
  final ments = [...opts.mentions]..sort((a, b) => a.start - b.start);
  var mFrom = 0;
  for (final mt in ments) {
    final snip = mt.snippet;
    if (snip.isEmpty) continue;
    var idx = s.indexOf(snip, mFrom);
    // Überlappungen mit Marks überspringen wie das Original (dort zerteilt
    // das eingefügte Tag den Text — der Snippet-Treffer schlägt fehl):
    while (idx != -1 && placed.any((p) => idx < p.end && idx + snip.length > p.start)) {
      idx = s.indexOf(snip, idx + 1);
    }
    if (idx == -1) continue;
    placed.add(_Placed(idx, idx + snip.length, MentionDeco(mt, decoSeq++)));
    mFrom = idx + snip.length;
  }

  // --- 4. Querverweise (nur mit xrefs; nur auf freiem Text) ----------------
  if (opts.xrefs) {
    for (final m in _xrefRe.allMatches(s)) {
      final word = m.group(1)!;
      final num = m.group(2)!;
      final target = word == 'Kapitel' ? '$num.0' : num;
      if (!res.hasSection(target)) continue;
      if (placed.any((p) => m.start < p.end && m.end > p.start)) continue;
      placed.add(_Placed(m.start, m.end, XrefDeco(word, num, target)));
    }
  }

  placed.sort((a, b) => a.start - b.start);

  // --- Highlights: Roh-Offsets → Sentinel-Offsets --------------------------
  final hls = [
    for (final h in opts.highlights)
      (
        start: _mapRawOffset(prep.markers, h.start),
        end: _mapRawOffset(prep.markers, h.end),
        kind: h.kind,
      ),
  ];

  Set<RichHighlightKind> hlAt(int start, int end) => {
        for (final h in hls)
          if (start < h.end && end > h.start) h.kind,
      };

  // --- Segmentierung: Marker + Deko-Grenzen + Highlight-Grenzen ------------
  final cuts = <int>{0, s.length};
  for (final m in prep.markers) {
    cuts.add(m.start);
    cuts.add(m.end);
  }
  for (final p in placed) {
    cuts.add(p.start);
    cuts.add(p.end);
  }
  for (final h in hls) {
    cuts.add(h.start.clamp(0, s.length));
    cuts.add(h.end.clamp(0, s.length));
  }
  final sorted = cuts.toList()..sort();

  final segments = <RichSegment>[];
  for (var i = 0; i + 1 < sorted.length; i++) {
    final a = sorted[i], b = sorted[i + 1];
    if (b <= a) continue;
    // Segment liegt in einem Marker (ganz oder — durch Highlight-Schnitte —
    // teilweise): der Chip entsteht genau EINMAL, am Marker-Anfang.
    _Marker? inMarker;
    for (final m in prep.markers) {
      if (a >= m.start && b <= m.end) {
        inMarker = m;
        break;
      }
    }
    if (inMarker != null) {
      if (inMarker.start == a) segments.add(FnSegment(inMarker.num));
      continue;
    }
    RichDeco? deco;
    for (final p in placed) {
      if (a >= p.start && b <= p.end) {
        deco = p.deco;
        break;
      }
    }
    segments.add(TextSegment(s.substring(a, b), deco: deco, highlights: hlAt(a, b)));
  }
  return segments;
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

/// Klick-Rückrufe des gerenderten Textes.
class RichTextCallbacks {
  /// Fußnoten-Chip (delegiert global ans Fußnoten-Modal, app.js:76-81).
  final void Function(int fn)? onFnTap;

  /// Quellen-Bezug angeklickt und dadurch HERVORGEHOBEN (`lit` an):
  /// `mk-src` und Erwähnungen (app.js:86-99). [fn] nur bei zusammengeführten
  /// Erwähnungen (`data-fn`).
  final void Function(String srcId, int? fn)? onSrcLit;

  /// Querverweis (Navigation `#/studio/<target>`).
  final void Function(String sectionId)? onXrefTap;

  const RichTextCallbacks({this.onFnTap, this.onSrcLit, this.onXrefTap});
}

/// Der gerenderte Rich-Text: übernimmt Segment-Berechnung, `lit`-Zustand
/// und Gesture-Verwaltung. Pendant zu einem mit `U.richText` gefüllten
/// Container inkl. der globalen Klick-Delegation.
class RichTextView extends StatefulWidget {
  const RichTextView(
    this.text, {
    super.key,
    required this.style,
    this.options = const RichTextOptions(),
    this.resolver,
    this.callbacks = const RichTextCallbacks(),
    this.textAlign = TextAlign.left,
  });

  final String? text;
  final TextStyle style;
  final RichTextOptions options;
  final RichTextResolver? resolver;
  final RichTextCallbacks callbacks;
  final TextAlign textAlign;

  @override
  State<RichTextView> createState() => _RichTextViewState();
}

class _RichTextViewState extends State<RichTextView> {
  /// `lit`-Zustand je Deko-Vorkommen (decoId) — überlebt Rebuilds desselben
  /// States, wird beim Textwechsel verworfen (wie der DOM-Neuaufbau).
  final Set<int> _lit = {};
  final List<GestureRecognizer> _recognizers = [];

  @override
  void didUpdateWidget(RichTextView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _lit.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  TapGestureRecognizer _tap(VoidCallback fn) {
    final r = TapGestureRecognizer()..onTap = fn;
    _recognizers.add(r);
    return r;
  }

  /// Hintergrund einer Highlight-Menge (::highlight-Regeln, app.css:1086-1087,
  /// 2241-2242). Stärkstes gewinnt: srcViewStrong > belegSpan > gptStyle >
  /// srcView.
  Color? _highlightColor(BookClothTokens t, Set<RichHighlightKind> hl) {
    if (hl.contains(RichHighlightKind.srcViewStrong)) return t.catNorm.alphaPct(32);
    if (hl.contains(RichHighlightKind.belegSpan)) return t.accent.alphaPct(16);
    if (hl.contains(RichHighlightKind.gptStyle)) return t.warn.alphaPct(22);
    if (hl.contains(RichHighlightKind.srcView)) return t.catNorm.alphaPct(14);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final t = BookClothTokens.of(context);
    final res = widget.resolver ?? RichTextResolver.empty;
    final opts = widget.options;
    final cb = widget.callbacks;
    final segments = computeRichSegments(widget.text, opts, res);

    final spans = <InlineSpan>[];
    for (final seg in segments) {
      switch (seg) {
        case FnSegment(:final num):
          final lvl = res.levelOf(num);
          final srcId = res.fnPrimarySource(num);
          final lvlName = switch (lvl) {
            1 => 'Stufe 1 · KI-vermutet',
            2 => 'Stufe 2 · Original gefunden',
            3 => 'Stufe 3 · belegt',
            _ => 'offen',
          };
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: _FnChipInline(
                num: num,
                level: lvl,
                mini: opts.fnStyle == FnStyle.mini,
                srcShort: opts.effectiveShowSrc && srcId != null
                    ? res.srcShort(srcId)
                    : null,
                tooltip: 'Fußnote $num — $lvlName · klicken für Beleg',
                onTap: cb.onFnTap == null ? null : () => cb.onFnTap!(num),
              ),
            ),
          ));
        case TextSegment(:final text, :final deco, :final highlights):
          final hlColor = _highlightColor(t, highlights);
          switch (deco) {
            case null:
              spans.add(TextSpan(
                text: text,
                style: hlColor == null ? null : TextStyle(backgroundColor: hlColor),
              ));
            case MarkDeco(:final kategorie, :final decoId):
              final c = t.cat(kategorie) ?? t.accent;
              final lit = _lit.contains(decoId) || opts.fastread;
              // mark.hl: Wash + kräftige Unterstreichung; .lit/⚡ voll.
              spans.add(TextSpan(
                text: text,
                style: TextStyle(
                  backgroundColor:
                      hlColor ?? (lit ? c.alphaPct(26) : c.alphaPct(9)),
                  fontWeight: lit ? FontWeight.w600 : null,
                  decoration: TextDecoration.underline,
                  decorationColor: lit ? c : c.alphaPct(55),
                  decorationThickness: 2,
                ),
                recognizer: _tap(() => setState(() {
                      _lit.contains(decoId) ? _lit.remove(decoId) : _lit.add(decoId);
                    })),
              ));
            case SrcMarkDeco(:final srcId, :final decoId):
              final c = t.catNorm;
              final lit = _lit.contains(decoId) || opts.fastread;
              // .mk-src: dezent gepunktet; .lit/⚡: Wash + solide Linie.
              spans.add(TextSpan(
                text: text,
                style: TextStyle(
                  backgroundColor: hlColor ?? (lit ? c.alphaPct(20) : null),
                  color: lit ? c.mix(t.ink, 72) : null,
                  fontWeight: lit ? FontWeight.w600 : null,
                  decoration: TextDecoration.underline,
                  decorationColor: lit ? c : c.alphaPct(65),
                  decorationStyle:
                      lit ? TextDecorationStyle.solid : TextDecorationStyle.dotted,
                  decorationThickness: lit ? 2 : 1.5,
                ),
                recognizer: _tap(() {
                  final wasLit = _lit.contains(decoId);
                  setState(() {
                    wasLit ? _lit.remove(decoId) : _lit.add(decoId);
                  });
                  // AN geschaltet → Quelle rechts öffnen (app.js:92-98).
                  if (!wasLit) cb.onSrcLit?.call(srcId, null);
                }),
              ));
            case MentionDeco(:final mention, :final decoId):
              final lit = _lit.contains(decoId);
              final merged = mention.status == 'beleg';
              final bestaetigt = mention.status == 'bestaetigt';
              spans.add(TextSpan(
                text: text,
                style: TextStyle(
                  backgroundColor: hlColor ?? (lit ? t.ki.alphaPct(20) : null),
                  fontWeight: lit ? FontWeight.w600 : null,
                  decoration: TextDecoration.underline,
                  decorationColor: merged
                      ? t.accentLine
                      : bestaetigt
                          ? t.good
                          : t.ki,
                  decorationStyle: merged || bestaetigt
                      ? TextDecorationStyle.solid
                      : TextDecorationStyle.dotted,
                  decorationThickness: 2,
                ),
                recognizer: _tap(() {
                  final wasLit = _lit.contains(decoId);
                  setState(() {
                    wasLit ? _lit.remove(decoId) : _lit.add(decoId);
                  });
                  if (!wasLit) {
                    cb.onSrcLit?.call(
                        mention.srcId, merged ? mention.fn : null);
                  }
                }),
              ));
            case XrefDeco(:final target):
              spans.add(TextSpan(
                text: text,
                style: TextStyle(
                  backgroundColor: hlColor,
                  color: t.accentInk,
                  decoration: TextDecoration.underline,
                  decorationColor: t.accent.alphaPct(35),
                ),
                recognizer: cb.onXrefTap == null
                    ? null
                    : _tap(() => cb.onXrefTap!(target)),
              ));
          }
      }
    }

    return Text.rich(
      TextSpan(style: widget.style, children: spans),
      textAlign: widget.textAlign,
    );
  }
}

/// Fußnoten-Chip als Inline-Baustein (`.fn-chip` / `.fn-chip.mini`,
/// theme.css:381-405) — eigene, kompakte Variante statt [FnChip] aus
/// core/widgets, weil die Inline-Metrik (vertical-align, Mini-Nacktform)
/// vom Karten-Chip abweicht.
class _FnChipInline extends StatefulWidget {
  const _FnChipInline({
    required this.num,
    required this.level,
    required this.mini,
    this.srcShort,
    this.tooltip,
    this.onTap,
  });

  final int num;
  final int level;
  final bool mini;
  final String? srcShort;
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  State<_FnChipInline> createState() => _FnChipInlineState();
}

class _FnChipInlineState extends State<_FnChipInline> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final mini = widget.mini;
    final dot = t.lvl(widget.level);

    final chip = Container(
      padding: mini
          ? const EdgeInsets.symmetric(horizontal: 3, vertical: 1)
          : const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
      decoration: BoxDecoration(
        color: _hover ? t.accentSoft : (mini ? Colors.transparent : t.surface2),
        border: mini
            ? null
            : Border.all(color: _hover ? t.accentLine : t.border),
        borderRadius: BorderRadius.circular(mini ? 4 : 6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: mini ? 5 : 6,
            height: mini ? 5 : 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dot ?? Colors.transparent,
              border: dot == null
                  ? Border.all(color: t.muted, width: 1.3)
                  : null,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${widget.num}',
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontFamilyFallback: AppFonts.fallback,
              fontWeight: FontWeight.w600,
              fontSize: mini ? 10 : 10.5,
              height: 1,
              color: mini || _hover ? t.accentInk : t.ink2,
            ),
          ),
          if (!mini && widget.srcShort != null) ...[
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 84),
              child: Text(
                widget.srcShort!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontFamilyFallback: AppFonts.fallback,
                  fontWeight: FontWeight.w500,
                  fontSize: 10.5,
                  height: 1,
                  color: t.ink2,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    Widget out = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(onTap: widget.onTap, child: chip),
    );
    if (widget.tooltip != null) {
      out = Tooltip(message: widget.tooltip!, child: out);
    }
    return out;
  }
}

/// Zusatz-Label einer Kategorie (Tooltip-Text der Marks) — hier zentral,
/// damit alle Konsumenten dieselben Texte nutzen.
String markTooltip(String kategorie) =>
    '${catLabels[kategorie] ?? kategorie} — klicken zum Hervorheben';
