import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:knotes/core/theme/knotes_theme.dart';

bool _still(BuildContext context) => MediaQuery.disableAnimationsOf(context);

/// Segmented progress with the current step's icon and name spelled out.
class StepProgress extends StatelessWidget {
  final int index;
  final int count;
  final IconData icon;
  final String label;
  const StepProgress({
    super.key,
    required this.index,
    required this.count,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final duration = Duration(milliseconds: _still(context) ? 0 : 320);
    return Semantics(
      label: 'Paso ${index + 1} de $count: $label',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: duration,
            child: Row(
              key: ValueKey(label),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: KnotesTheme.accent),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'PASO ${index + 1} DE $count · ${label.toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .6,
                      color: KnotesTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < count; i++)
                Expanded(
                  flex: i == index ? 3 : 1,
                  child: AnimatedContainer(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: i == index
                          ? KnotesTheme.pop
                          : i < index
                          ? KnotesTheme.accent
                          : KnotesTheme.surfaceContainer,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Fades and lifts its child in, [order] beats after the step appears.
class Reveal extends StatefulWidget {
  final int order;
  final Widget child;
  const Reveal({super.key, required this.order, required this.child});

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  static const _beat = 70;
  late final _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 360 + widget.order.clamp(0, 8) * _beat),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_still(context)) return widget.child;
    final start =
        widget.order.clamp(0, 8) * _beat / _controller.duration!.inMilliseconds;
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, .12),
          end: Offset.zero,
        ).animate(curve),
        child: widget.child,
      ),
    );
  }
}

/// Large icon tile that pops in at the top of a step.
class StepBadge extends StatelessWidget {
  final IconData icon;
  const StepBadge(this.icon, {super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: _still(context) ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 620),
      curve: Curves.elasticOut,
      builder: (_, t, child) => Transform.rotate(
        angle: (1 - t) * -.35,
        child: Transform.scale(scale: t, child: child),
      ),
      child: Container(
        width: 84,
        height: 84,
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: KnotesTheme.accent,
          borderRadius: BorderRadius.circular(KnotesTheme.radiusLg),
          border: Border.all(color: KnotesTheme.border, width: 1.5),
          boxShadow: KnotesTheme.hardShadow,
        ),
        child: Icon(icon, size: 42, color: KnotesTheme.onAccent),
      ),
    ),
  );
}

/// Selectable card led by an icon; used for every single-choice question.
class ChoiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final bool selected;
  final VoidCallback onTap;
  const ChoiceTile({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(KnotesTheme.radiusMd);
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: Duration(milliseconds: _still(context) ? 0 : 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? KnotesTheme.accentLight : KnotesTheme.surface,
          borderRadius: radius,
          border: Border.all(
            color: selected ? KnotesTheme.accent : KnotesTheme.border,
            width: selected ? 2.5 : 1.5,
          ),
          boxShadow: selected ? KnotesTheme.hardShadow : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: body == null
                  ? Column(
                      children: [
                        IconTile(icon, filled: selected),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KnotesTheme.fontTitle,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        IconTile(icon, filled: selected),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: KnotesTheme.fontTitle),
                              if (body != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  body!,
                                  style: TextStyle(
                                    color: KnotesTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        AnimatedScale(
                          scale: selected ? 1 : 0,
                          duration: Duration(
                            milliseconds: _still(context) ? 0 : 260,
                          ),
                          curve: Curves.easeOutBack,
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: KnotesTheme.accent,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded square holding an icon; filled when it represents the active state.
class IconTile extends StatelessWidget {
  final IconData icon;
  final bool filled;
  final Color? color;
  const IconTile(this.icon, {super.key, this.filled = false, this.color});

  @override
  Widget build(BuildContext context) {
    final tone = color ?? KnotesTheme.accent;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: filled
            ? tone
            : Color.alphaBlend(
                tone.withValues(alpha: .16),
                KnotesTheme.surface,
              ),
        borderRadius: BorderRadius.circular(KnotesTheme.radiusSm),
      ),
      child: Icon(icon, color: filled ? KnotesTheme.onAccent : tone),
    );
  }
}

/// Read-only row with an icon tile: explains an area or summarises a choice.
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color? color;
  const InfoRow(this.icon, this.title, this.body, {super.key, this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconTile(icon, color: color),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: KnotesTheme.fontTitle.copyWith(fontSize: 16)),
              const SizedBox(height: 2),
              Text(body, style: TextStyle(color: KnotesTheme.textSecondary)),
            ],
          ),
        ),
      ],
    ),
  );
}
