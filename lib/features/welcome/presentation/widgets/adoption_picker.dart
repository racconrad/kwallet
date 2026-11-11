import 'package:flutter/material.dart';

import 'package:knotes/core/models/pet_species.dart';
import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/kitty_companion.dart';

class AdoptionPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const AdoptionPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final current = PetSpeciesCatalog.get(selected);
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 8,
          children: [
            for (final species in PetSpecies.values)
              _choice(
                label: species.label,
                style: PetSpeciesCatalog.forSpecies(species).first.key,
                active: current.species == species,
                onTap: () =>
                    onChanged(PetSpeciesCatalog.forSpecies(species).first.key),
                species: true,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          current.species.label,
          style: TextStyle(color: KnotesTheme.textSecondary, fontSize: 13),
        ),
        if (PetSpeciesCatalog.forSpecies(current.species).length > 1) ...[
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final style in PetSpeciesCatalog.forSpecies(
                  current.species,
                ))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _choice(
                      label: style.name,
                      style: style.key,
                      active: selected == style.key,
                      onTap: () => onChanged(style.key),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _choice({
    required String label,
    required String style,
    required bool active,
    required VoidCallback onTap,
    bool species = false,
  }) => Semantics(
    label: label,
    selected: active,
    button: true,
    child: Tooltip(
      message: label,
      child: Material(
        color: active ? KnotesTheme.accentLight : KnotesTheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(species ? 24 : 14),
          side: BorderSide(
            color: active ? KnotesTheme.accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(species ? 24 : 14),
          child: SizedBox(
            width: 48,
            height: 56,
            child: IgnorePointer(
              child: TickerMode(
                enabled: false,
                child: KittyCompanionWidget(
                  size: 44,
                  settings: {'pet_style': style},
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
