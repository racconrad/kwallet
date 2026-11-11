import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:knotes/core/services/notification_service.dart';
import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/kitty_companion.dart';
import 'package:knotes/features/pets/presentation/pet_animation_lab.dart';

class AboutSection extends StatelessWidget {
  final String githubUsername;
  const AboutSection({super.key, required this.githubUsername});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      children: [
        SizedBox(
          width: 110,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                bottom: 2,
                child: Container(
                  width: 76,
                  height: 16,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(
                      Radius.elliptical(76, 16),
                    ),
                    gradient: RadialGradient(
                      colors: [
                        KnotesTheme.accent.withValues(alpha: 0.28),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              const Positioned(
                bottom: 6,
                child: KittyCompanionWidget(
                  settings: {
                    'pet_species': 'cat',
                    'pet_stage': 'adult',
                    'pet_color': 'shadow',
                  },
                  size: 84,
                  activity: PetActivity.walk,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('knotesa', style: KnotesTheme.fontTitle.copyWith(fontSize: 18)),
        Text(
          'knotes v1.1.0 · Creado con amor para tus finanzas',
          style: TextStyle(color: KnotesTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 14),
        FilledButton.tonalIcon(
          onPressed: () async {
            final profileUser = githubUsername.isNotEmpty
                ? githubUsername
                : 'MagusCat';
            final profileUrl = 'https://github.com/$profileUser';
            final opened = await NotificationService.openUrl(profileUrl);
            if (!opened) {
              await Clipboard.setData(ClipboardData(text: profileUrl));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text('Enlace copiado al portapapeles: $profileUrl'),
                ),
              );
            }
          },
          icon: const Icon(Icons.code_rounded, size: 18),
          label: Text(
            'GitHub @${githubUsername.isNotEmpty ? githubUsername : 'MagusCat'}',
          ),
        ),
        const SizedBox(height: 24),
        if (kDebugMode)
          TextButton.icon(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const PetAnimationLab())),
            icon: const Icon(Icons.grid_view_outlined),
            label: const Text('Pet animation lab'),
          ),
      ],
    ),
  );
}
