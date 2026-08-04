import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/document_sync_service.dart';

class SyncSettingsScreen extends StatelessWidget {
  const SyncSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: DocumentSyncService.instance,
      child: const _SyncSettingsContent(),
    );
  }
}

class _SyncSettingsContent extends StatelessWidget {
  const _SyncSettingsContent();

  @override
  Widget build(BuildContext context) {
    final syncService = context.watch<DocumentSyncService>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto-Sync Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Enable/Disable Switch
          Card(
            child: SwitchListTile(
              title: const Text('Automatic Document Sync'),
              subtitle: Text(
                syncService.isEnabled
                    ? 'Documents will be automatically synced to Cloudinary'
                    : 'Turn on to automatically backup your documents',
              ),
              value: syncService.isEnabled,
              onChanged: (value) async {
                if (value) {
                  await syncService.enable();
                } else {
                  syncService.disable();
                }
              },
            ),
          ),

          const SizedBox(height: 24),

          // Sync Status
          if (syncService.isEnabled) ...[
            Text(
              'Sync Status',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusRow(
                      icon: Icons.cloud_upload_rounded,
                      label: 'Status',
                      value: _getStatusText(syncService.status),
                      valueColor: _getStatusColor(syncService.status, theme),
                    ),
                    const Divider(height: 24),
                    _StatusRow(
                      icon: Icons.queue_rounded,
                      label: 'Pending Files',
                      value: '${syncService.queueLength}',
                    ),
                    const Divider(height: 24),
                    _StatusRow(
                      icon: Icons.check_circle_rounded,
                      label: 'Total Synced',
                      value: '${syncService.totalSyncedCount}',
                    ),
                    if (syncService.lastSyncTime != null) ...[
                      const Divider(height: 24),
                      _StatusRow(
                        icon: Icons.access_time_rounded,
                        label: 'Last Sync',
                        value: _formatTime(syncService.lastSyncTime!),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: syncService.status == SyncStatus.syncing
                        ? null
                        : () => syncService.syncNow(),
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text('Sync Now'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: syncService.queueLength == 0
                        ? null
                        : () => _showClearQueueDialog(context, syncService),
                    icon: const Icon(Icons.clear_all_rounded),
                    label: const Text('Clear Queue'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Sync Queue
            if (syncService.queueLength > 0) ...[
              Text(
                'Pending Files (${syncService.queueLength})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...syncService.syncQueue.map((item) => Card(
                    child: ListTile(
                      leading: item.isSyncing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.insert_drive_file_rounded),
                      title: Text(item.fileName),
                      subtitle: Text(
                        item.error ?? _formatBytes(item.fileSize),
                        style: TextStyle(
                          color: item.error != null
                              ? theme.colorScheme.error
                              : null,
                        ),
                      ),
                      trailing: item.error != null
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => syncService.removeFromQueue(item),
                            )
                          : null,
                    ),
                  )),
            ],

            const SizedBox(height: 24),

            // Info Card
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'How Auto-Sync Works',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• Scans your device documents every 5 minutes\n'
                      '• Automatically uploads PDF, DOC, TXT, and other documents\n'
                      '• Only syncs when connected to the internet\n'
                      '• Files larger than 100MB are skipped\n'
                      '• Each file is uploaded only once',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getStatusText(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return 'Idle';
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.completed:
        return 'Completed';
      case SyncStatus.failed:
        return 'Failed';
    }
  }

  Color _getStatusColor(SyncStatus status, ThemeData theme) {
    switch (status) {
      case SyncStatus.idle:
        return theme.colorScheme.onSurface;
      case SyncStatus.syncing:
        return theme.colorScheme.primary;
      case SyncStatus.completed:
        return Colors.green;
      case SyncStatus.failed:
        return theme.colorScheme.error;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _showClearQueueDialog(
    BuildContext context,
    DocumentSyncService syncService,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Sync Queue?'),
        content: const Text(
          'This will remove all pending files from the sync queue. '
          'They will not be automatically synced.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      syncService.clearQueue();
    }
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
