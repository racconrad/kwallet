import 'package:flutter/material.dart';

import 'package:knotes/core/services/notification_service.dart';
import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';

class NotificationsSettingsTile extends StatelessWidget {
  final Map<String, String> settings;
  final Future<void> Function(String key, String value) onToggle;

  const NotificationsSettingsTile({
    super.key,
    required this.settings,
    required this.onToggle,
  });

  Future<void> _pickTime(
    BuildContext context,
    String key,
    String defaultVal,
  ) async {
    final raw = settings[key] ?? defaultVal;
    final parts = raw.split(':').map((s) => int.tryParse(s) ?? 0).toList();
    final initial = TimeOfDay(
      hour: parts.isNotEmpty ? parts[0] : 8,
      minute: parts.length > 1 ? parts[1] : 0,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: key == 'day_start_time'
          ? 'Hora de inicio de día (Flow Start)'
          : 'Hora de finalización de día (Cierre)',
    );

    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      await onToggle(key, formatted);
    }
  }

  Future<void> _editMessages(BuildContext context) async {
    final fields = {
      'day_start_message': (
        'Inicio del día',
        NotificationService.defaultDayStartMessage,
      ),
      'day_end_message': (
        'Cierre del día',
        NotificationService.defaultDayEndMessage,
      ),
      'habit_reminder_message': (
        'Recordatorio de hábito',
        NotificationService.defaultHabitMessage,
      ),
    };
    final controllers = {
      for (final key in fields.keys)
        key: TextEditingController(text: settings[key] ?? ''),
    };
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tus mensajes'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Usa {pet} para el nombre de tu compañero y {habit} para el hábito. Vacío usa el mensaje de siempre.',
                style: TextStyle(
                  color: KnotesTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              for (final MapEntry(key: key, value: (label, hint))
                  in fields.entries) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: controllers[key],
                  maxLength: 140,
                  maxLines: 2,
                  minLines: 1,
                  decoration: InputDecoration(labelText: label, hintText: hint),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (saved == true) {
      for (final entry in controllers.entries) {
        await onToggle(entry.key, entry.value.text.trim());
      }
    }
    for (final c in controllers.values) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = settings['notifications_enabled'] == 'true';
    final notifyStart = settings['notify_day_start'] != 'false';
    final notifyEnd = settings['notify_day_end'] != 'false';
    final startTime = settings['day_start_time'] ?? '08:00';
    final endTime = settings['day_end_time'] ?? '21:00';

    final notifyFinances = settings['notify_finances'] != 'false';
    final notifyHabits = settings['notify_habits'] != 'false';
    final notifyPet = settings['notify_pet'] != 'false';

    final petName = settings['pet_name'] ?? 'Mishi';

    Future<void> handleSwitch(bool val) async {
      if (val) {
        final granted =
            await NotificationService.requestNotificationPermission();
        if (granted) {
          await onToggle('notifications_enabled', 'true');
        } else {
          await onToggle('notifications_enabled', 'false');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                content: const Text(
                  'No se pudieron activar las notificaciones. Los permisos están desactivados en tu dispositivo.',
                ),
                action: SnackBarAction(label: 'Entendido', onPressed: () {}),
              ),
            );
          }
        }
      } else {
        await onToggle('notifications_enabled', 'false');
      }
    }

    return LedgerPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: KnotesTheme.accentLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_active_outlined,
                  size: 20,
                  color: KnotesTheme.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notificaciones y Rutinas',
                      style: KnotesTheme.fontTitle.copyWith(fontSize: 16),
                    ),
                    Text(
                      enabled
                          ? 'Alertas de inicio de día y rutinas activas'
                          : 'Desactivadas por completo',
                      style: TextStyle(
                        fontSize: 12,
                        color: KnotesTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                activeThumbColor: KnotesTheme.accent,
                onChanged: handleSwitch,
              ),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 12),
            Divider(color: KnotesTheme.border.withValues(alpha: 0.3)),

            // 1. Inicio de día (Flow Start)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Checkbox(
                    value: notifyStart,
                    activeColor: KnotesTheme.accent,
                    onChanged: (val) =>
                        onToggle('notify_day_start', (val ?? true).toString()),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Inicio de día (Flow Start)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Motivación para registrar y arrancar tu día',
                          style: TextStyle(
                            fontSize: 12,
                            color: KnotesTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: notifyStart
                        ? () => _pickTime(context, 'day_start_time', '08:00')
                        : null,
                    icon: const Icon(Icons.schedule_rounded, size: 16),
                    label: Text(startTime),
                  ),
                ],
              ),
            ),

            // 2. Finalización de día (Cierre nocturno)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Checkbox(
                    value: notifyEnd,
                    activeColor: KnotesTheme.accent,
                    onChanged: (val) =>
                        onToggle('notify_day_end', (val ?? true).toString()),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Finalización de día (Cierre)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Recordatorio para cerrar gastos y hábitos antes de dormir',
                          style: TextStyle(
                            fontSize: 12,
                            color: KnotesTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: notifyEnd
                        ? () => _pickTime(context, 'day_end_time', '21:00')
                        : null,
                    icon: const Icon(Icons.nightlight_round, size: 16),
                    label: Text(endTime),
                  ),
                ],
              ),
            ),

            Divider(color: KnotesTheme.border.withValues(alpha: 0.3)),

            // Otras categorías
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Pagos y fechas de la agenda'),
              subtitle: const Text(
                'A tu hora de inicio del día, antes de que venzan',
              ),
              value: notifyFinances,
              activeColor: KnotesTheme.accent,
              onChanged: (val) =>
                  onToggle('notify_finances', (val ?? true).toString()),
            ),
            if (notifyFinances)
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: DropdownButton<String>(
                  value:
                      const [
                        '0',
                        '1',
                        '3',
                        '7',
                      ].contains(settings['plan_reminder_days'])
                      ? settings['plan_reminder_days']
                      : '1',
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: '0', child: Text('El mismo día')),
                    DropdownMenuItem(value: '1', child: Text('1 día antes')),
                    DropdownMenuItem(value: '3', child: Text('3 días antes')),
                    DropdownMenuItem(value: '7', child: Text('1 semana antes')),
                  ],
                  onChanged: (v) => onToggle('plan_reminder_days', v ?? '1'),
                ),
              ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Hábitos diarios'),
              subtitle: const Text(
                'A la hora que elijas en cada hábito y meta; no avisa si ya lo marcaste.',
              ),
              value: notifyHabits,
              activeColor: KnotesTheme.accent,
              onChanged: (val) =>
                  onToggle('notify_habits', (val ?? true).toString()),
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Mascota y compañero'),
              subtitle: const Text('Alertas de cariño y estado de ánimo'),
              value: notifyPet,
              activeColor: KnotesTheme.accent,
              onChanged: (val) =>
                  onToggle('notify_pet', (val ?? true).toString()),
            ),

            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _editMessages(context),
                  icon: const Icon(Icons.edit_notifications_outlined, size: 16),
                  label: const Text('Personalizar mensajes'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    NotificationService.showDayStartNotification(
                      petName: petName,
                      settings: settings,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notificación de inicio de día enviada'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.wb_sunny_rounded, size: 16),
                  label: const Text('Probar inicio'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    NotificationService.showDayEndNotification(
                      petName: petName,
                      settings: settings,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notificación de fin de día enviada'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.nights_stay_rounded, size: 16),
                  label: const Text('Probar fin de día'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
