import 'package:flutter/material.dart';

import 'package:knotes/core/theme/knotes_theme.dart';

/// Optional GitHub Gist backup: connect, sync, restore or manage.
class CloudBackupSection extends StatelessWidget {
  final bool connected;
  final bool busy;
  final String username;
  final String lastSync;
  final VoidCallback onManage;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onSync;
  final VoidCallback onRestore;
  const CloudBackupSection({
    super.key,
    required this.connected,
    required this.busy,
    required this.username,
    required this.lastSync,
    required this.onManage,
    required this.onConnect,
    required this.onDisconnect,
    required this.onSync,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Icon(Icons.cloud_sync_outlined, color: KnotesTheme.accent),
          const SizedBox(width: 8),
          Text(
            'Copia en la nube (GitHub)',
            style: KnotesTheme.fontTitle.copyWith(fontSize: 18),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        'Guarda tus datos de forma privada en un Gist secreto de tu cuenta de GitHub con control de versiones.',
        style: TextStyle(color: KnotesTheme.textSecondary, fontSize: 13),
      ),
      const SizedBox(height: 14),
      FilledButton.tonalIcon(
        onPressed: onManage,
        icon: const Icon(Icons.cloud_sync_rounded),
        label: const Text('Gestionar Nube Personal'),
      ),
      const SizedBox(height: 10),
      if (!connected) ...[
        OutlinedButton.icon(
          onPressed: busy ? null : onConnect,
          icon: const Icon(Icons.link_rounded),
          label: const Text('Conectar cuenta de GitHub'),
        ),
      ] else ...[
        Card(
          elevation: 0,
          color: KnotesTheme.surfaceContainer.withValues(alpha: 0.6),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: KnotesTheme.incomeGreen.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: KnotesTheme.incomeGreen,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '@$username',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            lastSync.isNotEmpty
                                ? 'Última copia: $lastSync'
                                : 'Sin copias en la nube aún',
                            style: TextStyle(
                              color: KnotesTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Desconectar GitHub',
                      icon: const Icon(Icons.link_off_rounded),
                      onPressed: busy ? null : onDisconnect,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: busy ? null : onSync,
                      icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                      label: const Text('Sincronizar ahora'),
                    ),
                    OutlinedButton.icon(
                      onPressed: busy ? null : onRestore,
                      icon: const Icon(Icons.cloud_download_outlined, size: 18),
                      label: const Text('Restaurar desde GitHub'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ],
  );
}
