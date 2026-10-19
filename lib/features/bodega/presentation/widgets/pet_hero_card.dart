import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/pet_species.dart';
import '../../../../core/theme/kwall_theme.dart';
import '../../../../core/widgets/finance_widgets.dart';
import '../../../../core/widgets/kitty_companion.dart';
import '../../../../core/widgets/pet_visual_toast.dart';
import '../../view_models/home_view_model.dart';
import 'pet_dialogue_bubble.dart';

class PetHeroCard extends StatefulWidget {
  final HomeViewModel controller;
  final ValueChanged<bool>? onHoldChanged;

  const PetHeroCard({super.key, required this.controller, this.onHoldChanged});

  @override
  State<PetHeroCard> createState() => _PetHeroCardState();
}

class _PetHeroCardState extends State<PetHeroCard>
    with TickerProviderStateMixin {
  Timer? _roamTimer;
  Timer? _walkStepTimer;
  Timer? _annoyedTimer;
  Timer? _celebrateTimer;

  static const double _groundY = 0.74;
  double _xPos = 0.0;
  double _yPos = _groundY; // ground level
  double _targetX = 0.0;
  bool _movingRight = true;
  PetActivity _currentActivity = PetActivity.idle;
  bool _isCelebrating = false;
  bool _isGrabbed = false;
  bool _isAnnoyed = false;
  String? _lastWidgetState;
  PetActivity? _spriteActivity;
  bool _earnedXpThisPet = false;

  // Particle animations
  late final AnimationController _particleAnim;
  late final AnimationController _annoyedAnim;
  final List<
    ({double x, double delay, double scale, Color color, IconData icon})
  >
  _particles = [];
  final List<
    ({double x, double delay, double scale, double rotation, Color color})
  >
  _annoyedParticles = [];

  @override
  void initState() {
    super.initState();
    _particleAnim =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1400),
        )..addListener(() {
          if (mounted) setState(() {});
        });

    _annoyedAnim =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1300),
        )..addListener(() {
          if (mounted) setState(() {});
        });

    _scheduleNextRoam();
  }

  void _scheduleNextRoam() {
    _roamTimer?.cancel();
    _walkStepTimer?.cancel();
    if (!mounted || _isGrabbed || _isAnnoyed || _isCelebrating) return;

    final random = math.Random();
    final delay = 3500 + random.nextInt(3500);

    _roamTimer = Timer(Duration(milliseconds: delay), () {
      if (!mounted || _isGrabbed || _isAnnoyed || _isCelebrating) return;

      final now = DateTime.now();
      if (now.hour >= 22 || now.hour < 6) {
        setState(() {
          _currentActivity = PetActivity.sleep;
        });
        _scheduleNextRoam();
        return;
      }

      // Pick next activity: walk, idle, curious (play), sleep, relax
      final choice = random.nextDouble();
      if (choice < 0.45) {
        _startAutonomousWalk();
      } else if (choice < 0.70) {
        setState(() {
          _currentActivity = PetActivity.curious;
        });
        _scheduleNextRoam();
      } else if (choice < 0.88) {
        setState(() {
          _currentActivity = PetActivity.relax;
        });
        _scheduleNextRoam();
      } else {
        setState(() {
          _currentActivity = PetActivity.idle;
        });
        _scheduleNextRoam();
      }
    });
  }

  void _startAutonomousWalk() {
    final random = math.Random();
    _targetX = (random.nextDouble() * 1.7) - 0.85; // between -0.85 and 0.85
    final movingRight = _targetX > _xPos;

    setState(() {
      _currentActivity = PetActivity.walk;
      _movingRight = movingRight;
    });

    _walkStepTimer?.cancel();
    _walkStepTimer = Timer.periodic(const Duration(milliseconds: 180), (timer) {
      if (!mounted || _isGrabbed || _isAnnoyed || _isCelebrating) {
        timer.cancel();
        return;
      }

      final diff = _targetX - _xPos;
      if (diff.abs() < 0.05) {
        timer.cancel();
        setState(() {
          _xPos = _targetX;
          _currentActivity = random.nextBool()
              ? PetActivity.idle
              : PetActivity.curious;
        });
        _scheduleNextRoam();
      } else {
        final step = diff > 0 ? 0.04 : -0.04;
        setState(() {
          _xPos = (_xPos + step).clamp(-0.88, 0.88);
        });
      }
    });
  }

  Future<void> _giveAffection() async {
    HapticFeedback.lightImpact();
    _annoyedTimer?.cancel();
    _celebrateTimer?.cancel();

    final awarded = await widget.controller.petCompanion(2);

    // Generate affection particles: hearts and sparkles
    _particles.clear();
    final random = math.Random();
    final colors = [
      const Color(0xFFF1B3C7),
      const Color(0xFFFFA726),
      const Color(0xFFB2D39C),
      const Color(0xFFFFCC80),
      const Color(0xFFE57373),
    ];

    final particleCount = awarded ? 7 : 4;
    for (int i = 0; i < particleCount; i++) {
      _particles.add((
        x: (random.nextDouble() - 0.5) * 65,
        delay: i * 0.10,
        scale: 0.65 + random.nextDouble() * 0.5,
        color: colors[i % colors.length],
        icon: (awarded && i.isEven)
            ? Icons.auto_awesome_rounded
            : Icons.favorite_rounded,
      ));
    }
    _particleAnim.forward(from: 0.0);

    setState(() {
      _isCelebrating = true;
      _isAnnoyed = false;
      _earnedXpThisPet = awarded;
    });

    if (mounted) {
      PetVisualToast.show(
        context,
        type: awarded ? PetVisualToastType.xp : PetVisualToastType.affection,
        badgeValue: awarded ? '+2 XP' : null,
      );
    }

    _celebrateTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        setState(() {
          _isCelebrating = false;
          _earnedXpThisPet = false;
        });
        _scheduleNextRoam();
      }
    });
  }

  void _handlePetDropped(bool wasMoved) {
    widget.onHoldChanged?.call(false);
    HapticFeedback.mediumImpact();
    _roamTimer?.cancel();
    _walkStepTimer?.cancel();
    _annoyedTimer?.cancel();

    setState(() {
      _isGrabbed = false;
      _yPos = _groundY; // return to ground level
      if (wasMoved) {
        _isAnnoyed = true;
        _isCelebrating = false;
      }
    });

    if (wasMoved) {
      _annoyedParticles.clear();
      final random = math.Random();
      final redShades = [
        const Color(0xFFEF4444),
        const Color(0xFFE53935),
        const Color(0xFFFF5252),
        const Color(0xFFDC2626),
      ];
      for (int i = 0; i < 5; i++) {
        _annoyedParticles.add((
          x: (random.nextDouble() - 0.5) * 60,
          delay: i * 0.10,
          scale: 0.7 + random.nextDouble() * 0.45,
          rotation: (random.nextDouble() - 0.5) * 0.4,
          color: redShades[i % redShades.length],
        ));
      }
      _annoyedAnim.forward(from: 0.0);
    }

    _annoyedTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) {
        setState(() {
          _isAnnoyed = false;
        });
        _scheduleNextRoam();
      }
    });
  }

  @override
  void dispose() {
    _roamTimer?.cancel();
    _walkStepTimer?.cancel();
    _annoyedTimer?.cancel();
    _celebrateTimer?.cancel();
    _particleAnim.dispose();
    _annoyedAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final petName = controller.settings['pet_name'] ?? 'Mishi';
    final level = controller.xp ~/ 100 + 1;
    final growthStage = PetGrowthStage.fromXp(controller.xp);
    final xpInCurrentLevel = controller.xp % 100;
    final xpProgress = (xpInCurrentLevel / 100).clamp(0.0, 1.0);
    final now = DateTime.now();
    final hour = now.hour;
    final allHabitsDone =
        controller.totalHabitsToday > 0 && controller.pendingHabitsCount == 0;
    final isSleepingTime = hour >= 22 || hour < 7 || (hour >= 14 && hour < 16);

    final defaultActivity = isSleepingTime
        ? PetActivity.sleep
        : (allHabitsDone ? PetActivity.celebrate : _currentActivity);

    final effectiveActivity = _isGrabbed
        ? PetActivity.grabbed
        : (_isCelebrating
              ? PetActivity.celebrate
              : (_isAnnoyed ? PetActivity.curious : defaultActivity));

    final mood = _isAnnoyed
        ? 'annoyed'
        : _isCelebrating || allHabitsDone
        ? 'happy'
        : 'normal';
    final widgetState = '${effectiveActivity.name}:$mood:$_movingRight';
    if (_lastWidgetState != widgetState) {
      _lastWidgetState = widgetState;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          controller.syncPetState(
            (_spriteActivity ?? effectiveActivity).name,
            mood,
            _movingRight,
          );
        }
      });
    }

    // Dynamic shadow: shrinks and fades when lifted high towards the ceiling
    final liftRatio = ((_groundY - _yPos) / 1.5).clamp(0.0, 1.0);
    final shadowWidth = 56.0 - (liftRatio * 32.0);
    final shadowHeight = 8.0 - (liftRatio * 4.5);
    final shadowOpacity = (0.28 - (liftRatio * 0.20)).clamp(0.05, 0.28);

    return LedgerPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: KwallTheme.surfaceContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: KwallTheme.accent.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.pets_rounded,
                      size: 14,
                      color: KwallTheme.accent,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      petName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: KwallTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              // Growth stage and level chip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: KwallTheme.accentLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      growthStage == PetGrowthStage.master
                          ? Icons.stars_rounded
                          : Icons.auto_awesome_rounded,
                      color: KwallTheme.accent,
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${growthStage.title} • Nv. $level',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: KwallTheme.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          LayoutBuilder(
            builder: (context, constraints) {
              final stageWidth = constraints.maxWidth;
              const stageHeight = 185.0;
              return Container(
                height: stageHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      KwallTheme.surfaceContainer.withValues(alpha: 0.2),
                      KwallTheme.accentLight.withValues(alpha: 0.35),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: KwallTheme.border.withValues(alpha: 0.3),
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 16,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: KwallTheme.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Dynamic shadow
                    AnimatedAlign(
                      duration: _isGrabbed
                          ? Duration.zero
                          : const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment(_xPos, 0.86),
                      child: Container(
                        width: shadowWidth,
                        height: shadowHeight,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: shadowOpacity),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    // Integrated pet dialogue bubble following the pet further away
                    AnimatedAlign(
                      duration: _isGrabbed
                          ? Duration.zero
                          : const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment(_xPos, _yPos - 0.76),
                      child: IgnorePointer(
                        child: PetDialogueBubble(
                          controller: controller,
                          isPurring: _isCelebrating,
                          isAnnoyed: _isAnnoyed,
                        ),
                      ),
                    ),

                    AnimatedAlign(
                      duration: _isGrabbed
                          ? Duration.zero
                          : const Duration(milliseconds: 450),
                      curve: _isGrabbed ? Curves.linear : Curves.bounceOut,
                      alignment: Alignment(_xPos, _yPos),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _giveAffection,
                        onPanStart: (details) {
                          HapticFeedback.lightImpact();
                          widget.onHoldChanged?.call(true);
                          _roamTimer?.cancel();
                          _walkStepTimer?.cancel();
                          _annoyedTimer?.cancel();
                          setState(() {
                            _isGrabbed = true;
                            _isAnnoyed = false;
                          });
                        },
                        onPanUpdate: (details) {
                          if (stageWidth <= 0) return;
                          final dx = details.delta.dx / (stageWidth * 0.45);
                          final dy = details.delta.dy / (stageHeight * 0.45);
                          setState(() {
                            _xPos = (_xPos + dx).clamp(-0.92, 0.92);
                            _yPos = (_yPos + dy).clamp(-0.95, _groundY);
                            if (details.delta.dx > 0.3) _movingRight = true;
                            if (details.delta.dx < -0.3) _movingRight = false;
                          });
                        },
                        onPanEnd: (details) {
                          final wasLifted =
                              _yPos < 0.40 ||
                              details.velocity.pixelsPerSecond.distance > 80;
                          _handlePetDropped(wasLifted);
                        },
                        onPanCancel: () {
                          widget.onHoldChanged?.call(false);
                          _handlePetDropped(false);
                        },
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 160),
                          scale: (_isGrabbed ? 1.10 : 1.0) * growthStage.scale,
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              Transform.flip(
                                flipX: !_movingRight,
                                child: KittyCompanionWidget(
                                  size: 92,
                                  reward: controller.xp,
                                  settings: controller.settings,
                                  activity: effectiveActivity,
                                  onPet: _giveAffection,
                                  onActivityChanged: (activity) {
                                    _spriteActivity = activity;
                                    controller.syncPetState(
                                      activity.name,
                                      _isAnnoyed
                                          ? 'annoyed'
                                          : _isCelebrating || allHabitsDone
                                          ? 'happy'
                                          : 'normal',
                                      _movingRight,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Affection particles
                    if (_particleAnim.isAnimating && _particles.isNotEmpty)
                      AnimatedAlign(
                        duration: Duration.zero,
                        alignment: Alignment(_xPos, _yPos - 0.2),
                        child: SizedBox(
                          width: 110,
                          height: 130,
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              for (final p in _particles)
                                Builder(
                                  builder: (context) {
                                    final t = (_particleAnim.value - p.delay)
                                        .clamp(0.0, 1.0);
                                    if (t <= 0.0) {
                                      return const SizedBox.shrink();
                                    }
                                    final yProgress = Curves.easeOutCubic
                                        .transform(t);
                                    final opacity = (1.0 - t).clamp(0.0, 1.0);
                                    return Positioned(
                                      bottom: yProgress * 65 + 30,
                                      left: 55 + p.x - 10,
                                      child: Opacity(
                                        opacity: opacity,
                                        child: Transform.scale(
                                          scale:
                                              p.scale * (0.8 + 0.4 * yProgress),
                                          child: Icon(
                                            p.icon,
                                            size: 17,
                                            color: p.color,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),

                              // Floating +2 XP badge
                              if (_earnedXpThisPet)
                                Builder(
                                  builder: (context) {
                                    final t = _particleAnim.value.clamp(
                                      0.0,
                                      1.0,
                                    );
                                    final yProgress = Curves.easeOutCubic
                                        .transform(t);
                                    final opacity = (1.0 - t * 0.9).clamp(
                                      0.0,
                                      1.0,
                                    );
                                    return Positioned(
                                      top: 15 - (yProgress * 25),
                                      child: Opacity(
                                        opacity: opacity,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: KwallTheme.accent,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: KwallTheme.accent
                                                    .withValues(alpha: 0.4),
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            '+2 XP',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                              color: KwallTheme.onAccent,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    // Annoyance cross particles
                    if (_annoyedAnim.isAnimating &&
                        _annoyedParticles.isNotEmpty)
                      AnimatedAlign(
                        duration: Duration.zero,
                        alignment: Alignment(_xPos, _yPos - 0.2),
                        child: SizedBox(
                          width: 110,
                          height: 130,
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              for (final p in _annoyedParticles)
                                Builder(
                                  builder: (context) {
                                    final t = (_annoyedAnim.value - p.delay)
                                        .clamp(0.0, 1.0);
                                    if (t <= 0.0) {
                                      return const SizedBox.shrink();
                                    }
                                    final yProgress = Curves.easeOutCubic
                                        .transform(t);
                                    final opacity = (1.0 - t).clamp(0.0, 1.0);
                                    return Positioned(
                                      bottom: yProgress * 65 + 30,
                                      left: 55 + p.x - 10,
                                      child: Opacity(
                                        opacity: opacity,
                                        child: Transform.rotate(
                                          angle: p.rotation,
                                          child: Transform.scale(
                                            scale:
                                                p.scale *
                                                (0.8 + 0.4 * yProgress),
                                            child: Icon(
                                              Icons.close_rounded,
                                              size: 20,
                                              color: p.color,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // XP progress towards next level
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: xpProgress,
              minHeight: 6,
              backgroundColor: KwallTheme.border.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(KwallTheme.accent),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nv. $level',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: KwallTheme.accent,
                ),
              ),
              Text(
                '${100 - xpInCurrentLevel} XP para subir',
                style: TextStyle(fontSize: 11, color: KwallTheme.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
