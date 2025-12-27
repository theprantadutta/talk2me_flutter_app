import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import 'storage_service.dart';

/// Firebase Storage implementation of StorageService
class FirebaseStorageService implements StorageService {
  final FirebaseStorage _storage;
  final Uuid _uuid = const Uuid();

  FirebaseStorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  /// Get storage path based on media type
  String _getStoragePath(String chatId, String senderId, MediaType mediaType, String fileName) {
    final String folder = switch (mediaType) {
      MediaType.image => 'images',
      MediaType.video => 'videos',
      MediaType.audio => 'audio',
      MediaType.document => 'documents',
    };

    final extension = path.extension(fileName);
    final uniqueFileName = '${_uuid.v4()}$extension';

    return 'chats/$chatId/$folder/$senderId/$uniqueFileName';
  }

  /// Get MIME type from file path
  String _getMimeType(String filePath) {
    return lookupMimeType(filePath) ?? 'application/octet-stream';
  }

  @override
  Future<UploadResult> uploadFile({
    required String filePath,
    required String chatId,
    required String senderId,
    required MediaType mediaType,
    UploadProgressCallback? onProgress,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found: $filePath');
    }

    final fileName = path.basename(filePath);
    final mimeType = _getMimeType(filePath);
    final storagePath = _getStoragePath(chatId, senderId, mediaType, fileName);
    final fileSize = await file.length();

    final ref = _storage.ref(storagePath);
    final metadata = SettableMetadata(
      contentType: mimeType,
      customMetadata: {
        'originalFileName': fileName,
        'uploadedBy': senderId,
        'chatId': chatId,
      },
    );

    final uploadTask = ref.putFile(file, metadata);

    // Listen to progress
    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((event) {
        final progress = event.bytesTransferred / event.totalBytes;
        onProgress(progress);
      });
    }

    // Wait for upload to complete
    await uploadTask;

    // Get download URL
    final downloadUrl = await ref.getDownloadURL();

    return UploadResult(
      downloadUrl: downloadUrl,
      storagePath: storagePath,
      fileName: fileName,
      fileSize: fileSize,
      mimeType: mimeType,
    );
  }

  @override
  Future<UploadResult> uploadBytes({
    required Uint8List bytes,
    required String fileName,
    required String chatId,
    required String senderId,
    required MediaType mediaType,
    UploadProgressCallback? onProgress,
  }) async {
    final mimeType = _getMimeType(fileName);
    final storagePath = _getStoragePath(chatId, senderId, mediaType, fileName);

    final ref = _storage.ref(storagePath);
    final metadata = SettableMetadata(
      contentType: mimeType,
      customMetadata: {
        'originalFileName': fileName,
        'uploadedBy': senderId,
        'chatId': chatId,
      },
    );

    final uploadTask = ref.putData(bytes, metadata);

    // Listen to progress
    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((event) {
        final progress = event.bytesTransferred / event.totalBytes;
        onProgress(progress);
      });
    }

    // Wait for upload to complete
    await uploadTask;

    // Get download URL
    final downloadUrl = await ref.getDownloadURL();

    return UploadResult(
      downloadUrl: downloadUrl,
      storagePath: storagePath,
      fileName: fileName,
      fileSize: bytes.length,
      mimeType: mimeType,
    );
  }

  @override
  Future<void> deleteFile(String storagePath) async {
    try {
      await _storage.ref(storagePath).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') {
        rethrow;
      }
      // File already deleted, ignore
    }
  }

  @override
  Future<String> getDownloadUrl(String storagePath) async {
    return await _storage.ref(storagePath).getDownloadURL();
  }

  @override
  Future<File> downloadFile(String storagePath, String localPath) async {
    final file = File(localPath);
    final dir = file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    await _storage.ref(storagePath).writeToFile(file);
    return file;
  }
}
