import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/connectivity_service.dart';

class ServerDownScreen extends StatelessWidget {
  const ServerDownScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityService>();
    final theme = Theme.of(context);

    String title;
    String message;
    IconData icon;
    Color iconColor;

    switch (connectivity.status) {
      case ConnectivityStatus.offline:
        title = 'No Internet Connection';
        message =
            'Please check your internet connection and try again.\n\nMake sure WiFi or mobile data is enabled.';
        icon = Icons.wifi_off_rounded;
        iconColor = theme.colorScheme.error;
        break;
      case ConnectivityStatus.serverDown:
        title = 'Server Unavailable';
        message =
            'Our servers are temporarily unavailable. This might be due to maintenance or high traffic.\n\nPlease try again in a few moments.';
        icon = Icons.cloud_off_rounded;
        iconColor = theme.colorScheme.error;
        break;
      case ConnectivityStatus.checking:
        title = 'Checking Connection';
        message = 'Please wait while we verify the connection...';
        icon = Icons.sync_rounded;
        iconColor = theme.colorScheme.primary;
        break;
      case ConnectivityStatus.online:
        title = 'Connected';
        message = 'Connection restored successfully!';
        icon = Icons.cloud_done_rounded;
        iconColor = theme.colorScheme.primary;
        break;
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (connectivity.status == ConnectivityStatus.checking)
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: theme.colorScheme.primary,
                    ),
                  )
                else
                  Icon(icon, size: 80, color: iconColor),
                const SizedBox(height: 32),
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                if (connectivity.status != ConnectivityStatus.checking) ...[
                  FilledButton.icon(
                    onPressed: () => connectivity.forceCheck(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try Again'),
                  ),
                  const SizedBox(height: 12),
                  if (connectivity.lastSuccessfulCheck != null)
                    Text(
                      'Last successful connection: ${_formatLastCheck(connectivity.lastSuccessfulCheck!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      textAlign: TextAlign.center,
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatLastCheck(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds} seconds ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    }
  }
}
