import 'package:flutter/material.dart';

import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/features/bodega/view_models/home_view_model.dart';

class PetDialogueBubble extends StatelessWidget {
  final HomeViewModel controller;
  final bool isPurring;
  final bool isAnnoyed;

  const PetDialogueBubble({
    super.key,
    required this.controller,
    this.isPurring = false,
    this.isAnnoyed = false,
  });

  ({IconData icon, Color color})? _computeEmotion() {
    if (isAnnoyed) {
      return (icon: Icons.close_rounded, color: const Color(0xFFEF4444));
    }

    if (isPurring) {
      return (icon: Icons.favorite_rounded, color: const Color(0xFFF43F5E));
    }

    final hour = DateTime.now().hour;
    final allHabitsDone =
        controller.totalHabitsToday > 0 && controller.pendingHabitsCount == 0;

    if (hour >= 22 || hour < 6) {
      return (icon: Icons.bedtime_rounded, color: const Color(0xFF818CF8));
    }

    if (controller.limit > 0 && controller.spent > controller.limit) {
      return (
        icon: Icons.priority_high_rounded,
        color: const Color(0xFFF97316),
      );
    }

    if (allHabitsDone) {
      return (icon: Icons.auto_awesome_rounded, color: const Color(0xFFF59E0B));
    }

    // Nothing to say right now
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final emotion = _computeEmotion();
    if (emotion == null) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: KnotesTheme.surface,
            borderRadius: BorderRadius.circular(KnotesTheme.radiusSm),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: emotion.color.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Icon(emotion.icon, size: 16, color: emotion.color),
        ),
        CustomPaint(
          size: const Size(8, 5),
          painter: _BubblePointerPainter(color: KnotesTheme.surface),
        ),
      ],
    );
  }
}

class _BubblePointerPainter extends CustomPainter {
  final Color color;
  _BubblePointerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BubblePointerPainter oldDelegate) =>
      color != oldDelegate.color;
}
