import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/chat_message.dart';

/// Widget for displaying video messages in chat
class VideoMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final double maxWidth;

  const VideoMessageBubble({
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
      onTap: () => _openVideoPlayer(context),
      child: ClipRRect(
        borderRadius: AppRadius.lg,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Thumbnail or placeholder
              if (media.thumbnailUrl != null)
                CachedNetworkImage(
                  imageUrl: media.thumbnailUrl!,
                  fit: BoxFit.cover,
                  height: 180,
                  width: maxWidth,
                  placeholder: (context, url) => _buildPlaceholder(),
                  errorWidget: (context, url, error) => _buildVideoPlaceholder(theme),
                )
              else
                _buildVideoPlaceholder(theme),

              // Play button overlay
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),

              // Duration badge
              if (media.duration != null)
                Positioned(
                  right: AppSpacing.sm,
                  bottom: AppSpacing.sm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      media.formattedDuration,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
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
    );
  }

  Widget _buildPlaceholder() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: maxWidth,
        height: 180,
        color: Colors.grey[300],
      ),
    );
  }

  Widget _buildVideoPlaceholder(ThemeData theme) {
    return Container(
      width: maxWidth,
      height: 180,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.videocam_rounded,
        size: 48,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }

  void _openVideoPlayer(BuildContext context) {
    final media = message.media;
    if (media == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenVideoPlayer(
          videoUrl: media.url,
          fileName: media.fileName,
        ),
      ),
    );
  }
}

/// Full screen video player
class _FullScreenVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String fileName;

  const _FullScreenVideoPlayer({
    required this.videoUrl,
    required this.fileName,
  });

  @override
  State<_FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<_FullScreenVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    try {
      await _controller.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _controller.play();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading video: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _showControls
          ? AppBar(
              backgroundColor: Colors.black.withValues(alpha: 0.5),
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Text(
                widget.fileName,
                style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
              ),
            )
          : null,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video
            if (_isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // Controls overlay
            if (_showControls && _isInitialized)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Progress bar
                      ValueListenableBuilder(
                        valueListenable: _controller,
                        builder: (context, value, child) {
                          final position = value.position;
                          final duration = value.duration;
                          return Column(
                            children: [
                              Slider(
                                value: position.inMilliseconds.toDouble(),
                                min: 0,
                                max: duration.inMilliseconds.toDouble(),
                                onChanged: (value) {
                                  _controller.seekTo(
                                    Duration(milliseconds: value.toInt()),
                                  );
                                },
                                activeColor: Colors.white,
                                inactiveColor: Colors.white.withValues(alpha: 0.3),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(position),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      _formatDuration(duration),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      // Play/Pause button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () {
                              final position = _controller.value.position;
                              _controller.seekTo(
                                position - const Duration(seconds: 10),
                              );
                            },
                            icon: const Icon(
                              Icons.replay_10_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          ValueListenableBuilder(
                            valueListenable: _controller,
                            builder: (context, value, child) {
                              return IconButton(
                                onPressed: () {
                                  if (value.isPlaying) {
                                    _controller.pause();
                                  } else {
                                    _controller.play();
                                  }
                                },
                                icon: Icon(
                                  value.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 48,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          IconButton(
                            onPressed: () {
                              final position = _controller.value.position;
                              _controller.seekTo(
                                position + const Duration(seconds: 10),
                              );
                            },
                            icon: const Icon(
                              Icons.forward_10_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
