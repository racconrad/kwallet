import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/kitty_companion.dart';

class AdoptionBox extends StatelessWidget {
  final bool opened;
  final Map<String, String> settings;
  final VoidCallback onOpen;
  const AdoptionBox({
    super.key,
    required this.opened,
    required this.settings,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: !opened,
    label: opened
        ? 'Tu compañero ha salido de la caja'
        : 'Abrir la caja de cartón',
    child: Center(
      child: SizedBox(
        width: 256,
        height: 256,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: opened ? null : onOpen,
            borderRadius: BorderRadius.circular(KnotesTheme.radiusLg),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: opened ? 1 : 0),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 650),
              curve: Curves.easeOutBack,
              builder: (context, t, _) {
                final open = t.clamp(0.0, 1.0);
                // A short squash while the flaps open, then the pet pops out.
                final squash = 1 - .06 * math.sin(math.pi * open);
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    if (t > 0)
                      Positioned(
                        top: -56 + 110 * (1 - t),
                        child: Opacity(
                          opacity: open,
                          child: Transform.scale(
                            scale: .5 + .5 * t,
                            alignment: Alignment.bottomCenter,
                            child: KittyCompanionWidget(
                              settings: settings,
                              size: 192,
                              activity: PetActivity.curious,
                            ),
                          ),
                        ),
                      ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Transform.scale(
                          scaleY: squash,
                          scaleX: 2 - squash,
                          alignment: Alignment.bottomCenter,
                          child: CustomPaint(painter: _BoxPainter(open)),
                        ),
                      ),
                    ),
                    if (open < 1)
                      Positioned(
                        bottom: 54,
                        child: Opacity(
                          opacity: 1 - open,
                          child: const Icon(
                            Icons.pets_rounded,
                            color: Color(0xFF533B28),
                            size: 32,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

class _BoxPainter extends CustomPainter {
  final double open;
  _BoxPainter(this.open);

  double _l(double a, double b) => a + (b - a) * open;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 256;
    canvas.scale(sx);
    final paint = Paint()..color = const Color(0xFFB98756);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(38, 145, 180, 96),
        const Radius.circular(4),
      ),
      paint,
    );
    paint.color = const Color(0xFFD6A775);
    final left = Path()
      ..moveTo(38, 145)
      ..lineTo(128, 145)
      ..lineTo(_l(128, 94), _l(120, 116))
      ..lineTo(_l(38, 6), _l(120, 116))
      ..close();
    final right = Path()
      ..moveTo(128, 145)
      ..lineTo(218, 145)
      ..lineTo(_l(218, 250), _l(120, 116))
      ..lineTo(_l(128, 162), _l(120, 116))
      ..close();
    canvas.drawPath(left, paint);
    canvas.drawPath(right, paint);
    paint.color = const Color(0xFFE8C59C);
    if (open < .5) {
      canvas.drawRect(const Rect.fromLTWH(117, 120, 22, 25), paint);
    }
    canvas.drawRect(const Rect.fromLTWH(117, 145, 22, 32), paint);
    paint
      ..color = const Color(0xFF825B38)
      ..strokeWidth = 2;
    canvas.drawLine(const Offset(38, 145), const Offset(218, 145), paint);
  }

  @override
  bool shouldRepaint(_BoxPainter oldDelegate) => oldDelegate.open != open;
}
