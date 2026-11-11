import 'package:flutter/material.dart';

import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/kitty_companion.dart';

class GitHubCloudHeader extends StatelessWidget {
  final Map<String, String> settings;
  final bool connected;
  final bool isBusy;

  const GitHubCloudHeader({
    super.key,
    required this.settings,
    required this.connected,
    required this.isBusy,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          SizedBox(
            width: 120,
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  bottom: 2,
                  child: Container(
                    width: 80,
                    height: 16,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(
                        Radius.elliptical(80, 16),
                      ),
                      gradient: RadialGradient(
                        colors: [
                          KnotesTheme.accent.withValues(alpha: 0.25),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  child: KittyCompanionWidget(
                    settings: settings,
                    size: 84,
                    activity: isBusy
                        ? PetActivity.run
                        : (connected
                              ? PetActivity.celebrate
                              : PetActivity.curious),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: connected
                          ? KnotesTheme.incomeGreen
                          : KnotesTheme.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      connected
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tu Nube Personal',
            style: KnotesTheme.fontTitle.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 4),
          Text(
            'Respaldo privado, cifrado y bajo tu propio control.',
            textAlign: TextAlign.center,
            style: TextStyle(color: KnotesTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
