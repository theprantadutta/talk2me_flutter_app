import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/chat_message.dart';

/// Widget for displaying image messages in chat
class ImageMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final double maxWidth;

  const ImageMessageBubble({
    super.key,
    required this.message,
    this.maxWidth = 250,
  });

  @override
  Widget build(BuildContext context) {
    final media = message.media;
    if (media == null) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => _openFullScreen(context),
      child: Hero(
        tag: 'image_${message.id}',
        child: ClipRRect(
          borderRadius: AppRadius.lg,
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: media.url,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _buildPlaceholder(context),
                  errorWidget: (context, url, error) => _buildError(context),
                ),
                // Caption overlay if there's a message
                if (message.message.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Text(
                        message.message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: maxWidth,
        height: 200,
        color: Colors.grey[300],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: maxWidth,
      height: 150,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.lg,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Failed to load image',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    final media = message.media;
    if (media == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenImageViewer(
          imageUrl: media.url,
          heroTag: 'image_${message.id}',
          fileName: media.fileName,
        ),
      ),
    );
  }
}

/// Full screen image viewer with zoom
class _FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String heroTag;
  final String fileName;

  const _FullScreenImageViewer({
    required this.imageUrl,
    required this.heroTag,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          fileName,
          style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: () {
              // TODO: Implement download
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Download coming soon')),
              );
            },
          ),
        ],
      ),
      body: Hero(
        tag: heroTag,
        child: PhotoView(
          imageProvider: CachedNetworkImageProvider(imageUrl),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3,
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          loadingBuilder: (context, event) {
            return Center(
              child: CircularProgressIndicator(
                value: event != null && event.expectedTotalBytes != null
                    ? event.cumulativeBytesLoaded / event.expectedTotalBytes!
                    : null,
                color: Colors.white,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 48,
              ),
            );
          },
        ),
      ),
    );
  }
}
