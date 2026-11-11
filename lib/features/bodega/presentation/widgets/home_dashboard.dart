import 'package:flutter/material.dart';

import 'package:knotes/features/bodega/view_models/home_view_model.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';
import 'package:knotes/features/bodega/models/account.dart';
import 'package:knotes/features/bodega/presentation/widgets/home_overview.dart';
import 'package:knotes/features/bodega/presentation/widgets/home_hub.dart';

class HomeDashboard extends StatefulWidget {
  final HomeViewModel controller;
  final ValueChanged<String> onTransaction;
  final VoidCallback onAddAccount;
  final ValueChanged<Account> onEditAccount;
  final VoidCallback onBudget;
  final VoidCallback onAgenda;
  final ValueChanged<int> onJournal;
  final VoidCallback? onOpenFinances;
  final VoidCallback? onSettings;

  const HomeDashboard({
    super.key,
    required this.controller,
    required this.onTransaction,
    required this.onAddAccount,
    required this.onEditAccount,
    required this.onBudget,
    required this.onAgenda,
    required this.onJournal,
    this.onOpenFinances,
    this.onSettings,
  });

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  bool _isHoldingPet = false;

  void _onPetHoldChanged(bool isHolding) {
    if (_isHoldingPet != isHolding) {
      setState(() => _isHoldingPet = isHolding);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: ContentWidth(
      child: RefreshIndicator(
        onRefresh: widget.controller.load,
        child: ListView(
          physics: _isHoldingPet
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            // 1. Hero Pet Companion & Resumen de Saldos y Acciones
            HomeOverview(
              controller: widget.controller,
              onOpenFinances: widget.onOpenFinances,
              onSettings: widget.onSettings,
              onPetHoldChanged: _onPetHoldChanged,
            ),
            const SizedBox(height: 8),
            HomeHub(
              controller: widget.controller,
              onTransaction: widget.onTransaction,
              onAgenda: widget.onAgenda,
              onOpenFinances: widget.onOpenFinances,
              onJournal: widget.onJournal,
            ),
          ],
        ),
      ),
    ),
  );
}
