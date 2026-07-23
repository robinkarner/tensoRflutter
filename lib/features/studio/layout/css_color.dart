/// CSS-Farbstrings → Theme-Farben.
///
/// View-/Instanz-Definitionen tragen ihre Farbe als CSS-String
/// (`"var(--cat-norm)"`, `"var(--good)"`, `"#c05f5f"`) — so liegen sie im
/// Original in `DOCK_DEFAULTS`, `instDefs` (KV) und in den mitgelieferten
/// Projekt-Instanzen. Die Strings sind Persistenz-Format und bleiben
/// unangetastet; hier werden sie zur Laufzeit in echte [Color]s übersetzt.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

/// `var(--token)` bzw. `#hex` auflösen; unbekannte Tokens → null.
Color? resolveCssColor(BookClothTokens t, String? css) {
  final s = (css ?? '').trim();
  if (s.isEmpty) return null;

  if (s.startsWith('#')) {
    final hex = s.substring(1);
    final v = int.tryParse(hex, radix: 16);
    if (v == null) return null;
    if (hex.length == 6) return Color(0xFF000000 | v);
    if (hex.length == 8) return Color(v);
    if (hex.length == 3) {
      final r = (v >> 8) & 0xF, g = (v >> 4) & 0xF, b = v & 0xF;
      return Color(0xFF000000 | (r * 17 << 16) | (g * 17 << 8) | (b * 17));
    }
    return null;
  }

  final m = RegExp(r'^var\(\s*--([a-z0-9-]+)\s*\)$').firstMatch(s);
  if (m == null) return null;
  return switch (m.group(1)!) {
    'accent' => t.accent,
    'accent-ink' => t.accentInk,
    'accent-strong' => t.accentStrong,
    'accent-soft' => t.accentSoft,
    'accent-line' => t.accentLine,
    'good' => t.good,
    'warn' || 'warning' => t.warn,
    'bad' || 'critical' => t.bad,
    'ki' => t.ki,
    'muted' => t.muted,
    'ink' => t.ink,
    'ink-2' => t.ink2,
    'cat-norm' => t.catNorm,
    'cat-frist' => t.catFrist,
    'cat-akteur' => t.catAkteur,
    'cat-tech' => t.catTech,
    'cat-these' => t.catThese,
    'cat-luecke' => t.catLuecke,
    'cat-zahl' => t.catZahl,
    'cat-abk' => t.catAbk,
    'cat-schlag' => t.catSchlag,
    'lvl-1' => t.lvl1,
    'lvl-2' => t.lvl2,
    'lvl-3' => t.lvl3,
    'wissen' => t.wissen,
    'wissen-ink' => t.wissenInk,
    _ => null,
  };
}
