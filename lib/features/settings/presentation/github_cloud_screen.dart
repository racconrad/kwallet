import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/services/notification_service.dart';
import 'package:knotes/features/settings/view_models/settings_view_model.dart';
import 'package:knotes/features/settings/presentation/components/github_cloud_status_panel.dart';
import 'package:knotes/features/settings/presentation/components/github_cloud_header.dart';
import 'package:knotes/features/settings/presentation/components/github_cloud_information.dart';

class GitHubCloudScreen extends StatefulWidget {
  final SettingsViewModel model;

  const GitHubCloudScreen({super.key, required this.model});

  @override
  State<GitHubCloudScreen> createState() => _GitHubCloudScreenState();
}

class _GitHubCloudScreenState extends State<GitHubCloudScreen> {
  final _tokenController = TextEditingController();

  SettingsViewModel get model => widget.model;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa tu Personal Access Token.')),
      );
      return;
    }

    final ok = await model.connectGitHub(token);
    if (!mounted) return;
    if (ok) {
      _tokenController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            '¡Conectado exitosamente como @${model.githubUsername}!',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(model.error ?? 'Error al validar el token de GitHub.'),
        ),
      );
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desconectar GitHub'),
        content: const Text(
          '¿Deseas desvincular tu cuenta de GitHub de este dispositivo?\n\nTus copias existentes en tu Gist no se borrarán.',
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

    if (confirmed == true && mounted) {
      await model.disconnectGitHub();
    }
  }

  Future<void> _sync() async {
    final ok = await model.syncToGitHub();
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: KnotesTheme.surface,
                size: 20,
              ),
              SizedBox(width: 10),
              Text('Respaldo sincronizado exitosamente en GitHub'),
            ],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(model.error ?? 'Error al sincronizar.'),
        ),
      );
    }
  }

  Future<void> _restore() async {
    final summary = await model.prepareGitHubRestore();
    if (!mounted) return;
    if (summary == null) {
      if (model.error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(model.error!)));
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar desde GitHub'),
        content: Text(
          'Contenido de la copia en GitHub:\n'
          '• ${summary.accounts} cuentas\n'
          '• ${summary.movements} movimientos\n'
          '• ${summary.notes} notas\n'
          '• ${summary.habits} hábitos\n\n'
          'Se creará una copia local de seguridad antes de sustituir los datos.\n\n'
          '¿Deseas continuar?',
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Listo, tus datos han sido restaurados desde GitHub.'),
        ),
      );
    }
  }

  Future<void> _openGitHub(String url) async {
    final opened = await NotificationService.openUrl(url);
    if (!opened) {
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Enlace copiado al portapapeles: $url'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final connected = model.isGitHubConnected;
        final username = model.githubUsername;
        final gistId = model.githubGistId;
        final lastSync = model.githubLastSync;
        final isBusy = model.githubBusy;

        return Scaffold(
          appBar: AppBar(title: const Text('Nube Personal (GitHub)')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GitHubCloudHeader(
                  settings: model.settings,
                  connected: connected,
                  isBusy: isBusy,
                ),
                const SizedBox(height: 20),

                GitHubCloudStatusPanel(
                  connected: connected,
                  username: username,
                  gistId: gistId,
                  lastSync: lastSync,
                  isBusy: isBusy,
                  tokenController: _tokenController,
                  onOpenGitHub: _openGitHub,
                  onSync: _sync,
                  onRestore: _restore,
                  onDisconnect: _disconnect,
                  onConnect: _connect,
                ),
                const SizedBox(height: 20),

                GitHubCloudInformation(
                  showTokenGuide: !connected,
                  onOpenGitHub: _openGitHub,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
