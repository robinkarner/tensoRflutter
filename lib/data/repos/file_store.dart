/// FileStore — Pendant zu `PdfStore` (pdfstore.js): der arbeitsübergreifende
/// Datei-Speicher für Quell-PDFs, Ablage (Inbox) und Bild-Quellen, jetzt auf
/// der Drift-Blob-Tabelle statt IndexedDB. Dazu die Kandidaten-Suche des
/// Imports (Referenz-Hash → exakte id → Dateinamen-Matching).
///
/// Übersetzungen gegenüber dem Original:
///  * `PdfStore.ready` → [fileStoreProvider] (FutureProvider, init einmal).
///  * Listener-System mit DOM-Anker-Autocleanup → [changes]-Broadcast-Stream
///    (Subscriptions räumen sich in Flutter über dispose selbst auf).
///  * ObjectURL-Cache → entfällt (Viewer bekommen direkt Bytes).
///  * Legacy File-System-Access-Ordner → entfällt (im Original bereits nur
///    Altbestand, Dossier 04 §9.5).
///  * HTTP-Fallback `sources/<id>.pdf` → gebündelte Assets
///    (`assets/sources/<id>.pdf`, via AssetManifest geprüft).
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/util/crc32.dart';
import '../db/daos/file_blobs_dao.dart';
import '../db/database.dart';
import '../db/kv.dart';
import '../models/models.dart';

part 'file_store.g.dart';

// ---------------------------------------------------------------------------
// Schlüsselschema (1:1 wie pdfstore.js)
// ---------------------------------------------------------------------------

/// Die Blob-Schlüssel-Namensräume des Originals.
abstract final class FileKeys {
  static const inboxPrefix = 'inbox:';
  static const imgPrefix = 'img:';

  static String inbox(String name) => '$inboxPrefix$name';
  static String img(String srcId) => '$imgPrefix$srcId';

  static bool isInbox(String key) => key.startsWith(inboxPrefix);
  static bool isImg(String key) => key.startsWith(imgPrefix);

  /// Schlüssel für weiteres Material einer Quelle — exakt `U.extraKey`
  /// (util.js:586): `<srcId>~x<ts36><rand36>`.
  static String extra(String srcId, [Random? rng]) {
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final rand = (rng ?? Random()).nextInt(1296).toRadixString(36);
    return '$srcId~x$ts$rand';
  }
}

// ---------------------------------------------------------------------------
// FileStore
// ---------------------------------------------------------------------------

class FileStore {
  FileStore(this._dao, {AssetBundle? assets}) : _assets = assets ?? rootBundle;

  final FileBlobsDao _dao;
  final AssetBundle _assets;

  /// In-Memory-Klassifikation der Schlüssel (Pendant zu PdfStore.files/
  /// images/inbox) — synchron abfragbar, beim init geladen.
  final Set<String> _files = {}; // plain Keys: <srcId> und <srcId>~x…
  final Set<String> _images = {}; // srcIds mit img:-Blob
  final Set<String> _inbox = {}; // Original-Dateinamen der Ablage

  /// PDF-Verfügbarkeits-Cache (Pendant zu `U.pdfStatusCache`); wird bei
  /// jedem Import/Reset geleert — und, anders als im Original (L2), auch
  /// beim Projekt-Reboot.
  final Map<String, bool?> pdfStatusCache = {};

  final _changes = StreamController<void>.broadcast();

  /// Änderungs-Benachrichtigung (Pendant zu PdfStore.onChange).
  Stream<void> get changes => _changes.stream;

  Set<String>? _assetKeys; // AssetManifest, lazy

  /// Schlüssel laden und klassifizieren (Pendant zu PdfStore.init;
  /// Fehler schlucken — die App läuft auch ohne Speicher weiter).
  Future<void> init() async {
    try {
      for (final key in await _dao.allKeys()) {
        if (FileKeys.isInbox(key)) {
          _inbox.add(key.substring(FileKeys.inboxPrefix.length));
        } else if (FileKeys.isImg(key)) {
          _images.add(key.substring(FileKeys.imgPrefix.length));
        } else {
          _files.add(key);
        }
      }
    } catch (_) {/* Speicher nicht verfügbar — App bleibt nutzbar */}
  }

  void _emit() => _changes.add(null);

  // --- Abfragen (synchron wie das Original) ---

  bool has(String id) => _files.contains(id);

  int count() => _files.length;

  bool hasImage(String srcId) => _images.contains(srcId);

  /// Ablage-Dateinamen, sortiert (Pendant zu listInbox).
  List<String> listInbox() => _inbox.toList()..sort();

  // --- Haupt-PDFs ---

  /// PDFs speichern; Schlüssel = Dateiname ohne `.pdf` (PdfStore.addFiles).
  /// Rückgabe: Anzahl übernommener Dateien.
  Future<int> addFiles(Iterable<(String name, Uint8List data)> files) async {
    var n = 0;
    for (final (name, data) in files) {
      if (!name.toLowerCase().endsWith('.pdf')) continue;
      final id = name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
      await _dao.write(id, data, mime: 'application/pdf');
      _files.add(id);
      n++;
    }
    if (n > 0) {
      pdfStatusCache.clear();
      _emit();
    }
    return n;
  }

  /// Rohdaten unter einer Quellen-id (bzw. einem `~x`-Materialschlüssel)
  /// speichern (Pendant zu putData).
  Future<void> putData(String key, Uint8List data,
      {String mime = 'application/pdf'}) async {
    await _dao.write(key, data, mime: mime);
    _files.add(key);
    pdfStatusCache.clear();
    _emit();
  }

  /// Daten einer Quelle: Blob → gebündeltes Asset `assets/sources/<id>.pdf`
  /// (Pendant zur getData-Fallback-Kette dir → blob → HTTP).
  Future<Uint8List?> getData(String id) async {
    if (_files.contains(id)) {
      final data = await _dao.readData(id);
      if (data != null) return data;
    }
    if (await _assetPdfExists(id)) {
      try {
        final bd = await _assets.load('assets/sources/$id.pdf');
        return bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);
      } catch (_) {/* Asset doch nicht lesbar */}
    }
    return null;
  }

  /// Alle Blobs sind löschbar (die read-only-Ordner-Einträge des Originals
  /// gibt es nicht mehr) — canRemove bleibt als API-Vertrag erhalten.
  bool canRemove(String id) => _files.contains(id);

  Future<bool> removeFile(String id) async {
    if (!_files.contains(id)) return false;
    await _dao.remove(id);
    _files.remove(id);
    pdfStatusCache.clear();
    _emit();
    return true;
  }

  /// ALLE Blobs löschen — inkl. Ablage und Bilder, für ALLE Arbeiten
  /// (Pendant zu clearAll; der Warntext dazu lebt in der Quellen-UI).
  Future<void> clearAll() async {
    await _dao.removeAll();
    _files.clear();
    _images.clear();
    _inbox.clear();
    pdfStatusCache.clear();
    _emit();
  }

  // --- Ablage (Inbox) ---

  Future<void> addInbox(String name, Uint8List data) async {
    await _dao.write(FileKeys.inbox(name), data, mime: 'application/pdf');
    _inbox.add(name);
    _emit();
  }

  Future<Uint8List?> getInboxData(String name) =>
      _dao.readData(FileKeys.inbox(name));

  Future<void> removeInbox(String name) async {
    await _dao.remove(FileKeys.inbox(name));
    _inbox.remove(name);
    _emit();
  }

  /// Ablage-Datei einer Quelle zuweisen: Blob auf den Key `srcId` kopieren,
  /// Inbox-Eintrag entfernen (Pendant zu assignInbox).
  Future<bool> assignInbox(String name, String srcId) async {
    final data = await getInboxData(name);
    if (data == null) return false;
    await _dao.write(srcId, data, mime: 'application/pdf');
    await _dao.remove(FileKeys.inbox(name));
    _files.add(srcId);
    _inbox.remove(name);
    pdfStatusCache.clear();
    _emit();
    return true;
  }

  // --- Bild-Quellen ---

  Future<void> putImage(String srcId, Uint8List data, {String? mime}) async {
    await _dao.write(FileKeys.img(srcId), data, mime: mime);
    _images.add(srcId);
    _emit();
  }

  /// Bild-Bytes + MIME (Pendant zu getImageUrl — der ObjectURL entfällt).
  Future<(Uint8List, String?)?> getImage(String srcId) async {
    final row = await _dao.read(FileKeys.img(srcId));
    return row == null ? null : (row.data, row.mime);
  }

  Future<void> removeImage(String srcId) async {
    await _dao.remove(FileKeys.img(srcId));
    _images.remove(srcId);
    _emit();
  }

  // --- PDF-Verfügbarkeit (U.detectPdf-Pendant) ---

  /// true/false = sicher, null = unbekannt. Kette wie util.js:601-611:
  /// Speicher → Cache → pdfManual-Flag → gebündeltes Asset.
  Future<bool?> detectPdf(String id, KvStore kv) async {
    if (has(id)) return true;
    if (pdfStatusCache.containsKey(id)) return pdfStatusCache[id];
    final manual = await kv.getMap(KvKeys.pdfManual);
    if (manual[id] == true) return pdfStatusCache[id] = true;
    return pdfStatusCache[id] = await _assetPdfExists(id);
  }

  /// Cache leeren (Import/Reset/Reboot).
  void resetStatusCache() => pdfStatusCache.clear();

  Future<bool> _assetPdfExists(String id) async {
    try {
      _assetKeys ??= (await AssetManifest.loadFromAssetBundle(_assets))
          .listAssets()
          .toSet();
    } catch (_) {
      _assetKeys = {};
    }
    return _assetKeys!.contains('assets/sources/$id.pdf');
  }

  void dispose() => _changes.close();
}

/// Der Datei-Speicher als Provider — das `PdfStore.ready`-Pendant: alle
/// Konsumenten warten auf `fileStoreProvider.future`, bevor sie zugreifen
/// (verhindert das Boot-Race „zugeordnete PDFs wirken fehlend", app.js:10-13).
@Riverpod(keepAlive: true)
Future<FileStore> fileStore(Ref ref) async {
  final store = FileStore(ref.watch(appDatabaseProvider).fileBlobsDao);
  ref.onDispose(store.dispose);
  await store.init();
  return store;
}

// ---------------------------------------------------------------------------
// Kandidaten-Suche (Import-Matching)
// ---------------------------------------------------------------------------

/// Referenz-Hash einer Quelle (`U.srcHash`-Pendant, bewusst ohne den
/// stale-anfälligen globalen Cache des Originals).
String srcHashOfSource(Source s) => srcHashOf(
      id: s.id,
      title: s.title,
      longTitle: s.longTitle,
      author: s.author,
      year: s.year,
    );

/// Quelle zu einem Referenz-Hash (`U.srcByHash`-Pendant) oder null.
String? srcIdByHash(String hash, Iterable<Source> sources) {
  for (final s in sources) {
    if (srcHashOfSource(s) == hash) return s.id;
  }
  return null;
}

/// Ergebnis des Dateinamen-Matchings.
class FilenameMatch {
  final String id;
  final double score;

  /// Eindeutiger, starker Treffer (Score ≥ 60).
  final bool sure;

  const FilenameMatch({required this.id, required this.score, required this.sure});
}

/// Dateiname → wahrscheinlichste Quelle — Port von `U.matchFilename`
/// (util.js:526-547) mit exakt dem Original-Scoring: id exakt = 100,
/// id-Teilstring = 50, Titel-Token-Quote max 40, Autor-Nachname 25,
/// Jahr 15; unter Score 25 → null, `sure` ab 60.
FilenameMatch? matchFilename(String filename, Iterable<Source> sources) {
  String norm(String? v) {
    // Wie srcHashNorm, aber Nicht-Alphanumerisches wird zu ' ' statt
    // entfernt (Token-Grenzen bleiben erhalten).
    final lower = (v ?? '').toLowerCase();
    final out = StringBuffer();
    for (final rune in lower.runes) {
      final keep = (rune >= 0x61 && rune <= 0x7a) || (rune >= 0x30 && rune <= 0x39);
      if (keep) {
        out.writeCharCode(rune);
      } else {
        final mapped = srcHashNorm(String.fromCharCode(rune));
        out.write(mapped.isNotEmpty ? mapped : ' ');
      }
    }
    return out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  final base = norm(filename.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), ''));
  if (base.isEmpty) return null;
  final baseTokens = base.split(' ').where((t) => t.length > 2).toSet();

  FilenameMatch? best;
  for (final s in sources) {
    var score = 0.0;
    final idN = norm(s.id);
    if (base == idN) {
      score += 100;
    } else if (base.contains(idN) || idN.contains(base)) {
      score += 50;
    }
    final titleTokens = norm('${s.title} ${s.longTitle ?? ''}')
        .split(' ')
        .where((t) => t.length > 3)
        .toList();
    final hits = titleTokens.where(baseTokens.contains).length;
    if (titleTokens.isNotEmpty) {
      score += 40 * (hits / min(8, titleTokens.length));
    }
    final author = norm((s.author ?? '').split(RegExp(r'[,;]| u\.a\.| et al\.')).first);
    if (author.length > 3 && base.contains(author)) score += 25;
    if (s.year != null && s.year != 0 && base.contains('${s.year}')) score += 15;
    if (best == null || score > best.score) {
      best = FilenameMatch(id: s.id, score: score, sure: false);
    }
  }
  if (best == null || best.score < 25) return null;
  return FilenameMatch(id: best.id, score: best.score, sure: best.score >= 60);
}
