import 'package:knotes/core/theme/account_visuals.dart';
import 'package:knotes/features/bodega/presentation/statistics_screen.dart';
import 'package:knotes/features/bodega/presentation/add_account_dialog.dart';
import 'package:knotes/features/bodega/presentation/add_transaction_sheet.dart';

import 'package:flutter/material.dart';

import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';
import 'package:knotes/core/widgets/financial_balance_card.dart';
import 'package:knotes/core/widgets/juice_widgets.dart';
import 'package:knotes/core/widgets/pet_cameo_empty_state.dart';
import 'package:knotes/features/bodega/models/account.dart';
import 'package:knotes/features/bodega/view_models/home_view_model.dart';
import 'package:knotes/features/bodega/presentation/movements_screen.dart';
import 'package:knotes/features/bodega/presentation/widgets/budget_panel.dart';
import 'package:knotes/features/bodega/presentation/widgets/movement_tile.dart';

class FinancesScreen extends StatelessWidget {
  final HomeViewModel controller;
  final ValueChanged<String> onTransaction;
  final VoidCallback onAddAccount;
  final ValueChanged<Account> onEditAccount;
  final VoidCallback onBudget;
  final VoidCallback onAgenda;

  const FinancesScreen({
    super.key,
    required this.controller,
    required this.onTransaction,
    required this.onAddAccount,
    required this.onEditAccount,
    required this.onBudget,
    required this.onAgenda,
  });

  @override
  Widget build(BuildContext context) {
    final cashByCur = controller.cashByCurrency;

    return SafeArea(
      bottom: false,
      child: ContentWidth(
        child: RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
              // Header de Finanzas
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: KnotesTheme.accentLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      color: KnotesTheme.accent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Finanzas',
                          style: KnotesTheme.fontTitle.copyWith(fontSize: 26),
                        ),
                        Text(
                          'Control de ingresos, gastos y cuentas',
                          style: TextStyle(
                            fontSize: 12,
                            color: KnotesTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Presupuesto',
                    onPressed: onBudget,
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 1. Unified Balance Card
              FinancialBalanceCard(
                title: 'Saldo Total',
                balance: controller.balance,
                available: controller.available,
                currency: controller.currency,
                cashByCurrency: cashByCur,
              ),
              const SizedBox(height: 16),

              // 2. Botones de Registro de Movimiento (Gasto, Ingreso, Transferir)
              Row(
                children: [
                  Expanded(
                    child: JuiceButton(
                      icon: Icons.north_east_rounded,
                      label: 'Gasto',
                      filled: true,
                      onPressed: () => onTransaction('expense'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: JuiceButton(
                      icon: Icons.south_west_rounded,
                      label: 'Ingreso',
                      onPressed: () => onTransaction('income'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: JuiceButton(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Transferir',
                      onPressed: () => onTransaction('transfer'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        StatisticsScreen(currency: controller.currency),
                  ),
                ),
                icon: const Icon(Icons.bar_chart_rounded),
                label: const Text('Estadísticas semanales y mensuales'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ahorro',
                      style: KnotesTheme.fontTitle.copyWith(fontSize: 21),
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Nueva meta'),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => AddAccountDialog(
                        currency: controller.currency,
                        initialType: 'vault',
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                'Ahorrado: ${KnotesTheme.formatCurrency(controller.savings, controller.currency)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (!controller.accounts.any((a) => a.type == 'vault'))
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Crea una cuenta de ahorro y aparta dinero para tus metas.',
                  ),
                ),
              for (final account in controller.accounts.where(
                (a) => a.type == 'vault',
              )) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(account.iconData, color: account.displayColor),
                  onTap: () => onEditAccount(account),
                  title: Text(account.name),
                  subtitle: Text(
                    account.savingsTarget > 0
                        ? '${KnotesTheme.formatCurrency(account.balance, account.currency)} de ${KnotesTheme.formatCurrency(account.savingsTarget, account.currency)}'
                        : KnotesTheme.formatCurrency(
                            account.balance,
                            account.currency,
                          ),
                  ),
                  trailing: TextButton(
                    onPressed: controller.accounts.length < 2
                        ? null
                        : () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => AddTransactionSheet(
                              accounts: controller.accounts,
                              initialType: 'transfer',
                              currency: controller.currency,
                              preselectedAccountId: controller.accounts
                                  .firstWhere((a) => a.id != account.id)
                                  .id,
                              preselectedDestinationId: account.id,
                            ),
                          ),
                    child: const Text('Aportar'),
                  ),
                ),
                if (account.savingsTarget > 0) ...[
                  LinearProgressIndicator(
                    value: (account.balance / account.savingsTarget).clamp(
                      0.0,
                      1.0,
                    ),
                    color: account.displayColor,
                    backgroundColor: KnotesTheme.surfaceContainer,
                    minHeight: 6,
                    semanticsLabel: 'Progreso de ${account.name}',
                    semanticsValue:
                        '${(account.balance / account.savingsTarget * 100).clamp(0, 100).round()} %',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    account.balance >= account.savingsTarget
                        ? '¡Meta alcanzada!'
                        : 'Faltan ${KnotesTheme.formatCurrency(account.savingsTarget - account.balance, account.currency)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: KnotesTheme.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 16),

              // Compromisos semanales
              CommitmentAlert(
                balance: controller.balance,
                committed: controller.committed,
                currency: controller.currency,
              ),
              const SizedBox(height: 12),

              // 3. Cuentas
              LedgerPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cuentas (${controller.accounts.length})',
                          style: KnotesTheme.fontTitle.copyWith(fontSize: 18),
                        ),
                        IconButton.filledTonal(
                          tooltip: 'Nueva cuenta',
                          onPressed: onAddAccount,
                          icon: const Icon(Icons.add_rounded, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (controller.accounts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: OutlinedButton.icon(
                          onPressed: onAddAccount,
                          icon: const Icon(Icons.add_card_rounded),
                          label: const Text('Agregar primera cuenta'),
                        ),
                      )
                    else
                      for (final account in controller.accounts) ...[
                        InkWell(
                          borderRadius: BorderRadius.circular(
                            KnotesTheme.radiusSm,
                          ),
                          onTap: () => onEditAccount(account),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 4,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: account.displayColor.withValues(
                                      alpha: 0.15,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    account.iconData,
                                    size: 18,
                                    color: account.displayColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        account.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        account.excludeFromAvailable
                                            ? '${account.typeLabel} · Fuera del saldo libre'
                                            : account.typeLabel,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: KnotesTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  KnotesTheme.formatCurrency(
                                    account.balance,
                                    account.currency,
                                  ),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: account.balance < 0
                                        ? KnotesTheme.expenseRed
                                        : KnotesTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: KnotesTheme.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 10),
                      ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (controller.inactiveAccounts.isNotEmpty) ...[
                ExpansionTile(
                  title: Text(
                    'Cuentas desactivadas (${controller.inactiveAccounts.length})',
                  ),
                  tilePadding: EdgeInsets.zero,
                  children: [
                    for (final account in controller.inactiveAccounts)
                      ListTile(
                        leading: Icon(
                          account.iconData,
                          color: account.displayColor,
                        ),
                        title: Text(account.name),
                        subtitle: Text(
                          KnotesTheme.formatCurrency(
                            account.balance,
                            account.currency,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => onEditAccount(account),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              // 4. Presupuesto
              BudgetPanel(controller: controller, onEdit: onBudget),
              const SizedBox(height: 20),

              // 5. Movimientos
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Movimientos',
                    style: KnotesTheme.fontTitle.copyWith(fontSize: 21),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            MovementsScreen(currency: controller.currency),
                      ),
                    ),
                    icon: const Icon(Icons.manage_search_rounded, size: 18),
                    label: const Text('Ver todos'),
                  ),
                ],
              ),
              if (controller.transactions.isEmpty)
                const PetCameoEmptyState(
                  label: 'No hay movimientos recientes.',
                  iconBadge: Icons.monetization_on_outlined,
                ),
              for (final tx in controller.transactions.take(10))
                MovementTile(
                  tx: tx,
                  currency: controller.currency,
                  categories: controller.categories,
                  onVoid: controller.voidMovement,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
