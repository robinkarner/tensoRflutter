/// `.tex`-Export — Pendant zu `U.download(name, text, 'text/x-tex')`
/// (util.js): auf dem Web löst der Browser den Download aus, auf dem
/// Desktop öffnet der System-Speichern-Dialog (file_picker schreibt die
/// Bytes selbst an den gewählten Ort).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<void> saveTexFile(String filename, String content) async {
  await FilePicker.saveFile(
    dialogTitle: filename,
    fileName: filename,
    bytes: Uint8List.fromList(utf8.encode(content)),
  );
}
