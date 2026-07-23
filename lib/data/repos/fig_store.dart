/// FigStore — Pendant zu `FigStore` (figures.js:8-55): hochgeladene
/// Abbildungs-Blobs (für Manifest-Einträge mit `file: null`), jetzt in der
/// Drift-Tabelle statt IndexedDB `ehds-figstore`.
///
/// Der ObjectURL-Cache des Originals (der nie revoked wurde, L2) entfällt —
/// Bild-Widgets bekommen direkt Bytes (`Image.memory`).
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../db/daos/fig_imgs_dao.dart';
import '../db/database.dart';

part 'fig_store.g.dart';

class FigStore {
  FigStore(this._dao);

  final FigImgsDao _dao;

  /// fig-ids mit hochgeladenem Bild (synchron abfragbar, beim init geladen).
  final Set<String> _ids = {};

  final _changes = StreamController<void>.broadcast();

  /// Änderungs-Benachrichtigung (Platzhalter ↔ Bild wechselt live).
  Stream<void> get changes => _changes.stream;

  /// ids laden; Fehler schlucken wie das Original (figures.js:13-23).
  Future<void> init() async {
    try {
      _ids.addAll(await _dao.allIds());
    } catch (_) {/* Speicher nicht verfügbar */}
  }

  bool has(String figId) => _ids.contains(figId);

  Future<void> put(String figId, Uint8List data, {String? mime}) async {
    await _dao.write(figId, data, mime: mime);
    _ids.add(figId);
    _changes.add(null);
  }

  /// Bild-Bytes + MIME oder null (Pendant zu getUrl, ohne ObjectURL).
  Future<(Uint8List, String?)?> getImage(String figId) async {
    final row = await _dao.read(figId);
    return row == null ? null : (row.data, row.mime);
  }

  Future<void> remove(String figId) async {
    await _dao.remove(figId);
    _ids.remove(figId);
    _changes.add(null);
  }

  void dispose() => _changes.close();
}

/// Der Abbildungs-Speicher als Provider (init einmal, wie FigStore.init()
/// beim Skript-Laden).
@Riverpod(keepAlive: true)
Future<FigStore> figStore(Ref ref) async {
  final store = FigStore(ref.watch(appDatabaseProvider).figImgsDao);
  ref.onDispose(store.dispose);
  await store.init();
  return store;
}
