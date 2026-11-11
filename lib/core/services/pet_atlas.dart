import 'dart:ui';

import 'package:knotes/core/models/pet_species.dart';

/// Each species and age has an independent sheet with the same frame grid.
class PetAtlasLayout {
  final Size cellSize = const Size(64, 64);
  final Size atlasSize = const Size(512, 640);
  final int framesPerRow = 8;
  final int animationRows = 10;

  const PetAtlasLayout();

  Rect frameRect({
    required PetSpecies species,
    required PetGrowthStage stage,
    required int row,
    int frame = 0,
  }) {
    RangeError.checkValueInInterval(row, 0, animationRows - 1, 'row');
    RangeError.checkValueInInterval(frame, 0, framesPerRow - 1, 'frame');
    return Rect.fromLTWH(
      frame * cellSize.width,
      row * cellSize.height,
      cellSize.width,
      cellSize.height,
    );
  }
}

class PetAtlas {
  static Future<PetAtlasLayout> loadLayout() async => const PetAtlasLayout();
}
