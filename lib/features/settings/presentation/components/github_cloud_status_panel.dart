import 'package:flutter/material.dart';

import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';

class GitHubCloudStatusPanel extends StatelessWidget {
  final bool connected;
  final String username;
  final String gistId;
  final String lastSync;
  final bool isBusy;
  final TextEditingController tokenController;
  final ValueChanged<String> onOpenGitHub;
  final VoidCallback onSync;
  final VoidCallback onRestore;
  final VoidCallback onDisconnect;
  final VoidCallback onConnect;

  const GitHubCloudStatusPanel({
    super.key,
    required this.connected,
    required this.username,
    required this.gistId,
    required this.lastSync,
    required this.isBusy,
    required this.tokenController,
    required this.onOpenGitHub,
    required this.onSync,
    required this.onRestore,
    required this.onDisconnect,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return LedgerPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: connected
                      ? KnotesTheme.incomeGreen.withValues(alpha: 0.15)
                      : KnotesTheme.surfaceContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  connected
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  color: connected
                      ? KnotesTheme.incomeGreen
                      : KnotesTheme.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connected ? 'Conectado a GitHub' : 'No conectado',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      connected ? '@$username' : 'Sin cuenta vinculada',
                      style: TextStyle(
                        color: KnotesTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (connected)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: KnotesTheme.incomeGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(KnotesTheme.radiusSm),
                  ),
                  child: Text(
                    'Activo',
                    style: TextStyle(
                      color: KnotesTheme.incomeGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: KnotesTheme.border.withValues(alpha: 0.3)),
          const SizedBox(height: 10),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.history_rounded, size: 18, color: KnotesTheme.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estado del último cambio:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lastSync.isNotEmpty
                          ? 'Última sincronización: $lastSync'
                          : (connected
                                ? 'Aún no se ha realizado la primera sincronización.'
                                : 'Conecta tu token para sincronizar.'),
                      style: TextStyle(
                        color: KnotesTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (gistId.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.tag_rounded, size: 18, color: KnotesTheme.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Gist Secreto: ${gistId.substring(0, gistId.length > 12 ? 12 : gistId.length)}…',
                    style: TextStyle(
                      color: KnotesTheme.textSecondary,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      onOpenGitHub('https://gist.github.com/$gistId'),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('Ver Gist', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),

          if (connected) ...[
            FilledButton.icon(
              onPressed: isBusy ? null : onSync,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text(isBusy ? 'Sincronizando…' : 'Sincronizar ahora'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: isBusy ? null : onRestore,
              icon: const Icon(Icons.cloud_download_outlined),
              label: const Text('Restaurar desde GitHub'),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => onOpenGitHub('https://github.com/$username'),
                  icon: const Icon(Icons.person_outline_rounded, size: 16),
                  label: Text('Ver perfil @$username'),
                ),
                TextButton.icon(
                  onPressed: isBusy ? null : onDisconnect,
                  icon: const Icon(Icons.link_off_rounded, size: 16),
                  label: const Text('Desconectar'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          ] else ...[
            TextField(
              controller: tokenController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Personal Access Token de GitHub',
                hintText: 'ghp_xxxxxxxxxxxx',
                prefixIcon: Icon(Icons.key_rounded),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isBusy ? null : onConnect,
              icon: const Icon(Icons.link_rounded),
              label: Text(isBusy ? 'Validando…' : 'Conectar cuenta'),
            ),
          ],
        ],
      ),
    );
  }
}
