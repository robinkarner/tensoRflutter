/// LaTeX-Editor-Logik (Studio-Modus „Editor“) — Port des Logik-Teils von
/// `js/editor.js` (die Render-Funktion `renderEditorPane` wird in Welle 1
/// als Widget gebaut).
///
/// Abschnittsweises Bearbeiten des aus den geparsten Daten REKONSTRUIERTEN
/// LaTeX-Quelltexts mit Prüfbericht (erlaubte Befehle, Klammern,
/// Umgebungen), Live-Vorschau als strukturiertes Modell und .tex-Export.
/// Änderungen liegen ausschließlich im Store (`texEdits`) — die
/// Originaldaten bleiben unberührte „Ground Truth“.
library;

import '../data/models/json_utils.dart';
import '../data/models/models.dart';
import 'domain_context.dart';
import 'domain_store.dart';

// ---------------------------------------------------------------------------
// Vorschau-Modell (statt HTML-Strings): Blöcke aus Inline-Spans
// ---------------------------------------------------------------------------

/// Ein Inline-Stück der Vorschau.
sealed class PreviewSpan {
  const PreviewSpan();
}

/// Text mit akkumulierten Stil-Flags (\textbf/\textit/\emph verschachteln).
class PreviewTextSpan extends PreviewSpan {
  final String text;
  final bool bold;
  final bool italic;

  const PreviewTextSpan(this.text, {this.bold = false, this.italic = false});
}

/// Fußnote als hochgestellte laufende Nummer mit Tooltip
/// (Pendant zu `<sup class="pv-fn" title="…">N</sup>`).
class PreviewFootnoteSpan extends PreviewSpan {
  final int num;

  /// Fußnotentext ohne LaTeX-Befehle (Tooltip-Inhalt).
  final String tooltip;

  const PreviewFootnoteSpan(this.num, this.tooltip);
}

/// Ein Block der Vorschau.
sealed class PreviewBlock {
  const PreviewBlock();
}

/// Überschrift: \chapter → h2, \section → h3, \sub(sub)section → h4.
class PreviewHeadingBlock extends PreviewBlock {
  /// 2, 3 oder 4 (wie die HTML-Ebene des Originals).
  final int htmlLevel;
  final List<PreviewSpan> spans;

  const PreviewHeadingBlock(this.htmlLevel, this.spans);
}

/// Fließtext-Absatz (Zeilen mit Leerzeichen verbunden).
class PreviewParagraphBlock extends PreviewBlock {
  final List<PreviewSpan> spans;

  const PreviewParagraphBlock(this.spans);
}

/// Liste (itemize → ungeordnet, enumerate → geordnet).
class PreviewListBlock extends PreviewBlock {
  final bool ordered;
  final List<List<PreviewSpan>> items;

  const PreviewListBlock({required this.ordered, required this.items});
}

/// `%`-Kommentarzeile → „Platzhalter“-Kachel (Pendant zu
/// `<div class="fig-missing small"><span class="eyebrow">Platzhalter</span>…`).
class PreviewPlaceholderBlock extends PreviewBlock {
  final List<PreviewSpan> spans;

  const PreviewPlaceholderBlock(this.spans);
}

/// Ergebnis von [EditorLogic.preview].
class PreviewDocument {
  final List<PreviewBlock> blocks;

  const PreviewDocument(this.blocks);
}

/// Prüfbericht: Fehler (nicht kompilierbar) + Hinweise.
class LintResult {
  final List<String> errs;
  final List<String> warns;

  const LintResult({required this.errs, required this.warns});

  bool get ok => errs.isEmpty;
}

// ---------------------------------------------------------------------------
// Editor-Logik
// ---------------------------------------------------------------------------

class EditorLogic {
  final DomainContext ctx;
  final DomainStore store;

  EditorLogic(this.ctx, this.store);

  /// Erlaubte Befehle. Abweichung zum Original (W9-Fix, E9): `cite` ist
  /// AUFGENOMMEN — im Original fügt „＋ Quelle“ `\cite{id}` ein, obwohl
  /// `\cite` nicht erlaubt war, und der Lint meldete sofort einen Fehler.
  /// Dieser Selbstwiderspruch ist hier bewusst gefixt.
  static const List<String> allowed = [
    'chapter', 'section', 'subsection', 'subsubsection', 'textbf', 'textit', 'emph',
    'enquote', 'footnote', 'cite', 'item', 'begin', 'end', 'S', '%', '&', '_', ',', 'dots',
  ];
  static const List<String> allowedEnvs = ['itemize', 'enumerate'];

  /// Export-Dateinamen (editor.js:132/266).
  static const String exportAllName = 'thesis-export.tex';
  static String sectionExportName(String sectionId) =>
      'abschnitt-${sectionId.replaceAll('.', '_')}.tex';

  // ---- texEdits-Store (Map sectionId → kompletter editierter LaTeX-Text) --

  Map<String, String> edits() => {
        for (final e in store.readMap('texEdits').entries)
          if (e.value != null) e.key: asString(e.value),
      };

  void saveEdit(String id, String tex) {
    final e = store.readMap('texEdits');
    e[id] = tex;
    store.write('texEdits', e);
  }

  void clearEdit(String id) {
    final e = store.readMap('texEdits');
    e.remove(id);
    store.write('texEdits', e);
  }

  // ---- Rekonstruktion -----------------------------------------------------

  /// LaTeX eines Abschnitts aus den geparsten Daten rekonstruieren
  /// (editor.js:20-36). Intro-Abschnitte („X.0“) liefern den Kapitel-Kopf.
  String reconstruct(String sectionId) {
    final info = ctx.unitIndex[sectionId];
    if (info == null) return '';
    final u = info.unit;
    final ch = info.chapter;
    final depth = sectionId.split('.').length - 1;
    final head = u.isIntro
        ? '\\chapter{${ch.title}}'
        : '\\${depth == 1 ? 'section' : depth == 2 ? 'subsection' : 'subsubsection'}{${u.title}}';
    final paras = u.paragraphs.map((p) {
      if (p.typeEnum == ParagraphType.list) {
        return '\\begin{itemize}\n${p.items.map((i) => '  \\item ${inlineToTex(i)}').join('\n')}\n\\end{itemize}';
      }
      if (p.typeEnum == ParagraphType.figure || p.typeEnum == ParagraphType.table) {
        return '% ${p.text.isNotEmpty ? p.text : '[${p.type.toUpperCase()}]'}';
      }
      return inlineToTex(p.text);
    });
    return '$head\n\n${paras.join('\n\n')}\n';
  }

  /// `[^N]`-Marker → `\footnote{Originaltext der Fußnote}`.
  /// ✎-Anzeige-Overrides (fnEdits) bleiben Anzeige-Sache: ins LaTeX gehört
  /// IMMER der Originaltext (`fnOrigTexts`), sonst sickert der Override beim
  /// nächsten Absatz-Edit dauerhaft in texEdits ein (editor.js:38-47).
  String inlineToTex(String? text) {
    return (text ?? '').replaceAllMapped(RegExp(r'\[\^(\d+)\]'), (m) {
      final n = int.parse(m.group(1)!);
      final fn = ctx.fnIndex[n];
      if (fn == null) return '\\footnote{Fußnote $n}';
      return '\\footnote{${ctx.fnOrigTexts[n] ?? fn.text}}';
    });
  }

  // ---- Lint ---------------------------------------------------------------

  /// Prüfbericht im Compiler-Stil: erlaubte Befehle/Umgebungen, Klammern —
  /// jede Meldung mit Zeilennummer, klar getrennt in Fehler und Hinweise
  /// (editor.js:53-81, Meldungstexte wörtlich).
  LintResult lint(String? texInput) {
    final tex = texInput ?? '';
    final errs = <String>[];
    final warns = <String>[];
    final lines = tex.split('\n');
    int lineOf(int idx) => tex.substring(0, idx).split('\n').length;

    final letterAllowed =
        allowed.where((x) => RegExp(r'^[a-z]', caseSensitive: false).hasMatch(x));
    for (final m in RegExp(r'\\([a-zA-Z]+)').allMatches(tex)) {
      final c = m.group(1)!;
      if (!allowed.contains(c)) {
        errs.add(
            'Zeile ${lineOf(m.start)}: Unbekannter/nicht erlaubter Befehl \\$c — erlaubt sind: ${letterAllowed.map((x) => '\\$x').join(', ')}.');
      }
    }
    for (final m in RegExp(r'\\begin\{([a-zA-Z*]+)\}').allMatches(tex)) {
      if (!allowedEnvs.contains(m.group(1))) {
        errs.add(
            'Zeile ${lineOf(m.start)}: Nicht erlaubte Umgebung „${m.group(1)}“ — erlaubt: ${allowedEnvs.join(', ')}.');
      }
    }
    var depth = 0;
    var firstOpen = -1;
    for (var i = 0; i < tex.length; i++) {
      final ch = tex[i];
      if (ch == '{') {
        if (depth == 0) firstOpen = i;
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth < 0) {
          errs.add('Zeile ${lineOf(i)}: Schließende } ohne öffnende {.');
          depth = 0;
        }
      }
    }
    if (depth > 0) {
      errs.add('Zeile ${lineOf(firstOpen)}: $depth geschweifte Klammer(n) nicht geschlossen.');
    }
    final begins = RegExp(r'\\begin\{').allMatches(tex).length;
    final ends = RegExp(r'\\end\{').allMatches(tex).length;
    if (begins != ends) {
      errs.add('\\begin/\\end nicht balanciert ($begins begin / $ends end).');
    }
    // Hinweise (kompilierbar, aber auffällig)
    final mathRe = RegExp(r'[^\\]\$\S');
    for (var i = 0; i < lines.length; i++) {
      if (mathRe.hasMatch(' ${lines[i]}')) {
        warns.add('Zeile ${i + 1}: \$…\$-Mathematik wird im Studio nur als [Formel]-Marker übernommen.');
      }
    }
    return LintResult(errs: errs, warns: warns);
  }

  // ---- Vorschau -----------------------------------------------------------

  /// Brace-bewusstes Ersetzen: `\cmd{...}` → fn(inhalt) (editor.js:84-97).
  /// Wird von Wave-1-Code weiterverwendet (z. B. Notebook-Vorschau).
  static String replaceCmd(String str, String cmd, String Function(String inner) fn) {
    final out = StringBuffer();
    var i = 0;
    final needle = '\\$cmd{';
    while (i < str.length) {
      final idx = str.indexOf(needle, i);
      if (idx == -1) {
        out.write(str.substring(i));
        break;
      }
      out.write(str.substring(i, idx));
      var d = 1;
      var j = idx + needle.length;
      while (j < str.length && d > 0) {
        if (str[j] == '{') {
          d++;
        } else if (str[j] == '}') {
          d--;
        }
        j++;
      }
      out.write(fn(str.substring(idx + needle.length, d == 0 ? j - 1 : j)));
      i = j;
    }
    return out.toString();
  }

  /// Vorschau: eingeschränktes LaTeX → strukturiertes Block-Modell.
  ///
  /// Abweichung zum Original: `preview()` lieferte einen HTML-String; hier
  /// entsteht dieselbe Struktur als [PreviewDocument] (die Widgets bauen
  /// daraus RichText). Die Inline-Verarbeitung ist ein rekursiver Abstieg
  /// statt sequentieller String-Ersetzungen — für wohlgeformte Eingaben
  /// identisches Ergebnis; Fußnoten werden wie im Original dokumentweit
  /// fortlaufend nummeriert.
  PreviewDocument preview(String? texInput) {
    final tex = (texInput ?? '').replaceAll('\r', '');
    var fnCount = 0;

    // Zeichen-Ersetzungen des Originals auf reinen Textstücken
    // (\S → §, \, → schmales Leerzeichen, \% \& \_ \dots, -- → –).
    String chars(String s) => s
        .replaceAll(RegExp(r'\\S\b'), '§')
        .replaceAll(r'\,', '\u2009')
        .replaceAll(r'\%', '%')
        .replaceAll(r'\&', '&')
        .replaceAll(r'\_', '_')
        .replaceAll(RegExp(r'\\dots\b'), '…')
        .replaceAll('--', '–');

    // Rekursiver Inline-Parser: findet den JEWEILS NÄCHSTEN der 5 Befehle,
    // extrahiert brace-bewusst und steigt mit akkumulierten Stil-Flags ab.
    List<PreviewSpan> inline(String s, {bool bold = false, bool italic = false}) {
      final spans = <PreviewSpan>[];
      var i = 0;
      const cmds = ['footnote', 'textbf', 'textit', 'emph', 'enquote'];
      while (i < s.length) {
        var bestIdx = -1;
        String? bestCmd;
        for (final cmd in cmds) {
          final idx = s.indexOf('\\$cmd{', i);
          if (idx != -1 && (bestIdx == -1 || idx < bestIdx)) {
            bestIdx = idx;
            bestCmd = cmd;
          }
        }
        if (bestIdx == -1) {
          final rest = chars(s.substring(i));
          if (rest.isNotEmpty) spans.add(PreviewTextSpan(rest, bold: bold, italic: italic));
          break;
        }
        if (bestIdx > i) {
          final txt = chars(s.substring(i, bestIdx));
          if (txt.isNotEmpty) spans.add(PreviewTextSpan(txt, bold: bold, italic: italic));
        }
        // Inhalt brace-bewusst extrahieren (unbalanciert → bis Stringende)
        final open = bestIdx + bestCmd!.length + 2;
        var d = 1;
        var j = open;
        while (j < s.length && d > 0) {
          if (s[j] == '{') {
            d++;
          } else if (s[j] == '}') {
            d--;
          }
          j++;
        }
        final inner = s.substring(open, d == 0 ? j - 1 : j);
        switch (bestCmd) {
          case 'footnote':
            fnCount++;
            final tooltip = inner.replaceAll(RegExp(r'\\[a-zA-Z]+\{?|\}'), '');
            spans.add(PreviewFootnoteSpan(fnCount, tooltip));
          case 'textbf':
            spans.addAll(inline(inner, bold: true, italic: italic));
          case 'textit':
          case 'emph':
            spans.addAll(inline(inner, bold: bold, italic: true));
          case 'enquote':
            spans.add(PreviewTextSpan('„', bold: bold, italic: italic));
            spans.addAll(inline(inner, bold: bold, italic: italic));
            spans.add(PreviewTextSpan('“', bold: bold, italic: italic));
        }
        i = j;
      }
      return spans;
    }

    final blocks = <PreviewBlock>[];
    final para = <String>[];
    PreviewListBlock? openList;

    void flush() {
      if (para.isNotEmpty) {
        blocks.add(PreviewParagraphBlock(inline(para.join(' '))));
        para.clear();
      }
    }

    final headRe = RegExp(r'^\\(chapter|section|subsection|subsubsection)\{(.*)\}\s*$');
    for (final rawLine in tex.split('\n')) {
      final l = rawLine.trim();
      final h = headRe.firstMatch(l);
      if (h != null) {
        flush();
        openList = null;
        const tags = {'chapter': 2, 'section': 3, 'subsection': 4, 'subsubsection': 4};
        blocks.add(PreviewHeadingBlock(tags[h.group(1)]!, inline(h.group(2)!)));
        continue;
      }
      if (RegExp(r'^\\begin\{(itemize|enumerate)\}').hasMatch(l)) {
        flush();
        openList = PreviewListBlock(ordered: l.contains('enumerate'), items: []);
        blocks.add(openList);
        continue;
      }
      if (RegExp(r'^\\end\{(itemize|enumerate)\}').hasMatch(l)) {
        flush();
        openList = null;
        continue;
      }
      final it = RegExp(r'^\\item\s*(.*)').firstMatch(l);
      if (it != null) {
        flush();
        // \item außerhalb einer Umgebung: das Original rendert trotzdem ein
        // <li> — hier landet es in einer impliziten ungeordneten Liste.
        if (openList == null) {
          openList = PreviewListBlock(ordered: false, items: []);
          blocks.add(openList);
        }
        openList.items.add(inline(it.group(1)!));
        continue;
      }
      if (l.startsWith('%')) {
        flush();
        blocks.add(PreviewPlaceholderBlock(inline(l.substring(1).trim())));
        continue;
      }
      if (l.isEmpty) {
        flush();
        continue;
      }
      para.add(l);
    }
    flush();
    return PreviewDocument(blocks);
  }

  // ---- Gesamt-Export ------------------------------------------------------

  /// Das GANZE, kompilierbare LaTeX-Dokument aus allen Abschnitten (inkl.
  /// lokaler Editor-Änderungen) — mit Präambel, Titel und
  /// `\begin/\end{document}` (editor.js:139-160). Der `abstract`-Parameter
  /// entspricht `meta.abstract` des Originals (bei den mitgelieferten
  /// Arbeiten nie gesetzt).
  String fullDocument({String? abstract}) {
    final meta = ctx.thesis?.meta;
    final all = edits();
    final body = ctx.orderedUnitIds.map((id) => all[id] ?? reconstruct(id)).join('\n\n');
    final title = meta?.title ?? '';
    final subtitle = meta?.subtitle ?? '';
    final author = meta?.author ?? '';
    final university = meta?.university ?? '';
    final date = meta?.date ?? '';
    final lines = <String>[
      '% $title${subtitle.isNotEmpty ? ' — $subtitle' : ''}',
      '% Generiert aus Thesis Studio (lokale Änderungen eingerechnet)',
      '\\documentclass[11pt,a4paper]{report}',
      '\\usepackage[utf8]{inputenc}',
      '\\usepackage[T1]{fontenc}',
      '\\usepackage{hyperref}',
      '\\usepackage{graphicx}',
      '',
    ];
    if (title.isNotEmpty) {
      lines.add('\\title{$title${subtitle.isNotEmpty ? '\\\\[0.4em]\\large $subtitle' : ''}}');
    }
    if (author.isNotEmpty) {
      lines.add('\\author{$author${university.isNotEmpty ? '\\\\ $university' : ''}}');
    }
    lines.addAll(['\\date{${date.isNotEmpty ? date : '\\today'}}', '', '\\begin{document}', '\\maketitle', '']);
    if (abstract != null && abstract.isNotEmpty) {
      lines.addAll(['\\begin{abstract}', abstract, '\\end{abstract}', '']);
    }
    lines.addAll([body, '', '\\bibliographystyle{plain}', '% \\bibliography{lit}', '\\end{document}', '']);
    return lines.join('\n');
  }
}
