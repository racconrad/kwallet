import 'dart:async';

import 'package:flutter/material.dart';

import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/database_error_view.dart';
import 'package:knotes/core/widgets/kitty_companion.dart';

class PetLoadingScreen extends StatefulWidget {
  final Map<String, String> settings;
  final bool failed;
  final String? errorMessage;
  final bool hasRecovery;
  final VoidCallback? onRestoreRecovery;
  final VoidCallback? onRepairDatabase;
  final VoidCallback? onImportBackup;
  final String? diagnosticInfo;

  const PetLoadingScreen({
    super.key,
    this.settings = const {},
    this.failed = false,
    this.errorMessage,
    this.hasRecovery = false,
    this.onRestoreRecovery,
    this.onRepairDatabase,
    this.onImportBackup,
    this.diagnosticInfo,
  });

  @override
  State<PetLoadingScreen> createState() => _PetLoadingScreenState();
}

class _PetLoadingScreenState extends State<PetLoadingScreen> {
  static const _loadingPhrases = [
    'Despertando a tu compañero…',
    'Abriendo tu bóveda privada…',
    'Organizando tus finanzas locales…',
    'Todo listo en tu dispositivo…',
  ];

  int _phraseIndex = 0;
  Timer? _phraseTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTimer();
  }

  @override
  void didUpdateWidget(PetLoadingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.failed != oldWidget.failed) {
      _syncTimer();
    }
  }

  void _syncTimer() {
    _phraseTimer?.cancel();
    _phraseTimer = null;

    if (widget.failed) return;
    final animationsDisabled =
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled;
    if (animationsDisabled) return;

    _phraseTimer = Timer.periodic(const Duration(milliseconds: 2200), (timer) {
      if (!mounted || widget.failed) {
        timer.cancel();
        return;
      }
      setState(() {
        _phraseIndex = (_phraseIndex + 1) % _loadingPhrases.length;
      });
    });
  }

  @override
  void dispose() {
    _phraseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.failed) {
      return DatabaseErrorView(
        settings: widget.settings,
        errorMessage: widget.errorMessage,
        hasRecovery: widget.hasRecovery,
        onRestoreRecovery: widget.onRestoreRecovery,
        onRepairDatabase: widget.onRepairDatabase,
        onImportBackup: widget.onImportBackup,
        diagnosticInfo: widget.diagnosticInfo,
      );
    }

    final animationsDisabled =
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'knotes',
                    style: KnotesTheme.fontTitle.copyWith(
                      fontSize: 30,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 140,
                    height: 130,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          bottom: 2,
                          child: Container(
                            width: 86,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.rectangle,
                              borderRadius: const BorderRadius.all(
                                Radius.elliptical(86, 18),
                              ),
                              gradient: RadialGradient(
                                colors: [
                                  KnotesTheme.accent.withValues(alpha: 0.22),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          child: KittyCompanionWidget(
                            settings: widget.settings,
                            size: 104,
                            activity: PetActivity.walk,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 130,
                    height: 5,
                    decoration: BoxDecoration(
                      color: KnotesTheme.surfaceContainer.withValues(
                        alpha: 0.8,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: animationsDisabled ? 0.6 : null,
                        backgroundColor: Colors.transparent,
                        color: KnotesTheme.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: Duration(
                      milliseconds: animationsDisabled ? 0 : 320,
                    ),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.2),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Text(
                      _loadingPhrases[_phraseIndex],
                      key: ValueKey(_phraseIndex),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: KnotesTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
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
