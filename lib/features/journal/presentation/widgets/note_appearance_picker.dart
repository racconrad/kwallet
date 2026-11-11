import 'package:flutter/material.dart';

import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/features/journal/models/journal_models.dart';

/// Icon and colour chooser for a note; pops with (iconKey, colorValue).
class NoteAppearancePicker extends StatefulWidget {
  final String iconKey;
  final int colorValue;
  const NoteAppearancePicker({
    super.key,
    required this.iconKey,
    required this.colorValue,
  });
  @override
  State<NoteAppearancePicker> createState() => _NoteAppearancePickerState();
}

class _NoteAppearancePickerState extends State<NoteAppearancePicker> {
  late String _icon = widget.iconKey;
  late int _color = widget.colorValue;
  String _query = '';
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Icono y color'),
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              onChanged: (value) =>
                  setState(() => _query = value.toLowerCase().trim()),
              decoration: const InputDecoration(
                labelText: 'Buscar icono',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (key, icon, label) in noteIcons.where(
                  (entry) => entry.$3.toLowerCase().contains(_query),
                ))
                  Semantics(
                    selected: key == _icon,
                    child: IconButton.filledTonal(
                      tooltip: label,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        backgroundColor: key == _icon
                            ? KnotesTheme.accentLight
                            : KnotesTheme.surfaceContainer,
                        foregroundColor: key == _icon
                            ? KnotesTheme.accent
                            : KnotesTheme.textPrimary,
                        side: key == _icon
                            ? BorderSide(color: KnotesTheme.accent)
                            : BorderSide.none,
                      ),
                      icon: Icon(icon),
                      onPressed: () => setState(() => _icon = key),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              noteIcons
                  .firstWhere(
                    (entry) => entry.$1 == _icon,
                    orElse: () => noteIcons.first,
                  )
                  .$3,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            if (!noteIcons.any(
              (entry) => entry.$3.toLowerCase().contains(_query),
            ))
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No hay iconos con ese nombre.'),
              ),
            const SizedBox(height: 24),
            Text('Color', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (value, label) in noteColors)
                  Semantics(
                    selected: _color == value,
                    child: IconButton.filledTonal(
                      tooltip: label,
                      onPressed: () => setState(() => _color = value),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        backgroundColor: value == 0
                            ? KnotesTheme.surfaceContainer
                            : Color(value),
                      ),
                      icon: Icon(
                        _color == value
                            ? Icons.check_rounded
                            : Icons.circle_outlined,
                        color: value == 0
                            ? KnotesTheme.textPrimary
                            : ThemeData.estimateBrightnessForColor(
                                    Color(value),
                                  ) ==
                                  Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, (_icon, _color)),
        child: const Text('Aplicar'),
      ),
    ],
  );
}
