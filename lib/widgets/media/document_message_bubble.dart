import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/chat_message.dart';

/// Widget for displaying document messages in chat
class DocumentMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final double maxWidth;
  final VoidCallback? onDownload;

  const DocumentMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.maxWidth = 250,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = message.media;
    if (media == null) return const SizedBox.shrink();

    final iconData = _getFileIcon(media.mimeType);
    final iconColor = _getFileColor(media.mimeType);

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: AppRadius.lg,
        color: isMe
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // File type icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: AppRadius.md,
            ),
            child: Icon(
              iconData,
              color: iconColor,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // File info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  media.fileName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Row(
                  children: [
                    Text(
                      media.formattedSize,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '•',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      _getFileExtension(media.fileName).toUpperCase(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: iconColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Download button
          IconButton(
            onPressed: onDownload ?? () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Download coming soon')),
              );
            },
            icon: Icon(
              Icons.download_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String mimeType) {
    if (mimeType.startsWith('application/pdf')) {
      return Icons.picture_as_pdf_rounded;
    } else if (mimeType.contains('word') || mimeType.contains('document')) {
      return Icons.description_rounded;
    } else if (mimeType.contains('excel') || mimeType.contains('spreadsheet')) {
      return Icons.table_chart_rounded;
    } else if (mimeType.contains('powerpoint') || mimeType.contains('presentation')) {
      return Icons.slideshow_rounded;
    } else if (mimeType.startsWith('text/')) {
      return Icons.article_rounded;
    } else if (mimeType.contains('zip') || mimeType.contains('archive') || mimeType.contains('compressed')) {
      return Icons.folder_zip_rounded;
    } else {
      return Icons.insert_drive_file_rounded;
    }
  }

  Color _getFileColor(String mimeType) {
    if (mimeType.startsWith('application/pdf')) {
      return Colors.red;
    } else if (mimeType.contains('word') || mimeType.contains('document')) {
      return Colors.blue;
    } else if (mimeType.contains('excel') || mimeType.contains('spreadsheet')) {
      return Colors.green;
    } else if (mimeType.contains('powerpoint') || mimeType.contains('presentation')) {
      return Colors.orange;
    } else if (mimeType.startsWith('text/')) {
      return Colors.grey;
    } else if (mimeType.contains('zip') || mimeType.contains('archive')) {
      return Colors.amber;
    } else {
      return Colors.blueGrey;
    }
  }

  String _getFileExtension(String fileName) {
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.last : 'file';
  }
}
