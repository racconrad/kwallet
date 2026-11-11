import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:knotes/core/models/pet_species.dart';
import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';
import 'package:knotes/core/widgets/kitty_companion.dart';
import 'package:knotes/core/widgets/pet_visual_toast.dart';
import 'package:knotes/features/bodega/view_models/home_view_model.dart';
import 'package:knotes/features/bodega/presentation/widgets/pet_dialogue_bubble.dart';

part 'pet_hero_stage.dart';

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

  // Lets the part-file extension rebuild without touching protected setState.
  void _update(VoidCallback change) => setState(change);

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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: Icon(
                  Icons.pets_rounded,
                  size: 14,
                  color: KnotesTheme.accent,
                ),
                label: Text(
                  petName.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: KnotesTheme.textPrimary,
                  ),
                ),
                backgroundColor: KnotesTheme.surfaceContainer.withValues(
                  alpha: 0.5,
                ),
              ),
              Chip(
                avatar: Icon(
                  growthStage == PetGrowthStage.master
                      ? Icons.stars_rounded
                      : Icons.auto_awesome_rounded,
                  color: KnotesTheme.accent,
                  size: 13,
                ),
                label: Text(
                  '${growthStage.title} • Nv. $level',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: KnotesTheme.accent,
                  ),
                ),
                backgroundColor: KnotesTheme.accentLight,
              ),
            ],
          ),
          const SizedBox(height: 12),

          _stage(
            controller: controller,
            effectiveActivity: effectiveActivity,
            growthStage: growthStage,
            allHabitsDone: allHabitsDone,
            shadowWidth: shadowWidth,
            shadowHeight: shadowHeight,
            shadowOpacity: shadowOpacity,
          ),
          const SizedBox(height: 12),

          // XP progress towards next level
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: xpProgress,
              minHeight: 6,
              backgroundColor: KnotesTheme.border.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(KnotesTheme.accent),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'Nv. $level',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: KnotesTheme.accent,
                ),
              ),
              Text(
                '${100 - xpInCurrentLevel} XP para subir',
                style: TextStyle(
                  fontSize: 11,
                  color: KnotesTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
