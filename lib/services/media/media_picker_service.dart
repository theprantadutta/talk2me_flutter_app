import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Result of media picking operation
class PickedMedia {
  final File file;
  final String fileName;
  final String mimeType;
  final MediaPickType type;

  const PickedMedia({
    required this.file,
    required this.fileName,
    required this.mimeType,
    required this.type,
  });
}

/// Type of media to pick
enum MediaPickType {
  image,
  video,
  document,
}

/// Service for picking media files
class MediaPickerService {
  final ImagePicker _imagePicker = ImagePicker();

  /// Pick an image from gallery or camera
  Future<PickedMedia?> pickImage({
    required ImageSource source,
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  }) async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: source,
        maxWidth: maxWidth?.toDouble(),
        maxHeight: maxHeight?.toDouble(),
        imageQuality: imageQuality ?? 85,
      );

      if (file == null) return null;

      return PickedMedia(
        file: File(file.path),
        fileName: file.name,
        mimeType: file.mimeType ?? 'image/jpeg',
        type: MediaPickType.image,
      );
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  /// Pick a video from gallery or camera
  Future<PickedMedia?> pickVideo({
    required ImageSource source,
    Duration? maxDuration,
  }) async {
    try {
      final XFile? file = await _imagePicker.pickVideo(
        source: source,
        maxDuration: maxDuration,
      );

      if (file == null) return null;

      return PickedMedia(
        file: File(file.path),
        fileName: file.name,
        mimeType: file.mimeType ?? 'video/mp4',
        type: MediaPickType.video,
      );
    } catch (e) {
      debugPrint('Error picking video: $e');
      return null;
    }
  }

  /// Pick multiple images from gallery
  Future<List<PickedMedia>> pickMultipleImages({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
    int? limit,
  }) async {
    try {
      final List<XFile> files = await _imagePicker.pickMultiImage(
        maxWidth: maxWidth?.toDouble(),
        maxHeight: maxHeight?.toDouble(),
        imageQuality: imageQuality ?? 85,
        limit: limit,
      );

      return files.map((file) => PickedMedia(
        file: File(file.path),
        fileName: file.name,
        mimeType: file.mimeType ?? 'image/jpeg',
        type: MediaPickType.image,
      )).toList();
    } catch (e) {
      debugPrint('Error picking multiple images: $e');
      return [];
    }
  }

  /// Pick a document/file
  Future<PickedMedia?> pickDocument({
    List<String>? allowedExtensions,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
      );

      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      if (file.path == null) return null;

      return PickedMedia(
        file: File(file.path!),
        fileName: file.name,
        mimeType: _getMimeType(file.extension ?? ''),
        type: MediaPickType.document,
      );
    } catch (e) {
      debugPrint('Error picking document: $e');
      return null;
    }
  }

  /// Pick multiple documents/files
  Future<List<PickedMedia>> pickMultipleDocuments({
    List<String>? allowedExtensions,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
        allowMultiple: true,
      );

      if (result == null) return [];

      return result.files
          .where((file) => file.path != null)
          .map((file) => PickedMedia(
                file: File(file.path!),
                fileName: file.name,
                mimeType: _getMimeType(file.extension ?? ''),
                type: MediaPickType.document,
              ))
          .toList();
    } catch (e) {
      debugPrint('Error picking multiple documents: $e');
      return [];
    }
  }

  String _getMimeType(String extension) {
    final ext = extension.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/x-rar-compressed';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      default:
        return 'application/octet-stream';
    }
  }
}
