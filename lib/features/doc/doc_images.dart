/// Bild-Beschaffung für den `#/doc`-Druck: die Abbildungen des Manifests
/// kommen entweder als gebündeltes Asset (`fig.file`, z. B.
/// "figures/abb-3-3-2-acm.png") oder als hochgeladenes FigStore-Bild —
/// dieselbe Priorität wie `figureCard` (figures.js:58-77).
///
/// Das pdf-Paket kann nur PNG/JPEG einbetten; .webp-Assets (und alles
/// andere, was Flutter dekodieren kann) werden deshalb über `dart:ui`
/// nach PNG umkodiert. Nicht auffindbare oder unlesbare Bilder fallen
/// still auf den Druck-Platzhalter zurück — kein Abbruch des Druckens
/// wegen eines einzelnen Bildes.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;

import '../../data/models/models.dart';
import '../../data/repos/fig_store.dart';
import 'doc_print.dart' show isPdfEmbeddableImage;

// Die Magic-Byte-Prüfung lebt in doc_print.dart (dort wird sie vor dem
// Einbetten erneut angewandt) — hier mit exportiert.
export 'doc_print.dart' show isPdfEmbeddableImage;

/// Bytes in ein einbettbares Format bringen: PNG/JPEG unverändert
/// durchreichen, alles andere (WebP …) via dart:ui dekodieren und als
/// PNG neu kodieren. `null` = nicht dekodierbar.
Future<Uint8List?> toPdfEmbeddableImage(Uint8List bytes) async {
  if (isPdfEmbeddableImage(bytes)) return bytes;
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();
    return data?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

/// Alle Manifest-Abbildungen laden → Map Figur-id → PNG/JPEG-Bytes für
/// [buildThesisPdfBytes]. [onProgress] meldet den Zählerstand an den
/// Fortschritts-Dialog.
Future<Map<String, Uint8List>> loadDocPrintImages({
  required FiguresManifest figures,
  FigStore? figStore,
  void Function(int geladen, int gesamt)? onProgress,
}) async {
  final out = <String, Uint8List>{};
  final figs = figures.figuren;
  var done = 0;
  for (final fig in figs) {
    Uint8List? raw;
    final file = fig.file;
    if (file != null && file.isNotEmpty) {
      // Statisches Asset (Priorität 1, wie figureCard).
      try {
        raw = (await rootBundle.load('assets/$file')).buffer.asUint8List();
      } catch (_) {/* Asset fehlt → ggf. FigStore, sonst Platzhalter */}
    }
    if (raw == null && figStore != null && figStore.has(fig.id)) {
      // Hochgeladenes Bild (Priorität 2).
      raw = (await figStore.getImage(fig.id))?.$1;
    }
    if (raw != null) {
      final embeddable = await toPdfEmbeddableImage(raw);
      if (embeddable != null) out[fig.id] = embeddable;
    }
    done++;
    onProgress?.call(done, figs.length);
  }
  return out;
}
