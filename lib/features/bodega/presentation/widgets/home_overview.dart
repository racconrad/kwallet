import 'package:flutter/material.dart';

import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';
import 'package:knotes/core/widgets/financial_balance_card.dart';
import 'package:knotes/features/bodega/view_models/home_view_model.dart';
import 'package:knotes/features/bodega/presentation/widgets/pet_hero_card.dart';

class HomeOverview extends StatelessWidget {
  final HomeViewModel controller;
  final VoidCallback? onOpenFinances;
  final VoidCallback? onSettings;
  final ValueChanged<bool>? onPetHoldChanged;

  const HomeOverview({
    super.key,
    required this.controller,
    this.onOpenFinances,
    this.onSettings,
    this.onPetHoldChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cashByCur = controller.cashByCurrency;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Saludo de bienvenida con acceso a ajustes
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Bienvenido',
                  style: KnotesTheme.fontTitle.copyWith(fontSize: 26),
                ),
              ),
              if (onSettings != null)
                IconButton.filledTonal(
                  tooltip: 'Ajustes',
                  onPressed: onSettings,
                  icon: const Icon(Icons.tune_rounded, size: 20),
                ),
            ],
          ),
        ),

        // 1. CARD PRINCIPAL: LA MASCOTA VIRTUAL
        PetHeroCard(controller: controller, onHoldChanged: onPetHoldChanged),
        const SizedBox(height: 16),

        // 2. Financial Balance Card
        FinancialBalanceCard(
          balance: controller.balance,
          available: controller.available,
          currency: controller.currency,
          cashByCurrency: cashByCur,
          onAction: onOpenFinances,
          actionLabel: 'Finanzas',
        ),
        const SizedBox(height: 12),

        // Alerta de compromisos próximos
        CommitmentAlert(
          balance: controller.balance,
          committed: controller.committed,
          currency: controller.currency,
        ),
      ],
    );
  }
}
