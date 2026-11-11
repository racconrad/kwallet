import 'package:flutter/material.dart';

import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/features/bodega/presentation/categories_sheet.dart';

class CategoriesSettingsCard extends StatelessWidget {
  const CategoriesSettingsCard({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: KnotesTheme.surfaceContainer.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(KnotesTheme.radiusSm),
      border: Border.all(color: KnotesTheme.border.withValues(alpha: 0.25)),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: KnotesTheme.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(KnotesTheme.radiusSm),
          ),
          child: Icon(
            Icons.category_rounded,
            color: KnotesTheme.accent,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gestionar categorías',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                'Personaliza, crea y administra tus categorías de gastos e ingresos.',
                style: TextStyle(
                  color: KnotesTheme.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.tonal(
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => const CategoriesSheet(type: 'expense'),
          ),
          child: const Text('Ver todas'),
        ),
      ],
    ),
  );
}
