/// Tests des RichText-Builders (core/richtext) — die verhaltensrelevanten
/// Regeln der `U.richText`-Pipeline (util.js:114-186): Sentinel-Trick,
/// Mark-Einfügeordnung, Erwähnungs-Anker, Xrefs, Highlight-Offsets.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/core/richtext/mini_md.dart';
import 'package:thesor/core/theme/theme.dart';
import 'package:thesor/core/richtext/richtext_builder.dart';
import 'package:thesor/core/richtext/source_matcher.dart';
import 'package:thesor/data/models/models.dart';

RichTextResolver _resolver({String? Function(String)? match}) =>
    RichTextResolver(
      levelOf: (fn) => fn % 4,
      fnPrimarySource: (fn) => 'src$fn',
      srcShort: (id) => id.toUpperCase(),
      matchSource: match ?? (_) => null,
      hasSection: (id) => const {'3.2', '5.0'}.contains(id),
    );

List<RichSegment> _run(String text,
        {RichTextOptions opts = const RichTextOptions(),
        RichTextResolver? res}) =>
    computeRichSegments(text, opts, res ?? _resolver());

String _plain(List<RichSegment> segs) => [
      for (final s in segs)
        if (s is TextSegment) s.text else '⟨${(s as FnSegment).num}⟩',
    ].join();

void main() {
  group('Fußnoten-Marker (Sentinel-Trick)', () {
    test('[^N] wird zum FnSegment, Text bleibt vollständig', () {
      final segs = _run('Ein Satz.[^12] Noch einer.[^7]');
      expect(_plain(segs), 'Ein Satz.⟨12⟩ Noch einer.⟨7⟩');
      expect(segs.whereType<FnSegment>().map((s) => s.num), [12, 7]);
    });

    test('Marks zerschneiden Marker nie (Snippet mit Marker-Text matcht nicht)',
        () {
      final segs = _run(
        'Vorher [^3] nachher',
        opts: const RichTextOptions(
          marks: [Mark(snippet: '[^3]', kategorie: 'abk')],
        ),
      );
      // Der Marker bleibt Chip; kein Mark-Segment entsteht.
      expect(segs.whereType<FnSegment>().length, 1);
      expect(
        segs.whereType<TextSegment>().every((s) => s.deco == null),
        isTrue,
      );
    });
  });

  group('Marks (Einfügeordnung wie das Original)', () {
    test('längstes Snippet zuerst; Teilstring bereits gesetzter übersprungen',
        () {
      final segs = _run(
        'Der EHDS-Verordnung Text EHDS Ende',
        opts: const RichTextOptions(marks: [
          Mark(snippet: 'EHDS', kategorie: 'abk'),
          Mark(snippet: 'EHDS-Verordnung', kategorie: 'tech'),
        ]),
      );
      final marked = segs
          .whereType<TextSegment>()
          .where((s) => s.deco is MarkDeco)
          .toList();
      // Nur das LANGE Snippet wird gesetzt — "EHDS" ist Teilstring davon
      // (done.some(d => d.includes(snip))) und wird verworfen.
      expect(marked.length, 1);
      expect(marked.single.text, 'EHDS-Verordnung');
      expect((marked.single.deco as MarkDeco).kategorie, 'tech');
    });

    test('nur das ERSTE Vorkommen eines Snippets wird markiert', () {
      final segs = _run(
        'Frist gilt. Die Frist endet.',
        opts: const RichTextOptions(
          marks: [Mark(snippet: 'Frist', kategorie: 'frist')],
        ),
      );
      final marked = segs
          .whereType<TextSegment>()
          .where((s) => s.deco is MarkDeco)
          .toList();
      expect(marked.length, 1);
      expect(segs.indexOf(marked.single), 0); // erstes Segment = erster Treffer
    });

    test('activeCats filtert Kategorien', () {
      final segs = _run(
        'Frist und Zahl',
        opts: const RichTextOptions(
          marks: [
            Mark(snippet: 'Frist', kategorie: 'frist'),
            Mark(snippet: 'Zahl', kategorie: 'zahl'),
          ],
          activeCats: {'zahl'},
        ),
      );
      final marked = segs
          .whereType<TextSegment>()
          .where((s) => s.deco is MarkDeco)
          .map((s) => s.text);
      expect(marked, ['Zahl']);
    });

    test('norm-Marks nur mit echter Register-Quelle (sonst verworfen)', () {
      final withMatch = _run(
        'Die DSGVO regelt.',
        opts: const RichTextOptions(
          marks: [Mark(snippet: 'DSGVO', kategorie: 'norm')],
        ),
        res: _resolver(match: (s) => s == 'DSGVO' ? 'dsgvo' : null),
      );
      final srcMark = withMatch
          .whereType<TextSegment>()
          .where((s) => s.deco is SrcMarkDeco)
          .toList();
      expect(srcMark.length, 1);
      expect((srcMark.single.deco as SrcMarkDeco).srcId, 'dsgvo');

      final without = _run(
        'Die DSGVO regelt.',
        opts: const RichTextOptions(
          marks: [Mark(snippet: 'DSGVO', kategorie: 'norm')],
        ),
      );
      expect(
        without.whereType<TextSegment>().every((s) => s.deco == null),
        isTrue,
      );
    });
  });

  group('Erwähnungen (fortlaufender Suchanker)', () {
    test('identische Snippets treffen je ihre EIGENE Stelle', () {
      const text = 'Kim (2023) sagt X. Später sagt Kim (2023) auch Y.';
      final segs = _run(
        text,
        opts: RichTextOptions(mentions: [
          RichMention(
              snippet: 'Kim (2023)', start: 0, status: 'offen', srcId: 'kim'),
          RichMention(
              snippet: 'Kim (2023)',
              start: text.indexOf('Kim (2023)', 1),
              status: 'beleg',
              srcId: 'kim',
              fn: 4),
        ]),
      );
      final ments = segs
          .whereType<TextSegment>()
          .where((s) => s.deco is MentionDeco)
          .toList();
      expect(ments.length, 2);
      expect((ments[0].deco as MentionDeco).mention.status, 'offen');
      expect((ments[1].deco as MentionDeco).mention.status, 'beleg');
      // Beide Stellen sind verschieden (kein doppeltes erstes Vorkommen).
      expect(_plain(segs), text);
    });
  });

  group('Querverweise', () {
    test('Abschnitt 3.2 wird Link, unbekannte Ziele bleiben Text', () {
      final segs = _run('Siehe Abschnitt 3.2 und Abschnitt 9.9.',
          opts: const RichTextOptions(xrefs: true));
      final xrefs = segs
          .whereType<TextSegment>()
          .where((s) => s.deco is XrefDeco)
          .toList();
      expect(xrefs.length, 1);
      expect((xrefs.single.deco as XrefDeco).target, '3.2');
      expect(xrefs.single.text, 'Abschnitt 3.2');
    });

    test('Kapitel N zielt auf N.0', () {
      final segs = _run('Kapitel 5 behandelt das.',
          opts: const RichTextOptions(xrefs: true));
      final xref = segs
          .whereType<TextSegment>()
          .firstWhere((s) => s.deco is XrefDeco);
      expect((xref.deco as XrefDeco).target, '5.0');
    });

    test('ohne xrefs-Option keine Links', () {
      final segs = _run('Siehe Abschnitt 3.2.');
      expect(
          segs.whereType<TextSegment>().every((s) => s.deco == null), isTrue);
    });
  });

  group('Highlights (Roh-Offsets mit Markern)', () {
    test('Spanne hinter einem Marker landet auf dem richtigen Text', () {
      const text = 'Erster Satz.[^10] Zweiter Satz.';
      final start = text.indexOf('Zweiter');
      final segs = _run(
        text,
        opts: RichTextOptions(highlights: [
          RichHighlight(start, text.length, RichHighlightKind.belegSpan),
        ]),
      );
      final hl = [
        for (final s in segs.whereType<TextSegment>())
          if (s.highlights.contains(RichHighlightKind.belegSpan)) s.text,
      ].join();
      expect(hl, 'Zweiter Satz.');
    });

    test('Spanne ÜBER einen Marker hinweg deckt beide Satzteile', () {
      const text = 'A Satz.[^2] B Satz.';
      final segs = _run(
        text,
        opts: const RichTextOptions(highlights: [
          RichHighlight(0, 19, RichHighlightKind.gptStyle),
        ]),
      );
      final hlText = [
        for (final s in segs.whereType<TextSegment>())
          if (s.highlights.contains(RichHighlightKind.gptStyle)) s.text,
      ].join();
      expect(hlText, 'A Satz. B Satz.');
      expect(segs.whereType<FnSegment>().length, 1);
    });
  });

  group('SourceTextMatcher (U.matchSourceInText)', () {
    final sources = [
      Source.fromJson(const {
        'id': 'dsgvo',
        'title': 'Verordnung (EU) 2016/679 (DSGVO)',
        'kind': 'recht-eu',
      }),
      Source.fromJson(const {
        'id': 'kim2023',
        'title': 'Health Data Paper',
        'author': 'Kimble, J.',
        'year': 2023,
        'kind': 'artikel',
      }),
    ];
    final matcher = SourceTextMatcher(
        sources, (id) => id == 'dsgvo' ? 'DSGVO' : 'Kimble 2023');

    test('Kurzname, Nummern-Muster und Autor-Nachname matchen', () {
      expect(matcher.match('die DSGVO verlangt'), 'dsgvo');
      expect(matcher.match('VO 2016/679'), 'dsgvo');
      expect(matcher.match('nach Kimble et al.'), 'kim2023');
    });

    test('zu kurze/fremde Snippets liefern null', () {
      expect(matcher.match('ab'), isNull);
      expect(matcher.match('Unbekanntes Werk'), isNull);
    });
  });

  group('miniMdInline', () {
    testWidgets('fett/kursiv/code werden zu Spans', (tester) async {
      // Nur die reine Span-Zerlegung — ohne Widget-Baum kein Theme nötig,
      // aber tokens braucht einen BuildContext → über pumpWidget.
      await tester.pumpWidget(MaterialAppWithTokens(
        child: Builder(builder: (context) {
          return const MiniMd('Ein **fetter** und *kursiver* `code`-Test');
        }),
      ));
      expect(find.byType(MiniMd), findsOneWidget);
      final rich = find.byType(RichText);
      expect(rich, findsWidgets);
    });
  });
}

/// Mini-App mit BookCloth-Theme für Widget-Checks.
class MaterialAppWithTokens extends StatelessWidget {
  const MaterialAppWithTokens({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: Scaffold(body: child),
    );
  }
}
