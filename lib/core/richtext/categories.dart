/// Mark-Kategorien der Schlüsselstellen — Pendant zu `CAT_LABELS` /
/// `CAT_ORDER` (util.js:919-924).
///
/// Die Keys sind Persistenz-Format (`cats`-Store, `marksExtra`, Voranalyse-
/// Marks) — niemals umbenennen. Die Farben dazu liefert das Token-System
/// (`BookClothTokens.cat(key)` = `--cat-<key>`).
library;

/// Anzeige-Reihenfolge der 9 Kategorien (util.js:924).
const List<String> catOrder = [
  'norm',
  'frist',
  'akteur',
  'tech',
  'these',
  'luecke',
  'zahl',
  'abk',
  'schlag',
];

/// Deutsche Labels — wortwörtlich (util.js:919-923).
const Map<String, String> catLabels = {
  'norm': 'Quelle/Rechtsnorm',
  'frist': 'Frist/Datum',
  'akteur': 'Akteur/Institution',
  'tech': 'Technik/Standard',
  'these': 'These/Wertung',
  'luecke': 'Lücke/Problem',
  'zahl': 'Zahl/Menge',
  'abk': 'Abkürzung',
  'schlag': 'Schlagwort',
};
