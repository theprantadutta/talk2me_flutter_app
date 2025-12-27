import 'dart:io';
import 'dart:typed_data';

/// Upload progress callback
typedef UploadProgressCallback = void Function(double progress);

/// Result of a media upload operation
class UploadResult {
  final String downloadUrl;
  final String storagePath;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final int? width;
  final int? height;
  final int? duration; // For audio/video in seconds

  const UploadResult({
    required this.downloadUrl,
    required this.storagePath,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    this.width,
    this.height,
    this.duration,
  });

  Map<String, dynamic> toMap() {
    return {
      'downloadUrl': downloadUrl,
      'storagePath': storagePath,
      'fileName': fileName,
      'fileSize': fileSize,
      'mimeType': mimeType,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (duration != null) 'duration': duration,
    };
  }
}

/// Media type enumeration
enum MediaType {
  image,
  video,
  audio,
  document,
}

/// Abstract storage service interface
abstract class StorageService {
  /// Upload a file from path
  Future<UploadResult> uploadFile({
    required String filePath,
    required String chatId,
    required String senderId,
    required MediaType mediaType,
    UploadProgressCallback? onProgress,
  });

  /// Upload file from bytes
  Future<UploadResult> uploadBytes({
    required Uint8List bytes,
    required String fileName,
    required String chatId,
    required String senderId,
    required MediaType mediaType,
    UploadProgressCallback? onProgress,
  });

  /// Delete a file from storage
  Future<void> deleteFile(String storagePath);

  /// Get download URL for a file
  Future<String> getDownloadUrl(String storagePath);

  /// Download file to local storage
  Future<File> downloadFile(String storagePath, String localPath);
}
