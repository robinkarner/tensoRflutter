/// Tests der Bild-Beschaffung für den `#/doc`-Druck (K-4):
/// Magic-Byte-Erkennung (nur PNG/JPEG kann das pdf-Paket einbetten),
/// Durchreichen einbettbarer Bytes und die WebP→PNG-Umkodierung
/// (dart:ui-Decoder der Test-Engine).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/features/doc/doc_images.dart';

/// 1×1-PNG (Base64).
final _tinyPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('isPdfEmbeddableImage', () {
    test('PNG- und JPEG-Magic werden erkannt', () {
      expect(isPdfEmbeddableImage(_tinyPng), isTrue);
      expect(
        isPdfEmbeddableImage(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])),
        isTrue,
      );
    });

    test('andere Formate (GIF/WebP/Müll) nicht', () {
      expect(isPdfEmbeddableImage(Uint8List.fromList(utf8.encode('GIF89a'))),
          isFalse);
      expect(isPdfEmbeddableImage(Uint8List.fromList(utf8.encode('RIFFxxxx'))),
          isFalse);
      expect(isPdfEmbeddableImage(Uint8List(0)), isFalse);
    });
  });

  group('toPdfEmbeddableImage', () {
    test('PNG wird identisch durchgereicht', () async {
      final out = await toPdfEmbeddableImage(_tinyPng);
      expect(out, same(_tinyPng));
    });

    test('nicht dekodierbare Bytes → null (kein Absturz)', () async {
      final out = await toPdfEmbeddableImage(
          Uint8List.fromList(utf8.encode('kein Bild')));
      expect(out, isNull);
    });
  });
}
