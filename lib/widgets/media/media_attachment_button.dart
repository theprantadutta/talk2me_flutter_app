import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../services/media/media_picker_service.dart';
import '../glass/glass_card.dart';

/// Callback for when media is selected
typedef OnMediaSelected = void Function(PickedMedia media);

/// A button that shows media attachment options
class MediaAttachmentButton extends StatelessWidget {
  final OnMediaSelected onMediaSelected;
  final VoidCallback? onVoiceRecordStart;
  final bool isRecording;

  const MediaAttachmentButton({
    super.key,
    required this.onMediaSelected,
    this.onVoiceRecordStart,
    this.isRecording = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _showAttachmentOptions(context),
      icon: Icon(
        isRecording ? Icons.close_rounded : Icons.add_rounded,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _showAttachmentOptions(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final picker = MediaPickerService();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: AppRadius.bottomSheetRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                borderRadius: AppRadius.bottomSheetRadius,
                color: isDark
                    ? Colors.black.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.9),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Share Media',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Attachment options grid
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _AttachmentOption(
                        icon: Icons.photo_library_rounded,
                        label: 'Gallery',
                        color: Colors.purple,
                        onTap: () async {
                          Navigator.pop(context);
                          final media = await picker.pickImage(
                            source: ImageSource.gallery,
                          );
                          if (media != null) onMediaSelected(media);
                        },
                      ),
                      _AttachmentOption(
                        icon: Icons.camera_alt_rounded,
                        label: 'Camera',
                        color: Colors.blue,
                        onTap: () async {
                          Navigator.pop(context);
                          final media = await picker.pickImage(
                            source: ImageSource.camera,
                          );
                          if (media != null) onMediaSelected(media);
                        },
                      ),
                      _AttachmentOption(
                        icon: Icons.videocam_rounded,
                        label: 'Video',
                        color: Colors.red,
                        onTap: () async {
                          Navigator.pop(context);
                          final media = await picker.pickVideo(
                            source: ImageSource.gallery,
                          );
                          if (media != null) onMediaSelected(media);
                        },
                      ),
                      _AttachmentOption(
                        icon: Icons.insert_drive_file_rounded,
                        label: 'Document',
                        color: Colors.orange,
                        onTap: () async {
                          Navigator.pop(context);
                          final media = await picker.pickDocument();
                          if (media != null) onMediaSelected(media);
                        },
                      ),
                    ],
                  ),
                  if (onVoiceRecordStart != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    GlassCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      onTap: () {
                        Navigator.pop(context);
                        onVoiceRecordStart!();
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.mic_rounded,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Text(
                            'Voice Message',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(
                    height: MediaQuery.of(context).padding.bottom + AppSpacing.md,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
