import 'package:flutter/material.dart';

/// Designsystem „V5 — Book Cloth" als ThemeExtension.
///
/// Alle CSS-Custom-Properties aus css/theme.css (Light `:root`, Dark
/// `:root[data-theme="dark"]`) mit den EXAKTEN Rohwerten. Terracotta ist der
/// EINZIGE Akzent auf warmem Papier; „Wissen" überschreibt punktuell mit
/// Marineblau; das Magic-System hat seine eigene Orange-Familie.
///
/// Design-Konvention des Originals (theme.css:9–10):
/// RUND = Belegstatus (Ampel-Punkte) · QUADRATISCH = Struktur/Datei/Verbindung.
class BookClothTokens extends ThemeExtension<BookClothTokens> {
  const BookClothTokens({
    required this.brightness,
    // Flächen & Linien
    required this.bg,
    required this.bgDeep,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.border,
    required this.borderStrong,
    // Text
    required this.ink,
    required this.ink2,
    required this.muted,
    // Akzent (Terracotta „Book Cloth")
    required this.accent,
    required this.accentStrong,
    required this.accentInk,
    required this.accentSoft,
    required this.accentLine,
    required this.accentContrast,
    // Ampel + KI
    required this.good,
    required this.goodSoft,
    required this.warn,
    required this.warnSoft,
    required this.bad,
    required this.badSoft,
    required this.ki,
    required this.kiSoft,
    // Beleg-Stufen 1–3
    required this.lvl1,
    required this.lvl1Soft,
    required this.lvl2,
    required this.lvl2Soft,
    required this.lvl3,
    required this.lvl3Soft,
    // Mark-Kategorien (9)
    required this.catNorm,
    required this.catFrist,
    required this.catAkteur,
    required this.catTech,
    required this.catThese,
    required this.catLuecke,
    required this.catZahl,
    required this.catAbk,
    required this.catSchlag,
    // Quellen-Tags (Basiston in beiden Themes gleich, nur Ink wechselt)
    required this.tagVenue,
    required this.tagVenueInk,
    required this.tagPublisher,
    required this.tagPublisherInk,
    required this.tagOa,
    required this.tagOaInk,
    required this.tagPaywall,
    required this.tagPaywallInk,
    // Abbildungen (immer hell — Print-Grafiken brauchen hellen Grund)
    required this.figBg,
    required this.figBgPop,
    // „Wissen"-Farbwelt (Marineblau)
    required this.wissen,
    required this.wissenInk,
    required this.wissenSoft,
    required this.wissenLine,
    // Charts
    required this.grid,
    required this.baseline,
    // Magic-CTA (Retro-Block-Knöpfe)
    required this.magicTop,
    required this.magicBottom,
    required this.magicEdge,
    required this.magicC,
    required this.magicGlow,
    // Schatten (3 Stufen)
    required this.shadow1,
    required this.shadow2,
    required this.shadowPop,
  });

  final Brightness brightness;

  final Color bg, bgDeep, surface, surface2, surface3, border, borderStrong;
  final Color ink, ink2, muted;
  final Color accent, accentStrong, accentInk, accentSoft, accentLine, accentContrast;
  final Color good, goodSoft, warn, warnSoft, bad, badSoft, ki, kiSoft;
  final Color lvl1, lvl1Soft, lvl2, lvl2Soft, lvl3, lvl3Soft;
  final Color catNorm, catFrist, catAkteur, catTech, catThese, catLuecke, catZahl, catAbk, catSchlag;
  final Color tagVenue, tagVenueInk, tagPublisher, tagPublisherInk, tagOa, tagOaInk, tagPaywall, tagPaywallInk;
  final Color figBg, figBgPop;
  final Color wissen, wissenInk, wissenSoft, wissenLine;
  final Color grid, baseline;
  final Color magicTop, magicBottom, magicEdge, magicC, magicGlow;
  final List<BoxShadow> shadow1, shadow2, shadowPop;

  // ---- Aliase (CSS: --warning/--critical/--ok + Legacy) -------------------
  Color get warning => warn;
  Color get critical => bad;
  Color get ok => good;

  /// `--magic-grad`: flacher Vertikal-Verlauf der Magic-Knöpfe.
  LinearGradient get magicGrad => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [magicTop, magicBottom],
      );

  /// Kategorie-Farbe zum Daten-Schlüssel (`--cat-<key>`, marks/pc-cat).
  Color? cat(String key) => switch (key) {
        'norm' => catNorm,
        'frist' => catFrist,
        'akteur' => catAkteur,
        'tech' => catTech,
        'these' => catThese,
        'luecke' => catLuecke,
        'zahl' => catZahl,
        'abk' => catAbk,
        'schlag' => catSchlag,
        _ => null,
      };

  /// Beleg-Stufen-Farbe (1–3); 0/unbekannt → null („offen").
  Color? lvl(int level) => switch (level) { 1 => lvl1, 2 => lvl2, 3 => lvl3, _ => null };
  Color? lvlSoft(int level) => switch (level) { 1 => lvl1Soft, 2 => lvl2Soft, 3 => lvl3Soft, _ => null };

  // ---- Feste Maße (in beiden Themes identisch) ----------------------------

  /// Radii — Konvention: „Eckiger = strukturell — Pills (999px) bleiben Pills."
  static const double radius = 8;
  static const double radiusSm = 6;
  static const double radiusXs = 4;
  static const double radiusLg = 11;
  static const double radiusPill = 999;

  /// Topbar-Höhe (`--topbar-h`).
  static const double topbarH = 56;

  /// Responsive-Tiers (css/app.css:70–77): Stack ≤720 · Schmal ≤900 ·
  /// Workspace ≤999/≥1000 · Breit ≥1200.
  static const double bpStack = 720;
  static const double bpNarrow = 900;
  static const double bpWorkspace = 999;
  static const double bpWide = 1200;

  // ---- Hardcodes außerhalb der Tokens (Dossier 02 §5.6) -------------------

  /// PDF-Seite ist IMMER weiß — auch im Dark-Theme (Scans bleiben lesbar).
  static const Color pdfPageBg = Color(0xFFFFFFFF);

  /// Suchtreffer im PDF (`.pe-found`): Gelb 60% + Outline.
  static const Color searchHit = Color(0x99FFC107);
  static const Color searchHitOutline = Color(0xFFE8A800);

  /// Default-Quelltext-Highlight (`--stc`).
  static const Color srcTextHighlight = Color(0xFFE8C33F);

  /// Magic-Knopf-Textfarben + Preis-Slot + ✓-Finale + Busy-Verlauf.
  static const Color magicText = Color(0xFFEFE9DD);
  static const Color magicPriceText = Color(0xFFFFEEDA);
  static const Color magicPriceLiveText = Color(0xFFFFF4E6);
  static const Color magicCheckBg = Color(0xFF2E7D32);
  static const Color magicBusyA = Color(0xFF6B625C);
  static const Color magicBusyB = Color(0xFF453F3A);

  /// Brand-Blöcke im GPT-Hub.
  static const Color brandClaude = Color(0xFFCF6A45);
  static const Color brandClaudeEdge = Color(0xFF94441F);
  static const Color brandOpenAi = Color(0xFF10A37F);
  static const Color brandOpenAiEdge = Color(0xFF0A6B53);
  static const Color brandDotOn = Color(0xFF9DF3A1);
  static const Color brandDotDemo = Color(0xFFFFD166);

  // ---- Beleg-Markierungspalette (js/levels.js:25–30) ----------------------
  //
  // Möglichst unterscheidbare Palette; die Farbe wird je Zitierstelle einer
  // Quelle rotierend AUTOMATISCH vorgeschlagen und ist manuell übersteuerbar.
  // Die Keys sind Persistenz-Format (pdfMarks/belegLevels) — nicht umbenennen!
  static const List<({String key, Color color})> markFarben = [
    (key: 'gelb', color: Color(0xFFE8C33F)),
    (key: 'blau', color: Color(0xFF5F8FC7)),
    (key: 'gruen', color: Color(0xFF7CAB54)),
    (key: 'rosa', color: Color(0xFFD77AA4)),
    (key: 'orange', color: Color(0xFFDD8A3E)),
    (key: 'violett', color: Color(0xFF9779C9)),
    (key: 'tuerkis', color: Color(0xFF4FB3A5)),
    (key: 'rot', color: Color(0xFFCF6D5C)),
  ];

  /// Pendant zu `Levels.farbHex(key)` — Farbe zum Palette-Key oder null.
  static Color? markFarbe(String? key) {
    for (final f in markFarben) {
      if (f.key == key) return f.color;
    }
    return null;
  }

  /// Bequemer Zugriff: `BookClothTokens.of(context)`.
  static BookClothTokens of(BuildContext context) =>
      Theme.of(context).extension<BookClothTokens>()!;

  // ---- Fabriken -----------------------------------------------------------

  /// Light: Terracotta auf warmem Papier (theme.css:28–155).
  factory BookClothTokens.light() => const BookClothTokens(
        brightness: Brightness.light,
        bg: Color(0xFFF4F2EC),
        bgDeep: Color(0xFFECE9E1),
        surface: Color(0xFFFEFDFB),
        surface2: Color(0xFFF9F7F1),
        surface3: Color(0xFFEFECE4),
        border: Color(0xFFDDD8CD),
        borderStrong: Color(0xFFC4BEB1),
        ink: Color(0xFF131316),
        ink2: Color(0xFF3A3C43),
        muted: Color(0xFF51535C),
        accent: Color(0xFFB4552D),
        accentStrong: Color(0xFF9A4423),
        accentInk: Color(0xFFA04A26),
        accentSoft: Color(0xFFF7EBE4),
        accentLine: Color(0xFFE3C4B2),
        accentContrast: Color(0xFFFFFFFF),
        good: Color(0xFF3F7449),
        goodSoft: Color(0xFFE8F0E5),
        warn: Color(0xFF96702C),
        warnSoft: Color(0xFFF5EEDA),
        bad: Color(0xFFA04B3C),
        badSoft: Color(0xFFF5E8E3),
        ki: Color(0xFF54687D),
        kiSoft: Color(0xFFE9EEF3),
        lvl1: Color(0xFF5D7186),
        lvl1Soft: Color(0xFFE9EEF3),
        lvl2: Color(0xFF96702C),
        lvl2Soft: Color(0xFFF5EEDA),
        lvl3: Color(0xFF3F7449),
        lvl3Soft: Color(0xFFE8F0E5),
        catNorm: Color(0xFF2E6B74),
        catFrist: Color(0xFFA8721E),
        catAkteur: Color(0xFF7D5A96),
        catTech: Color(0xFF34786F),
        catThese: Color(0xFF46679C),
        catLuecke: Color(0xFFAD5151),
        catZahl: Color(0xFF587F3F),
        catAbk: Color(0xFF8A6D4E),
        catSchlag: Color(0xFF4E5F8A),
        tagVenue: Color(0xFF46679C),
        tagVenueInk: Color(0xFF33567E),
        tagPublisher: Color(0xFF9779C9),
        tagPublisherInk: Color(0xFF5B4487),
        tagOa: Color(0xFF7CAB54),
        tagOaInk: Color(0xFF44652B),
        tagPaywall: Color(0xFFDD8A3E),
        tagPaywallInk: Color(0xFF8A5217),
        figBg: Color(0xFFF5F5F6),
        figBgPop: Color(0xFFFDFDFD),
        wissen: Color(0xFF3F5D8C),
        wissenInk: Color(0xFF38537D),
        wissenSoft: Color(0xFFE8EDF5),
        wissenLine: Color(0xFFC2CFE3),
        grid: Color(0xFFDBD7CC),
        baseline: Color(0xFF8A8990),
        magicTop: Color(0xFFF0591A),
        magicBottom: Color(0xFFD84408),
        magicEdge: Color(0xFFA33305),
        magicC: Color(0xFFFB8340),
        magicGlow: Color(0x66F76A20),
        shadow1: [BoxShadow(offset: Offset(0, 1), blurRadius: 2, color: Color(0x0D16171B))],
        shadow2: [
          BoxShadow(offset: Offset(0, 1), blurRadius: 3, color: Color(0x1216171B)),
          BoxShadow(offset: Offset(0, 8), blurRadius: 24, color: Color(0x1216171B)),
        ],
        shadowPop: [
          BoxShadow(offset: Offset(0, 4), blurRadius: 12, color: Color(0x1F0E0F13)),
          BoxShadow(offset: Offset(0, 20), blurRadius: 48, color: Color(0x290E0F13)),
        ],
      );

  /// Dark: helles Terracotta auf Ember-Graphit (theme.css:160–239).
  factory BookClothTokens.dark() => const BookClothTokens(
        brightness: Brightness.dark,
        bg: Color(0xFF1E1C17),
        bgDeep: Color(0xFF161411),
        surface: Color(0xFF27231D),
        surface2: Color(0xFF2E2A24),
        surface3: Color(0xFF39342C),
        border: Color(0xFF403A30),
        borderStrong: Color(0xFF575048),
        ink: Color(0xFFF0EDE5),
        ink2: Color(0xFFBEB8AC),
        muted: Color(0xFF98917F),
        accent: Color(0xFFE28A5D),
        accentStrong: Color(0xFFEB9F74),
        accentInk: Color(0xFFE69670),
        accentSoft: Color(0xFF3A2A1F),
        accentLine: Color(0xFF6E452E),
        accentContrast: Color(0xFF2B1409),
        good: Color(0xFF8FB87F),
        goodSoft: Color(0xFF253023),
        warn: Color(0xFFCFA05E),
        warnSoft: Color(0xFF332A1A),
        bad: Color(0xFFD1806F),
        badSoft: Color(0xFF37231E),
        ki: Color(0xFF94AABF),
        kiSoft: Color(0xFF252A2F),
        lvl1: Color(0xFF8BA1B6),
        lvl1Soft: Color(0xFF272D33),
        lvl2: Color(0xFFCFA05E),
        lvl2Soft: Color(0xFF332A1A),
        lvl3: Color(0xFF8FB87F),
        lvl3Soft: Color(0xFF253023),
        catNorm: Color(0xFF6FB5C0),
        catFrist: Color(0xFFD6A44E),
        catAkteur: Color(0xFFB291CC),
        catTech: Color(0xFF6FBCB0),
        catThese: Color(0xFF85A5D8),
        catLuecke: Color(0xFFE07F7F),
        catZahl: Color(0xFF9DC07F),
        catAbk: Color(0xFFC2A179),
        catSchlag: Color(0xFF8F9FD0),
        tagVenue: Color(0xFF46679C),
        tagVenueInk: Color(0xFFA8C6E8),
        tagPublisher: Color(0xFF9779C9),
        tagPublisherInk: Color(0xFFC3AEE7),
        tagOa: Color(0xFF7CAB54),
        tagOaInk: Color(0xFFB4D698),
        tagPaywall: Color(0xFFDD8A3E),
        tagPaywallInk: Color(0xFFEDB787),
        figBg: Color(0xFFECECEE),
        figBgPop: Color(0xFFFDFDFD),
        wissen: Color(0xFF8BA7D6),
        wissenInk: Color(0xFF9DB5DE),
        wissenSoft: Color(0xFF232A3A),
        wissenLine: Color(0xFF3E4C68),
        grid: Color(0xFF403A30),
        baseline: Color(0xFF938D80),
        magicTop: Color(0xFFF2621F),
        magicBottom: Color(0xFFDD4A0C),
        magicEdge: Color(0xFF8F2E04),
        magicC: Color(0xFFFC8C48),
        magicGlow: Color(0x80FA732D),
        shadow1: [BoxShadow(offset: Offset(0, 1), blurRadius: 2, color: Color(0x59000000))],
        shadow2: [
          BoxShadow(offset: Offset(0, 1), blurRadius: 3, color: Color(0x66000000)),
          BoxShadow(offset: Offset(0, 8), blurRadius: 24, color: Color(0x4D000000)),
        ],
        shadowPop: [
          BoxShadow(offset: Offset(0, 4), blurRadius: 12, color: Color(0x80000000)),
          BoxShadow(offset: Offset(0, 20), blurRadius: 48, color: Color(0x80000000)),
        ],
      );

  // ---- ThemeExtension-Vertrag ---------------------------------------------

  /// Die Token-Sets sind geschlossen (Light/Dark) — punktuelles Überschreiben
  /// ist im Designsystem nicht vorgesehen, daher gibt copyWith `this` zurück.
  @override
  BookClothTokens copyWith() => this;

  @override
  BookClothTokens lerp(BookClothTokens? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return BookClothTokens(
      brightness: t < 0.5 ? brightness : other.brightness,
      bg: c(bg, other.bg),
      bgDeep: c(bgDeep, other.bgDeep),
      surface: c(surface, other.surface),
      surface2: c(surface2, other.surface2),
      surface3: c(surface3, other.surface3),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      ink: c(ink, other.ink),
      ink2: c(ink2, other.ink2),
      muted: c(muted, other.muted),
      accent: c(accent, other.accent),
      accentStrong: c(accentStrong, other.accentStrong),
      accentInk: c(accentInk, other.accentInk),
      accentSoft: c(accentSoft, other.accentSoft),
      accentLine: c(accentLine, other.accentLine),
      accentContrast: c(accentContrast, other.accentContrast),
      good: c(good, other.good),
      goodSoft: c(goodSoft, other.goodSoft),
      warn: c(warn, other.warn),
      warnSoft: c(warnSoft, other.warnSoft),
      bad: c(bad, other.bad),
      badSoft: c(badSoft, other.badSoft),
      ki: c(ki, other.ki),
      kiSoft: c(kiSoft, other.kiSoft),
      lvl1: c(lvl1, other.lvl1),
      lvl1Soft: c(lvl1Soft, other.lvl1Soft),
      lvl2: c(lvl2, other.lvl2),
      lvl2Soft: c(lvl2Soft, other.lvl2Soft),
      lvl3: c(lvl3, other.lvl3),
      lvl3Soft: c(lvl3Soft, other.lvl3Soft),
      catNorm: c(catNorm, other.catNorm),
      catFrist: c(catFrist, other.catFrist),
      catAkteur: c(catAkteur, other.catAkteur),
      catTech: c(catTech, other.catTech),
      catThese: c(catThese, other.catThese),
      catLuecke: c(catLuecke, other.catLuecke),
      catZahl: c(catZahl, other.catZahl),
      catAbk: c(catAbk, other.catAbk),
      catSchlag: c(catSchlag, other.catSchlag),
      tagVenue: c(tagVenue, other.tagVenue),
      tagVenueInk: c(tagVenueInk, other.tagVenueInk),
      tagPublisher: c(tagPublisher, other.tagPublisher),
      tagPublisherInk: c(tagPublisherInk, other.tagPublisherInk),
      tagOa: c(tagOa, other.tagOa),
      tagOaInk: c(tagOaInk, other.tagOaInk),
      tagPaywall: c(tagPaywall, other.tagPaywall),
      tagPaywallInk: c(tagPaywallInk, other.tagPaywallInk),
      figBg: c(figBg, other.figBg),
      figBgPop: c(figBgPop, other.figBgPop),
      wissen: c(wissen, other.wissen),
      wissenInk: c(wissenInk, other.wissenInk),
      wissenSoft: c(wissenSoft, other.wissenSoft),
      wissenLine: c(wissenLine, other.wissenLine),
      grid: c(grid, other.grid),
      baseline: c(baseline, other.baseline),
      magicTop: c(magicTop, other.magicTop),
      magicBottom: c(magicBottom, other.magicBottom),
      magicEdge: c(magicEdge, other.magicEdge),
      magicC: c(magicC, other.magicC),
      magicGlow: c(magicGlow, other.magicGlow),
      shadow1: BoxShadow.lerpList(shadow1, other.shadow1, t)!,
      shadow2: BoxShadow.lerpList(shadow2, other.shadow2, t)!,
      shadowPop: BoxShadow.lerpList(shadowPop, other.shadowPop, t)!,
    );
  }
}
