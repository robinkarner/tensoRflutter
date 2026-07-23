/// Test-Arbeit der Wissen-Tests: kleine Thesis + komplettes DATA_META
/// (gesamt/kapitel/fazit/analyse/stats) — genug, damit alle 8 Tabs
/// rendern können.
library;

import 'package:thesor/data/bundles/runtime.dart';
import 'package:thesor/data/models/models.dart';

ThesisRuntime wissenTestRuntime({String? erklaerbuch}) {
  final thesis = Thesis.fromJson({
    'meta': {'title': 'Testarbeit', 'author': 'Muster, M.', 'university': 'FH Test'},
    'chapters': [
      {
        'id': '1',
        'num': 1,
        'title': 'Einleitung',
        'page': 1,
        'sections': [
          {
            'id': '1.1',
            'title': 'Motivation',
            'level': 2,
            'paragraphs': [
              {
                'id': '1.1-p1',
                'type': 'text',
                'text': 'Erster Satz. Zweiter Satz mit Beleg.[^1]',
                'footnotes': [
                  {
                    'num': 1,
                    'text': 'Vgl. Kim 2023, S. 4.',
                    'sources': ['kim2023'],
                  },
                ],
              },
              {'id': '1.1-p2', 'type': 'text', 'text': 'Ohne Belege.'},
            ],
          },
        ],
      },
      {
        'id': '6',
        'num': 6,
        'title': 'Fazit',
        'page': 40,
        'sections': [
          {
            'id': '6.0',
            'title': 'Fazit',
            'level': 2,
            'isIntro': true,
            'paragraphs': [
              {'id': '6.0-p1', 'type': 'text', 'text': 'Alles belegt.'},
            ],
          },
        ],
      },
    ],
  });

  return ThesisRuntime(
    projectId: 'default',
    projectName: 'Testarbeit',
    thesis: thesis,
    sections: {
      '1_1': SectionAnalyse.fromJson({
        'sectionId': '1.1',
        'paragraphs': [
          {
            'id': '1.1-p1',
            'kernaussage': 'Kern von p1.',
            'uebersetzung': 'Translation p1.',
            'sentences': [
              {'text': 'Erster Satz.', 'einfach': 'Einfach eins.'},
              {'text': 'Zweiter Satz mit Beleg.[^1]', 'einfach': 'Einfach zwei.'},
            ],
            'belege': [
              {
                'num': 1,
                'quellen': ['kim2023'],
                'claim': 'Was belegt wird.',
              },
            ],
          },
        ],
      }),
    },
    sources: [
      Source.fromJson(const {
        'id': 'kim2023',
        'title': 'Health Data Paper',
        'author': 'Kim, J.',
        'year': 2023,
        'kind': 'artikel',
        'citations': [
          {'footnote': 1},
        ],
      }),
    ],
    meta: DataMeta.fromJson({
      'gesamt': {
        'executiveSummary': 'Die **Zusammenfassung** der Arbeit.',
        'ergebnisse': {
          'positiv': [
            {'titel': 'Gutes Ergebnis', 'text': 'Alles gut.'},
          ],
          'luecken': [
            {'titel': 'Offene Lücke', 'text': 'Fehlt noch.', 'frist': '2029'},
          ],
          'spannungen': [
            {'titel': 'Spannungsfeld', 'text': 'Reibung.'},
          ],
        },
        'roterFaden': [
          {'schritt': 1, 'kapitel': 1, 'label': 'Frage stellen', 'text': 'Warum?'},
          {'schritt': 2, 'kapitel': 6, 'label': 'Antwort geben', 'text': 'Darum.'},
        ],
        'timeline': [
          {
            'datum': '2015-01-01',
            'label': 'ELGA-Rollout beginnt',
            'kategorie': 'at',
            'status': 'erledigt',
          },
          {
            'datum': '2029-03-26',
            'label': 'EHDS greift',
            'kategorie': 'eu',
            'status': 'offen',
          },
        ],
      },
      'kapitel': {
        '1': {
          'chapter': 1,
          'title': 'Einleitung',
          'kurzfassung': 'Worum es geht.',
          'kernaussagen': ['Kernaussage eins.'],
          'begriffe': [
            {'begriff': 'EHDS', 'erklaerung': 'European Health Data Space'},
          ],
          'fristen': [
            {'datum': '26. März 2029', 'was': 'Frist läuft ab'},
          ],
          'abschnitte': [
            {'id': '1.1', 'titel': 'Motivation', 'einzeiler': 'Der Einstieg.'},
          ],
          'fazitBeitrag': 'Liefert die Frage.',
        },
      },
      'fazit': {
        'kapitelFluss': [
          {'from': '1', 'to': '6', 'label': 'Frage → Antwort'},
        ],
        'findings': [
          {
            'id': 'f1',
            'label': 'Zugang erfüllt',
            'typ': 'positiv',
            'beschreibung': 'Das Portal erfüllt die Vorgabe.',
            'fazitParagraphId': '6.0-p1',
            'abschnitte': ['1.1'],
            'fristen': [],
          },
        ],
      },
      'analyse': {
        'standards': {
          'titel': 'Bewertung nach Standards',
          'verdikt': 'Insgesamt **solide**.',
          'kriterien': [
            {'name': 'Fragestellung & Methodik', 'note': 'stark', 'text': 'Klar.'},
            {'name': 'Quellenarbeit', 'note': 'ausbaufaehig', 'text': 'Mehr wäre gut.'},
          ],
          'verbesserung': ['Fazit-Konsistenz prüfen.'],
        },
        'struktur': {
          'titel': 'Struktur & Aufbau',
          'markdown': 'Der Aufbau trägt.',
          'punkte': [
            {'typ': 'staerke', 'text': 'Roter Faden sichtbar.'},
          ],
        },
      },
      'stats': {
        'fussnoten': 397,
        'quellen': 74,
        'absaetze': 233,
        'saetze': 688,
        'fnPerChapter': {'1': 3, '6': 0},
        'paraPerChapter': {'1': 2, '6': 1},
        'byKind': {'artikel': 20, 'recht-eu': 10},
        'kindLabels': {'artikel': 'Peer-Review-Artikel', 'recht-eu': 'Rechtsquelle EU'},
        'topSources': [
          {'id': 'ehds-vo', 'title': 'EHDS-Verordnung', 'kind': 'recht-eu', 'cites': 107},
        ],
      },
      'erklaerbuch': ?erklaerbuch,
    }),
    figures: FiguresManifest.fromJson(const {
      'figuren': [
        {'id': 'abb-1', 'nummer': 'Abb. 1', 'titel': 'Architektur'},
      ],
      'tabellen': [],
    }),
    erklaerbuch: erklaerbuch,
  );
}
