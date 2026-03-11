// lib/services/model_extractor.dart
//
// sherpa_onnx wymaga ABSOLUTNYCH ścieżek plików na dysku.
// Flutter assets są spakowane w binarce – trzeba je najpierw skopiować.
// Ta klasa robi to raz przy pierwszym uruchomieniu, potem używa cache.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class ModelExtractor {
  static const _tag = '[ModelExtractor]';

  // Ścieżki asset → nazwa pliku docelowego
  static const _assets = {
    'assets/models/silero_vad.onnx': 'silero_vad.onnx',
    'assets/models/kws/encoder.onnx': 'kws_encoder.onnx',
    'assets/models/kws/decoder.onnx': 'kws_decoder.onnx',
    'assets/models/kws/joiner.onnx': 'kws_joiner.onnx',
    'assets/models/kws/tokens.txt': 'kws_tokens.txt',
  };

  /// Zwraca mapę: nazwa_klucza → absolutna ścieżka na dysku.
  /// Kopiuje pliki tylko jeśli jeszcze nie istnieją (cache).
  static Future<Map<String, String>> extractAll() async {
    final dir = await getApplicationSupportDirectory();
    final result = <String, String>{};

    for (final entry in _assets.entries) {
      final assetPath = entry.key;
      final fileName = entry.value;
      final destFile = File('${dir.path}/$fileName');

      if (!await destFile.exists()) {
        debugPrint('$_tag Kopiuję $assetPath → ${destFile.path}');
        try {
          final bytes = await rootBundle.load(assetPath);
          await destFile.writeAsBytes(
            bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          );
          debugPrint('$_tag OK: $fileName (${destFile.lengthSync()} bytes)');
        } catch (e) {
          debugPrint('$_tag BŁĄD kopiowania $assetPath: $e');
          rethrow;
        }
      } else {
        debugPrint('$_tag Cache hit: $fileName');
      }

      result[fileName] = destFile.path;
    }

    debugPrint('$_tag Wszystkie modele gotowe w: ${dir.path}');
    return result;
  }

  /// Czyści cache – użyj gdy chcesz wymusić ponowne skopiowanie modeli.
  static Future<void> clearCache() async {
    final dir = await getApplicationSupportDirectory();
    for (final fileName in _assets.values) {
      final f = File('${dir.path}/$fileName');
      if (await f.exists()) await f.delete();
    }
    debugPrint('$_tag Cache wyczyszczony');
  }
}
