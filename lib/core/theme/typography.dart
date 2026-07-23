import 'package:flutter/material.dart';

/// Typografie des Book-Cloth-Systems.
///
/// Font-Rollen wie im Original (theme.css:29–33):
/// Inter = UI-Grundschrift · Space Grotesk = Display/h1/h2/Eyebrows ·
/// JetBrains Mono = Code/IDs/fn-Chips · Baloo 2 (Fallback Nunito) = Magic ·
/// Serif = Lese-/Zitatflächen. Das Original nutzt System-Serifen
/// (Iowan/Palatino/Georgia) ohne Datei — kanonische Wahl hier: PT Serif (E1).
/// Noto Sans Symbols 2 ist der gebündelte Fallback für die Sonderzeichen
/// ⭳⭱⌖⌗⇤⇥∅⤳◐ … (E2), die sonst nicht auf allen Plattformen rendern.
///
/// Die fluiden CSS-Größen (clamp) werden als feste Mittelwerte übernommen —
/// Flutter skaliert ohnehin über textScaler, ein zweiter Fluid-Mechanismus
/// würde nur Unruhe stiften.
abstract final class AppFonts {
  static const String ui = 'Inter';
  static const String display = 'Space Grotesk';
  static const String mono = 'JetBrains Mono';
  static const String serif = 'PT Serif';
  static const String magic = 'Baloo 2';
  static const String magicFallback = 'Nunito';
  static const String symbols = 'Noto Sans Symbols 2';

  /// Fallback-Kette für alle Stile — Sondersymbole laufen immer über
  /// Noto Sans Symbols 2, bevor das System raten muss.
  static const List<String> fallback = [symbols];

  /// Magic-Knöpfe: `'Baloo 2', 'Nunito', var(--font-ui)`.
  static const List<String> magicFallbackChain = [magicFallback, ui, symbols];
}

/// Feste Schriftgrößen-Leiter (theme.css:136–152, clamp → Festwert).
abstract final class AppFontSizes {
  /// `--fs-body: clamp(15px, .3vw+14px, 16px)` — body-Fallback ist 15.5px.
  static const double body = 15.5;

  /// `--fs-small: 13.5px`.
  static const double small = 13.5;

  /// `--fs-lesen: clamp(16px, .4vw+14.8px, 17.5px)` — Mittelwert ~16.75.
  static const double lesen = 16.75;

  /// Überschriften (CSS-Fallback-Werte: h1 27 / h2 20 / h3 18 / h4 16).
  static const double h1 = 27;
  static const double h2 = 20;
  static const double h3 = 18;
  static const double h4 = 16;

  /// Skala `--fs-2xs … --fs-2xl`.
  static const double xs2 = 12;
  static const double xs = 13;
  static const double sm = 14;
  static const double md = 15;
  static const double lg = 16;
  static const double xl = 18;
  static const double xl2 = 21;

  /// 12px ist der BODEN für bedeutungstragenden Text (theme.css:148).
  static const double floor = 12;
}

/// Zeilenhöhen + Tracking (theme.css:145–147).
abstract final class AppLineHeights {
  static const double tight = 1.28;
  static const double ui = 1.55;

  /// body: `line-height:1.62`.
  static const double body = 1.62;
  static const double read = 1.72;
}

/// Vorgefertigte Textstile — Farben kommen aus dem Theme/DefaultTextStyle,
/// hier stehen nur Familie/Gewicht/Größe/Laufweite.
abstract final class AppTextStyles {
  /// body: Inter 400 15.5/1.62.
  static const TextStyle body = TextStyle(
    fontFamily: AppFonts.ui,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: AppFontSizes.body,
    height: AppLineHeights.body,
    fontWeight: FontWeight.w400,
  );

  /// `.small`: 13.5px.
  static const TextStyle small = TextStyle(
    fontFamily: AppFonts.ui,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: AppFontSizes.small,
    height: AppLineHeights.ui,
    fontWeight: FontWeight.w400,
  );

  /// h1/h2: Display 700, lh 1.22, ls −0.015em.
  static const TextStyle h1 = TextStyle(
    fontFamily: AppFonts.display,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: AppFontSizes.h1,
    height: 1.22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.015 * AppFontSizes.h1,
  );
  static const TextStyle h2 = TextStyle(
    fontFamily: AppFonts.display,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: AppFontSizes.h2,
    height: 1.22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.015 * AppFontSizes.h2,
  );

  /// h3/h4: UI 600, lh 1.25, ls −0.012em.
  static const TextStyle h3 = TextStyle(
    fontFamily: AppFonts.ui,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: AppFontSizes.h3,
    height: 1.25,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.012 * AppFontSizes.h3,
  );
  static const TextStyle h4 = TextStyle(
    fontFamily: AppFonts.ui,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: AppFontSizes.h4,
    height: 1.25,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.012 * AppFontSizes.h4,
  );

  /// `.eyebrow`: 600 12/1.3 Display, uppercase, tracking .09em (Aufrufer
  /// setzen den Text selbst in Großbuchstaben — siehe Eyebrow-Widget).
  static const TextStyle eyebrow = TextStyle(
    fontFamily: AppFonts.display,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.09 * 12,
  );

  /// Lese-Fläche (Lesen-Modus): Serif in `--fs-lesen`.
  static const TextStyle lesen = TextStyle(
    fontFamily: AppFonts.serif,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: AppFontSizes.lesen,
    height: AppLineHeights.read,
    fontWeight: FontWeight.w400,
  );

  /// Code/IDs: Mono in .9em der Umgebung — hier als eigenständige Größe.
  static const TextStyle mono = TextStyle(
    fontFamily: AppFonts.mono,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: AppFontSizes.sm,
    fontWeight: FontWeight.w400,
  );

  /// Formulare: 500 14/1.5 UI (theme.css:469).
  static const TextStyle form = TextStyle(
    fontFamily: AppFonts.ui,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w500,
  );

  /// Buttons `.btn`: 500 14/1.
  static const TextStyle button = TextStyle(
    fontFamily: AppFonts.ui,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 14,
    height: 1,
    fontWeight: FontWeight.w500,
  );
}
