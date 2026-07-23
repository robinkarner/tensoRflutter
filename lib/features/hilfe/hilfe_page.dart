/// `#/hilfe` — die Hilfe- & Anleitungs-Seite (Port von `renderHilfe`,
/// views_hilfe.js:8-206): 5 Karten, max. 980px breit, Abstand 14px.
/// Die Texte sind die Produkt-Doku und wortwörtlich übernommen; NUR
/// technisch Überholtes ist minimal an die App-Realität angepasst —
/// jede Anpassung ist an Ort und Stelle kommentiert (E3 OCR, E5 pdfToTex,
/// E6 Passwort-Gate, E7 Drift statt localStorage/IndexedDB).
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/color_mix.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/notice.dart';
import 'hilfe_bedienung.dart';
import 'hilfe_text.dart';

/// Veröffentlichte Web-Version (Original-Link, views_hilfe.js:102).
const kThesorWebUrl = 'https://robinkarner.github.io/thesoR/';

/// Doku-Dateien — im Original relative Repo-Links (`docs/…`); die App hat
/// kein docs-Verzeichnis, daher zeigen die Links auf die Web-Version.
const kThesorDocsBase = '${kThesorWebUrl}docs/';

class HilfePage extends StatelessWidget {
  const HilfePage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // .page-head
        Text('Hilfe & Anleitung', style: AppTextStyles.h1.copyWith(color: t.ink)),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Wie die Software funktioniert, wie du KI-Analysen '),
            hb('nachträglich generierst und ersetzt'),
            const TextSpan(
                text: ', wo deine Daten liegen — und wie das Ganze im Web und '
                    'lokal läuft.'),
          ]),
          style: AppTextStyles.body.copyWith(color: t.ink2),
        ),
        const SizedBox(height: 20),
        // .hilfe: flex-column, gap 14, max-width 980.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: const [
              _FlowCard(),
              _GenerierenCard(),
              _SpeicherCard(),
              _WebLokalCard(),
              HilfeBedienungCard(),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 1 · So fließt alles zusammen (Flow-Diagramm)
// ---------------------------------------------------------------------------

class _FlowCard extends StatelessWidget {
  const _FlowCard();

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return HilfeCard(
      eyebrow: '1 · So fließt alles zusammen',
      children: [
        const SizedBox(height: 10),
        Semantics(
          label: 'Ablauf: LaTeX wird geparst, extern GPT-analysiert, '
              'importiert, geprüft und als Belegstand gesichert',
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 6,
                children: [
                  const _FlowStep(
                      b: 'LaTeX', sub: 'Quelltext der Arbeit\n(bleibt unverändert)'),
                  _arrow(t),
                  // „— im Browser“ → „— in der App“: der Parser läuft hier
                  // lokal in der Flutter-App (nur auf dem Web-Target wäre
                  // „Browser“ noch wörtlich richtig).
                  const _FlowStep(
                      b: 'Parsen',
                      sub: 'Gliederung, Absätze,\nFußnoten/\\cite — in der App'),
                  _arrow(t),
                  const _FlowStep(
                      b: 'GPT-Voranalyse',
                      sub: 'extern per Prompt:\nBelege, Dossiers, Connections',
                      variant: _FlowVariant.ki),
                  _arrow(t),
                  const _FlowStep(
                      b: 'Prüfen',
                      sub: 'Splitscreen: PDF/Text markieren,\nZitat + Position sichern'),
                  _arrow(t),
                  const _FlowStep(
                      b: 'Belegstand',
                      sub: '✓ belegt — exportierbar\nals eine JSON-Datei',
                      variant: _FlowVariant.ok),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Die Software erfindet nichts: Die KI-Teile sind '),
            hb('Vermutungen'),
            const TextSpan(
                text: ' (✦), verlässlich wird ein Beleg erst durch dein '
                    'Markieren/Prüfen (✓). Jede Arbeit (Projekt-Instanz) hat '
                    'ihren eigenen Prüfstand.'),
          ]),
          style: AppTextStyles.small.copyWith(color: t.muted),
        ),
      ],
    );
  }

  static Widget _arrow(BookClothTokens t) => Center(
        child: Text('→',
            style: TextStyle(
                fontSize: 16,
                color: t.muted,
                fontFamilyFallback: AppFonts.fallback)),
      );
}

enum _FlowVariant { plain, ki, ok }

/// `.flow-step` (app.css:1327-1334): min-width 128, border-strong,
/// radius 10, surface-2; `.ki` accent-line + accent-6%-Fond, `.ok` good.
class _FlowStep extends StatelessWidget {
  const _FlowStep({required this.b, required this.sub, this.variant = _FlowVariant.plain});

  final String b;
  final String sub;
  final _FlowVariant variant;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final (borderColor, bg) = switch (variant) {
      _FlowVariant.ki => (t.accentLine, t.accent.mix(t.surface2, 6)),
      _FlowVariant.ok => (t.good, t.surface2),
      _ => (t.borderStrong, t.surface2),
    };
    return Container(
      constraints: const BoxConstraints(minWidth: 128),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 4,
        children: [
          Text(b,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontFamilyFallback: AppFonts.fallback,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: t.ink,
              )),
          Text(sub,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontFamilyFallback: AppFonts.fallback,
                fontSize: 12,
                height: 1.5,
                color: t.muted,
              )),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2 · KI-Teile nachträglich generieren & ersetzen
// ---------------------------------------------------------------------------

class _GenerierenCard extends StatelessWidget {
  const _GenerierenCard();

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final small = AppTextStyles.small.copyWith(color: t.ink2, height: 1.55);
    final mut = AppTextStyles.small.copyWith(color: t.muted);

    /// Baustein-Zelle: fett + optionale muted-Unterzeile.
    Widget baustein(String name, [String? sub]) => Text.rich(
          TextSpan(children: [
            hb(name),
            if (sub != null) TextSpan(text: '\n$sub', style: mut),
          ]),
          style: small,
        );
    Widget cell(List<InlineSpan> spans) =>
        Text.rich(TextSpan(children: spans), style: small);

    return HilfeCard(
      eyebrow: '2 · KI-Teile nachträglich generieren & ersetzen',
      children: [
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Jeder KI-Baustein lässt sich '),
            hb('jederzeit neu erzeugen'),
            const TextSpan(
                text: ': Prompt kopieren → einem externen Modell (GPT/Claude/…) '
                    'geben → Antwort importieren. Der Import '),
            hb('ersetzt'),
            const TextSpan(
                text: ' den gespeicherten Baustein — dein manuell Erfasstes '
                    '(Zitate, Markierungen, Status) bleibt dabei immer '
                    'erhalten und hat Vorrang.'),
          ]),
          style: small,
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(children: [
            hb('EIN Muster überall:'),
            const TextSpan(
                text: ' Jeder 🤖-Dialog sagt oben, was der Prompt enthält und '
                    'wohin die Antwort fließt — Prompt kopieren und Antwort '
                    'importieren passieren im SELBEN Dialog.'),
          ]),
          style: small,
        ),
        const SizedBox(height: 8),
        HilfeTable(
          headers: const [
            'Baustein',
            'Wo (Prompt + Import in EINEM Dialog)',
            'Ersetzt',
          ],
          rows: [
            [
              baustein('Komplette Voranalyse',
                  'Belege je Fußnote, Dossiers, Zusammenfassungen'),
              cell([
                const TextSpan(text: '🗂-Menü (oben rechts) → Arbeit → '),
                hcode(context, '🤖 Gesamt-Prompt'),
                const TextSpan(text: ', Antwort daneben über '),
                hcode(context, '⭱ Analysen'),
                const TextSpan(text: ' (JSON-Dateien)'),
              ]),
              cell([const TextSpan(text: 'die gespeicherte Voranalyse der Arbeit')]),
            ],
            [
              baustein('Instanzen',
                  'Übersetzung, Erklärung, Analyse + selbst definierte'),
              cell([
                hcode(context, 'GPT'),
                const TextSpan(text: '-Knopf oben in der Kopfleiste (neben Suchen)'),
              ]),
              cell([
                const TextSpan(text: 'leere Absatz-Instanzen (Geschriebenes bleibt)'),
              ]),
            ],
            [
              baustein('Durchlauf je Quelle', 'Fundstelle + Zitat je Zitierstelle'),
              cell([
                const TextSpan(text: 'Quellenseite oder Status → '),
                hcode(context, 'Durchlauf'),
              ]),
              cell([const TextSpan(text: 'den früheren Durchlauf dieser Quelle')]),
            ],
            [
              baustein('Neue Quelle'),
              cell([
                const TextSpan(text: 'Quellenseite (manuelle Quelle) → '),
                hcode(context, '🤖 Ergänzung'),
              ]),
              cell([
                const TextSpan(text: 'Metadaten/Dossier der manuellen Quelle'),
              ]),
            ],
            [
              baustein('Markierungen'),
              cell([
                const TextSpan(text: 'Studio → '),
                hcode(context, '🖍 Markierungen'),
              ]),
              cell([
                const TextSpan(text: 'zusätzliche Markierungen des Abschnitts'),
              ]),
            ],
            [
              baustein('Connections',
                  'inhaltliche Verbindungen zwischen Abschnitten'),
              cell([
                hcode(context, 'GPT'),
                const TextSpan(text: '-Knopf oben → ⤳ Connections'),
              ]),
              cell([const TextSpan(text: 'die importierten KI-Connections')]),
            ],
            [
              baustein('📓 Erklärbuch',
                  'Visualisierungs-/Inhaltsplattform: Charts, Tabellen, Mathe, LaTeX, Python'),
              cell([
                const TextSpan(text: 'Wissen → Erklärbuch → '),
                hcode(context, '🤖 Prompt'),
                const TextSpan(text: ' / '),
                hcode(context, '⭱ Import'),
              ]),
              cell([
                const TextSpan(text: 'das gespeicherte Erklärbuch dieser Arbeit'),
              ]),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(children: [
            const TextSpan(
                text: 'Alle Antworten sind reines JSON in dokumentierten '
                    'Formaten — '),
            hlink(context, 'PROJEKT-FORMAT.md ↗',
                () => launchUrl(Uri.parse('${kThesorDocsBase}PROJEKT-FORMAT.md'))),
            const TextSpan(text: ' · '),
            hlink(context, 'QUELLEN-WORKFLOW.md ↗',
                () => launchUrl(Uri.parse('${kThesorDocsBase}QUELLEN-WORKFLOW.md'))),
            const TextSpan(text: '.'),
          ]),
          style: mut,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 3 · Wo liegen meine Daten — und wie ersetze ich sie
// ---------------------------------------------------------------------------

class _SpeicherCard extends StatelessWidget {
  const _SpeicherCard();

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final small = AppTextStyles.small.copyWith(color: t.ink2, height: 1.55);
    Widget cell(List<InlineSpan> spans) =>
        Text.rich(TextSpan(children: spans), style: small);

    return HilfeCard(
      eyebrow: '3 · Wo liegen meine Daten — und wie ersetze ich sie',
      children: [
        const SizedBox(height: 8),
        HilfeTable(
          headers: const ['Daten', 'Speicherort', 'sichern / ersetzen'],
          rows: [
            [
              cell([
                hb('Prüfstand'),
                const TextSpan(
                    text: ' (Status, Zitate, Positionen, Markierungen, Links, '
                        'Notizen, Quellentexte)'),
              ]),
              // E7: „Browser (localStorage)“ → lokale Datenbank (Drift/SQLite).
              cell([
                const TextSpan(text: 'Lokale Datenbank der App, '),
                hb('pro Arbeit getrennt'),
              ]),
              cell([
                const TextSpan(text: 'Bibliothek → '),
                hcode(context, '⭳ Sichern'),
                const TextSpan(text: ' / '),
                hcode(context, '⭱ Laden'),
                const TextSpan(
                    text: ' — Laden ersetzt den Prüfstand der aktiven Arbeit'),
              ]),
            ],
            [
              cell([hb('Quellen-PDFs')]),
              // E7: „Browser (IndexedDB) oder Ordner sources/<id>.pdf“ →
              // lokale Datenbank bzw. gebündelte Assets.
              cell([
                const TextSpan(text: 'Lokale Datenbank oder gebündelt als '),
                hcode(context, 'assets/sources/<id>.pdf'),
                const TextSpan(text: ' — von allen Arbeiten geteilt'),
              ]),
              cell([
                const TextSpan(
                    text: 'Inline-Zuordnung je Quelle (⭳ Download mit ↗-Link '
                        'daneben · ⭱ Datei lokal wählen · 📥 Aus '
                        'Dateiverzeichnis) · Import '),
                hcode(context, '⭱ (PDF/ZIP)'),
                const TextSpan(text: ' mit automatischer Zuordnung · '),
                hcode(context, '⌗ Datei-Auftrag'),
                const TextSpan(text: ' (ZIP-Roundtrip) · '),
                hcode(context, '🗑 Dateispeicher leeren'),
                const TextSpan(
                    text: ' setzt ALLE gespeicherten Dateien zurück (für den '
                        'frischen, neuesten Stand)'),
              ]),
            ],
            [
              cell([
                hb('Arbeiten (Instanzen)'),
                const TextSpan(text: ' inkl. Original-LaTeX + Voranalyse'),
              ]),
              // E7: „Browser (IndexedDB)“ → lokale Datenbank; die Builtins
              // liegen als Assets in der App (statt „im Repo“).
              cell([
                const TextSpan(
                    text: 'Lokale Datenbank; die eingebauten Arbeiten liegen '
                        'als Assets in der App'),
              ]),
              // E5: der Zusatz „oder per 📄 PDF → LaTeX (Beta)“ entfällt —
              // pdfToTex ist in dieser Version zurückgestellt.
              cell([
                const TextSpan(text: '🗂-Menü (oben rechts) → '),
                hcode(context, '⭳'),
                const TextSpan(text: ' exportieren / '),
                hcode(context, '⭱ Arbeit importieren'),
                const TextSpan(text: '; neu anlegen über '),
                hcode(context, '＋ Neue Arbeit'),
                const TextSpan(text: ' — aus LaTeX-Quelltext'),
              ]),
            ],
            [
              cell([
                hb('Eingebaute Voranalyse'),
                const TextSpan(text: ' der mitgelieferten Arbeiten'),
              ]),
              // „gebündelt in js/data/“ → in der Flutter-App: assets/data/.
              cell([
                const TextSpan(text: 'Repo: '),
                hcode(context, 'data/generated/'),
                const TextSpan(text: ' → gebündelt in '),
                hcode(context, 'assets/data/'),
              ]),
              cell([
                const TextSpan(
                    text: 'per Gesamt-Prompt neu erzeugen und als eigene '
                        'Arbeit importieren'),
              ]),
            ],
          ],
        ),
        const SizedBox(height: 10),
        // E7-Anpassung des Umzieh-Hinweises: „localhost und file://“ gibt es
        // in der App nicht mehr — der Origin-Gedanke gilt nur fürs Web-Target,
        // lokal ist es die Datenbank des Geräts; belegstand.json ist hier ein
        // gebündeltes Asset (assets/data/belegstand.json, Import-Once).
        Notice(
          variant: NoticeVariant.info,
          child: Text.rich(TextSpan(children: [
            hb('Wichtig beim Umziehen:'),
            const TextSpan(
                text: ' Der Speicher gehört zum Gerät (im Web: zur '
                    'Adresse/Origin). Web-Version und lokale App haben '),
            hb('getrennte'),
            const TextSpan(text: ' Speicher — den Belegstand mit '),
            hcode(context, '⭳ Sichern'),
            const TextSpan(text: ' mitnehmen und drüben mit '),
            hcode(context, '⭱ Laden'),
            const TextSpan(text: ' ersetzen. Als '),
            hcode(context, 'assets/data/belegstand.json'),
            const TextSpan(
                text: ' mitgebündelt, übernimmt ihn eine frische '
                    'Installation automatisch.'),
          ])),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 4 · Im Web nutzen vs. lokal starten
// ---------------------------------------------------------------------------

class _WebLokalCard extends StatelessWidget {
  const _WebLokalCard();

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final small = AppTextStyles.small.copyWith(color: t.ink2, height: 1.55);

    Widget li(List<InlineSpan> spans) => Padding(
          padding: const EdgeInsets.only(left: 18),
          child: Text.rich(
              TextSpan(children: [const TextSpan(text: '• '), ...spans]),
              style: small),
        );

    // `.well` (theme.css:314): surface-2, Hairline, radius-sm, 11/13.
    Widget well(List<Widget> children) => Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
            decoration: BoxDecoration(
              color: t.surface2,
              border: Border.all(color: t.border),
              borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          ),
        );

    final web = well([
      Text('🌐 Web (GitHub Pages)',
          style: small.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
      const SizedBox(height: 6),
      Text('Einfach aufrufen — auch am iPad:', style: small),
      const SizedBox(height: 6),
      Text.rich(
        TextSpan(children: [
          hlink(context, 'robinkarner.github.io/thesoR ↗',
              () => launchUrl(Uri.parse(kThesorWebUrl))),
        ]),
        style: small,
      ),
      const SizedBox(height: 6),
      li([
        const TextSpan(text: 'immer der letzte Stand von '),
        hcode(context, 'main'),
      ]),
      // E6: der Original-Punkt „Passwort-geschützt — einmal eingeben, der
      // Browser bleibt angemeldet“ entfällt — das Gate gibt es nicht mehr.
      li([
        // „PDFs aus sources/ im Repo“ → in der App sind es die gebündelten
        // assets/sources/-Dateien.
        const TextSpan(text: 'gebündelte PDFs ('),
        hcode(context, 'assets/sources/'),
        const TextSpan(text: ') werden automatisch erkannt'),
      ]),
      li([const TextSpan(text: 'eigene PDFs/Belege bleiben im Browser des Geräts')]),
    ]);

    // E7/Plattform-Anpassung: die Original-Box beschrieb den Start der
    // JS-Web-App (start-website.bat, python3 server.py, file://-Doppelklick).
    // Die Flutter-App startet lokal als natives Programm — der Inhalt ist
    // minimal auf diese Realität umgeschrieben.
    final lokal = well([
      Text('💻 Lokal',
          style: small.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
      const SizedBox(height: 6),
      Text.rich(
        TextSpan(children: [
          hb('Desktop (Windows/macOS/Linux):'),
          const TextSpan(
              text: ' die App als natives Programm starten — gleicher '
                  'Funktionsumfang inkl. PDF-Markieren.'),
        ]),
        style: small,
      ),
      const SizedBox(height: 6),
      Text.rich(
        TextSpan(children: [
          const TextSpan(
              text: 'Alle Daten bleiben in der lokalen Datenbank des Geräts; '
                  'PDFs über '),
          hcode(context, '⭱ Import'),
          const TextSpan(text: ' laden oder über ⭳ direkt beschaffen.'),
        ]),
        style: small,
      ),
    ]);

    return HilfeCard(
      eyebrow: '4 · Im Web nutzen vs. lokal starten',
      children: [
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, box) {
          // .grid.grid-2 mit gap 12 — auf schmalen Viewports untereinander.
          if (box.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                Row(children: [web]),
                Row(children: [lokal]),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [web, lokal],
          );
        }),
      ],
    );
  }
}
