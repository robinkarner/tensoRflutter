/// Karte „5 · Bedienung & Barrierefreiheit“ — die große Bedienungs-Liste
/// (views_hilfe.js:122-205); sie dokumentiert faktisch die Gesamtsoftware.
/// Texte wortwörtlich; angepasst sind NUR die technisch überholten Stellen
/// (jeweils kommentiert): OCR/Tesseract (E3), PDF → LaTeX (E5),
/// js-/py-Rechenzellen (E4), CORS-Formulierung (S-1: „Netzwerk“) und
/// „Browser-Zoom“ (Desktop: System-Zoom).
library;

import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'hilfe_text.dart';

class HilfeBedienungCard extends StatelessWidget {
  const HilfeBedienungCard({super.key});

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    // ul.small mit line-height 2 (views_hilfe.js:124).
    final style = AppTextStyles.small.copyWith(color: t.ink2, height: 2);

    Widget li(List<InlineSpan> spans) => Padding(
          padding: const EdgeInsets.only(left: 18),
          child: Text.rich(
            TextSpan(children: [const TextSpan(text: '• '), ...spans]),
            style: style,
          ),
        );

    return HilfeCard(
      eyebrow: '5 · Bedienung & Barrierefreiheit',
      children: [
        const SizedBox(height: 8),
        li([
          hkbd(context, 'Strg/⌘ K'),
          const TextSpan(
              text: ' — überallhin springen (Abschnitte, Quellen, Ansichten) · '),
          hkbd(context, 'Esc'),
          const TextSpan(text: ' schließt Panels/Dialoge'),
        ]),
        li([
          hb('Der Arbeitsraum hat bis zu 4 parallele Bereiche'),
          const TextSpan(text: ' (links → rechts): '),
          hb('Kapitel/Subkapitel'),
          const TextSpan(text: ', der '),
          hb('Inhalt'),
          const TextSpan(text: ' (Lesen/Prüfen/Editor), die '),
          hb('Andock-Spalte'),
          const TextSpan(
              text: ' (Erklärung/Übersetzung/Connections) und ganz rechts '),
          hb('Datei/Quelle'),
          const TextSpan(
              text: ' als Hauptanker — jeder Bereich ist an den Trennlinien '
                  'frei verziehbar (Doppelklick = Standard) und einzeln '
                  'einklappbar — ⇤ oben im Inhaltsverzeichnis, ⇥ oben in der '
                  'Quellen-Spalte; die Rand-Leisten holen sie zurück. Alle '
                  'Breiten werden gemerkt.'),
        ]),
        li([
          hb('Die Modus-Leiste (Lesen/Prüfen/Editor) steht immer fix oben'),
          const TextSpan(
              text: ' an derselben Stelle — beim Umschalten versetzt sich '
                  'nichts, und der Scrollstand je Modus bleibt erhalten.'),
        ]),
        li([
          hb('Im PDF-Viewer:'),
          const TextSpan(text: ' '),
          hb('Endlos-Scroll'),
          const TextSpan(
              text: ' — alle Seiten liegen untereinander, einfach '
                  'durchscrollen (kein Blättern nötig, die Seitenzahl folgt; '
                  'Seiten laden lazy und geben Speicher wieder frei) · '),
          hkbd(context, '←'),
          const TextSpan(text: '/'),
          hkbd(context, '→'),
          const TextSpan(text: ' springen zum Seitenanfang · '),
          hkbd(context, '+'),
          const TextSpan(text: '/'),
          hkbd(context, '−'),
          const TextSpan(text: ' zoomen · '),
          hkbd(context, '0'),
          const TextSpan(text: ' auf Breite · die '),
          hb('Volltextsuche'),
          const TextSpan(
              text: ' ist groß integriert und findet Text über alle Seiten '
                  '(Enter = nächste Trefferseite, scrollt hin). Die '
                  '🔎-Suchbegriff-Chips an Beleg und Zitierelement starten '
                  'die Suche per Klick — GPT liefert sie als '),
          hb('wörtlich auffindbare Original-Passagen'),
          // E3: OCR entfällt in dieser Version — der Original-Satz
          // („Tesseract erkennt den Text, einmalig vom CDN, …“) ist auf die
          // Hinweis-Leiste der App umgeschrieben.
          const TextSpan(
              text: ' (|-getrennt). Seiten ohne Textlayer (Scans) bekommen '
                  'eine Hinweis-Leiste — die 🔍-Texterkennung (OCR) ist in '
                  'dieser Version nicht enthalten.'),
        ]),
        li([
          hb('Unten in der Quellen-Spalte dockt das Beleg-Dock an:'),
          const TextSpan(
              text: ' ⌖ Beleg & Fußnote in EINER Fläche — Seite und Zitat '
                  'direkt editierbar, darunter der Vermutungs-Block mit '
                  'Suchbegriffen. Die '),
          hb('Naht zum PDF ist in der Höhe ziehbar'),
          const TextSpan(
              text: ' (Doppelklick = Standard), einklappen geht weiterhin '
                  '(▾), damit das PDF die volle Höhe bekommt; 📚 Dossier und '
                  '↗ offizielle Seite öffnen über die Buttons in der '
                  'Datei-Leiste'),
        ]),
        li([
          hb('⭳ Download-Engine je Quelle:'),
          const TextSpan(
              text: ' lädt die Datei über den gefundenen Download-Link — bei '
                  'Erfolg wird sie '),
          hb('sofort zugeordnet'),
          const TextSpan(
              text: ' (jederzeit änderbar: ersetzen/entfernen im 📄-Panel). '
                  'Der Link selbst steht immer als kleines '),
          hb('↗'),
          // „(CORS/Paywall)“ → „(Netzwerk/Paywall)“: außerhalb des Browsers
          // gibt es kein CORS — die Download-Engine (S-1) meldet „blockiert
          // (Netzwerk)“.
          const TextSpan(
              text: ' daneben: falls der automatische Download blockiert ist '
                  '(Netzwerk/Paywall), von Hand laden und „⭱ Datei lokal '
                  'wählen“. Der Status daneben merkt sich dauerhaft, was ging '
                  'bzw. schiefging. Im '),
          hb('Projekt'),
          const TextSpan(
              text: ' versucht „⭳ Alle laden“ alle fehlenden Dateien auf '
                  'einmal — Fehler stehen deutlich in der Liste.'),
        ]),
        li([
          const TextSpan(
              text: 'Beleg-Boxen und Absätze sind komplett klickbar und per '),
          hkbd(context, 'Tab'),
          const TextSpan(text: ' + '),
          hkbd(context, '↵'),
          const TextSpan(text: ' erreichbar'),
        ]),
        li([
          // „mit dem Browser-Zoom“ → auch Desktop: System- bzw. Browser-Zoom.
          const TextSpan(
              text: 'Hell/Dunkel folgt dem System (◐ oben rechts); '
                  'Schriftgröße skaliert mit dem System- bzw. Browser-Zoom; '
                  'reduzierte Bewegung wird respektiert'),
        ]),
        li([
          const TextSpan(
              text: 'Die große Vollbild-Ansicht gibt es je Absatz '
                  '(„⌖ Große Ansicht“) und über das ⌖ in der Quellen-Spalte'),
        ]),
        li([
          const TextSpan(text: 'Eine '),
          hb('gesetzte Markierung zählt als vollwertiger Nachweis'),
          const TextSpan(text: ' — Zitat und Seite stecken in ihr'),
        ]),
        li([
          hb('Instanz-Fenster im Prüftab:'),
          const TextSpan(
              text: ' rechtsbündig neben jeder Absatz-Karte liegt ein '
                  'gleichwertiges, nahtlos verschmolzenes Fenster — '),
          hb('⤳ Connections'),
          const TextSpan(
              text: ' (Standard), ⚡ Schnelllesen, 🌐 Übersetzung, '
                  '✎ Erklärung, ✦ Analyse oder ◻ Ohne (reiner Text ohne jede '
                  'Markierung — die ruhige Ansicht). Die Auswahl in der '
                  'rechtsbündigen '),
          hb('Instanz-Leiste'),
          const TextSpan(text: ' gilt '),
          hb('überall'),
          const TextSpan(text: '; ∅ ist die leere Auswahl (kein Fenster), das '),
          hb('×'),
          const TextSpan(
              text: ' am Fenster schließt nur den Abschnitt, die Naht zieht die '),
          hb('Breite'),
          const TextSpan(text: '. Über '),
          hb('✎ in der Instanz-Leiste'),
          const TextSpan(
              text: ' sind die Instanzen wie eine App-Liste '),
          hb('verschiebbar, umbenennbar und NEU definierbar'),
          const TextSpan(
              text: ' (Name = id, Beschreibung = GPT-Auftrag). Generiert wird '),
          hb('global'),
          const TextSpan(text: ' über '),
          hb('GPT'),
          const TextSpan(
              text: '-Knopf oben in der Kopfleiste: EIN Prompt mit allen '
                  'Instanz-Beschreibungen und dem kompletten Text, Antwort '
                  'direkt importierbar — nicht mehr pro Kategorie. Jedes '
                  'Fenster ist '),
          hb('direkt beschreibbar'),
          const TextSpan(
              text: ': Doppelklick — genauso smooth wie der Absatztext, '),
          hkbd(context, 'Esc'),
          const TextSpan(
              text: ' übernimmt. Gesamtdokument: Analyse → „Übersetzung & '
                  'Instanzen“; genereller (ohne Kapitel): 📓 Erklärbuch. Das '
                  'LaTeX-Original bleibt Ground Truth.'),
        ]),
        li([
          hb('⚡ Schnelllesen:'),
          const TextSpan(
              text: ' als Instanz gewählt, bekommt der Absatztext einen '
                  'Spezial-Anstrich — alle Markierungen (Fristen, Akteure, '
                  'Abkürzungen, Schlagwörter …) sind voll ausgemalt, das Auge '
                  'springt von Anker zu Anker. Der Anstrich überlappt auch in '
                  'den '),
          hb('Lesen-Modus'),
          const TextSpan(
              text: ': dort über den ⚡-Knopf in der Modus-Leiste '
                  'ein-/ausschaltbar.'),
        ]),
        li([
          hb('✎ Doppelklick-Bearbeitung:'),
          const TextSpan(
              text: ' Doppelklick auf einen Absatz im Prüftab macht ihn '
                  'direkt editierbar — gleiche Schrift, gleiche Stelle, '
                  'Fußnoten als [^n]-Rohform; '),
          hkbd(context, 'Esc'),
          const TextSpan(
              text: ' (oder Klick außerhalb) übernimmt. Änderungen fließen '
                  'synchron ins LaTeX des Abschnitts (Editor), ↺ am Absatz '
                  'stellt das Original wieder her.'),
        ]),
        li([
          hb('⤳ Connections:'),
          const TextSpan(
              text: ' zeigt erkannte/bestätigte Zusammenhänge zwischen den '
                  'Absätzen als animierte Kanten mit Text — zur Navigation '
                  'gedacht und jederzeit ausblendbar; das '
                  'Verbindungs-Framework erkennt zusätzlich automatisch '
                  'Abschnitte mit '),
          hb('gemeinsamen (seltenen) Quellen'),
          const TextSpan(text: ' (⌗ „teilt Quellen mit“)'),
        ]),
        li([
          hb('Markierungen im Text:'),
          const TextSpan(
              text: ' Kategorien (Frist, Akteur, These, Abkürzung, Schlagwort '
                  '…) sind kurze Wortmarker für schnelles Querlesen — Klick '
                  'hebt sie voll hervor. Die '),
          hb('vorkommenden Kategorien stehen dezent unter jedem Absatz'),
          const TextSpan(
              text: ' und sind dort ein-/ausschaltbar (keine globale Legende '
                  'mehr). '),
          hb('Quellen/Rechtsnormen'),
          const TextSpan(
              text: ' haben eine eigene Farbe und bleiben bewusst dezent '
                  '(gepunktete Linie): erst der direkte Klick hebt hervor und '
                  'öffnet die Quelle in der Quellen-Spalte — genauso klickbar '
                  'sind erkannte '),
          hb('Text-Erwähnungen'),
          const TextSpan(
              text: ' (Autor (Jahr) ohne Fußnote); markiert wird nur, was '
                  'wirklich im Quellenregister existiert. Über '),
          hb('🖍 Markierungen'),
          const TextSpan(
              text: ' (Prüfen-Werkzeuge) lassen sich Markierungen je '
                  'Abschnitt flexibel per KI nachziehen: Prompt kopieren → '
                  'Antwort importieren'),
        ]),
        li([
          hb('📓 Erklärbuch (Analyse):'),
          const TextSpan(
              text: ' die Visualisierungs- und Inhaltsplattform — Markdown '
                  'oberste Ebene, eingebettet: Diagramme ('),
          hcode(context, '```chart'),
          const TextSpan(text: '), Tabellen, Mathematik ('),
          hcode(context, r'$$…$$'),
          const TextSpan(
              text: ', eigener Renderer), LaTeX über '),
          hb('denselben Interpreter wie die Arbeit'),
          const TextSpan(text: ', Abbildungen ('),
          hcode(context, '```figure'),
          const TextSpan(text: '), Textpassagen ('),
          hcode(context, '```include'),
          // E4: js-/py-Rechenzellen werden gerendert, nicht ausgeführt —
          // der Original-Satz („```js sofort/offline, ```py mit
          // Python/Pyodide inkl. numpy/…“) ist entsprechend angepasst.
          const TextSpan(text: ') und Rechenzellen — '),
          hcode(context, '```js'),
          const TextSpan(text: '/'),
          hcode(context, '```py'),
          const TextSpan(
              text: ' werden dargestellt (Ausführung ist in dieser Version '
                  'nicht enthalten). Vollständig KI-generierbar: 🤖 Prompt → '
                  '⭱ Import; Referenz: docs/ERKLAERBUCH.md'),
        ]),
        li([
          hb('🔬 Analysemodus (Wissen):'),
          const TextSpan(
              text: ' die Arbeit selbst als angereicherte Ansicht — der '
                  'Original-Text Kapitel für Kapitel mit den Abbildungen und '
                  'Tabellen im Fluss und einer '),
          hb('Erklärung direkt unter jedem Absatz'),
          const TextSpan(
              text: '. Die Erklärungs-Linse ist wählbar (Erklärung, '
                  'Übersetzung, Analyse + selbst definierte Instanzen); '
                  'Inhalte entstehen über den GPT-Knopf oben (global), leere '
                  'Absätze zeigen die KI-Voranalyse'),
        ]),
        li([
          // E5: pdfToTex (Beta) ist zurückgestellt — der Original-Punkt
          // (Schriftgrößen-Heuristik via pdf.js) ist auf den Hinweis
          // reduziert; neue Arbeiten entstehen aus dem Quelltext.
          hb('📄 PDF → LaTeX (Beta):'),
          const TextSpan(
              text: ' ist in dieser Version zurückgestellt — neue Arbeiten '
                  'entstehen aus dem echten LaTeX-Quelltext (🗂-Menü → '
                  '＋ Neue Arbeit); damit bleibt das Ergebnis ohnehin immer '
                  'besser'),
        ]),
        li([
          hb('Automatische Datei-Zuordnung:'),
          const TextSpan(
              text: ' Beim Import (PDF/ZIP) erkennt die Software selbst, zu '
                  'welcher Quelle eine Datei gehört — „⌗ Datei-Auftrag“ in '
                  'der Bibliothek exportiert alle fehlenden Quellen als '
                  'ZIP-Auftrag für Mensch/KI/Download-Engine. Offizielle '
                  'Seiten ergeben sich automatisch aus DOI/URL jeder Quelle; '
                  'öffentliche Datei-Links kommen aus Registry bzw. '
                  '🤖 Ergänzung'),
        ]),
        li([
          hb('Erwähnungs-Erkennung:'),
          const TextSpan(
              text: ' Nennt der Text eine Quelle nur über „Autor (Jahr)“ ohne '
                  'Fußnote, erkennt die Software das deterministisch (ohne '
                  'KI) und schlägt es im Prüfen-Modus zur '),
          hb('Bestätigung'),
          const TextSpan(
              text: ' vor — bestätigte Erwähnungen erscheinen unterstrichen '
                  'im Text und auf der Quellenseite'),
        ]),
      ],
    );
  }
}
