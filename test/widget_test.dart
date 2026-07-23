// Shell-/Router-Basistests (F-E): Pfad-Bauhilfen und die Active-Logik der
// Topbar-Navigation — reine Funktionslogik ohne DB/Assets. Der einstige
// Flutter-Template-Test (MyApp/Counter) ist mit der echten App entfallen;
// End-to-End-Boot-Tests folgen in Welle 3 (Integrations-Sweep).

import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/core/router/routes.dart';

void main() {
  group('Routes.studioPath', () {
    test('baut die Segmente sec/modus/para in Original-Reihenfolge', () {
      expect(Routes.studioPath(), '/studio');
      expect(Routes.studioPath(sec: '3.2'), '/studio/3.2');
      expect(
        Routes.studioPath(sec: '3.2', modus: StudioModes.lesen),
        '/studio/3.2/lesen',
      );
      expect(
        Routes.studioPath(sec: '3.2', modus: StudioModes.pruefen, para: 'p-3-2-4'),
        '/studio/3.2/pruefen/p-3-2-4',
      );
    });

    test('ohne Abschnitt gibt es weder Modus noch Absatz-Anker', () {
      expect(Routes.studioPath(modus: StudioModes.editor), '/studio');
      expect(Routes.studioPath(sec: '', modus: StudioModes.editor), '/studio');
    });
  });

  group('weitere Pfad-Bauhilfen', () {
    test('quellen/analyse/hilfe mit und ohne Parameter', () {
      expect(Routes.quellenPath(), '/quellen');
      expect(Routes.quellenPath('kim2023'), '/quellen/kim2023');
      expect(Routes.analysePath(), '/analyse');
      expect(Routes.analysePath(tab: 'kapitel', arg: '3'), '/analyse/kapitel/3');
      expect(Routes.hilfePath('import'), '/hilfe/import');
    });

    test('Parameter werden URL-kodiert', () {
      expect(Routes.quellenPath('a b'), '/quellen/a%20b');
    });
  });

  group('Routes.viewOf (Topbar-Active-Logik)', () {
    test('liefert das erste Pfadsegment', () {
      expect(Routes.viewOf('/studio/3.2/lesen'), 'studio');
      expect(Routes.viewOf('/analyse/kapitel'), 'analyse');
      expect(Routes.viewOf('/doc'), 'doc');
    });

    test('leere Location fällt aufs Studio zurück', () {
      expect(Routes.viewOf('/'), 'studio');
      expect(Routes.viewOf(''), 'studio');
    });
  });
}
