/// Format-Helfer — Pendants zu `ClaudeAI.fmtUsd/fmtTok/fmtEur` (claude.js:66–78),
/// `U.fmtDate` (util.js:188–193) und dem de-AT-Zahlenformat der Chart-/
/// Notebook-Werte (notebook.js:275). Die Schwellen sind sichtbarer Teil der
/// UI und werden EXAKT übernommen. (`U.esc` entfällt — Flutter rendert Text,
/// kein HTML.)
library;

import 'package:intl/intl.dart';

final NumberFormat _deAt = NumberFormat.decimalPattern('de_AT');

/// Dollar-Preis: unter 0.1 vier Dezimalen, unter 1 drei, sonst zwei;
/// `null` → „–".
String fmtUsd(num? v) {
  if (v == null) return '–';
  if (v < 0.1) return '\$${v.toStringAsFixed(4)}';
  if (v < 1) return '\$${v.toStringAsFixed(3)}';
  return '\$${v.toStringAsFixed(2)}';
}

/// Kompakter Euro-Preis für die Magic-Knöpfe: „0.33 €" statt „$0.3299";
/// unter einem halben Cent ehrlich „<0.01 €".
String fmtEur(num? v) {
  if (v == null) return '–';
  if (v < 0.005) return '<0.01 €';
  return '${v.toStringAsFixed(2)} €';
}

/// Token-Zähler: ab 1000 → „x.xk", ab 10000 ohne Dezimale („12k").
String fmtTok(int n) {
  if (n < 1000) return '$n';
  return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k';
}

/// ISO-Datum menschlich: `"2024-03-07"` → „7.3.2024", `"2024-03"` → „3.2024";
/// alles andere unverändert, leer/null → ''.
String fmtDate(String? d) {
  if (d == null || d.isEmpty) return '';
  final m = RegExp(r'^(\d{4})-(\d{2})(?:-(\d{2}))?').firstMatch(d);
  if (m == null) return d;
  final day = m.group(3) == null ? '' : '${int.parse(m.group(3)!)}.';
  return '$day${int.parse(m.group(2)!)}.${m.group(1)}';
}

/// Zahlwert im de-AT-Format der Charts/Notebook-Zellen: ab |1000| gruppiert
/// (de-AT laut CLDR mit geschütztem Leerzeichen, „1 234,568" — exakt wie
/// `toLocaleString('de-AT')` im Browser des Originals), darunter auf 2
/// Dezimalen gerundet und OHNE überflüssige Nullen („2.5" → „2.5", „2.0" → „2").
String fmtDeNum(num v) {
  if (v.abs() >= 1000) return _deAt.format(v);
  final r = (v * 100).round() / 100;
  if (r == r.roundToDouble()) return '${r.round()}';
  return '$r';
}

/// Kürzt [s] auf [max] Zeichen und hängt „…" an (JS-Muster
/// `s.length > max ? s.slice(0, max) + '…' : s`).
String ellipsize(String s, int max) =>
    s.length > max ? '${s.substring(0, max)}…' : s;
