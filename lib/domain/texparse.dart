/// LaTeX→Struktur-Parser — Port von `js/texparse.js` (die 14-stufige
/// Pipeline komplett).
///
/// Parst kompletten `.tex`-Quelltext neuer Arbeiten zu
/// `{meta, chapters, footnotes, sources}` in denselben Datenformen wie
/// `data/parsed/`. Zusätzlich: robuste Vorverarbeitung für ROHES LaTeX
/// (Präambel, \mainmatter, figure/table → Marker, Mathematik → Marker,
/// \cite-Modus für Paper) und eine ausführliche DEUTSCHE Fehler-/
/// Warnungsliste, warum etwas nicht ladbar/darstellbar ist — die Texte sind
/// Teil der UI (Prüfbericht in „Neue Arbeit aus .tex“) und wörtlich
/// übernommen. Quellen werden über eine Registry (Regex-`aliases` als
/// Strings) den Fußnotentexten zugeordnet; ohne Registry bleiben Fußnoten
/// quellenlos (Warnung).
///
/// Die Ausgabe ist bewusst JSON-nah (Maps/Listen) — bitkompatibel zum
/// JS-Original und damit golden-testbar; [TexParseResult.thesisModel] und
/// [TexParseResult.sourceModels] liefern die typisierte Sicht für die
/// Projekt-Schicht.
library;

import '../data/models/models.dart';
import 'js_compat.dart';

/// Ergebnis von [TexParse.parse]. `ok == errors.isEmpty`; bei frühen
/// Fehlern (leere Eingabe, PDF statt .tex, keine Gliederung) fehlen
/// stats/thesis/footnotes/sources wie im Original.
class TexParseResult {
  final bool ok;
  final List<String> errors;
  final List<String> warnings;

  /// {kapitel, abschnitte, fussnoten, quellen}
  final Map<String, Object?>? stats;

  /// {meta, chapters} — JSON-Form wie `data/parsed/thesis.json`.
  final Map<String, Object?>? thesis;

  /// Flache Fußnotenliste [{num, text, sectionId?, paragraphId?}].
  final List<Map<String, Object?>>? footnotes;

  /// Registry-Einträge (ohne aliases) + expectedFile + citations.
  final List<Map<String, Object?>>? sources;

  const TexParseResult({
    required this.ok,
    required this.errors,
    required this.warnings,
    this.stats,
    this.thesis,
    this.footnotes,
    this.sources,
  });

  /// Exakte JSON-Form des JS-Ergebnisses (für Golden-Tests/Speicherung).
  Map<String, Object?> toJson() => {
        'ok': ok,
        'errors': errors,
        'warnings': warnings,
        if (stats != null) 'stats': stats,
        if (thesis != null) 'thesis': thesis,
        if (footnotes != null) 'footnotes': footnotes,
        if (sources != null) 'sources': sources,
      };

  /// Typisierte Struktur für die Projekt-Schicht (tolerantes fromJson).
  Thesis? get thesisModel {
    final t = thesis;
    return t == null ? null : Thesis.fromJson(Map<String, dynamic>.from(t));
  }

  /// Typisierte Quellen (inkl. citations) für die Projekt-Schicht.
  List<Source> get sourceModels => [
        for (final s in sources ?? const <Map<String, Object?>>[])
          Source.fromJson(Map<String, dynamic>.from(s)),
      ];
}

class TexParse {
  const TexParse._();

  /// Pakete, die die Übersetzung vollständig oder still abdeckt.
  static const Set<String> pkgOk = {
    'fontenc', 'inputenc', 'babel', 'csquotes', 'graphicx', 'hyperref', 'url', 'array',
    'booktabs', 'tabularx', 'longtable', 'geometry', 'microtype', 'xcolor', 'color', 'biblatex', 'natbib',
    'cite', 'enumitem', 'caption', 'subcaption', 'float', 'setspace', 'parskip', 'amssymb', 'amsfonts',
    'lmodern', 'mathptmx', 'times', 'helvet', 'courier', 'textcomp', 'ifthen', 'calc', 'etoolbox',
    'llncs', 'vutinfth', 'fancyhdr', 'titlesec', 'tocloft', 'appendix', 'breakurl', 'xurl', 'doi',
    'orcidlink', 'multirow', 'multicol', 'wrapfig', 'placeins', 'rotating', 'pdflscape', 'lscape',
    'threeparttable', 'makecell', 'verbatim', 'quoting',
  };

  /// Definierte Sammlung NICHT (voll) abgedeckter Pakete → präzise deutsche
  /// Meldung.
  static const Map<String, String> pkgNotes = {
    'tikz': 'Zeichnungen (TikZ) werden als [GRAFIK]-Marker ersetzt.',
    'pgfplots': 'Diagramme (pgfplots) werden als [GRAFIK]-Marker ersetzt.',
    'listings': 'Quelltext-Listings werden als [CODE]-Marker ersetzt.',
    'minted': 'Quelltext-Listings (minted) werden als [CODE]-Marker ersetzt.',
    'fancyvrb': 'Verbatim-Blöcke (fancyvrb) werden als [CODE]-Marker ersetzt.',
    'amsmath': 'Mathematik wird als [FORMEL]-Marker ersetzt.',
    'mathtools': 'Mathematik wird als [FORMEL]-Marker ersetzt.',
    'amsthm': 'Theorem-Umgebungen werden als Fließtext übernommen (ohne Nummerierung).',
    'algorithm': 'Pseudocode-Blöcke werden als [CODE]-Marker ersetzt.',
    'algorithm2e': 'Pseudocode-Blöcke werden als [CODE]-Marker ersetzt.',
    'algorithmicx': 'Pseudocode-Blöcke werden als [CODE]-Marker ersetzt.',
    'algpseudocode': 'Pseudocode-Blöcke werden als [CODE]-Marker ersetzt.',
    'siunitx': 'Einheiten-Makros (\\SI, \\si, \\num) erscheinen roh im Text (siehe Restbefehl-Bericht).',
    'glossaries': 'Glossar-Kurzformen (\\gls u. a.) werden entfernt — ausgeschriebene Begriffe gehen verloren.',
    'glossaries-extra': 'Glossar-Kurzformen (\\gls u. a.) werden entfernt — ausgeschriebene Begriffe gehen verloren.',
    'acronym': 'Abkürzungs-Makros (\\ac u. a.) erscheinen roh im Text (siehe Restbefehl-Bericht).',
    'chemfig': 'Chemische Strukturformeln sind nicht darstellbar — der Inhalt geht verloren.',
    'musixtex': 'Notensatz ist nicht darstellbar — der Inhalt geht verloren.',
    'pdfpages': 'Eingebundene PDF-Seiten (\\includepdf) können nicht übernommen werden.',
    'todonotes': 'Randnotizen (\\todo) erscheinen roh im Text (siehe Restbefehl-Bericht).',
    'tcolorbox': 'Farbige Boxen werden nicht dargestellt — der Inhalt kann als Rest verbleiben.',
  };

  /// TeX-Akzentmakros → Unicode (`\"a`, `\'e`, `` \`a ``, `\^o`, `\~n`,
  /// `\=o` — mit und ohne Braces).
  static const Map<String, String> accents = {
    '"a': 'ä', '"o': 'ö', '"u': 'ü', '"A': 'Ä', '"O': 'Ö', '"U': 'Ü', '"e': 'ë', '"i': 'ï', '"y': 'ÿ',
    "'a": 'á', "'e": 'é', "'i": 'í', "'o": 'ó', "'u": 'ú', "'y": 'ý', "'c": 'ć', "'n": 'ń', "'s": 'ś', "'z": 'ź',
    "'A": 'Á', "'E": 'É', "'I": 'Í', "'O": 'Ó', "'U": 'Ú',
    '`a': 'à', '`e': 'è', '`i': 'ì', '`o': 'ò', '`u': 'ù', '`A': 'À', '`E': 'È',
    '^a': 'â', '^e': 'ê', '^i': 'î', '^o': 'ô', '^u': 'û',
    '~n': 'ñ', '~a': 'ã', '~o': 'õ', '~N': 'Ñ',
    '=a': 'ā', '=e': 'ē', '=o': 'ō',
  };

  /// Alle \cite-Varianten, die zu Fußnoten-Äquivalenten werden.
  static final RegExp _citeRe = RegExp(
      r'\\(?:cite|citep|citet|autocite|Autocite|parencite|Parencite|footcite|footfullcite|fullcite|smartcite|Smartcite|textcite|Textcite)\s*(?:\[[^\]]*\])?\s*\{([^}]*)\}');

  // -------------------------------------------------------------------------
  // Haupteinstieg
  // -------------------------------------------------------------------------

  /// parse(texText, registry) → Ergebnis mit denselben Formen wie das
  /// JS-Original. `registry`: Liste von `{id, kind?, author?, year?, title?,
  /// aliases: [Regex-Strings], …beliebige Metafelder}`.
  static TexParseResult parse(String? tex, {List<Map<String, dynamic>>? registry}) {
    final errors = <String>[];
    final warnings = <String>[];
    if (tex == null || tex.trim().length < 40) {
      return TexParseResult(
        ok: false,
        errors: ['Leere oder viel zu kurze Eingabe — bitte den vollständigen LaTeX-Quelltext übergeben.'],
        warnings: warnings,
      );
    }
    if (tex.length >= 5 && tex.substring(0, tex.length < 20 ? tex.length : 20).contains('%PDF-')) {
      return TexParseResult(
        ok: false,
        errors: ['Das ist eine PDF-Datei, kein LaTeX-Quelltext (.tex). Bitte den Quelltext der Arbeit laden.'],
        warnings: warnings,
      );
    }

    // ---------- 0. Vorverarbeitung ----------
    var body = tex.replaceAll(RegExp('\r\n?'), '\n');
    final meta = extractMeta(body, warnings);
    // Paket-Abdeckung VOR dem Hauptteil-Zuschnitt prüfen (danach ist die
    // Präambel weg)
    scanPackages(body, warnings);

    // Nur Hauptteil: \mainmatter … \backmatter (falls vorhanden), sonst
    // document-Umgebung
    final mm = body.indexOf('\\mainmatter');
    final bm = body.indexOf('\\backmatter');
    if (mm != -1) {
      body = bm != -1 ? body.substring(mm, bm) : body.substring(mm);
    } else {
      final bd = body.indexOf('\\begin{document}');
      final ed = body.indexOf('\\end{document}');
      if (bd != -1) {
        final from = bd + '\\begin{document}'.length;
        body = ed != -1 ? body.substring(from, ed) : body.substring(from);
      } else {
        warnings.add('Kein \\begin{document} gefunden — die Datei wird als reiner Hauptteil interpretiert.');
      }
    }

    // Abstract/Kurzfassung NICHT wegwerfen: Inhalt (inkl. \keywords)
    // sichern — er erscheint als Front-Kapitel „0 · Abstract“ in der Anzeige.
    ({String title, String raw})? frontMatter;
    for (final e in [('abstract', 'Abstract'), ('kurzfassung', 'Kurzfassung')]) {
      final am = RegExp('\\\\begin\\{${e.$1}\\}([\\s\\S]*?)\\\\end\\{${e.$1}\\}').firstMatch(body);
      if (am != null && am.group(1)!.trim().isNotEmpty) {
        frontMatter = (title: e.$2, raw: am.group(1)!);
        break;
      }
    }
    final kwMatch = RegExp(r'\\keywords\{([\s\S]*?)\}').firstMatch(body);

    // filecontents/abstract/kurzfassung u. ä. aus dem Hauptteil entfernen
    for (final env in ['filecontents\\*?', 'abstract', 'kurzfassung', 'danksagung\\*?', 'acknowledgements\\*?', 'kitools']) {
      body = body.replaceAll(RegExp('\\\\begin\\{$env\\}[\\s\\S]*?\\\\end\\{$env\\}'), '');
    }

    // Verbatim-/Listing-/Algorithmus-Blöcke VOR dem Kommentarfilter ersetzen
    // ('%' ist dort Inhalt) und VOR der Zitat-Extraktion (\cite darf dort
    // nicht zählen).
    var nCode = 0;
    final codeEnvRe = RegExp(
        r'\\begin\{(verbatim|Verbatim|lstlisting|minted|algorithm|algorithmic)\*?\}(?:\[[^\]]*\])?(?:\{[^}]*\})?[\s\S]*?\\end\{\1\*?\}');
    body = body.replaceAllMapped(codeEnvRe, (m) {
      nCode++;
      return '\n\n[CODE: Quelltext-Auszug]\n\n';
    });
    body = body.replaceAllMapped(RegExp(r'\\lstinputlisting(?:\[[^\]]*\])?\{[^}]*\}'), (m) {
      nCode++;
      return '\n\n[CODE: Quelltext-Auszug]\n\n';
    });
    if (nCode > 0) {
      warnings.add(
          '$nCode Code-/Algorithmus-Block${nCode > 1 ? ' (mehrere)' : ''} durch [CODE]-Marker ersetzt — Listings sind im Studio nicht darstellbar.');
    }
    body = body.replaceAllMapped(RegExp(r'\\verb\*?([^a-zA-Z\s])(.*?)\1'), (m) => m.group(2)!);

    // Kommentare VOR der Zitat-/Fußnotenextraktion entfernen — ganze Zeilen
    // UND Zeilenrest-Kommentare („Text … %notiz \cite{x}“): sonst erzeugen
    // \cite/\footnote in Kommentaren verwaiste Fußnoten ohne Anker im Text.
    body = _stripComments(body);

    // ---------- 0b. \cite-basierte Arbeiten (Paper-Format, z. B. LLNCS) ----
    // \cite{a,b} wird zu einem Fußnoten-Äquivalent; die Quellen-Registry
    // entsteht automatisch aus den Bib-Keys (per registry.json ersetzbar).
    final citeKeys = <String>{}; // LinkedHashSet: Reihenfolge = Registry-Reihenfolge
    List<String> regKeys(String keys) {
      final list = keys.split(',').map((k) => k.trim()).where((k) => k.isNotEmpty).toList();
      citeKeys.addAll(list);
      return list;
    }

    // \nocite nimmt Quellen nur ins Verzeichnis auf — Keys registrieren,
    // kein Fußnotentext
    body = body.replaceAllMapped(RegExp(r'\\nocite\s*\{([^}]*)\}'), (m) {
      regKeys(m.group(1)!);
      return '';
    });
    // Autor-/Jahr-Varianten erscheinen als Fließtext (keine Fußnote), Keys
    // werden registriert
    body = body.replaceAllMapped(RegExp(r'\\[cC]iteauthor\*?\s*(?:\[[^\]]*\])?\s*\{([^}]*)\}'), (m) {
      return regKeys(m.group(1)!).map((k) {
        final author = sourceFromKey(k)['author'];
        return jsTruthy(author) ? '$author' : k;
      }).join(', ');
    });
    body = body.replaceAllMapped(RegExp(r'\\citeyear(par)?\s*(?:\[[^\]]*\])?\s*\{([^}]*)\}'), (m) {
      final ys = regKeys(m.group(2)!).map((k) => '${sourceFromKey(k)['year'] ?? '?'}');
      return m.group(1) != null ? '(${ys.join(', ')})' : ys.join(', ');
    });
    body = body.replaceAllMapped(_citeRe, (m) {
      final list = regKeys(m.group(1)!);
      return list.isNotEmpty ? '\\footnote{${list.join(', ')}}' : '';
    });
    var effectiveRegistry = registry ?? const <Map<String, dynamic>>[];
    if (citeKeys.isNotEmpty) {
      warnings.add(
          '\\cite-basierte Arbeit erkannt: ${citeKeys.length} Quellen aus den Bib-Keys übernommen — Metadaten sind daraus geraten und per registry.json (Gesamt-Prompt) ersetzbar.');
      if (effectiveRegistry.isEmpty) {
        effectiveRegistry = [for (final k in citeKeys) sourceFromKey(k)];
      }
    }

    // figure/table-Umgebungen → Marker-Absätze mit Caption
    body = body.replaceAllMapped(RegExp(r'\\begin\{(figure|table)\}[\s\S]*?\\end\{\1\}'), (m) {
      final block = m.group(0)!;
      final kind = m.group(1)!;
      final cap = RegExp(r'\\caption(?:\[[^\]]*\])?\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}').firstMatch(block);
      final label = kind == 'figure' ? 'ABBILDUNG' : 'TABELLE';
      final text = cap != null ? cap.group(1)!.replaceAll(r'\footnotemark', '').trim() : 'ohne Titel';
      return '\n\n[$label: $text]\n\n';
    });
    // TikZ-Zeichnungen außerhalb von figure-Umgebungen
    body = body.replaceAll(RegExp(r'\\begin\{tikzpicture\}[\s\S]*?\\end\{tikzpicture\}'), '\n\n[GRAFIK: TikZ-Zeichnung]\n\n');
    // tabularx/longtable u. ä. außerhalb von table-Umgebungen
    body = body.replaceAll(RegExp(r'\\begin\{(?:tabularx?|longtable)\}[\s\S]*?\\end\{(?:tabularx?|longtable)\}'), '\n\n[TABELLE: Tabelle im Fließtext]\n\n');
    // Mathematik → Marker; \$ (Dollarzeichen im Text) vorher schützen
    body = body.replaceAll(r'\$', '\u0001');
    var nMath = 0;
    String asFormula(Match m) {
      nMath++;
      return '\n\n[FORMEL]\n\n';
    }

    body = body.replaceAllMapped(
        RegExp(r'\\begin\{(equation|align|gather|multline|eqnarray|alignat|flalign|displaymath)\*?\}[\s\S]*?\\end\{\1\*?\}'), asFormula);
    body = body.replaceAllMapped(RegExp(r'\\\[[\s\S]*?\\\]'), asFormula);
    body = body.replaceAllMapped(RegExp(r'\$\$[\s\S]*?\$\$'), asFormula);
    body = body.replaceAllMapped(RegExp(r'\\\([\s\S]*?\\\)'), (m) {
      nMath++;
      return ' [Formel] ';
    });
    body = body.replaceAllMapped(RegExp(r'\$[^$\n]+\$'), (m) {
      nMath++;
      return ' [Formel] ';
    });
    body = body.replaceAll('\u0001', r'\$');
    if (nMath > 0) {
      warnings.add('$nMath Formel(n) durch [Formel]-Marker ersetzt — Mathematik ist im Studio nicht darstellbar.');
    }
    // \input/\include können im Browser nicht nachgeladen werden — explizit
    // melden
    for (final mIn in RegExp(r'\\(?:input|include)\{([^}]*)\}').allMatches(body)) {
      warnings.add(
          '\\input{${mIn.group(1)}} kann im Browser nicht nachgeladen werden — der Inhalt von „${mIn.group(1)}.tex“ fehlt in dieser Analyse. Bitte den Quelltext zu einer Datei zusammenführen.');
    }
    body = body.replaceAll(
        RegExp(
            r'\\(tableofcontents\*?|listoffigures|listoftables|printindex|printglossaries|addtitlepage\{[^}]*\}|addstatementpage\{[^}]*\}|selectlanguage\{[^}]*\}|frontmatter|appendix|cleardoublepage|newpage|input\{[^}]*\}|include\{[^}]*\}|addcontentsline\{[^}]*\}\{[^}]*\}\{[^}]*\})'),
        '');
    // Paper-Präambel-Reste (LLNCS u. ä.) im Dokumentkörper
    body = body.replaceAll(
        RegExp(
            r'\\(maketitle|title\{[^}]*\}|titlerunning\{[^}]*\}|author\{[^}]*\}|authorrunning\{[^}]*\}|institute\{[^}]*\}|keywords\{[^}]*\}|bibliographystyle\{[^}]*\}|bibliography\{[^}]*\}|thanks\{[^}]*\})'),
        '');
    // Zitat-Umgebungen auspacken — der Inhalt bleibt als eigener Absatz
    // erhalten
    body = body.replaceAll(RegExp(r'\\(?:begin|end)\{(?:quote|quotation|verse)\}'), '\n\n');
    // \chapter*{Literaturverzeichnis} / \section*{References} /
    // thebibliography abtrennen
    final starCh = RegExp(r'\\(chapter|section)\*\{|\\begin\{thebibliography\}').firstMatch(body);
    if (starCh != null) body = body.substring(0, starCh.start);

    // ---------- 1. Fußnoten extrahieren (brace-aware) ----------
    final footnotes = <Map<String, Object?>>[];
    final out = StringBuffer();
    var i = 0;
    while (i < body.length) {
      final idx = body.indexOf('\\footnote{', i);
      if (idx == -1) {
        out.write(body.substring(i));
        break;
      }
      out.write(body.substring(i, idx));
      var depth = 0;
      var k = idx + '\\footnote{'.length - 1;
      for (; k < body.length; k++) {
        if (body[k] == '{') {
          depth++;
        } else if (body[k] == '}') {
          depth--;
          if (depth == 0) break;
        }
      }
      if (depth != 0) {
        final line = body.substring(0, idx).split('\n').length;
        errors.add('Nicht geschlossene \\footnote{…} ab Zeile ~$line — geschweifte Klammern prüfen.');
        out.write(body.substring(idx, idx + 10 > body.length ? body.length : idx + 10));
        i = idx + 10;
        continue;
      }
      final fnText = body.substring(idx + '\\footnote{'.length, k);
      final num = footnotes.length + 1;
      footnotes.add({'num': num, 'text': cleanTex(fnText)});
      out.write('[^$num]');
      i = k + 1;
    }
    body = out.toString().split('\n').where((l) => !RegExp(r'^\s*%').hasMatch(l)).join('\n');

    // ---------- 2. Struktur ----------
    // \paragraph-Ebene: keine 5. Gliederungsstufe — als Absatzanfang
    // übernehmen
    if (RegExp(r'\\paragraph\*?\{').hasMatch(body)) {
      warnings.add('\\paragraph-Überschriften wurden als Absatzanfänge übernommen (keine eigene Gliederungsebene).');
      body = body.replaceAllMapped(RegExp(r'\\paragraph\*?\{([^}]*)\}\s*'), (m) {
        return '\n\n${m.group(1)!.replaceAll(RegExp(r'\.\s*$'), '')}. ';
      });
    }
    final structRe = RegExp(r'\\(chapter|section|subsection|subsubsection)\{([^}]*)\}');
    final tokens = <({String type, String value})>[];
    var last = 0;
    for (final m in structRe.allMatches(body)) {
      tokens.add((type: 'text', value: body.substring(last, m.start)));
      tokens.add((type: m.group(1)!, value: m.group(2)!));
      last = m.end;
    }
    tokens.add((type: 'text', value: body.substring(last)));

    if (!tokens.any((t) => t.type == 'chapter' || t.type == 'section')) {
      errors.add('Kein \\chapter{…} oder \\section{…} im Hauptteil gefunden — ohne Gliederung kann die Arbeit nicht aufgebaut werden.');
      return TexParseResult(ok: false, errors: errors, warnings: warnings);
    }
    final hasChapters = tokens.any((t) => t.type == 'chapter');
    if (!hasChapters) {
      warnings.add('Keine \\chapter-Ebene gefunden — \\section wird als oberste Ebene behandelt.');
    }

    final chapters = <Map<String, Object?>>[];
    Map<String, Object?>? curChapter, curSection, curSub;
    var chN = 0, secN = 0, subN = 0, subsubN = 0;

    /* Ohne \chapter-Ebene rückt alles eine Ebene hoch — die Verschiebung
     * passiert genau EINMAL beim Token (nicht in den Fallback-Rekursionen,
     * sonst würde z. B. eine \subsubsection ohne offene \subsection bis zur
     * Kapitel-Ebene durchrutschen). */
    String shiftLevel(String lvl) {
      if (!hasChapters) {
        if (lvl == 'section') return 'chapter';
        if (lvl == 'subsection') return 'section';
        if (lvl == 'subsubsection') return 'subsection';
      }
      return lvl;
    }

    // Sticky-Promotion: einmal angehobene Einheiten bleiben angehoben, damit
    // aufeinanderfolgende gleichrangige Überschriften Geschwister bleiben.
    final promoted = Set<Map<String, Object?>>.identity();

    late ({String id, Map<String, Object?> container, bool isIntro}) Function(String, String) unitFor;
    unitFor = (String level, String title) {
      if (level == 'chapter') {
        chN++;
        secN = 0;
        subN = 0;
        subsubN = 0;
        curChapter = {'id': '$chN', 'num': chN, 'title': title, 'sections': <Map<String, Object?>>[]};
        chapters.add(curChapter!);
        curSection = null;
        curSub = null;
        return (id: '$chN.0', container: curChapter!, isIntro: true);
      }
      if (curChapter == null) {
        chN++;
        curChapter = {'id': '$chN', 'num': chN, 'title': 'Hauptteil', 'sections': <Map<String, Object?>>[]};
        chapters.add(curChapter!);
      }
      if (level == 'section') {
        secN++;
        subN = 0;
        subsubN = 0;
        curSection = {'id': '$chN.$secN', 'title': title, 'level': 2, 'paragraphs': <Map<String, Object?>>[], 'children': <Map<String, Object?>>[]};
        (curChapter!['sections'] as List).add(curSection);
        curSub = null;
        return (id: curSection!['id'] as String, container: curSection!, isIntro: false);
      }
      if (level == 'subsection') {
        // Ohne offene \section wird die Ebene angehoben — und zwar STICKY:
        // aufeinanderfolgende gleichrangige Überschriften bleiben Geschwister
        // (z. B. mehrere \subsubsection direkt unter einem Kapitel).
        if (curSection == null || promoted.contains(curSection)) {
          final res = unitFor('section', title);
          promoted.add(res.container);
          return res;
        }
        subN++;
        subsubN = 0;
        curSub = {'id': '$chN.$secN.$subN', 'title': title, 'level': 3, 'paragraphs': <Map<String, Object?>>[], 'children': <Map<String, Object?>>[]};
        (curSection!['children'] as List).add(curSub);
        return (id: curSub!['id'] as String, container: curSub!, isIntro: false);
      }
      if (curSub == null || promoted.contains(curSub)) {
        final res = unitFor('subsection', title);
        promoted.add(res.container);
        return res;
      }
      subsubN++;
      final s4 = {'id': '$chN.$secN.$subN.$subsubN', 'title': title, 'level': 4, 'paragraphs': <Map<String, Object?>>[], 'children': <Map<String, Object?>>[]};
      (curSub!['children'] as List).add(s4);
      return (id: s4['id'] as String, container: s4, isIntro: false);
    };

    ({String id, Map<String, Object?> container, bool isIntro})? pending;
    for (final t in tokens) {
      if (t.type == 'text') {
        if (t.value.trim().isEmpty || pending == null) continue;
        final paras = parseParagraphs(t.value, pending.id);
        if (pending.isIntro) {
          if (paras.isNotEmpty) {
            final intro = {
              'id': '${pending.container['id']}.0',
              'title': 'Überblick',
              'level': 2,
              'paragraphs': paras,
              'children': <Map<String, Object?>>[],
              'isIntro': true,
            };
            (pending.container['sections'] as List).insert(0, intro);
          }
        } else {
          (pending.container['paragraphs'] as List).addAll(paras);
        }
      } else {
        pending = unitFor(shiftLevel(t.type), cleanTex(t.value).replaceAll(RegExp(r'\.\s*$'), ''));
      }
    }

    // ---------- 2b. Front-Kapitel „0 · Abstract/Kurzfassung“ ----------
    // Der gesicherte Abstract (+ Keywords) steht VOR Kapitel 1 in der
    // Anzeige — Zitate/Fußnoten im Abstract werden nicht gezählt.
    if (frontMatter != null) {
      var raw = frontMatter.raw
          .replaceAll(RegExp(r'\\keywords\{[\s\S]*?\}'), '')
          .replaceAll(_citeRe, '')
          .replaceAll(RegExp(r'\\nocite\s*\{[^}]*\}'), '')
          .replaceAll(RegExp(r'\\footnote\{[^{}]*\}'), '');
      // Dieselben Ersatz-Marker wie im Hauptteil — der Abstract lief an der
      // Verbatim-/Mathematik-Behandlung oben vorbei (er war da schon
      // gesichert)
      raw = raw
          .replaceAll(codeEnvRe, '\n\n[CODE: Quelltext-Auszug]\n\n')
          .replaceAll(RegExp(r'\\begin\{(equation|align|gather|multline|eqnarray|alignat|flalign|displaymath)\*?\}[\s\S]*?\\end\{\1\*?\}'), '\n\n[FORMEL]\n\n')
          .replaceAll(RegExp(r'\\\[[\s\S]*?\\\]'), '\n\n[FORMEL]\n\n')
          .replaceAll(RegExp(r'\$\$[\s\S]*?\$\$'), '\n\n[FORMEL]\n\n')
          .replaceAll(RegExp(r'\\\([\s\S]*?\\\)'), ' [Formel] ')
          .replaceAll(RegExp(r'\$[^$\n]+\$'), ' [Formel] ');
      raw = raw.split('\n').where((l) => !RegExp(r'^\s*%').hasMatch(l)).join('\n');
      final fparas = parseParagraphs(raw, '0.0');
      if (kwMatch != null) {
        final kws = cleanTex(kwMatch.group(1)!.replaceAll(RegExp(r'\\and\b'), ' · '))
            .replaceAll(RegExp(r'\s{2,}'), ' ')
            .replaceAll(RegExp(r'\.\s*$'), '')
            .trim();
        if (kws.isNotEmpty) {
          fparas.add({'id': '0.0-p${fparas.length + 1}', 'type': 'text', 'text': 'Keywords: $kws'});
        }
      }
      if (fparas.isNotEmpty) {
        chapters.insert(0, {
          'id': '0',
          'num': 0,
          'title': frontMatter.title,
          'sections': [
            {
              'id': '0.0',
              'title': frontMatter.title,
              'level': 2,
              'paragraphs': fparas,
              'children': <Map<String, Object?>>[],
            }
          ],
        });
      }
    }

    // ---------- 3. Registry-Matching + Fußnoten-Zuordnung ----------
    final compiled = <({Map<String, dynamic> entry, List<RegExp> res})>[];
    for (final r in effectiveRegistry) {
      if (!jsTruthy(r['id'])) continue;
      final res = <RegExp>[];
      for (final a in (r['aliases'] is List ? r['aliases'] as List : const [])) {
        try {
          res.add(RegExp('$a', caseSensitive: false));
        } catch (_) {
          warnings.add('Registry ${r['id']}: ungültiges alias-Muster "$a"');
        }
      }
      compiled.add((entry: r, res: res));
    }
    List<String> matchSources(String fnText) => [
          for (final r in compiled)
            if (r.res.any((re) => re.hasMatch(fnText))) '${r.entry['id']}',
        ];

    final fnByNum = {for (final f in footnotes) f['num'] as int: f};
    void walk(List units) {
      for (final u in units.cast<Map<String, Object?>>()) {
        for (final p in (u['paragraphs'] as List? ?? const []).cast<Map<String, Object?>>()) {
          final texts = p['type'] == 'list' ? (p['items'] as List? ?? const []).cast<String>() : ['${p['text'] ?? ''}'];
          final fns = <int>[];
          for (final t in texts) {
            for (final mm2 in RegExp(r'\[\^(\d+)\]').allMatches(t)) {
              fns.add(int.parse(mm2.group(1)!));
            }
          }
          p['footnotes'] = [
            for (final num in fns)
              () {
                final f = fnByNum[num];
                if (f != null) {
                  f['sectionId'] = u['id'];
                  f['paragraphId'] = p['id'];
                }
                return {
                  'num': num,
                  'text': f != null ? f['text'] : '',
                  'sources': f != null ? matchSources('${f['text']}') : const <String>[],
                };
              }(),
          ];
        }
        walk(u['children'] as List? ?? const []);
      }
    }

    walk([for (final c in chapters) ...(c['sections'] as List)]);

    final sources = <Map<String, Object?>>[
      for (final r in compiled)
        {
          for (final e in r.entry.entries)
            if (e.key != 'aliases') e.key: e.value,
          'expectedFile': 'sources/${r.entry['id']}.pdf',
          'citations': [
            for (final f in footnotes)
              if (matchSources('${f['text']}').contains('${r.entry['id']}'))
                {
                  'footnote': f['num'],
                  'sectionId': f['sectionId'],
                  'paragraphId': f['paragraphId'],
                  'footnoteText': f['text'],
                },
          ],
        },
    ];

    // ---------- 3b. Restbefehl-Scan: was hat die Übersetzung NICHT
    // geschafft? ----------
    residualScan(chapters, footnotes, warnings);

    // ---------- 4. Diagnose ----------
    var nUnits = 0;
    void countUnits(List units) {
      for (final u in units.cast<Map<String, Object?>>()) {
        if ((u['paragraphs'] as List? ?? const []).isNotEmpty) nUnits++;
        countUnits(u['children'] as List? ?? const []);
      }
    }

    for (final ch in chapters) {
      countUnits(ch['sections'] as List);
    }
    if (footnotes.isEmpty) {
      warnings.add('Keine \\footnote{…} gefunden — ohne Fußnoten gibt es keine Belege zum Prüfen.');
    }
    if (compiled.isEmpty) {
      warnings.add('Keine Quellen-Registry übergeben — Fußnoten bleiben ohne Quellenzuordnung (per Registry-Import nachholbar).');
    } else {
      final unmatched = footnotes.where((f) => matchSources('${f['text']}').isEmpty).length;
      if (unmatched > 0) {
        warnings.add('$unmatched von ${footnotes.length} Fußnoten ohne Quellen-Match (Registry-aliases prüfen).');
      }
    }
    if (nUnits == 0) {
      errors.add('Gliederung gefunden, aber keine Abschnitte mit Text — ist der Hauptteil leer?');
    }

    return TexParseResult(
      ok: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      stats: {'kapitel': chapters.length, 'abschnitte': nUnits, 'fussnoten': footnotes.length, 'quellen': sources.length},
      thesis: {'meta': meta, 'chapters': chapters},
      footnotes: footnotes,
      sources: sources,
    );
  }

  // -------------------------------------------------------------------------
  // Bausteine (öffentlich wie im Original — Projekt-Schicht nutzt sie einzeln)
  // -------------------------------------------------------------------------

  /// Präambel-Scan: meldet je Paket, was die Übersetzung damit macht
  /// (Warnungen).
  static void scanPackages(String tex, List<String> warnings) {
    final src = tex.split('\n').where((l) => !RegExp(r'^\s*%').hasMatch(l)).join('\n');
    final seen = <String>{};
    for (final m in RegExp(r'\\usepackage(?:\[[^\]]*\])?\{([^}]*)\}').allMatches(src)) {
      for (final p in m.group(1)!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty)) {
        if (seen.contains(p) || pkgOk.contains(p)) continue;
        seen.add(p);
        final note = pkgNotes[p];
        warnings.add(note != null
            ? 'Nicht abgedeckt: Paket „$p“ — $note'
            : 'Nicht abgedeckt: Paket „$p“ — unbekanntes Paket; zugehörige Befehle können als Rest im Text verbleiben (siehe Restbefehl-Bericht).');
      }
    }
  }

  /// Nach cleanTex sollte kein \befehl mehr im Text stehen. Was übrig
  /// bleibt, wird gesammelt gemeldet — der „LaTeX nicht vollständig
  /// übersetzbar“-Bericht.
  static void residualScan(List<Map<String, Object?>> chapters, List<Map<String, Object?>> footnotes, List<String> warnings) {
    final found = <String, ({int count, String first})>{};
    void note(Object? text, String where) {
      for (final m in RegExp(r'\\[a-zA-Z]+').allMatches('${text ?? ''}')) {
        final cmd = m.group(0)!;
        final e = found[cmd];
        found[cmd] = (count: (e?.count ?? 0) + 1, first: e?.first ?? where);
      }
    }

    void walk(List units) {
      for (final u in units.cast<Map<String, Object?>>()) {
        for (final p in (u['paragraphs'] as List? ?? const []).cast<Map<String, Object?>>()) {
          if (p['type'] == 'list') {
            for (final t in (p['items'] as List? ?? const [])) {
              note(t, 'Abschnitt ${u['id']}');
            }
          } else {
            note(p['text'], 'Abschnitt ${u['id']}');
          }
        }
        walk(u['children'] as List? ?? const []);
      }
    }

    walk([for (final c in chapters) ...(c['sections'] as List)]);
    for (final f in footnotes) {
      note(f['text'], 'Fußnote ${f['num']}');
    }
    if (found.isNotEmpty) {
      final list = stableSorted(found.entries, (a, b) => b.value.count - a.value.count)
          .map((e) => '${e.key} (${e.value.count}×, z. B. ${e.value.first})')
          .join(' · ');
      warnings.add('LaTeX nicht vollständig übersetzbar — verbleibende Befehle im Text: $list. Diese Stellen erscheinen roh; oben stehen die nicht abgedeckten Pakete dazu.');
    }
  }

  /// Metadaten aus der Präambel (vutinfth, LLNCS u. a.).
  static Map<String, Object?> extractMeta(String tex, List<String>? warnings) {
    String g(RegExp re) {
      final m = re.firstMatch(tex);
      return m != null ? cleanTex(m.group(1)!) : '';
    }

    var title = g(RegExp(r'\\settitle\{[^}]*\}\{([^}]*)\}'));
    if (title.isEmpty) title = g(RegExp(r'\\title\{([^}]*)\}'));
    if (title.isEmpty) title = g(RegExp(r'\\newcommand\{\\thesistitle\}\{([^}]*)\}'));
    final institute = g(RegExp(r'\\institute\{([^}]*)\}'));
    var author = g(RegExp(r'\\newcommand\{\\authorname\}\{([^}]*)\}'));
    if (author.isEmpty) author = g(RegExp(r'\\author\{([^}]*)\}'));
    final dateM = RegExp(r'\\setdate\{(\d+)\}\{(\d+)\}\{(\d+)\}').firstMatch(tex);
    final meta = <String, Object?>{
      'title': title.isNotEmpty ? title : 'Unbenannte Arbeit',
      'subtitle': g(RegExp(r'\\setsubtitle\{[^}]*\}\{([^}]*)\}')),
      'author': author,
      'university': institute.isNotEmpty
          ? institute
          : (RegExp('TU Wien|vutinfth|Technische Universität Wien').hasMatch(tex) ? 'Technische Universität Wien' : ''),
      'date': dateM != null ? [dateM.group(3), dateM.group(2), dateM.group(1)].join('-') : '',
      'thesisPdf': 'sources/thesis.pdf',
      'pageOffset': 0,
    };
    if (title.isEmpty && warnings != null) {
      warnings.add('Kein Titel gefunden (\\settitle/\\title) — „Unbenannte Arbeit“ verwendet.');
    }
    return meta;
  }

  /// Quellen-Stub aus einem Bib-Key (z. B. "abu-rasheed_context_2023"):
  /// Autor/Jahr/Titel sind daraus GERATEN — die richtige Registry kommt
  /// später über registry.json aus dem Gesamt-Prompt.
  static Map<String, dynamic> sourceFromKey(String key) {
    final clean = key.trim();
    final id = clean.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '-');
    final yearM = RegExp(r'(?:19|20)\d{2}').firstMatch(clean);
    final year = yearM != null ? int.parse(yearM.group(0)!) : null;
    final parts = clean.split('_').where((p) => p.isNotEmpty).toList();
    String cap(String w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1);
    final author = (parts.isNotEmpty ? parts.first : clean).split('-').map(cap).join('-');
    final titleWords = parts.skip(1).where((p) => !RegExp(r'^(?:19|20)\d{2}$').hasMatch(p)).toList();
    return {
      'id': id,
      'kind': 'artikel',
      'author': RegExp(r'^[A-Za-z]').hasMatch(author) ? author : '',
      'year': year,
      'title': titleWords.isNotEmpty ? cap(titleWords.join(' ')) : clean,
      'keyGuessed': true,
      'aliases': [RegExp.escape(clean)],
    };
  }

  /// LaTeX-Bereinigung (wie tools/parse_thesis.js) — Reihenfolge exakt.
  static String cleanTex(String? input) {
    var s = input ?? '';
    // Kommentare entfernen — escaptes \% bleibt (Lookbehind: % ohne
    // Backslash davor)
    s = s.replaceAll(RegExp(r'(?<!\\)%.*$', multiLine: true), '');
    s = s.replaceAllMapped(RegExp(r'\\href\{([^}]*)\}\{([^}]*)\}'), (m) => m.group(2)!);
    s = s.replaceAllMapped(RegExp(r'\\url\{([^}]*)\}'), (m) => m.group(1)!);
    s = s.replaceAllMapped(RegExp(r'\\text(it|sl|sc|bf|tt)\{([^}]*)\}'), (m) => m.group(2)!);
    s = s.replaceAllMapped(RegExp(r'\\emph\{([^}]*)\}'), (m) => m.group(1)!);
    s = s.replaceAllMapped(RegExp(r'\\enquote\{([^}]*)\}'), (m) => '„${m.group(1)}“');
    s = s.replaceAll(RegExp(r'\\glqq\s*'), '„');
    s = s.replaceAll(RegExp(r'\\grqq\{?\}?\s*'), '“');
    s = s.replaceAll(RegExp(r'\\(ref|label|cite|index|gls|acrshort|acrlong)\{[^}]*\}'), '');
    s = s.replaceAll(r'\footnotemark', '');
    s = s.replaceAll(RegExp(r'\\footnotetext\{[^}]*\}'), '');
    s = s.replaceAll('~', ' ');
    s = s.replaceAll(r'\,', ' ');
    s = s.replaceAll(r'\\', ' ');
    s = s.replaceAll(r'\&', '&');
    s = s.replaceAll(r'\%', '%');
    s = s.replaceAll(r'\_', '_');
    s = s.replaceAll(r'\#', '#');
    s = s.replaceAll(RegExp(r'\\S\b'), '§');
    s = s.replaceAll(RegExp(r'\\dots\b'), '…');
    s = s.replaceAll(r'\$', r'$');
    s = s.replaceAllMapped(RegExp('\\\\(["\'`^~=])\\{?([a-zA-Z])\\}?'), (m) {
      return accents['${m.group(1)}${m.group(2)}'] ?? m.group(2)!;
    });
    s = s.replaceAll(RegExp(r'\\ss\b\{?\}?'), 'ß');
    s = s.replaceAll(RegExp(r'\\ae\b'), 'æ');
    s = s.replaceAll(RegExp(r'\\AE\b'), 'Æ');
    s = s.replaceAll(RegExp(r'\\oe\b'), 'œ');
    s = s.replaceAll(RegExp(r'\\OE\b'), 'Œ');
    s = s.replaceAll(RegExp(r'\\aa\b'), 'å');
    s = s.replaceAll(RegExp(r'\\AA\b'), 'Å');
    s = s.replaceAll(RegExp(r'\\o\b'), 'ø');
    s = s.replaceAll(RegExp(r'\\O\b'), 'Ø');
    s = s.replaceAllMapped(RegExp(r'\\c\{([cC])\}'), (m) => m.group(1) == 'c' ? 'ç' : 'Ç');
    s = s.replaceAll(
        RegExp(
            r'\\(newpage|clearpage|cleardoublepage|noindent|centering|small|footnotesize|raggedright|arraybackslash|vspace\{[^}]*\}|hspace\{[^}]*\}|renewcommand\{[^}]*\}\{[^}]*\}|setlength\{[^}]*\}\{[^}]*\})'),
        '');
    s = s.replaceAll(RegExp(r'\\(toprule|midrule|bottomrule|addlinespace|hline)'), '');
    s = s.replaceAll(RegExp(r'\{|\}'), '');
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s.trim();
  }

  /// Absätze eines Textblocks (itemize/enumerate/description isolieren,
  /// Marker erkennen).
  static List<Map<String, Object?>> parseParagraphs(String raw, String unitId) {
    final paragraphs = <Map<String, Object?>>[];
    // JS `split` mit Capture-Gruppe: Teile UND Listen-Blöcke in Reihenfolge
    final listRe = RegExp(r'\\begin\{(?:itemize|enumerate|description)\}[\s\S]*?\\end\{(?:itemize|enumerate|description)\}');
    final parts = <String>[];
    var pos = 0;
    for (final m in listRe.allMatches(raw)) {
      parts.add(raw.substring(pos, m.start));
      parts.add(m.group(0)!);
      pos = m.end;
    }
    parts.add(raw.substring(pos));

    var pNum = 0;
    for (final part in parts) {
      if (part.trim().isEmpty) continue;
      if (RegExp(r'^\\begin\{(itemize|enumerate|description)\}').hasMatch(part)) {
        final inner = part.replaceAll(RegExp(r'\\(?:begin|end)\{(?:itemize|enumerate|description)\}(?:\[[^\]]*\])?'), '');
        // description-Items tragen ihr Label in [..] → „Label: Text“
        final items = <String>[];
        for (final s in inner.split(RegExp(r'\\item\b'))) {
          final lm = RegExp(r'^\s*\[([^\]]*)\]\s*([\s\S]*)$').firstMatch(s);
          final txt = lm != null
              ? '${cleanTex(lm.group(1))}: ${cleanTex(lm.group(2))}'.replaceAll(RegExp(r'^:\s*'), '')
              : cleanTex(s);
          if (txt.isNotEmpty) items.add(txt);
        }
        if (items.isEmpty) continue;
        pNum++;
        paragraphs.add({'id': '$unitId-p$pNum', 'type': 'list', 'items': items});
        continue;
      }
      // Absatztrenner: Leerzeile ODER \\ am Zeilenende (Paper-Stil)
      for (final chunk in part.split(RegExp(r'\n\s*\n|\\\\\s*\n'))) {
        final cleaned = cleanTex(chunk);
        if (cleaned.isEmpty) continue;
        final figMatch = RegExp(r'^\[(ABBILDUNG|TABELLE):\s*([\s\S]*)\]$').firstMatch(cleaned);
        pNum++;
        if (figMatch != null) {
          paragraphs.add({
            'id': '$unitId-p$pNum',
            'type': figMatch.group(1) == 'ABBILDUNG' ? 'figure' : 'table',
            'text': figMatch.group(2),
          });
        } else {
          paragraphs.add({'id': '$unitId-p$pNum', 'type': 'text', 'text': cleaned});
        }
      }
    }
    return paragraphs;
  }

  /// Ganze `%`-Zeilen filtern und Zeilenrest-Kommentare kappen.
  static String _stripComments(String body) => body
      .split('\n')
      .where((l) => !RegExp(r'^\s*%').hasMatch(l))
      .map((l) => l.replaceAll(RegExp(r'(?<!\\)%.*$'), ''))
      .join('\n');
}
