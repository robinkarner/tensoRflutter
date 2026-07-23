import 'package:flutter/material.dart';

import 'color_mix.dart';
import 'tokens.dart';
import 'typography.dart';

/// Baut das komplette ThemeData für Light/Dark aus den Book-Cloth-Tokens.
///
/// Ziel: Screens kommen mit `Theme.of(context)` + `BookClothTokens.of(context)`
/// aus — Material-Bausteine (Buttons, Inputs, Scrollbars, Divider, Dialoge)
/// sind hier so eingestellt, dass sie den CSS-Bausteinen `.btn`/`.btn-primary`/
/// `.btn-ghost`, Formularen und Scrollbars des Originals entsprechen.
/// Für die pixelgenauen Sonderformen (Magic-Blöcke, Chips, fn-Chips …) gibt es
/// eigene Widgets in `core/widgets/`.
ThemeData buildAppTheme(Brightness brightness) {
  final t = brightness == Brightness.dark
      ? BookClothTokens.dark()
      : BookClothTokens.light();

  final textTheme = _textTheme(t);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    // Web-Optik: keine Ripples, kein Material-Tint — Flächenwechsel passieren
    // gezielt über die Widgets (Hover surface-2, Active surface-3).
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: t.accent,
      onPrimary: t.accentContrast,
      secondary: t.ki,
      onSecondary: t.surface,
      error: t.bad,
      onError: t.surface,
      surface: t.surface,
      onSurface: t.ink,
      surfaceContainerHighest: t.surface3,
      outline: t.borderStrong,
      outlineVariant: t.border,
      shadow: Colors.black,
    ),
    scaffoldBackgroundColor: t.bg,
    canvasColor: t.surface,
    dividerColor: t.border,
    hintColor: t.muted,
    fontFamily: AppFonts.ui,
    textTheme: textTheme,
    iconTheme: IconThemeData(color: t.ink2, size: 18),

    // ---- .card: surface, Hairline, Radius 8 (Schatten setzen Panels selbst)
    cardTheme: CardThemeData(
      color: t.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BookClothTokens.radius),
        side: BorderSide(color: t.border),
      ),
    ),

    dividerTheme: DividerThemeData(color: t.border, thickness: 1, space: 1),

    // ---- Buttons: OutlinedButton = .btn · ElevatedButton = .btn-primary ·
    //      TextButton = .btn-ghost. Hover/Active-Farben exakt aus theme.css.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: _buttonBase(t).copyWith(
        backgroundColor: _states(
          normal: t.surface,
          hovered: t.surface2,
          pressed: t.surface3,
          disabled: t.surface,
        ),
        foregroundColor: _states(
          normal: t.ink,
          disabled: t.ink.alphaPct(45),
        ),
        side: WidgetStateProperty.resolveWith((s) => BorderSide(
              color: s.contains(WidgetState.hovered)
                  ? t.ink.alphaPct(26)
                  : t.borderStrong,
            )),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: _buttonBase(t).copyWith(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: _states(
          normal: t.accent,
          hovered: t.accentStrong,
          pressed: t.accentStrong,
          disabled: t.accent.alphaPct(45),
        ),
        foregroundColor: _states(
          normal: t.accentContrast,
          disabled: t.accentContrast.alphaPct(60),
        ),
        textStyle: WidgetStatePropertyAll(
          AppTextStyles.button.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: _buttonBase(t).copyWith(
        backgroundColor: _states(
          normal: Colors.transparent,
          hovered: t.surface3,
          pressed: t.surface3,
          disabled: Colors.transparent,
        ),
        foregroundColor: _states(
          normal: t.ink2,
          hovered: t.ink,
          disabled: t.ink2.alphaPct(45),
        ),
      ),
    ),

    // ---- Formulare (theme.css:469–481): surface, border-strong, radius-sm,
    //      Fokus = Akzent-Border (der 3px-Glow-Ring ist mit Material nicht
    //      1:1 abbildbar — die 2px-Akzent-Border ersetzt ihn sichtbar genug).
    inputDecorationTheme: InputDecorationThemeData(
      isDense: true,
      filled: true,
      fillColor: t.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      hintStyle: AppTextStyles.form.copyWith(color: t.muted),
      labelStyle: AppTextStyles.small.copyWith(
        color: t.ink2,
        fontWeight: FontWeight.w500,
      ),
      enabledBorder: _inputBorder(t.borderStrong),
      border: _inputBorder(t.borderStrong),
      focusedBorder: _inputBorder(t.accent, width: 2),
      errorBorder: _inputBorder(t.bad),
      focusedErrorBorder: _inputBorder(t.bad, width: 2),
    ),

    // ---- ::selection + caret-color (theme.css:297)
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: t.accent,
      selectionColor: t.accent.alphaPct(22),
      selectionHandleColor: t.accent,
    ),

    // ---- Scrollbars dezent: 8px, Thumb border-strong, rund (theme.css:300)
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(8),
      radius: const Radius.circular(8),
      thumbColor: WidgetStatePropertyAll(t.borderStrong),
      trackColor: const WidgetStatePropertyAll(Colors.transparent),
      trackBorderColor: const WidgetStatePropertyAll(Colors.transparent),
    ),

    // ---- Tooltips im viz-tip-Stil (surface, border-strong, radius 8, 13px)
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      textStyle: AppTextStyles.small.copyWith(color: t.ink, fontSize: 13),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.borderStrong),
        borderRadius: BorderRadius.circular(8),
        boxShadow: t.shadow2,
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BookClothTokens.radius),
        side: BorderSide(color: t.border),
      ),
    ),

    extensions: [t],
  );
}

ThemeData get appThemeLight => buildAppTheme(Brightness.light);
ThemeData get appThemeDark => buildAppTheme(Brightness.dark);

/// Gemeinsame `.btn`-Basis: 500 14/1, radius-sm, Padding 7.5/13, kompakt.
ButtonStyle _buttonBase(BookClothTokens t) => ButtonStyle(
      textStyle: const WidgetStatePropertyAll(AppTextStyles.button),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 13, vertical: 7.5),
      ),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
      )),
      minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      animationDuration: const Duration(milliseconds: 100),
    );

/// Zustandsabhängige Farbe im CSS-Sinn: normal / :hover / :active / [disabled].
WidgetStateProperty<Color?> _states({
  required Color normal,
  Color? hovered,
  Color? pressed,
  Color? disabled,
}) =>
    WidgetStateProperty.resolveWith((s) {
      if (s.contains(WidgetState.disabled)) return disabled ?? normal;
      if (s.contains(WidgetState.pressed)) return pressed ?? hovered ?? normal;
      if (s.contains(WidgetState.hovered)) return hovered ?? normal;
      return normal;
    });

OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
      borderSide: BorderSide(color: color, width: width),
    );

/// Material-TextTheme aus der Book-Cloth-Leiter: h1/h2 = Display 700,
/// h3/h4 = UI 600, Fließtext 15.5/1.62, `.small` 13.5.
TextTheme _textTheme(BookClothTokens t) => TextTheme(
      headlineMedium: AppTextStyles.h1.copyWith(color: t.ink),
      titleLarge: AppTextStyles.h2.copyWith(color: t.ink),
      titleMedium: AppTextStyles.h3.copyWith(color: t.ink),
      titleSmall: AppTextStyles.h4.copyWith(color: t.ink),
      bodyLarge: AppTextStyles.form.copyWith(color: t.ink),
      bodyMedium: AppTextStyles.body.copyWith(color: t.ink),
      bodySmall: AppTextStyles.small.copyWith(color: t.muted),
      labelLarge: AppTextStyles.button.copyWith(color: t.ink),
      labelMedium: AppTextStyles.small.copyWith(
        color: t.ink2,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: AppTextStyles.eyebrow.copyWith(color: t.muted),
    );
