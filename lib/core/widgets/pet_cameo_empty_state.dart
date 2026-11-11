import 'package:flutter/material.dart';

import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/kitty_companion.dart';

class PetCameoEmptyState extends StatelessWidget {
  final String label;
  final PetActivity activity;
  final IconData? iconBadge;

  const PetCameoEmptyState({
    super.key,
    required this.label,
    this.activity = PetActivity.sleep,
    this.iconBadge,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.topRight,
              clipBehavior: Clip.none,
              children: [
                IgnorePointer(
                  child: KittyCompanionWidget(size: 72, activity: activity),
                ),
                if (iconBadge != null)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: KnotesTheme.accentLight,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: KnotesTheme.accent.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        iconBadge,
                        size: 14,
                        color: KnotesTheme.accent,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: KnotesTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
