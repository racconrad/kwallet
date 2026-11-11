part of 'pet_hero_card.dart';

/// The interactive stage where the pet walks, gets picked up and reacts.
extension _PetStage on _PetHeroCardState {
  Widget _stage({
    required HomeViewModel controller,
    required PetActivity effectiveActivity,
    required PetGrowthStage growthStage,
    required bool allHabitsDone,
    required double shadowWidth,
    required double shadowHeight,
    required double shadowOpacity,
  }) => LayoutBuilder(
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
              KnotesTheme.surfaceContainer.withValues(alpha: 0.2),
              KnotesTheme.accentLight.withValues(alpha: 0.35),
            ],
          ),
          borderRadius: BorderRadius.circular(KnotesTheme.radiusMd),
          border: Border.all(color: KnotesTheme.border.withValues(alpha: 0.3)),
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
                  color: KnotesTheme.accent.withValues(alpha: 0.15),
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
                  borderRadius: BorderRadius.circular(KnotesTheme.radiusSm),
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
                  _update(() {
                    _isGrabbed = true;
                    _isAnnoyed = false;
                  });
                },
                onPanUpdate: (details) {
                  if (stageWidth <= 0) return;
                  final dx = details.delta.dx / (stageWidth * 0.45);
                  final dy = details.delta.dy / (stageHeight * 0.45);
                  _update(() {
                    _xPos = (_xPos + dx).clamp(-0.92, 0.92);
                    _yPos = (_yPos + dy).clamp(
                      -0.95,
                      _PetHeroCardState._groundY,
                    );
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
                            final t = (_particleAnim.value - p.delay).clamp(
                              0.0,
                              1.0,
                            );
                            if (t <= 0.0) {
                              return const SizedBox.shrink();
                            }
                            final yProgress = Curves.easeOutCubic.transform(t);
                            final opacity = (1.0 - t).clamp(0.0, 1.0);
                            return Positioned(
                              bottom: yProgress * 65 + 30,
                              left: 55 + p.x - 10,
                              child: Opacity(
                                opacity: opacity,
                                child: Transform.scale(
                                  scale: p.scale * (0.8 + 0.4 * yProgress),
                                  child: Icon(p.icon, size: 17, color: p.color),
                                ),
                              ),
                            );
                          },
                        ),

                      // Floating +2 XP badge
                      if (_earnedXpThisPet)
                        Builder(
                          builder: (context) {
                            final t = _particleAnim.value.clamp(0.0, 1.0);
                            final yProgress = Curves.easeOutCubic.transform(t);
                            final opacity = (1.0 - t * 0.9).clamp(0.0, 1.0);
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
                                    color: KnotesTheme.accent,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: KnotesTheme.accent.withValues(
                                          alpha: 0.4,
                                        ),
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
                                      color: KnotesTheme.onAccent,
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
            if (_annoyedAnim.isAnimating && _annoyedParticles.isNotEmpty)
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
                            final t = (_annoyedAnim.value - p.delay).clamp(
                              0.0,
                              1.0,
                            );
                            if (t <= 0.0) {
                              return const SizedBox.shrink();
                            }
                            final yProgress = Curves.easeOutCubic.transform(t);
                            final opacity = (1.0 - t).clamp(0.0, 1.0);
                            return Positioned(
                              bottom: yProgress * 65 + 30,
                              left: 55 + p.x - 10,
                              child: Opacity(
                                opacity: opacity,
                                child: Transform.rotate(
                                  angle: p.rotation,
                                  child: Transform.scale(
                                    scale: p.scale * (0.8 + 0.4 * yProgress),
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
  );
}
