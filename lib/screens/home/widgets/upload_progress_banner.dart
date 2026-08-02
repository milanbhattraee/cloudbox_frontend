import 'package:flutter/material.dart';

import '../../../providers/upload_provider.dart';

class UploadProgressBanner extends StatelessWidget {
  final UploadProvider uploadProvider;

  const UploadProgressBanner({super.key, required this.uploadProvider});

  @override
  Widget build(BuildContext context) {
    if (uploadProvider.status == UploadStatus.idle) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isError = uploadProvider.status == UploadStatus.error;
    final isSuccess = uploadProvider.status == UploadStatus.success;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : isSuccess
                    ? Icons.check_circle_outline_rounded
                    : Icons.cloud_upload_outlined,
            color: isError ? theme.colorScheme.error : theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isError
                      ? (uploadProvider.errorMessage ?? 'Upload failed')
                      : isSuccess
                          ? 'Uploaded ${uploadProvider.currentBatchLabel ?? ''}'
                          : 'Uploading ${uploadProvider.currentBatchLabel ?? ''}...',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (uploadProvider.status == UploadStatus.uploading) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: uploadProvider.progress, minHeight: 4),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
