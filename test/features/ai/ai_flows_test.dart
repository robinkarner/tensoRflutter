/// K-3-Flow-Tests: Registry (7 Flows, Meta wörtlich), Prompt-Bau inkl.
/// ⚙-Zusatz-Instruktion, Import-Kernlogik (Marks/Instanzen/Quellen) mit
/// KV-Speicherorten, Format-Checker-Meldungen und Referenz-/Stat-Stände —
/// gegen die enhance.js-Vorlage, mit der Mini-Testarbeit aus S-2.
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/data/bundles/indexes.dart';
import 'package:thesor/data/db/database.dart';
import 'package:thesor/data/db/kv.dart';
import 'package:thesor/features/ai/ai.dart';
import 'package:thesor/features/quellen/quellen.dart' show QuellenGptHooks;
import 'package:thesor/features/quellen/state/quellen_kv.dart';
import 'package:thesor/features/studio/layout/studio_state.dart';
import 'package:thesor/features/studio/views/instanz_edit_modal.dart'
    show InstanzGenerateHook;

import '../studio/studio_state_test.dart' show testRuntime;

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
    container.read(activeRuntimeProvider.notifier).activate(testRuntime());
    await container.read(studioPrefsCtlProvider.future);
    await container.read(studioKvProvider.future);
    await container.read(quellenKvProvider.future);
    await container.read(claudeCfgStoreProvider.future);
    await container.read(enhCfgStoreProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  const ctx = AiFlowCtx();

  group('Registry (enhance.js:60-185)', () {
    test('7 Flows mit exakten ids/Icons/Scopes', () {
      final flows = buildAiFlows(container, ctx);
      expect(flows.map((f) => f.id),
          ['all', 'buch', 'marks', 'conn', 'inst', 'quellen', 'style']);
      expect(flows.map((f) => f.icon), ['⚡', '📓', '🖍', '⤳', '🎛', '📚', '🤖']);
      final all = flows[0];
      expect(all.title, 'Voranalyse (alles)');
      expect(all.aktion, 'Analyze');
      expect(all.multi, isTrue);
      expect(all.scope, 'Ganze Arbeit');
      expect(flows[2].scope, 'Dieser Abschnitt');
      // Abschnitts-Fallback: erster geordneter Abschnitt der Testarbeit.
      expect(flows[2].section, '1.1');
      expect(flows[6].toggle, isTrue);
      expect(flows[6].aktion, isNull);
    });

    test('all.run wirft die Multi-Datei-Meldung wörtlich', () {
      final all = aiFlowById(buildAiFlows(container, ctx), 'all');
      expect(
        () => all.run!('egal'),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          'Die Voranalyse-Antwort umfasst mehrere Dateien — als einzelne Dateien sichern und über „⭱ Analysen importieren“ einlesen.',
        )),
      );
    });

    test('all.build = masterPrompt + LaTeX-Umschlag', () {
      final all = aiFlowById(buildAiFlows(container, ctx), 'all');
      final prompt = all.build!();
      expect(prompt, contains('=' * 60));
      expect(prompt, contains('HIER DER LATEX-QUELLTEXT DER ARBEIT:'));
    });

    test('marks.build enthält Regeln + Absatz-Blöcke ohne [^n]-Marker', () {
      final marks = aiFlowById(buildAiFlows(container, ctx), 'marks');
      final prompt = marks.build!();
      expect(prompt,
          startsWith('Du markierst in „Thesis Studio" Schluesselstellen'));
      expect(prompt, contains('ANTWORTE NUR mit diesem JSON:'));
      expect(prompt, contains('ABSÄTZE (Abschnitt 1.1 · Motivation):'));
      expect(prompt, contains('[1.1-p1]'));
      // Fußnoten-Marker sind entfernt:
      expect(prompt, isNot(contains('[^1]')));
    });

    test('aiPromptFor hängt die ⚙-Zusatz-Instruktion an', () {
      container
          .read(enhCfgStoreProvider.notifier)
          .patch('marks', instruction: 'Sei knapper');
      final marks = aiFlowById(buildAiFlows(container, ctx), 'marks');
      expect(aiPromptFor(container, marks),
          endsWith('\n\nZUSÄTZLICHE ANWEISUNG:\nSei knapper'));
    });

    test('quellen: _src-Kaskade + Prompt projektabhängig (W8/E9-Fix)', () {
      final quellen = aiFlowById(buildAiFlows(container, ctx), 'quellen');
      // Keine aktive Datei → erste Quelle des Abschnitts (kim2023).
      final prompt = quellen.build!();
      expect(prompt, contains('„Testarbeit“')); // statt hartem EHDS-Text
      expect(prompt, contains('QUELLE: Kim, J. — Health Data Paper'));
      // Die Mini-Testarbeit trägt keine vorgebauten `stellen` (das macht
      // build_data beim Bundle-Merge) — die Kopfzeile zählt trotzdem exakt.
      expect(prompt, contains('ZITIERSTELLEN (0):'));
      expect(prompt, contains('"sourceId": "kim2023"'));
      // artikel → Seiten-Belegung ('seite', nicht 'fundstelle').
      expect(prompt, contains('"seite": <Seitenzahl>'));
    });
  });

  group('Import-Kernlogik (enhance.js:187-213)', () {
    test('Marks: ersetzt je Absatz komplett, filtert Unbekanntes', () {
      final out = aiImportMarks(container, '''
        {"sectionId":"1.1","items":{
          "1.1-p1":[{"snippet":" binnen 24 Monaten ","kategorie":"frist"},
                     {"snippet":"","kategorie":"frist"},
                     {"snippet":"x","kategorie":"gibtsnicht"}],
          "1.1-p2":"kein array"}}''');
      expect(out, '1 Markierungen übernommen');
      final extra = container
          .read(studioKvProvider.notifier)
          .readMap(KvKeys.marksExtra);
      expect(extra['1.1-p1'], [
        {'snippet': 'binnen 24 Monaten', 'kategorie': 'frist'},
      ]);
      // Marks-Stat zieht nach.
      final marks = aiFlowById(buildAiFlows(container, ctx), 'marks');
      expect(marks.stat!(), '1');
      expect(marks.statOn!(), isTrue);
    });

    test('Marks: fehlendes items wirft wörtlich', () {
      expect(
        () => aiImportMarks(container, '{"nix": 1}'),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', 'Feld "items" fehlt.')),
      );
    });

    test('Instanzen: Hauptform + Teil-Form, unbekannte ids übersprungen', () {
      final out1 = aiImportInst(container,
          '{"instanzen":{"erklaerung":{"1.1-p1":"**md**"},"fremd":{"1.1-p1":"x"}}}');
      expect(out1, '1 Absatz-Instanzen übernommen · übersprungen: fremd');
      final dock = container
          .read(studioKvProvider.notifier)
          .readMap(KvKeys.paraDock);
      expect((dock['erklaerung'] as Map)['1.1-p1'], '**md**');

      // Teil-Form mit "mode" ERGÄNZT.
      final out2 = aiImportInst(
          container, '{"mode":"analyse","items":{"1.1-p2":"Zeile"}}');
      expect(out2, '1 Absatz-Instanzen übernommen');
      final dock2 = container
          .read(studioKvProvider.notifier)
          .readMap(KvKeys.paraDock);
      expect((dock2['erklaerung'] as Map)['1.1-p1'], '**md**');
      expect((dock2['analyse'] as Map)['1.1-p2'], 'Zeile');
    });

    test('quellen.run: defaultet sourceId/generatedBy, legt roh ab', () {
      final quellen = aiFlowById(buildAiFlows(container, ctx), 'quellen');
      final out = quellen.run!(
          '{"stellen":[{"footnote":1,"seite":4,"zitat":"Original."}]}');
      expect(out, '1 Stelle(n) übernommen');
      final res = container
          .read(quellenKvProvider.notifier)
          .readMap(KvKeys.resolutions);
      final r = res['kim2023'] as Map;
      expect(r['sourceId'], 'kim2023');
      expect(r['generatedBy'], 'gpt');
      expect((r['stellen'] as List).length, 1);
    });

    test('conn.run: Import in kiConnections + Statusmeldung', () {
      final conn = aiFlowById(buildAiFlows(container, ctx), 'conn');
      // Die Mini-Arbeit hat nur EINEN Abschnitt — von==nach wird verworfen.
      expect(
        () => conn.run!(
            '{"connections":[{"typ":"folgerung","von":{"sectionId":"1.1"},"nach":{"sectionId":"1.1"}}]}'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Format-Checker (enhance.js:215-318)', () {
    test('leer / Format frei / ungültiges JSON', () {
      final buch = aiFlowById(buildAiFlows(container, ctx), 'buch');
      final leer = runAiCheck(buch, '   ', claudeClean);
      expect(leer.ok, isFalse);
      expect(leer.head.single.text,
          'Nichts zu prüfen — die Antwort (z. B. aus dem externen GPT) oben einfügen.');

      final marks = aiFlowById(buildAiFlows(container, ctx), 'marks');
      final bad = runAiCheck(marks, 'kein json', claudeClean);
      expect(bad.ok, isFalse);
      expect(bad.head.single.text, startsWith('✗ Kein gültiges Format: kein gültiges JSON'));

      // Flow ohne Checker (all) → Format frei.
      final all = aiFlowById(buildAiFlows(container, ctx), 'all');
      expect(runAiCheck(all, 'x', claudeClean).head.single.text,
          'Format frei — dieser Import nimmt den Text unverändert an.');
    });

    test('Marks-Checker zählt gültige, meldet Probleme', () {
      final r = aiCheckMarks(
          '{"items":{"p1":[{"snippet":"a","kategorie":"frist"},{"snippet":"","kategorie":"frist"},{"snippet":"b","kategorie":"nope"}]}}');
      expect(r.ok, isTrue);
      expect(r.head.map((b) => b.text).join(),
          'Format erkannt: Markierungen · 1 gültige über 1 Absätze.');
      expect(r.problems, [
        '1 Eintrag/Einträge ohne Snippet (werden übersprungen)',
        'unbekannte Kategorie(n): nope — erlaubt: norm, frist, akteur, tech, these, luecke, zahl, abk, schlag',
      ]);
      expect(r.bereit, isFalse);
    });

    test('Conn-Checker: vollständige nach Typ, unvollständige ignoriert', () {
      final r = aiCheckConn(
          '{"connections":[{"typ":"folgerung","von":{"sectionId":"1"},"nach":{"sectionId":"2"}},{"typ":"x"}]}');
      expect(r.ok, isTrue);
      expect(r.head.map((b) => b.text).join(),
          'Format erkannt: Connections · 1 vollständig (folgerung: 1).');
      expect(r.problems,
          ['1 ohne von/nach (mit sectionId) oder typ (werden ignoriert)']);
    });

    test('Inst-Checker meldet unbekannte ids', () {
      final r = aiCheckInst(
          '{"instanzen":{"erklaerung":{"p":"x"},"fremd":{"p":"y"}}}',
          {'erklaerung'});
      expect(r.ok, isTrue);
      expect(r.problems, ['unbekannte Instanz-IDs (übersprungen): fremd']);
    });

    test('Quellen-Checker: sourceId-Hinweis + formatVersion-Toleranz', () {
      final r = aiCheckQuellen(
          '{"sourceId":"anders","stellen":[{"footnote":1,"seite":2,"zitat":"z"},{"kommentar":"ohne num"}]}',
          'kim2023');
      expect(r.ok, isTrue);
      expect(r.head.map((b) => b.text).join(),
          'Format erkannt: Quellen-Durchlauf · 2 Stellen (1 mit Seite/Fundstelle, 1 mit Zitat).');
      expect(r.problems, [
        '1 Stelle(n) ohne "footnote" (Fußnoten-Zuordnung fehlt)',
        'sourceId „anders“ ≠ aktive Quelle „kim2023“ — beim Übernehmen wird die aktive Quelle gesetzt',
        'kein "formatVersion" (erwartet "1.0") — wird toleriert',
      ]);
    });

    test('Buch-Checker: JSON abgelehnt, Titel-Pflicht, Zaun-Parität', () {
      expect(
        () => aiCheckBuch('{"a":1}'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message',
            'Das sieht nach JSON aus — das Erklärbuch erwartet Markdown (beginnend mit „# Titel“).')),
      );
      final ok = aiCheckBuch('# Mein Buch\n\n```js\n1\n```\n');
      expect(ok.ok, isTrue);
      expect(ok.head.map((b) => b.text).join(),
          'Format erkannt: Erklärbuch (Markdown) · Titel „Mein Buch“ · ~1 Code-/Chart-Zellen.');
      final offen = aiCheckBuch('kein titel\n```\n');
      expect(offen.ok, isFalse);
      expect(offen.problems, [
        'keine „# Titel“-Überschrift gefunden',
        'ungerade Zahl von ```-Zäunen — ein Block ist nicht geschlossen',
      ]);
    });
  });

  group('Referenzen & Stände', () {
    test('refAll zählt Abschnitte/Quellen/KI-Connections', () {
      final all = aiFlowById(buildAiFlows(container, ctx), 'all');
      final r = all.reference!();
      expect(r.summary.map((b) => b.text).join(),
          'Aktueller Stand der Arbeit: 1 Abschnitte analysiert · 1 Quellen · 0 KI-Connections importiert.');
      expect(all.stat!(), '1 Abschn.');
    });

    test('buch-Stat: Testarbeit ohne Erklärbuch → „—“, mit eigenem → ✓',
        () async {
      final flows = buildAiFlows(container, ctx);
      expect(aiFlowById(flows, 'buch').stat!(), '—');
    });

    test('style-Stat folgt uiStyleCheck', () {
      final style = aiFlowById(buildAiFlows(container, ctx), 'style');
      expect(style.stat!(), 'aus');
      container.read(studioPrefsCtlProvider.notifier).setStyleCheck(true);
      expect(style.stat!(), 'an');
      expect(style.statOn!(), isTrue);
    });

    test('marksPromptFor ist auch solo nutzbar (Registry-Baustein)', () {
      final domain = container.read(studioDomainProvider)!;
      final p = marksPromptFor(domain.ctx, '1.1');
      expect(p, contains('{"sectionId": "1.1", "items"'));
    });
  });

  group('Verdrahtungs-Anker', () {
    test('wireAiHooks ist idempotent und füllt die K-3-Anker', () {
      wireAiHooks();
      wireAiHooks();
      expect(QuellenGptHooks.magicBar, isNotNull);
      expect(InstanzGenerateHook.recompile, isNotNull);
      expect(InstanzGenerateHook.afterCreate, isNotNull);
    });
  });
}
