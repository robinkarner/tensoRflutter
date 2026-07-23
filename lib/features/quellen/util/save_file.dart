/// Datei-Sichern — Pendant zu `U.download` (temporäres `<a download>`).
///
/// Auf dem Web schreibt `FilePicker.saveFile` die Bytes selbst (Browser-
/// Download); auf Desktop liefert es nur den Zielpfad — dort schreiben wir
/// die Datei nach dem Dialog selbst.
library;

import 'dart:convert';
import 'dart:io' as io;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

/// Bytes unter [fileName] sichern. true = gesichert, false = abgebrochen.
Future<bool> saveBytesFile(String fileName, Uint8List bytes) async {
  final path = await FilePicker.saveFile(
    dialogTitle: 'Sichern',
    fileName: fileName,
    bytes: bytes,
  );
  if (path == null) return false;
  if (!kIsWeb) {
    // Desktop: der Dialog liefert nur den Pfad — Datei selbst schreiben.
    await io.File(path).writeAsBytes(bytes, flush: true);
  }
  return true;
}

/// Text (UTF-8) unter [fileName] sichern.
Future<bool> saveTextFile(String fileName, String text) =>
    saveBytesFile(fileName, Uint8List.fromList(utf8.encode(text)));
