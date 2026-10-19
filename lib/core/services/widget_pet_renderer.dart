import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import '../models/pet_species.dart';

/// Renders the same atlas cells and coat filter used by the in-app companion.
/// Cache one sprite pack; state updates only send the pose and direction.
class WidgetPetRenderer {
  static String? _cacheKey;
  static Future<Map<String, String>>? _cache;
  static Future<Map<String, String>> render(
    Map<String, String> settings,
    int xp,
  ) {
    final key =
        '${settings['pet_style']}:${PetGrowthStage.fromXp(xp).name}:${settings['pet_image_data']}';
    if (_cacheKey != key) {
      _cacheKey = key;
      _cache = _render(settings, xp).catchError((Object error) {
        if (_cacheKey == key) {
          _cacheKey = null;
          _cache = null;
        }
        throw error;
      });
    }
    return _cache!;
  }

  static Future<Map<String, String>> _render(
    Map<String, String> settings,
    int xp,
  ) async {
    final style = settings['pet_style'];
    final custom = style == 'custom' ? settings['pet_image_data'] : null;
    final bytes = custom != null && custom.length <= 5600000
        ? base64Decode(custom)
        : (await rootBundle.load(PetSpeciesCatalog.resolveAsset(style, xp: xp)))
              .buffer
              .asUint8List();
    final codec = await ui.instantiateImageCodec(bytes);
    final image = (await codec.getNextFrame()).image;
    codec.dispose();
    try {
      final sprites = <String, String>{};
      for (final entry in const {
        'idle': 0,
        'walk': 4,
        'run': 5,
        'sleep': 6,
        'curious': 7,
        'celebrate': 8,
        'relax': 9,
        'grabbed': 8,
      }.entries) {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        final paint = ui.Paint()
          ..filterQuality = ui.FilterQuality.none
          ..isAntiAlias = false;
        ui.Rect source, target;
        if (custom != null) {
          source = ui.Rect.fromLTWH(
            0,
            0,
            image.width.toDouble(),
            image.height.toDouble(),
          );
          final ratio = image.width / image.height;
          final width = ratio > 1 ? 128.0 : 128 * ratio;
          final height = ratio > 1 ? 128 / ratio : 128.0;
          target = ui.Rect.fromLTWH(
            (128 - width) / 2,
            (128 - height) / 2,
            width,
            height,
          );
        } else {
          source = ui.Rect.fromLTWH(0, entry.value * 32.0, 32, 32);
          target = const ui.Rect.fromLTWH(0, 0, 128, 128);
          // Match ColorFiltered after scaling the source pixel art.
          canvas.saveLayer(
            target,
            ui.Paint()..colorFilter = PetSpeciesCatalog.get(style).colorFilter,
          );
        }
        canvas.drawImageRect(image, source, target, paint);
        if (custom == null) canvas.restore();
        final picture = recorder.endRecording();
        final frame = await picture.toImage(128, 128);
        picture.dispose();
        final data = await frame.toByteData(format: ui.ImageByteFormat.png);
        frame.dispose();
        sprites[entry.key] = base64Encode(data!.buffer.asUint8List());
      }
      return sprites;
    } finally {
      image.dispose();
    }
  }
}
