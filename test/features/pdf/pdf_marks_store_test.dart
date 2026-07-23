/// Marks-Store: KV-Persistenz in der Original-Datenform `{srcId: Mark[]}`,
/// id-/ts-Vergabe, Object.assign-Patch, Leere-Liste-Löschung, marksForFn
/// und die Levels-Verdrahtung (levelsMarksForFnProvider).
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/data/bundles/indexes.dart';
import 'package:thesor/data/db/database.dart';
import 'package:thesor/data/db/kv.dart';
import 'package:thesor/data/models/models.dart';
import 'package:thesor/data/repos/project_repository.dart';
import 'package:thesor/features/pdf/marks/pdf_mark.dart';
import 'package:thesor/features/pdf/marks/pdf_marks_store.dart';

/// Boot-Fake: liefert eine Mini-Runtime, ohne Assets/Seeding anzufassen.
class _FakeBoot extends ProjectBoot {
  @override
  Future<BootResult> build() async => BootResult(
        runtime: ThesisRuntime(
          projectId: ProjectRecord.defaultId,
          projectName: 'Test',
          thesis: Thesis.fromJson({
            'meta': {'title': 'T'},
            'chapters': [],
          }),
        ),
        overrides: TextOverrideState.empty,
        activeId: ProjectRecord.defaultId,
        activeName: 'Test',
        warnings: const [],
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      projectBootProvider.overrideWith(_FakeBoot.new),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('addMark: id "m"+ts36+rand3, ts gesetzt, KV-Form {srcId: [json]}',
      () async {
    await container.read(pdfMarksProvider.future);
    final notifier = container.read(pdfMarksProvider.notifier);

    final mark = notifier.addMark(
      'kraus2025',
      PdfMark.neu(
        fn: 42,
        page: 15,
        rects: const [MarkRect(x: .1, y: .2, w: .5, h: .02)],
        farbe: 'blau',
        zitat: 'Zitat',
        comment: const MarkComment(x: .94, y: .195, text: '[42] Beleg'),
      ),
    );
    expect(mark.id, matches(RegExp(r'^m[0-9a-z]+$')));
    expect(mark.ts, greaterThan(0));

    // Persistenz-Form 1:1 prüfen (Belegstand dumpt diesen Key roh).
    final kv = container.read(kvStoreProvider);
    final stored = await kv.getMap(KvKeys.pdfMarks);
    expect(stored.keys, ['kraus2025']);
    final list = stored['kraus2025'] as List;
    expect(list, hasLength(1));
    final json = list.first as Map;
    expect(json['fn'], 42);
    expect(json['page'], 15);
    expect(json['farbe'], 'blau');
    expect(json['zitat'], 'Zitat');
    expect((json['rects'] as List).first, {'x': .1, 'y': .2, 'w': .5, 'h': .02});
    expect(json['comment'], {'x': .94, 'y': .195, 'text': '[42] Beleg'});
  });

  test('updateMark patcht flach; removeMark löscht; leere Liste fliegt raus',
      () async {
    await container.read(pdfMarksProvider.future);
    final notifier = container.read(pdfMarksProvider.notifier);
    final kv = container.read(kvStoreProvider);

    final m = notifier.addMark('src', PdfMark.neu(fn: 1, page: 2));
    final updated = notifier.updateMark('src', m.id, {'comment': null});
    expect(updated!.comment, isNull);
    expect(updated.fn, 1); // Rest bleibt

    notifier.removeMark('src', m.id);
    expect(notifier.marks('src'), isEmpty);
    // Leere Listen werden aus dem Objekt gelöscht (pdfengine.js:201).
    expect(await kv.getMap(KvKeys.pdfMarks), isEmpty);
  });

  test('marksForFn: Number-Vergleich toleriert String-fn', () async {
    await container.read(pdfMarksProvider.future);
    final notifier = container.read(pdfMarksProvider.notifier);
    notifier.addMark('src', const PdfMark({'fn': '7', 'page': 1, 'rects': []}));
    notifier.addMark('src', PdfMark.neu(fn: 8, page: 1));
    expect(notifier.marksForFn('src', 7), hasLength(1));
    expect(notifier.marksForFn('src', 8), hasLength(1));
    expect(notifier.marksForFn('src', 9), isEmpty);
  });

  test('bestehende Web-App-Daten im KV werden gelesen (Migration 1:1)',
      () async {
    final kv = container.read(kvStoreProvider);
    await kv.setJson(KvKeys.pdfMarks, {
      'nist-abac2014': [
        {
          'id': 'mlxq3f8abc',
          'ts': 1753257600000,
          'fn': 42,
          'page': 15,
          'farbe': 'blau',
          'zitat': 'Text …',
          'rects': [
            {'x': 0.15, 'y': 0.33, 'w': 0.68, 'h': 0.018},
          ],
          'comment': {'x': 0.94, 'y': 0.32, 'text': '[42] Label'},
        },
      ],
    });

    final state = await container.read(pdfMarksProvider.future);
    expect(state['nist-abac2014'], hasLength(1));
    expect(state['nist-abac2014']!.first.farbe, 'blau');

    // Levels-Verdrahtung (Gate-0-Risiko 5): Provider liefert die Funktion.
    final marksForFn = container.read(levelsMarksForFnProvider);
    expect(marksForFn, isNotNull);
    final inputs = marksForFn!('nist-abac2014', 42);
    expect(inputs, hasLength(1));
    expect(inputs.first.zitat, 'Text …');
    expect(inputs.first.page, 15);
    expect(inputs.first.farbe, 'blau');
    expect(marksForFn('nist-abac2014', 1), isEmpty);
  });
}
