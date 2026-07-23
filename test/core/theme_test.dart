import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/core/theme/color_mix.dart';
import 'package:thesor/core/theme/theme.dart';
import 'package:thesor/core/theme/tokens.dart';
import 'package:thesor/core/util/format.dart';

/// Token-Stichproben gegen die Rohwerte aus css/theme.css (Dossier 02 §5.2)
/// — schlägt eine dieser Proben fehl, ist das Designsystem verfälscht.
void main() {
  group('BookClothTokens Light', () {
    final t = BookClothTokens.light();

    test('Kernfarben', () {
      expect(t.bg, const Color(0xFFF4F2EC));
      expect(t.bgDeep, const Color(0xFFECE9E1));
      expect(t.surface, const Color(0xFFFEFDFB));
      expect(t.border, const Color(0xFFDDD8CD));
      expect(t.ink, const Color(0xFF131316));
      expect(t.muted, const Color(0xFF51535C));
      expect(t.accent, const Color(0xFFB4552D));
      expect(t.accentSoft, const Color(0xFFF7EBE4));
      expect(t.accentContrast, const Color(0xFFFFFFFF));
    });

    test('Ampel, KI, Level', () {
      expect(t.good, const Color(0xFF3F7449));
      expect(t.warn, const Color(0xFF96702C));
      expect(t.bad, const Color(0xFFA04B3C));
      expect(t.ki, const Color(0xFF54687D));
      expect(t.lvl1, const Color(0xFF5D7186));
      // Stufe 2 = warn, Stufe 3 = good (bewusste Gleichsetzung im Original).
      expect(t.lvl2, t.warn);
      expect(t.lvl3, t.good);
      // Aliase.
      expect(t.warning, t.warn);
      expect(t.critical, t.bad);
      expect(t.ok, t.good);
    });

    test('Kategorien, Wissen, Magic', () {
      expect(t.catNorm, const Color(0xFF2E6B74));
      expect(t.catFrist, const Color(0xFFA8721E));
      expect(t.catSchlag, const Color(0xFF4E5F8A));
      expect(t.cat('luecke'), const Color(0xFFAD5151));
      expect(t.cat('unbekannt'), isNull);
      expect(t.wissen, const Color(0xFF3F5D8C));
      expect(t.wissenSoft, const Color(0xFFE8EDF5));
      expect(t.magicTop, const Color(0xFFF0591A));
      expect(t.magicEdge, const Color(0xFFA33305));
    });
  });

  group('BookClothTokens Dark', () {
    final t = BookClothTokens.dark();

    test('Kernfarben', () {
      expect(t.bg, const Color(0xFF1E1C17));
      expect(t.bgDeep, const Color(0xFF161411));
      expect(t.surface, const Color(0xFF27231D));
      expect(t.borderStrong, const Color(0xFF575048));
      expect(t.ink, const Color(0xFFF0EDE5));
      expect(t.accent, const Color(0xFFE28A5D));
      expect(t.accentContrast, const Color(0xFF2B1409));
    });

    test('Level, Wissen, Magic', () {
      expect(t.lvl1, const Color(0xFF8BA1B6));
      expect(t.lvl1Soft, const Color(0xFF272D33));
      expect(t.kiSoft, const Color(0xFF252A2F));
      expect(t.wissen, const Color(0xFF8BA7D6));
      expect(t.wissenLine, const Color(0xFF3E4C68));
      expect(t.magicTop, const Color(0xFFF2621F));
      expect(t.magicEdge, const Color(0xFF8F2E04));
      // Tag-Basistöne sind in beiden Themes identisch.
      expect(t.tagVenue, BookClothTokens.light().tagVenue);
      expect(t.tagOa, BookClothTokens.light().tagOa);
    });
  });

  group('Feste Werte', () {
    test('Radii, Topbar, Breakpoints', () {
      expect(BookClothTokens.radiusXs, 4);
      expect(BookClothTokens.radiusSm, 6);
      expect(BookClothTokens.radius, 8);
      expect(BookClothTokens.radiusLg, 11);
      expect(BookClothTokens.topbarH, 56);
      expect(BookClothTokens.bpStack, 720);
      expect(BookClothTokens.bpNarrow, 900);
      expect(BookClothTokens.bpWorkspace, 999);
      expect(BookClothTokens.bpWide, 1200);
    });

    test('Beleg-Palette (levels.js)', () {
      expect(BookClothTokens.markFarben.length, 8);
      expect(BookClothTokens.markFarbe('gelb'), const Color(0xFFE8C33F));
      expect(BookClothTokens.markFarbe('rot'), const Color(0xFFCF6D5C));
      expect(BookClothTokens.markFarbe('tuerkis'), const Color(0xFF4FB3A5));
      expect(BookClothTokens.markFarbe('fuchsia'), isNull);
    });

    test('Hardcodes', () {
      expect(BookClothTokens.pdfPageBg, const Color(0xFFFFFFFF));
      expect(BookClothTokens.searchHitOutline, const Color(0xFFE8A800));
      expect(BookClothTokens.magicCheckBg, const Color(0xFF2E7D32));
      expect(BookClothTokens.brandClaude, const Color(0xFFCF6A45));
    });
  });

  group('ThemeData-Verdrahtung', () {
    test('Extension vorhanden, Scaffold = bg', () {
      final light = appThemeLight;
      final dark = appThemeDark;
      expect(light.extension<BookClothTokens>(), isNotNull);
      expect(light.scaffoldBackgroundColor, const Color(0xFFF4F2EC));
      expect(dark.scaffoldBackgroundColor, const Color(0xFF1E1C17));
      expect(light.colorScheme.primary, const Color(0xFFB4552D));
    });

    test('lerp interpoliert Farben', () {
      final l = BookClothTokens.light();
      final d = BookClothTokens.dark();
      expect(l.lerp(d, 0).bg, l.bg);
      expect(l.lerp(d, 1).bg, d.bg);
    });
  });

  group('color-mix-Pendant', () {
    test('alphaPct = C x% transparent', () {
      const c = Color(0xFFB4552D);
      expect(c.alphaPct(22).a, closeTo(.22, .005));
      expect(c.alphaPct(100), c);
    });

    test('mix = color-mix(A x%, B)', () {
      const a = Color(0xFF000000);
      const b = Color(0xFFFFFFFF);
      // 100% A → A; 0% A → B; 50% → Mittelgrau.
      expect(a.mix(b, 100), a);
      expect(a.mix(b, 0), b);
      expect(a.mix(b, 50).r, closeTo(.5, .01));
    });
  });

  group('Format-Helfer (Schwellen exakt)', () {
    test('fmtUsd', () {
      expect(fmtUsd(null), '–');
      expect(fmtUsd(0.0333), '\$0.0333');
      expect(fmtUsd(0.3299), '\$0.330');
      expect(fmtUsd(1.5), '\$1.50');
    });

    test('fmtEur', () {
      expect(fmtEur(null), '–');
      expect(fmtEur(0.004), '<0.01 €');
      expect(fmtEur(0.3299), '0.33 €');
    });

    test('fmtTok', () {
      expect(fmtTok(999), '999');
      expect(fmtTok(1500), '1.5k');
      expect(fmtTok(12345), '12k');
    });

    test('fmtDate', () {
      expect(fmtDate('2024-03-07'), '7.3.2024');
      expect(fmtDate('2024-03'), '3.2024');
      expect(fmtDate('irgendwas'), 'irgendwas');
      expect(fmtDate(null), '');
    });

    test('fmtDeNum', () {
      expect(fmtDeNum(2.5), '2.5');
      expect(fmtDeNum(2.0), '2');
      // de-AT gruppiert laut CLDR mit geschütztem Leerzeichen (U+00A0) —
      // identisch zu `toLocaleString('de-AT')` im Browser (Original-Optik).
      expect(fmtDeNum(1234.5678), '1\u00A0234,568');
    });

    test('ellipsize', () {
      expect(ellipsize('kurz', 10), 'kurz');
      expect(ellipsize('ein langer Titel', 8), 'ein lang…');
    });
  });
}
