import 'package:knotes/core/theme/category_visuals.dart';

import 'package:flutter/material.dart';

import 'package:knotes/app/app_dependencies.dart';
import 'package:knotes/core/mvvm/view_model_state.dart';
import 'package:knotes/features/bodega/view_models/categories_view_model.dart';
import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/game_hud_widgets.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';
import 'package:knotes/features/bodega/models/category_model.dart';

class CategoriesSheet extends StatefulWidget {
  final String type; // 'expense' or 'income'

  const CategoriesSheet({super.key, this.type = 'expense'});

  @override
  State<CategoriesSheet> createState() => _CategoriesSheetState();
}

class _CategoriesSheetState
    extends ViewModelState<CategoriesSheet, CategoriesViewModel> {
  @override
  CategoriesViewModel createViewModel(AppDependencies dependencies) =>
      dependencies.categories(widget.type);
  final TextEditingController _nameController = TextEditingController();
  String _selectedIconKey = 'food';
  int _selectedColor = 0xFF10B981;
  String get _currentType => model.type;

  List<CategoryModel> get _categories => model.categories;
  bool get _isLoading => model.loading;

  final List<Map<String, dynamic>> _availableIcons = [
    {'key': 'food', 'icon': Icons.restaurant_rounded, 'label': 'Comida'},
    {'key': 'home', 'icon': Icons.home_rounded, 'label': 'Hogar'},
    {
      'key': 'transport',
      'icon': Icons.directions_car_rounded,
      'label': 'Transporte',
    },
    {'key': 'game', 'icon': Icons.sports_esports_rounded, 'label': 'Ocio'},
    {'key': 'potion', 'icon': Icons.medical_services_rounded, 'label': 'Salud'},
    {'key': 'loot', 'icon': Icons.shopping_bag_rounded, 'label': 'Compras'},
    {'key': 'energy', 'icon': Icons.bolt_rounded, 'label': 'Servicios'},
    {'key': 'fish', 'icon': Icons.pets_rounded, 'label': 'Mascotas'},
    {'key': 'quest', 'icon': Icons.work_rounded, 'label': 'Trabajo'},
    {'key': 'gift', 'icon': Icons.card_giftcard_rounded, 'label': 'Regalos'},
    {'key': 'gem', 'icon': Icons.savings_rounded, 'label': 'Ahorro'},
    {'key': 'boss', 'icon': Icons.warning_rounded, 'label': 'Imprevisto'},
  ];

  final List<int> _availableColors = [
    0xFF10B981, // Emerald
    0xFF715033,
    0xFF8C493F,
    0xFFEC4899, // Pink
    0xFFF59E0B, // Amber
    0xFF6B703A,
    0xFFF97316, // Orange
    0xFFEF4444, // Red
    0xFF625B52, // Slate
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addCategory() async {
    final name = _nameController.text.trim();
    final saved = await model.add(name, _selectedIconKey, _selectedColor);
    if (!mounted) return;
    if (saved) {
      _nameController.clear();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Categoría "$name" creada')));
    } else {
      showFailure(context, model.error ?? 'No se pudo guardar la categoría.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: KnotesTheme.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Gestionar Categorías',
                  style: KnotesTheme.fontTitle.copyWith(fontSize: 18),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: KnotesTheme.textSecondary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Type Toggle
            Row(
              children: [
                Expanded(
                  child: FilterChip(
                    label: Center(child: Text('Gastos')),
                    selected: _currentType == 'expense',
                    selectedColor: KnotesTheme.accent.withValues(alpha: 0.2),
                    backgroundColor: KnotesTheme.surfaceContainer,
                    checkmarkColor: KnotesTheme.accent,
                    labelStyle: TextStyle(
                      color: _currentType == 'expense'
                          ? KnotesTheme.accent
                          : KnotesTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) {
                      model.selectType('expense');
                    },
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: FilterChip(
                    label: Center(child: Text('Ingresos')),
                    selected: _currentType == 'income',
                    selectedColor: KnotesTheme.accent.withValues(alpha: 0.2),
                    backgroundColor: KnotesTheme.surfaceContainer,
                    checkmarkColor: KnotesTheme.accent,
                    labelStyle: TextStyle(
                      color: _currentType == 'income'
                          ? KnotesTheme.accent
                          : KnotesTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) {
                      model.selectType('income');
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // New category form
            Text(
              'CREAR NUEVA CATEGORÍA',
              style: KnotesTheme.fontBody.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: KnotesTheme.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    style: TextStyle(color: KnotesTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Ej. Gimnasio, Libros, Streaming...',
                      hintStyle: TextStyle(
                        color: KnotesTheme.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                ExpressiveButton(
                  onPressed: _addCategory,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Icon(Icons.add_rounded, color: KnotesTheme.onAccent),
                ),
              ],
            ),
            SizedBox(height: 14),

            // Icon Picker
            Text(
              'Icono',
              style: KnotesTheme.fontBody.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: KnotesTheme.textSecondary,
              ),
            ),
            SizedBox(height: 6),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _availableIcons.length,
                separatorBuilder: (_, _) => SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final item = _availableIcons[i];
                  final isSelected = _selectedIconKey == item['key'];
                  return GestureDetector(
                    onTap: () => setState(
                      () => _selectedIconKey = item['key'] as String,
                    ),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? KnotesTheme.accent.withValues(alpha: 0.2)
                            : KnotesTheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isSelected
                              ? KnotesTheme.accent
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        size: 20,
                        color: isSelected
                            ? KnotesTheme.accent
                            : KnotesTheme.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 14),

            // Color Picker
            Text(
              'Color',
              style: KnotesTheme.fontBody.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: KnotesTheme.textSecondary,
              ),
            ),
            SizedBox(height: 6),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _availableColors.length,
                separatorBuilder: (_, _) => SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final c = _availableColors[i];
                  final isSelected = _selectedColor == c;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = c),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: KnotesTheme.onAccent,
                                width: 2.5,
                              )
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 20),

            // Existing categories list
            Text(
              'CATEGORÍAS EXISTENTES (${_categories.length})',
              style: KnotesTheme.fontBody.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: KnotesTheme.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 10),

            if (_isLoading)
              Center(child: CircularProgressIndicator())
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  return Chip(
                    avatar: Icon(
                      cat.iconData,
                      size: 16,
                      color: KnotesTheme.displayColor(cat.colorValue),
                    ),
                    label: Text(
                      cat.name,
                      style: TextStyle(
                        fontSize: 12,
                        color: KnotesTheme.textPrimary,
                      ),
                    ),
                    backgroundColor: KnotesTheme.surfaceContainer,
                    side: BorderSide(color: KnotesTheme.border),
                    deleteIcon: cat.isDefault
                        ? null
                        : Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: KnotesTheme.textMuted,
                          ),
                    onDeleted: cat.isDefault
                        ? null
                        : () async {
                            if (!await model.remove(cat.id) &&
                                context.mounted) {
                              showFailure(
                                context,
                                model.error ??
                                    'No se pudo eliminar la categoría.',
                              );
                            }
                          },
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
