part of 'settings_screen.dart';

/// Export, restore, GitHub and recovery-copy flows of the settings screen.
extension _BackupActions on _SettingsScreenState {
  Future<void> _export() async {
    if (await model.export() && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Respaldo guardado')));
    }
  }

  Future<void> _restore({String? recovery}) async {
    final summary = await model.prepareRestore(recovery: recovery);
    if (summary == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar respaldo'),
        content: Text(
          '${summary.accounts} cuentas · ${summary.movements} movimientos\n${summary.notes} notas · ${summary.habits} hábitos\n\nReemplazará los datos actuales. Antes se guardará una copia local de recuperación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      model.discardRestore();
      return;
    }
    if (await model.restore() && mounted) {
      _update(_syncFields);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listo, recuperamos tus datos.')),
      );
    }
  }

  Future<void> _connectGitHubDialog() async {
    final tokenController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conectar con GitHub'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ingresa tu Personal Access Token con permiso "gist". Tus respaldos se guardarán en un Gist secreto y privado.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: tokenController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'GitHub Token (ghp_...)',
                hintText: 'ghp_xxxxxxxxxxxx',
                prefixIcon: Icon(Icons.key_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Conectar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final ok = await model.connectGitHub(tokenController.text);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conectado a GitHub como @${model.githubUsername}'),
          ),
        );
      }
    }
    tokenController.dispose();
  }

  Future<void> _disconnectGitHub() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desconectar GitHub'),
        content: const Text(
          '¿Deseas desvincular tu cuenta de GitHub de este dispositivo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desconectar'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await model.disconnectGitHub();
    }
  }

  Future<void> _syncToGitHub() async {
    final ok = await model.syncToGitHub();
    if (ok && mounted) {
      final iconColor = KnotesTheme.surface;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.cloud_done_rounded, color: iconColor, size: 20),
              const SizedBox(width: 10),
              const Text('Respaldo sincronizado en GitHub'),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _restoreFromGitHub() async {
    final summary = await model.prepareGitHubRestore();
    if (summary == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar desde GitHub'),
        content: Text(
          '${summary.accounts} cuentas · ${summary.movements} movimientos\n${summary.notes} notas · ${summary.habits} hábitos\n\nReemplazará los datos actuales con la copia de GitHub. Antes se guardará una copia local de recuperación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      model.discardRestore();
      return;
    }
    if (await model.restore() && mounted) {
      _update(_syncFields);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Listo, datos restaurados desde GitHub.'),
        ),
      );
    }
  }

  Future<void> _recoveries() async {
    if (!await model.loadRecoveries() || !mounted) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Copias de recuperación'),
        children: [
          if (model.recoveries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Aún no hay copias de recuperación.'),
            ),
          for (final copy in model.recoveries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, copy.id),
              child: ListTile(
                leading: const Icon(Icons.history),
                title: Text(
                  copy.automatic
                      ? 'Copia automática diaria'
                      : copy.beforeUpdate
                      ? 'Antes de actualizar'
                      : 'Antes de restaurar',
                ),
                subtitle: Text(copy.createdAt.toString().substring(0, 19)),
              ),
            ),
        ],
      ),
    );
    if (selected != null && mounted) await _restore(recovery: selected);
  }
}
