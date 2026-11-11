import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/kitty_companion.dart';

class DatabaseErrorView extends StatelessWidget {
  final Map<String, String> settings;
  final String? errorMessage;
  final bool hasRecovery;
  final VoidCallback? onRestoreRecovery;
  final VoidCallback? onRepairDatabase;
  final VoidCallback? onImportBackup;
  final String? diagnosticInfo;

  const DatabaseErrorView({
    super.key,
    this.settings = const {},
    this.errorMessage,
    this.hasRecovery = false,
    this.onRestoreRecovery,
    this.onRepairDatabase,
    this.onImportBackup,
    this.diagnosticInfo,
  });

  void _showDiagnostics(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Detalle técnico del error'),
        content: SingleChildScrollView(
          child: SelectableText(
            diagnosticInfo ?? 'No hay información adicional disponible.',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          if (diagnosticInfo != null)
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: diagnosticInfo!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copiado al portapapeles')),
                );
                Navigator.of(ctx).pop();
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copiar'),
            ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _confirmRestore(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar copia previa'),
        content: const Text(
          'Se creará un respaldo del archivo actual (.corrupted) y se importarán tus datos desde la copia automática previa a la migración.\n\n¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onRestoreRecovery?.call();
            },
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
  }

  void _confirmNewVault(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Crear nueva bóveda limpia'),
        content: const Text(
          'Se guardará tu archivo actual como copia segura (.corrupted) y se iniciará una nueva bóveda limpia para empezar de cero.\n\n¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onRepairDatabase?.call();
            },
            child: const Text('Crear nueva bóveda'),
          ),
        ],
      ),
    );
  }

  (String title, String description, IconData icon) _resolveErrorDetails() {
    final msg = (errorMessage ?? '').toLowerCase();
    final diag = (diagnosticInfo ?? '').toLowerCase();
    final combined = '$msg $diag';

    if (combined.contains('no es compatible') ||
        combined.contains('incompatible') ||
        combined.contains('version')) {
      return (
        'Versión no compatible',
        errorMessage ?? 'Esta bóveda o copia requiere una versión más reciente de knotes para abrirse sin riesgo. Actualiza knotes o crea una nueva bóveda para empezar.',
        Icons.auto_mode_rounded,
      );
    } else if (combined.contains('corrupt') ||
        combined.contains('malformed') ||
        combined.contains('disk') ||
        combined.contains('lock') ||
        combined.contains('databaseexception') ||
        combined.contains('lectura') ||
        combined.contains('problemas de lectura')) {
      return (
        'Problema al leer tu bóveda',
        errorMessage ?? 'No se pudo leer el archivo local de tu bóveda en este dispositivo. Puedes crear una nueva bóveda limpia o restaurar una copia previa.',
        Icons.folder_off_outlined,
      );
    } else {
      return (
        'No se pudieron cargar tus datos',
        errorMessage ?? 'Ocurrió un contratiempo al abrir tu información local. Puedes crear una nueva bóveda limpia o importar una copia previa.',
        Icons.warning_amber_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (errTitle, errDesc, errIcon) = _resolveErrorDetails();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'knotes',
                    style: KnotesTheme.fontTitle.copyWith(
                      fontSize: 30,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 140,
                    height: 130,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          bottom: 2,
                          child: Container(
                            width: 86,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.rectangle,
                              borderRadius: const BorderRadius.all(
                                Radius.elliptical(86, 18),
                              ),
                              gradient: RadialGradient(
                                colors: [
                                  theme.colorScheme.error.withValues(
                                    alpha: 0.22,
                                  ),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          child: KittyCompanionWidget(
                            settings: settings,
                            size: 104,
                            activity: PetActivity.sleep,
                          ),
                        ),
                        Positioned(
                          right: 12,
                          top: 4,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.error,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.sentiment_dissatisfied_rounded,
                              size: 22,
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    errTitle,
                    style: KnotesTheme.fontTitle.copyWith(fontSize: 19),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withValues(
                        alpha: 0.35,
                      ),
                      borderRadius: BorderRadius.circular(KnotesTheme.radiusSm),
                      border: Border.all(
                        color: theme.colorScheme.error.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(errIcon, color: theme.colorScheme.error, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            errDesc,
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (onRepairDatabase != null)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _confirmNewVault(context),
                        icon: const Icon(Icons.shield_outlined),
                        label: const Text('Crear nueva bóveda'),
                      ),
                    ),
                  if (onImportBackup != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onImportBackup,
                        icon: const Icon(Icons.file_open_outlined),
                        label: const Text('Importar otra copia'),
                      ),
                    ),
                  ],
                  if (hasRecovery && onRestoreRecovery != null) ...[
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () => _confirmRestore(context),
                      icon: const Icon(Icons.settings_backup_restore_rounded),
                      label: const Text('Restaurar copia local previa'),
                    ),
                  ],
                  if (diagnosticInfo != null && diagnosticInfo!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => _showDiagnostics(context),
                      child: const Text('Ver detalle técnico'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
