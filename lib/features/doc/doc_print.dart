/// 🖨-Druck der `#/doc`-Ansicht — Pendant zu `window.print()` samt
/// Print-CSS (app.css:1292-1300, 1999-2006: Lesefläche 11pt/1.5, h1 20pt,
/// weißer Grund, Chrome ausgeblendet), umgesetzt mit dem `printing`/`pdf`-
/// Paket als ECHTES Dokument-PDF:
///
/// * Titelseite aus den Meta-Daten (Titel/Untertitel/Autor/Uni/Datum —
///   das `\maketitle`-Pendant der report-Klasse),
/// * je Kapitel ein eigener Seitenlauf (Kapitel-Kopf „Kapitel n" + Titel),
///   darunter die Abschnitts-Hierarchie mit Überschriften nach
///   Gliederungsebene,
/// * Absätze im PT-Serif-Satz (E1) mit hochgestellten `[^N]`-Fußnoten-
///   Markern, Listen als Aufzählungen,
/// * Abbildungen/Tabellen aus dem Manifest: eingebettete Bilder
///   (Asset oder FigStore-Upload, siehe `doc_images.dart`) bzw. echte
///   Tabellen — ohne Bild bleibt der kursive Platzhalter,
/// * Fußnoten als **Endnoten je Kapitel** (die Web-Druckansicht verliert
///   die Fußnotentexte komplett — hier stehen sie gesammelt am
///   Kapitelende; echte Seitenfußnoten kann das pdf-Paket im
///   MultiPage-Fluss nicht setzen, bewusste Abweichung),
/// * Struktur-Beschriftungen (Kapitel-Eyebrow, Bildunterschriften,
///   Fußnoten-Nummern, Seitenzahlen) in Inter — der UI-Schrift der App.
library;

import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/models/models.dart';

/// `[^N]`-Fußnoten-Marker.
final RegExp kFnMarkerRe = RegExp(r'\[\^(\d+)\]');

/// `[ABBILDUNG: …]`/`[TABELLE: …]`-Marker (stripFigMarker-Pendant).
final RegExp _figMarkerRe = RegExp(r'\s*\[(?:ABBILDUNG|TABELLE):[^\]]*\]\s*');

/// Absatztext → Spans: Fließtext + hochgestellte Fußnoten-Nummern.
/// Sichtbar getestet und von [buildThesisPdfBytes] genutzt.
List<({String text, int? fn})> splitFnMarkers(String text) {
  final out = <({String text, int? fn})>[];
  var pos = 0;
  for (final m in kFnMarkerRe.allMatches(text)) {
    if (m.start > pos) out.add((text: text.substring(pos, m.start), fn: null));
    out.add((text: m.group(1)!, fn: int.parse(m.group(1)!)));
    pos = m.end;
  }
  if (pos < text.length) out.add((text: text.substring(pos), fn: null));
  return out;
}

/// Fußnoten eines Unit-Baums in Dokumentreihenfolge einsammeln
/// (Marker im Text/Listen-Items zuerst, dann restliche footnotes-Einträge).
void _collectFns(List<Unit> units, Set<int> seen, List<int> order) {
  void take(String text) {
    for (final m in kFnMarkerRe.allMatches(text)) {
      final n = int.parse(m.group(1)!);
      if (seen.add(n)) order.add(n);
    }
  }

  for (final u in units) {
    for (final p in u.paragraphs) {
      take(p.text);
      for (final item in p.items) {
        take(item);
      }
      for (final f in p.footnotes) {
        if (seen.add(f.num)) order.add(f.num);
      }
    }
    _collectFns(u.children, seen, order);
  }
}

/// Die im Dokument tatsächlich referenzierten Fußnoten in Dokumentreihenfolge.
List<int> collectFnOrder(Thesis thesis) {
  final seen = <int>{};
  final order = <int>[];
  for (final ch in thesis.chapters) {
    _collectFns(ch.sections, seen, order);
  }
  return order;
}

/// Die in EINEM Kapitel referenzierten Fußnoten in Dokumentreihenfolge —
/// Grundlage der Endnoten je Kapitel.
List<int> chapterFnOrder(Chapter ch) {
  final seen = <int>{};
  final order = <int>[];
  _collectFns(ch.sections, seen, order);
  return order;
}

/// PNG-/JPEG-Erkennung per Magic-Bytes — nur diese Formate kann das
/// pdf-Paket einbetten (es parst die Bytes erst beim `doc.save()`, daher
/// MUSS vor dem Einbetten geprüft werden).
bool isPdfEmbeddableImage(Uint8List bytes) {
  if (bytes.length >= 4 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return true; // PNG
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return true; // JPEG
  }
  return false;
}

/// Eingebettete Druck-Schriften: PT Serif für die Lesefläche (der
/// kanonische Serif, E1) und Inter 400/600 für Struktur-Beschriftungen
/// (die UI-Schrift der App) — beide direkt aus den gebündelten
/// Font-Assets (printing-Font-Einbettung).
class DocPrintFonts {
  final pw.Font serif;
  final pw.Font serifBold;
  final pw.Font serifItalic;
  final pw.Font sans;
  final pw.Font sansBold;

  const DocPrintFonts({
    required this.serif,
    required this.serifBold,
    required this.serifItalic,
    required this.sans,
    required this.sansBold,
  });

  static Future<DocPrintFonts> load() async {
    Future<pw.Font> f(String asset) async =>
        pw.Font.ttf(await rootBundle.load(asset));
    return DocPrintFonts(
      serif: await f('assets/fonts/PT_Serif-Web-Regular.ttf'),
      serifBold: await f('assets/fonts/PT_Serif-Web-Bold.ttf'),
      serifItalic: await f('assets/fonts/PT_Serif-Web-Italic.ttf'),
      sans: await f('assets/fonts/inter-400.ttf'),
      sansBold: await f('assets/fonts/inter-600.ttf'),
    );
  }
}

/// Das komplette Dokument als PDF-Bytes.
///
/// [fnTexts] sind die EFFEKTIVEN Fußnotentexte (inkl. fnEdits);
/// [figures] das Abbildungs-/Tabellen-Manifest der aktiven Arbeit;
/// [images] fertig einbettbare Bild-Bytes (PNG/JPEG) je Figur-id —
/// `loadDocPrintImages` (doc_images.dart) liefert sie inklusive
/// WebP→PNG-Umkodierung. [onProgress] meldet die Setz-Schritte an den
/// Fortschritts-Dialog.
Future<Uint8List> buildThesisPdfBytes({
  required Thesis thesis,
  required Map<int, String> fnTexts,
  FiguresManifest figures = FiguresManifest.empty,
  Map<String, Uint8List> images = const {},
  DocPrintFonts? fonts,
  void Function(String schritt)? onProgress,
}) async {
  // Zwischen den Schritten einmal ans Event-Loop abgeben, damit der
  // Fortschritts-Dialog die Meldung auch zeichnen kann.
  Future<void> step(String schritt) async {
    onProgress?.call(schritt);
    await Future<void>.delayed(Duration.zero);
  }

  await step('Schriften einbetten …');
  final f = fonts ?? await DocPrintFonts.load();

  final meta = thesis.meta;
  final figByPara = {for (final x in figures.figuren) x.paragraphId: x};
  final tabByPara = {for (final x in figures.tabellen) x.paragraphId: x};

  // ---- Stile (Druck-Maße aus dem Print-CSS: Lesefläche 11pt/1.5, h1 20pt).
  final body = pw.TextStyle(font: f.serif, fontSize: 11, lineSpacing: 3.5);
  final h1 = pw.TextStyle(font: f.serifBold, fontSize: 20);
  pw.TextStyle heading(int level) => pw.TextStyle(
        font: f.serifBold,
        fontSize: level <= 2 ? 14 : (level == 3 ? 12.5 : 11.5),
      );
  // Fußnoten-Marker: Inter 600, klein, auf angehobener Grundlinie.
  final sup =
      pw.TextStyle(font: f.sansBold, fontSize: 6.5, color: PdfColors.grey800);
  final eyebrow = pw.TextStyle(
      font: f.sansBold, fontSize: 9, letterSpacing: 1.4, color: PdfColors.grey600);
  final caption =
      pw.TextStyle(font: f.sans, fontSize: 9, color: PdfColors.grey700);
  final placeholder =
      pw.TextStyle(font: f.serifItalic, fontSize: 10, color: PdfColors.grey700);

  pw.RichText paraText(String text) {
    final clean =
        text.replaceAll(_figMarkerRe, ' ').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    return pw.RichText(
      textAlign: pw.TextAlign.justify,
      text: pw.TextSpan(
        style: body,
        children: [
          for (final part in splitFnMarkers(clean))
            part.fn == null
                ? pw.TextSpan(text: part.text)
                // Hochstellung: kleinere Type auf angehobener Grundlinie.
                : pw.TextSpan(text: part.text, style: sup, baseline: 4),
        ],
      ),
    );
  }

  // ---- Abbildung: eingebettetes Bild + Unterschrift, sonst Platzhalter.
  pw.Widget figureBlock(Paragraph p, Figur? fig) {
    final bytes = fig == null ? null : images[fig.id];
    // Magic-Byte-Prüfung VOR dem Einbetten — pw.MemoryImage parst erst
    // beim doc.save(), unlesbare Bytes würden dort das ganze PDF kippen.
    if (fig != null && bytes != null && isPdfEmbeddableImage(bytes)) {
      pw.MemoryImage? img;
      try {
        img = pw.MemoryImage(bytes);
      } catch (_) {
        img = null; // unlesbare Bytes → Platzhalter unten
      }
      if (img != null) {
        final credit = fig.credit.isNotEmpty ? ' · ${fig.credit}' : '';
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              alignment: pw.Alignment.center,
              margin: const pw.EdgeInsets.only(top: 8, bottom: 5),
              constraints: const pw.BoxConstraints(maxHeight: 260),
              child: pw.Image(img, fit: pw.BoxFit.contain),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Text(
                '${fig.nummer} — ${fig.titel}$credit',
                style: caption,
                textAlign: pw.TextAlign.center,
              ),
            ),
          ],
        );
      }
    }
    // Ohne Bild: kursiver Platzhalter mit allem, was bekannt ist.
    final cap = p.text.replaceAll(_figMarkerRe, ' ').trim();
    final label = fig != null
        ? '${fig.nummer} — ${fig.titel}'
        : (cap.isEmpty ? '' : ': $cap');
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 4, bottom: 8),
      child: pw.Text(
        fig != null
            ? '[Abbildung $label — nicht hinterlegt]'
            : '[Abbildung$label]',
        style: placeholder,
      ),
    );
  }

  // ---- Tabelle: echte Tabelle aus dem Manifest, sonst Platzhalter.
  pw.Widget tableBlock(Paragraph p, Tabelle? tab) {
    if (tab != null && (tab.kopf.isNotEmpty || tab.zeilen.isNotEmpty)) {
      // Ragged Zeilen auf gemeinsame Spaltenzahl auffüllen.
      var cols = tab.kopf.length;
      for (final z in tab.zeilen) {
        if (z.length > cols) cols = z.length;
      }
      List<String> pad(List<String> cells) =>
          [...cells, for (var i = cells.length; i < cols; i++) ''];
      final headStyle = pw.TextStyle(
          font: f.sansBold, fontSize: 8.5, color: PdfColors.grey800);
      final cellStyle = pw.TextStyle(font: f.serif, fontSize: 9);
      final credit = tab.credit.isNotEmpty ? ' · ${tab.credit}' : '';
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8, bottom: 5),
            child: pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
              children: [
                if (tab.kopf.isNotEmpty)
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      for (final h in pad(tab.kopf))
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 5, vertical: 3.5),
                          child: pw.Text(h, style: headStyle),
                        ),
                    ],
                  ),
                for (final z in tab.zeilen)
                  pw.TableRow(children: [
                    for (final cell in pad(z))
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 5, vertical: 3.5),
                        child: pw.Text(cell, style: cellStyle),
                      ),
                  ]),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Text(
              '${tab.nummer} — ${tab.titel}$credit',
              style: caption,
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      );
    }
    final cap = p.text.replaceAll(_figMarkerRe, ' ').trim();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 4, bottom: 8),
      child: pw.Text('[Tabelle${cap.isEmpty ? '' : ': $cap'}]',
          style: placeholder),
    );
  }

  final doc = pw.Document(title: meta.title.isEmpty ? 'thesis' : meta.title);

  // ---- Titelseite (\maketitle-Pendant aus den Meta-Daten). --------------
  await step('Titelseite setzen …');
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.symmetric(horizontal: 64, vertical: 72),
    build: (ctx) => pw.Center(
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            meta.title.isEmpty ? 'PDF Dokument' : meta.title,
            style: pw.TextStyle(font: f.serifBold, fontSize: 24),
            textAlign: pw.TextAlign.center,
          ),
          if (meta.subtitle.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 12),
              child: pw.Text(
                meta.subtitle,
                style: pw.TextStyle(
                    font: f.serifItalic,
                    fontSize: 14,
                    color: PdfColors.grey800),
                textAlign: pw.TextAlign.center,
              ),
            ),
          pw.SizedBox(height: 44),
          if (meta.author.isNotEmpty)
            pw.Text(meta.author,
                style: pw.TextStyle(font: f.serif, fontSize: 12.5),
                textAlign: pw.TextAlign.center),
          if (meta.university.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 6),
              child: pw.Text(meta.university,
                  style: pw.TextStyle(
                      font: f.sans, fontSize: 10.5, color: PdfColors.grey700),
                  textAlign: pw.TextAlign.center),
            ),
          if (meta.date.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 20),
              child: pw.Text(meta.date,
                  style: pw.TextStyle(
                      font: f.sans, fontSize: 10.5, color: PdfColors.grey700)),
            ),
        ],
      ),
    ),
  ));

  // ---- Kapitel: je Kapitel ein eigener Seitenlauf (\chapter-Pendant). ---
  final chapters = thesis.chapters;
  for (var i = 0; i < chapters.length; i++) {
    final ch = chapters[i];
    final content = <pw.Widget>[];

    // Kapitel-Kopf: Eyebrow „Kapitel n" + Kapiteltitel (h1 = 20pt).
    content.add(pw.Text('Kapitel ${ch.num}'.toUpperCase(), style: eyebrow));
    content.add(pw.Padding(
      padding: const pw.EdgeInsets.only(top: 5, bottom: 13),
      child: pw.Text(ch.title, style: h1),
    ));

    var hasBody = false;
    void walk(List<Unit> units) {
      for (final u in units) {
        if (u.paragraphs.isNotEmpty) {
          hasBody = true;
          // Intro-Abschnitte („X.0") tragen den Kapiteltitel — der steht
          // schon im Kapitel-Kopf, also keine doppelte Überschrift.
          if (!u.isIntro) {
            content.add(pw.Padding(
              padding: const pw.EdgeInsets.only(top: 11, bottom: 5),
              child: pw.Text('${u.id}  ${u.title}', style: heading(u.level)),
            ));
          }
          for (final p in u.paragraphs) {
            switch (p.typeEnum) {
              case ParagraphType.list:
                for (final item in p.items) {
                  content.add(pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 12, bottom: 2),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('•  ', style: body),
                        pw.Expanded(child: paraText(item)),
                      ],
                    ),
                  ));
                }
                content.add(pw.SizedBox(height: 6));
              case ParagraphType.figure:
                content.add(figureBlock(p, figByPara[p.id]));
              case ParagraphType.table:
                content.add(tableBlock(p, tabByPara[p.id]));
              case ParagraphType.text:
                content.add(pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: paraText(p.text),
                ));
            }
          }
        }
        walk(u.children);
      }
    }

    walk(ch.sections);
    if (!hasBody) continue; // leeres Kapitel: keine leere Seite erzeugen

    // Endnoten je Kapitel (die Web-Druckansicht verliert die Fußnoten —
    // hier stehen sie gesammelt am Kapitelende).
    final fns = chapterFnOrder(ch)
        .where((n) => (fnTexts[n] ?? '').isNotEmpty)
        .toList();
    if (fns.isNotEmpty) {
      content.add(pw.Container(
        margin: const pw.EdgeInsets.only(top: 16, bottom: 6),
        height: .7,
        color: PdfColors.grey500,
      ));
      content.add(pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Text('Fußnoten zu Kapitel ${ch.num}',
            style: pw.TextStyle(
                font: f.sansBold, fontSize: 9.5, color: PdfColors.grey800)),
      ));
      for (final n in fns) {
        content.add(pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2.5),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 26,
                child: pw.Text('$n',
                    style: pw.TextStyle(
                        font: f.sansBold,
                        fontSize: 8.5,
                        color: PdfColors.grey700)),
              ),
              pw.Expanded(
                child: pw.Text(fnTexts[n]!,
                    style: pw.TextStyle(
                        font: f.serif, fontSize: 9, lineSpacing: 2.5)),
              ),
            ],
          ),
        ));
      }
    }

    await step('Kapitel ${i + 1}/${chapters.length} setzen …');
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(56, 56, 56, 64),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('${ctx.pageNumber}',
            style: pw.TextStyle(
                font: f.sans, fontSize: 9, color: PdfColors.grey600)),
      ),
      build: (ctx) => content,
    ));
  }

  await step('PDF schreiben …');
  return doc.save();
}
