import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/kitty_companion.dart';

/// A quiet first meeting, using the actual baby sprite the user is adopting.
class AdoptionScene extends StatefulWidget {
  final Map<String, String> settings;
  final PetActivity activity;
  final bool arriving;
  final bool greeted;
  final VoidCallback? onGreet;
  const AdoptionScene({
    super.key,
    required this.settings,
    this.activity = PetActivity.idle,
    this.arriving = false,
    this.greeted = false,
    this.onGreet,
  });
  @override
  State<AdoptionScene> createState() => _AdoptionSceneState();
}

class _AdoptionSceneState extends State<AdoptionScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrival = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  Timer? _reactionTimer;
  bool _reacting = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) || !widget.arriving) {
      _arrival.value = 1;
    } else if (!_arrival.isAnimating && _arrival.value == 0) {
      _arrival.forward();
    }
  }

  @override
  void dispose() {
    _reactionTimer?.cancel();
    _arrival.dispose();
    super.dispose();
  }

  void _greet() {
    HapticFeedback.lightImpact();
    setState(() => _reacting = true);
    widget.onGreet?.call();
    _reactionTimer?.cancel();
    _reactionTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _reacting = false);
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.min(320.0, constraints.maxWidth);
      final height = width * .78;
      final petSize = width * .56;
      final reduced = MediaQuery.disableAnimationsOf(context);
      return Center(
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 6,
                child: Container(
                  width: width * .70,
                  height: height * .88,
                  decoration: BoxDecoration(
                    color: KnotesTheme.accentLight,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(width),
                      bottom: const Radius.circular(28),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 15,
                child: Container(
                  width: width * .78,
                  height: 28,
                  decoration: BoxDecoration(
                    color: KnotesTheme.accent.withValues(alpha: .13),
                    borderRadius: const BorderRadius.all(
                      Radius.elliptical(140, 28),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: width * .06,
                bottom: 48,
                child: Transform.rotate(
                  angle: -.35,
                  child: Icon(
                    Icons.eco_outlined,
                    color: KnotesTheme.accent,
                    size: 32,
                  ),
                ),
              ),
              Positioned(
                right: width * .05,
                top: 35,
                child: Transform.rotate(
                  angle: .25,
                  child: Icon(
                    Icons.eco_outlined,
                    color: KnotesTheme.accent,
                    size: 22,
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _arrival,
                builder: (_, _) {
                  final progress = Curves.easeOutCubic.transform(
                    _arrival.value,
                  );
                  return Transform.translate(
                    offset: Offset(
                      widget.arriving ? 60 * (1 - progress) : 0,
                      12,
                    ),
                    child: Semantics(
                      label:
                          'Saludar a ${widget.settings['pet_name'] ?? 'tu compañero'}',
                      button: true,
                      child: AnimatedSwitcher(
                        duration: reduced
                            ? Duration.zero
                            : const Duration(milliseconds: 240),
                        child: KittyCompanionWidget(
                          key: ValueKey(widget.settings['pet_style']),
                          settings: widget.settings,
                          size: petSize,
                          activity: _reacting
                              ? PetActivity.celebrate
                              : widget.arriving && progress < .8
                              ? PetActivity.walk
                              : widget.activity,
                          onPet: _greet,
                        ),
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                top: 9,
                right: width * .23,
                child: AnimatedScale(
                  scale: _reacting || widget.greeted ? 1 : 0,
                  duration: reduced
                      ? Duration.zero
                      : const Duration(milliseconds: 280),
                  curve: Curves.easeOutBack,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: KnotesTheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _reacting
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: KnotesTheme.accent,
                      size: 25,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
