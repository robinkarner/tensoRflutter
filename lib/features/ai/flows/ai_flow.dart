/// Flow-Modell der KI-Werkbank — typisiertes Pendant der `Enhance.flows`-
/// Objekte (enhance.js:60-185). Alle UIs (Hub, Panel, Magic-Dock, Modals)
/// sind reine Projektionen dieser Liste.
///
/// Der HTML-liefernde `check()`/`reference()`-Teil des Originals wird als
/// STRUKTURIERTES Modell nachgebaut ([AiCheckResult]/[AiReference] mit
/// [RichBit]-Fettauszeichnung) — der WORTLAUT der Meldungen bleibt exakt
/// (Dossier 08 §9.7).
library;

import 'package:flutter/widgets.dart';

/// Kontext der Flow-Erzeugung (`ctx` = `{sectionId?, srcId?}`).
class AiFlowCtx {
  final String? sectionId;
  final String? srcId;

  const AiFlowCtx({this.sectionId, this.srcId});

  @override
  bool operator ==(Object other) =>
      other is AiFlowCtx && other.sectionId == sectionId && other.srcId == srcId;

  @override
  int get hashCode => Object.hash(sectionId, srcId);
}

/// Datenpaket-Beschreibung (`paket {in[], out, ziel}`).
class AiPaket {
  final List<String> input;
  final String out;
  final String ziel;

  const AiPaket({required this.input, required this.out, required this.ziel});
}

/// Ein Stück reicher Text (Ersatz für `<b>…</b>` in den Meldungen).
class RichBit {
  final String text;
  final bool bold;

  const RichBit(this.text, {this.bold = false});
}

/// Ergebnis des ✓ Format-Checkers (`{ok, html}` → strukturiert).
///
/// Darstellung (enh-check): Kopfzeile aus [head]-Bits (Renderer stellt bei
/// [ok] „✓ “ voran), darunter [problems] als Liste; ist [bereit] gesetzt,
/// hängt der Renderer „ Bereit für „⭱ Übernehmen“.“ an die Kopfzeile.
class AiCheckResult {
  final bool ok;
  final List<RichBit> head;
  final List<String> problems;
  final bool bereit;

  const AiCheckResult({
    required this.ok,
    required this.head,
    this.problems = const [],
    this.bereit = false,
  });

  /// Reiner Meldungs-Fall (leer / Format frei / Fehler).
  AiCheckResult.plain(String text, {required this.ok})
      : head = [RichBit(text)],
        problems = const [],
        bereit = false;
}

/// Chip der Referenz-Ansicht (`.enh-chips .chip.mini`); [catKey] färbt über
/// `--c: var(--cat-<kategorie>)` (enhance.js:345).
class AiRefChip {
  final String label;
  final String? catKey;

  const AiRefChip(this.label, {this.catKey});
}

/// Referenz „wie die aktuellen Daten dieser Stelle gerade aussehen“
/// (`Enhance._wrap` + `_ref*`, enhance.js:320-366).
class AiReference {
  /// `.enh-ref-sum` — Zusammenfassung mit Fett-Bits.
  final List<RichBit> summary;

  /// Chips (Marks/Connections/Instanzen nach Typ).
  final List<AiRefChip> chips;

  /// `<p class="small mut">…` — Hinweiszeile unter der Zusammenfassung.
  final String? hint;

  /// Markdown-Vorschau (Erklärbuch, max. 700 Zeichen) — [mdTruncated]
  /// hängt die „…“-Zeile an.
  final String? mdPreview;
  final bool mdTruncated;

  const AiReference({
    required this.summary,
    this.chips = const [],
    this.hint,
    this.mdPreview,
    this.mdTruncated = false,
  });
}

/// EIN Flow (Datenpaket). Funktionsfelder statt Vererbung — wie die
/// Objektliteral-Registry des Originals.
class AiFlow {
  final String id;
  final String icon;
  final String title;

  /// Kurz-Aktion des Magic-Knopfs (`aktion`; Stil-Check hat keine).
  final String? aktion;

  /// 'Ganze Arbeit' | 'Dieser Abschnitt' — gruppiert Hub & Panel-Nav.
  final String scope;

  /// Abschnitts-Bezug (nur `marks`).
  final String? section;

  /// Multi-Datei-Flow (Voranalyse): kein Ein-Klick-Kochen/Übernehmen.
  final bool multi;

  /// Sofort-Schalter (Stil-Check): kein Prompt, kein Import.
  final bool toggle;

  final String? kurz;
  final String erzeugt;
  final String how;
  final String? basis;
  final String? wieder;
  final AiPaket? paket;
  final String? placeholder;

  /// Prompt-Erzeugung (ohne Zusatz-Instruktion — die hängt [buildAiPrompt] an).
  final String Function()? build;

  /// Import; liefert den Erfolgs-Text, wirft [FormatException] mit der
  /// exakten Original-Meldung.
  final String Function(String text)? run;

  /// Format-Checker (roh, bereits ge-`clean`-t) — wirft bei ungültigem Format.
  final AiCheckResult Function(String raw)? check;

  final AiReference Function()? reference;

  /// Navigation/Refresh nach erfolgreichem Import (`done()`); der Kontext
  /// kommt vom aufrufenden Widget.
  final void Function(BuildContext context)? done;

  /// Live-Stand fürs Hub-Badge / die ⓘ-Übersicht.
  final String Function()? stat;
  final bool Function()? statOn;

  const AiFlow({
    required this.id,
    required this.icon,
    required this.title,
    this.aktion,
    required this.scope,
    this.section,
    this.multi = false,
    this.toggle = false,
    this.kurz,
    required this.erzeugt,
    required this.how,
    this.basis,
    this.wieder,
    this.paket,
    this.placeholder,
    this.build,
    this.run,
    this.check,
    this.reference,
    this.done,
    this.stat,
    this.statOn,
  });
}

/// Meldungstext einer Ausnahme — [FormatException] liefert die nackte
/// `message` (Pendant zu `e.message` im Original), alles andere `toString`.
String aiErrText(Object e) {
  if (e is FormatException) return e.message;
  final s = e.toString();
  return s.startsWith('Exception: ') ? s.substring(11) : s;
}
