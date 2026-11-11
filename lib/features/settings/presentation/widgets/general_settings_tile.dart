import 'package:flutter/material.dart';

import 'package:knotes/core/theme/knotes_theme.dart';

const startPages = {
  '0': 'Inicio',
  '1': 'Finanzas',
  '2': 'Agenda',
  '3': 'Mi espacio',
};

/// Small everyday preferences, each saved as soon as it changes.
class GeneralSettingsTile extends StatelessWidget {
  final Map<String, String> settings;
  final Future<void> Function(String key, String value) onChanged;
  const GeneralSettingsTile({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.home_outlined, color: KnotesTheme.accent),
        title: const Text('Al abrir la app'),
        subtitle: const Text('La pantalla con la que empiezas'),
        trailing: DropdownButton<String>(
          value: startPages.containsKey(settings['start_page'])
              ? settings['start_page']
              : '0',
          underline: const SizedBox.shrink(),
          items: [
            for (final MapEntry(:key, :value) in startPages.entries)
              DropdownMenuItem(value: key, child: Text(value)),
          ],
          onChanged: (value) => onChanged('start_page', value ?? '0'),
        ),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: Icon(
          Icons.visibility_off_outlined,
          color: KnotesTheme.accent,
        ),
        title: const Text('Modo discreto'),
        subtitle: const Text(
          'Oculta los importes en pantalla; útil si usas la app en público.',
        ),
        value: settings['hide_amounts'] == 'true',
        onChanged: (on) => onChanged('hide_amounts', '$on'),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: Icon(Icons.history_rounded, color: KnotesTheme.accent),
        title: const Text('Copia automática diaria'),
        subtitle: const Text(
          'Guarda una copia local al día y conserva la última semana.',
        ),
        value: settings['auto_backup'] != 'false',
        onChanged: (on) => onChanged('auto_backup', '$on'),
      ),
    ],
  );
}
