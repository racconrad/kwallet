import 'package:flutter/material.dart';

import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';

class GitHubCloudInformation extends StatelessWidget {
  final bool showTokenGuide;
  final ValueChanged<String> onOpenGitHub;

  const GitHubCloudInformation({
    super.key,
    required this.showTokenGuide,
    required this.onOpenGitHub,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '¿Cómo funciona tu Nube Personal?',
          style: KnotesTheme.fontTitle.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 12),
        const _FeatureCard(
          icon: Icons.shield_outlined,
          title: '100% Privado y sin intermediarios',
          description: 'Tus finanzas no pasan por ningún servidor de knotes ni de terceros. La comunicación es directa entre tu teléfono y la API oficial de GitHub.',
        ),
        const SizedBox(height: 10),
        const _FeatureCard(
          icon: Icons.lock_outline_rounded,
          title: 'Secret Gist personal',
          description: 'Tus copias se guardan en un Gist secreto exclusivo de tu cuenta de GitHub. Solo quien tenga tu token o el enlace exacto puede acceder.',
        ),
        const SizedBox(height: 10),
        const _FeatureCard(
          icon: Icons.history_edu_rounded,
          title: 'Historial de revisiones (Commits)',
          description: 'Cada sincronización crea un punto de restauración en el historial de versiones de GitHub, garantizando que nunca pierdas datos.',
        ),
        const SizedBox(height: 10),
        const _FeatureCard(
          icon: Icons.vpn_key_outlined,
          title: 'Token resguardado en Keystore',
          description: 'Tu Personal Access Token se almacena en el almacén de credenciales cifrado nativo de tu dispositivo.',
        ),
        if (showTokenGuide) ...[
          const SizedBox(height: 24),
          LedgerPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.help_outline_rounded, color: KnotesTheme.accent),
                    const SizedBox(width: 8),
                    const Text(
                      '¿Cómo obtener tu Token?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  '1. Inicia sesión en github.com en tu navegador.\n'
                  '2. Ve a Settings → Developer Settings → Personal access tokens → Tokens (classic).\n'
                  '3. Haz clic en "Generate new token (classic)".\n'
                  '4. Asigna un nombre (ej. "knotes-backup") y marca ÚNICAMENTE el permiso "gist".\n'
                  '5. Copia el token que empieza por ghp_ y pégalo arriba.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      onOpenGitHub('https://github.com/settings/tokens'),
                  icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                  label: const Text('Abrir GitHub Tokens'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: KnotesTheme.surfaceContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: KnotesTheme.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: KnotesTheme.accent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      color: KnotesTheme.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
