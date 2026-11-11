import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class PetAtlasPainter extends CustomPainter {
  final ui.Image? atlas;
  final Rect? source;
  PetAtlasPainter(this.atlas, this.source);

  @override
  void paint(Canvas canvas, Size size) {
    if (atlas == null || source == null) return;
    // Keep the full cell so tails and ears are not clipped.
    canvas.drawImageRect(
      atlas!,
      source!,
      Offset.zero & size,
      Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false,
    );
  }

  @override
  bool shouldRepaint(PetAtlasPainter oldDelegate) =>
      atlas != oldDelegate.atlas || source != oldDelegate.source;
}
