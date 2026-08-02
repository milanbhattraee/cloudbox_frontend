import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/byte_formatter.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/confirm_dialog.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: auth.refreshProfile,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 42,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        user.email.isNotEmpty ? user.email[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      user.fullName?.isNotEmpty == true ? user.fullName! : user.email,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  if (user.fullName?.isNotEmpty == true)
                    Center(
                      child: Text(
                        user.email,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ),
                  const SizedBox(height: 28),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Storage', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: user.usageFraction,
                              minHeight: 8,
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              color: user.usageFraction > 0.9
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${formatBytes(user.storageUsed)} of ${formatBytes(user.storageLimit)} used',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed = await showConfirmDialog(
                        context,
                        title: 'Sign out?',
                        message: 'You can sign back in any time.',
                        confirmLabel: 'Sign out',
                      );
                      if (confirmed) {
                        await context.read<AuthProvider>().signOut();
                        if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                      }
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sign out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
