/// Projekt-Export-Format `thesis-studio-projekt` v1 (projects.js:266-284)
/// plus die id-Schemata für neue/importierte/kopierte Arbeiten.
///
/// Der Export ist der rohe ProjectRecord mit vorangestelltem Umschlag
/// `{format, version, …rec}`, JSON mit Einrückung 1 — bit-kompatibel zur
/// Web-App (unbekannte Felder überleben, F-B hält das rohe JSON im Record).
library;

import 'dart:convert';
import 'dart:math';

import '../models/models.dart';

/// Export einer Arbeit (Pendant zu `Projects.exportProject`).
String exportProjectJson(ProjectRecord rec) =>
    const JsonEncoder.withIndent(' ').convert(rec.toExportJson());

/// Import-JSON parsen und validieren (Pendant zum Anfang von
/// `Projects.importProject`, projects.js:271-274): Format-/Struktur-Checks
/// mit den deutschen Original-Fehlertexten (in ProjectRecord.fromExportJson),
/// fehlende id → `p-import-<rand6>`. Die Kollisionsbehandlung
/// (Überschreiben/Kopie) übernimmt das Repository, weil sie einen Dialog
/// braucht.
ProjectRecord parseProjectImport(String jsonText) {
  final decoded = json.decode(jsonText);
  final map = decoded is Map<String, dynamic>
      ? decoded
      : throw const FormatException(
          'Unbekanntes Format — erwartet "thesis-studio-projekt" mit parsed.thesis.');
  final rec = ProjectRecord.fromExportJson(map);
  // rec.raw IST die dekodierte Map — die id-Zuweisung nach der Validierung
  // entspricht `d.id = d.id || 'p-import-…'` (projects.js:274).
  if (rec.id.isEmpty) {
    map['id'] = 'p-import-${randomBase36(6)}';
  }
  return rec;
}

/// n zufällige Base36-Zeichen — Pendant zu
/// `Math.random().toString(36).slice(2, 2+n)`.
String randomBase36(int n, [Random? rng]) {
  final r = rng ?? Random();
  const chars = '0123456789abcdefghijklmnopqrstuvwxyz';
  return String.fromCharCodes(
    List.generate(n, (_) => chars.codeUnitAt(r.nextInt(chars.length))),
  );
}

/// id einer neuen Arbeit aus dem Namen — exakt projects.js:105-106:
/// `'p-' + slug(name, max 30) + '-' + rand4`.
String newProjectId(String name, [Random? rng]) {
  var slug = (name.isEmpty ? 'arbeit' : name)
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.length > 30) slug = slug.substring(0, 30);
  return 'p-$slug-${randomBase36(4, rng)}';
}

/// Kopie-id bei Import-Kollision (projects.js:278): `<id>-kopie-<rand3>`.
String copyProjectId(String id, [Random? rng]) =>
    '$id-kopie-${randomBase36(3, rng)}';

/// Kopie-Name bei Import-Kollision (projects.js:279): `<name> (Kopie)`.
String copyProjectName(String? name) =>
    '${(name == null || name.isEmpty) ? 'Arbeit' : name} (Kopie)';
