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
    final isUploading = uploadProvider.status == UploadStatus.uploading;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError 
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
            : isSuccess
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                : theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError
              ? theme.colorScheme.error
              : theme.colorScheme.primary,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                child: Text(
                  isError
                      ? (uploadProvider.errorMessage ?? 'Upload failed')
                      : isSuccess
                          ? 'Upload complete!'
                          : 'Uploading ${uploadProvider.currentBatchLabel ?? ''}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isError 
                        ? theme.colorScheme.error 
                        : theme.colorScheme.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isUploading)
                Text(
                  '${(uploadProvider.progress * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
          if (isUploading) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: uploadProvider.progress,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
