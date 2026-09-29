import 'package:flutter/material.dart';

import '../../data/futar/futar_error.dart';

/// Felhasználónak szóló szöveg és ikon egy API-hibához.
({IconData icon, String title, String detail}) describeError(
  FutarError error,
) => switch (error) {
  NetworkError() => (
    icon: Icons.wifi_off,
    title: 'Nincs internetkapcsolat',
    detail: 'Ellenőrizd a hálózatot, és próbáld újra.',
  ),
  HttpError(isUnauthorized: true) => (
    icon: Icons.key_off,
    title: 'Érvénytelen API-kulcs',
    detail:
        'A BKK nem fogadta el a kulcsot. Ellenőrizd az env.json-t, '
        'és indítsd újra az appot.',
  ),
  HttpError(:final status) => (
    icon: Icons.cloud_off,
    title: 'A BKK szervere nem válaszol',
    detail: 'HTTP $status. Próbáld újra később.',
  ),
  ApiError(:final code) => (
    icon: Icons.cloud_off,
    title: 'A BKK hibát jelzett',
    detail: 'Hibakód: $code. Próbáld újra később.',
  ),
  ParseError() => (
    icon: Icons.error_outline,
    title: 'Váratlan válasz',
    detail: 'A BKK válasza nem értelmezhető. Próbáld újra később.',
  ),
};

/// Középre igazított hiba- vagy üres állapot, opcionális gombbal.
class StatusMessage extends StatelessWidget {
  const StatusMessage({
    super.key,
    required this.icon,
    required this.title,
    this.detail,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (detail != null) ...[
            const SizedBox(height: 8),
            Text(
              detail!,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
