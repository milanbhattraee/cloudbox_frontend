import 'package:flutter/material.dart';

import '../../../core/utils/byte_formatter.dart';
import '../../../models/app_user.dart';

class StorageUsageBar extends StatelessWidget {
  final AppUser user;
  const StorageUsageBar({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = user.usageFraction;
    final isNearLimit = fraction > 0.9;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${formatBytes(user.storageUsed)} of ${formatBytes(user.storageLimit)} used',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
              Text(
                '${(fraction * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isNearLimit ? theme.colorScheme.error : theme.colorScheme.outline,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: isNearLimit ? theme.colorScheme.error : theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
