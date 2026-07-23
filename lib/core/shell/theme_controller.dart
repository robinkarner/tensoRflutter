/// Theme-Zyklus auto → light → dark — Pendant zum `#themeToggle`-Verhalten
/// (app.js:52-73).
///
/// Das Original hält den Zustand als `'light' | 'dark' | null` im Store-Key
/// `theme` (global, JSON) und wendet ihn als `data-theme`-Attribut an; hier
/// übernimmt [ThemeMode] die Anwendung (auto = System-Präferenz, exakt wie
/// `prefers-color-scheme` ohne Attribut). Der Persistenz-Wert bleibt
/// bit-kompatibel: `"light"` / `"dark"` / `null` unter `ehds.theme` —
/// eine Migration aus der Web-App liest denselben Key.
library;

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/db/kv.dart';

part 'theme_controller.g.dart';

/// Die drei Stellungen des Umschalters (Reihenfolge = Klick-Zyklus).
enum ThemeSetting {
  /// System entscheidet (Original: kein `data-theme`-Attribut).
  auto,
  light,
  dark;

  /// Button-Zeichen ◐ / ☀ / ☾ (app.js:57).
  String get icon => switch (this) {
        ThemeSetting.auto => '◐',
        ThemeSetting.light => '☀',
        ThemeSetting.dark => '☾',
      };

  /// Tooltip „Theme: {auto|light|dark} (klicken zum Wechseln)“ (app.js:58).
  String get tooltip => 'Theme: $storeName (klicken zum Wechseln)';

  /// Wert im Store — `auto` heißt dort schlicht `null` (bzw. „auto“ im Text).
  String get storeName => switch (this) {
        ThemeSetting.auto => 'auto',
        ThemeSetting.light => 'light',
        ThemeSetting.dark => 'dark',
      };

  ThemeMode get themeMode => switch (this) {
        ThemeSetting.auto => ThemeMode.system,
        ThemeSetting.light => ThemeMode.light,
        ThemeSetting.dark => ThemeMode.dark,
      };
}

/// Persistierter Theme-Zustand. Lesen ist asynchron (DB); bis dahin gilt
/// `auto` — sichtbar identisch mit dem Original, das vor dem ersten
/// `applyTheme` ebenfalls die System-Präferenz zeigt.
@Riverpod(keepAlive: true)
class ThemeController extends _$ThemeController {
  @override
  Future<ThemeSetting> build() async {
    final v = await ref.watch(kvStoreProvider).getJson(KvKeys.theme);
    return switch (v) {
      'light' => ThemeSetting.light,
      'dark' => ThemeSetting.dark,
      _ => ThemeSetting.auto,
    };
  }

  /// Ein Klick = ein Schritt im Zyklus auto → light → dark → auto
  /// (app.js:70-72). Schreibt sofort und aktualisiert den Zustand optimistisch.
  Future<void> cycle() async {
    final current = state.value ?? ThemeSetting.auto;
    final next = switch (current) {
      ThemeSetting.auto => ThemeSetting.light,
      ThemeSetting.light => ThemeSetting.dark,
      ThemeSetting.dark => ThemeSetting.auto,
    };
    state = AsyncData(next);
    // `auto` wird wie im Original als JSON-`null` abgelegt.
    await ref.read(kvStoreProvider).setJson(
          KvKeys.theme,
          next == ThemeSetting.auto ? null : next.storeName,
        );
  }
}
