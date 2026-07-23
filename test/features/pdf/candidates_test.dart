/// Kandidaten-Erkennung: NUR Referenz-Hash (Score 200) und exakte
/// Quellen-id (150); „✗ passt nicht"-Liste filtert; Dateiname ist bewusst
/// KEIN Erkennungsmerkmal (pdfengine.js:266-282).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/features/pdf/assign_panel/candidates.dart';

void main() {
  test('Hash-Treffer: Score 200, „automatisch erkannt", sure', () {
    final out = findCandidates(
      srcId: 'kraus2025',
      srcHash: 'ts-3fa9c012',
      inbox: ['studie-TS-3FA9C012.pdf', 'anderes.pdf'],
      dismissed: const [],
    );
    expect(out, hasLength(1));
    expect(out.first.name, 'studie-TS-3FA9C012.pdf');
    expect(out.first.score, 200);
    expect(out.first.why, 'automatisch erkannt');
    expect(out.first.sure, isTrue);
  });

  test('id-Datei: Score 150, „id-Datei"; Ranking nach Score', () {
    final out = findCandidates(
      srcId: 'kraus2025',
      srcHash: 'ts-3fa9c012',
      inbox: ['Kraus2025.pdf', 'x-ts-3fa9c012.pdf'],
      dismissed: const [],
    );
    expect(out.map((c) => c.score), [200, 150]);
    expect(out[1].why, 'id-Datei');
  });

  test('„✗ passt nicht" filtert dauerhaft', () {
    final out = findCandidates(
      srcId: 'kraus2025',
      srcHash: 'ts-3fa9c012',
      inbox: ['kraus2025.pdf'],
      dismissed: ['kraus2025.pdf'],
    );
    expect(out, isEmpty);
  });

  test('ähnliche Dateinamen sind KEINE Kandidaten', () {
    final out = findCandidates(
      srcId: 'kraus2025',
      srcHash: 'ts-3fa9c012',
      inbox: ['kraus-2025-study.pdf', 'Kraus_Health_2025.pdf'],
      dismissed: const [],
    );
    expect(out, isEmpty);
  });
}
