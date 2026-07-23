/// Kern-Logik des Sammel-Imports (PDF/ZIP) — reine, testbare Funktionen aus
/// `importFilesModal` (views_quellen.js:718-859):
///
/// Matching-Kaskade je Datei:
///  (a) Referenz-Hash `ts-[0-9a-f]{8}` im (lowercased) Dateinamen →
///      `U.srcByHash` → „✓ automatisch erkannt" (Häkchen an),
///  (b) Dateiname exakt = Quellen-id → „= Quellen-id" (Häkchen an),
///  (c) sonst `U.matchFilename` → unverbindlicher „✦ Vorschlag (bestätigen)"
///      (Select vorbelegt, Häkchen AUS),
///  (d) sonst „→ Ablage".
///
/// „Kein stiller Verlust": Der Go-Button ist auch OHNE Häkchen aktiv, sobald
/// neue Dateien da sind — Unbestätigtes wandert sicher in die Ablage.
library;

import 'dart:typed_data';

import '../../../data/models/models.dart';
import '../../../data/repos/file_store.dart';

/// Exakter Treffer (Kaskaden-Stufe a/b) — `it.match` des Originals.
class ImportMatch {
  final String id;
  final bool sure;
  final bool exact;

  /// true, wenn über den Referenz-Hash erkannt (Datei-Auftrag-Rücklauf).
  final bool hash;

  const ImportMatch({required this.id, this.sure = true, this.exact = true, this.hash = false});
}

/// Ein Import-Eintrag (mutabel — das Modal editiert sel/checked in-place).
class ImportItem {
  final String name;
  final Uint8List? data;
  final bool fromInbox;
  final int size;
  final ImportMatch? match;
  final FilenameMatch? suggest;
  final String? err;

  /// Gewählte Ziel-Quelle (Select) — null = keine.
  String? sel;

  /// Häkchen (nur checked+sel wird zugeordnet).
  bool checked;

  ImportItem({
    required this.name,
    this.data,
    this.fromInbox = false,
    this.size = 0,
    this.match,
    this.suggest,
    this.err,
    this.sel,
    this.checked = false,
  });

  /// Fehler-Eintrag (kein PDF / ZIP-Fehler) — bleibt als ✗-Zeile stehen.
  ImportItem.error(this.name, String error)
      : data = null,
        fromInbox = false,
        size = 0,
        match = null,
        suggest = null,
        err = error,
        sel = null,
        checked = false;
}

/// Eine Datei durch die Matching-Kaskade schicken (`addItem`, js:791-811).
/// [name] darf noch Pfad-Anteile tragen (ZIP-Einträge) — sie werden entfernt.
ImportItem buildImportItem(
  String name,
  Uint8List? data, {
  required Map<String, Source> srcById,
  required Iterable<Source> sources,
  bool fromInbox = false,
}) {
  final clean = name.replaceAll(RegExp(r'^.*[\\/]'), '');
  if (!RegExp(r'\.pdf$', caseSensitive: false).hasMatch(clean)) {
    return ImportItem.error(clean, 'kein PDF');
  }
  final id = clean.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');

  // (a) Referenz-Hash im Dateinamen → automatische Zuordnung.
  ImportMatch? exact;
  final hm = RegExp(r'ts-[0-9a-f]{8}').firstMatch(clean.toLowerCase());
  if (hm != null) {
    final sid = srcIdByHash(hm.group(0)!, sources);
    if (sid != null) exact = ImportMatch(id: sid, hash: true);
  }
  // (b) Dateiname exakt = Quellen-id.
  exact ??= srcById.containsKey(id) ? ImportMatch(id: id) : null;
  // (c) Dateinamen-Vorschlag — NUR unverbindlich (Häkchen bleibt aus).
  final suggest = exact != null ? null : matchFilename(clean, sources);

  return ImportItem(
    name: clean,
    data: data,
    fromInbox: fromInbox,
    size: data?.length ?? 0,
    match: exact,
    suggest: suggest,
    sel: exact?.id ?? suggest?.id,
    checked: exact != null,
  );
}

/// Zähler für den Go-Button (`syncGo`, js:783-788): [n] = zuzuordnen,
/// [rest] = neue Dateien ohne Zuordnung (wandern in die Ablage).
({int n, int rest}) goCounts(Iterable<ImportItem> items) {
  var n = 0, rest = 0;
  for (final it in items) {
    if (it.err != null) continue;
    if (it.checked && it.sel != null) {
      n++;
    } else if (!it.fromInbox) {
      rest++;
    }
  }
  return (n: n, rest: rest);
}

/// Button-Beschriftung — Texte exakt (js:787).
String goButtonLabel(int n, int rest) => n > 0
    ? '✓ $n zuordnen${rest > 0 ? ' · $rest in Ablage' : ''}'
    : rest > 0
        ? '📥 $rest in die Ablage'
        : '✓ Zuordnen';

/// Status-Chip einer Zeile: (Label, Tooltip, Kategorie) — js:756-759.
/// Kategorie: 'ok' | 'ki' | 'warn' (Chip-Variante der UI).
({String label, String tip, String cat}) importChipFor(ImportItem it) {
  if (it.match?.hash ?? false) {
    return (
      label: '✓ automatisch erkannt',
      tip: 'Aus dem Datei-Auftrag — automatische Zuordnung',
      cat: 'ok',
    );
  }
  if (it.match?.exact ?? false) {
    return (
      label: '= Quellen-id',
      tip: 'Dateiname entspricht exakt der Quellen-id — automatische Zuordnung',
      cat: 'ok',
    );
  }
  if (it.suggest != null) {
    return (
      label: '✦ Vorschlag (bestätigen)',
      tip: 'Unverbindlicher Vorschlag — erst das Häkchen ordnet zu',
      cat: 'ki',
    );
  }
  return (label: '→ Ablage', tip: '', cat: 'warn');
}
