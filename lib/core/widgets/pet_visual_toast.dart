import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:knotes/core/theme/knotes_theme.dart';

enum PetVisualToastType {
  xp(Icons.auto_awesome_rounded, Colors.amber),
  affection(Icons.favorite_rounded, Color(0xFFDE7586)),
  habitDone(Icons.check_circle_rounded, Color(0xFF4CAF50)),
  expense(Icons.payments_rounded, Color(0xFF3F51B5)),
  saving(Icons.savings_rounded, Color(0xFF009688));

  final IconData icon;
  final Color color;
  const PetVisualToastType(this.icon, this.color);
}

class PetVisualToast {
  static void show(
    BuildContext context, {
    required PetVisualToastType type,
    String? badgeValue,
  }) {
    HapticFeedback.lightImpact();

    final overlay = Overlay.of(context);
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _VisualToastWidget(
        type: type,
        badgeValue: badgeValue,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

class _VisualToastWidget extends StatefulWidget {
  final PetVisualToastType type;
  final String? badgeValue;
  final VoidCallback onDismiss;

  const _VisualToastWidget({
    required this.type,
    this.badgeValue,
    required this.onDismiss,
  });

  @override
  State<_VisualToastWidget> createState() => _VisualToastWidgetState();
}

class _VisualToastWidgetState extends State<_VisualToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _slideAnimation = Tween<double>(
      begin: -30,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 1800), () async {
      if (!mounted) return;
      await _controller.reverse();
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 12,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _slideAnimation.value),
              child: Opacity(opacity: _fadeAnimation.value, child: child),
            );
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: KnotesTheme.surface,
                borderRadius: BorderRadius.circular(KnotesTheme.radiusLg),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: widget.type.color.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.pets_rounded,
                    size: 16,
                    color: KnotesTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Icon(widget.type.icon, size: 20, color: widget.type.color),
                  if (widget.badgeValue != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      widget.badgeValue!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: widget.type.color,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
