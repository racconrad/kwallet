import 'package:flutter/material.dart';

import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/pet_selection_panel.dart';

class PetPicker extends StatelessWidget {
  final Map<String, String> settings;
  final bool busy;
  final String? error;
  final ValueChanged<String> onChoose;
  final VoidCallback onUpload;
  const PetPicker({
    super.key,
    required this.settings,
    required this.busy,
    required this.onChoose,
    required this.onUpload,
    this.error,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PetSelectionPanel(
        selectedStyle: settings['pet_style'] ?? 'classic',
        onSelectStyle: onChoose,
      ),
      if (busy)
        const Padding(
          padding: EdgeInsets.all(8),
          child: LinearProgressIndicator(),
        ),
      if (error != null)
        Text(error!, style: TextStyle(color: KnotesTheme.expenseRed)),
    ],
  );
}
