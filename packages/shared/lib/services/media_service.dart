import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'api/files_api.dart';

/// Why a file is being uploaded — mirrors the backend `FilePurpose` enum so
/// the server can validate type and retention.
enum UploadPurpose {
  profile,
  verification,
  listing,
  complaint,
  document,
  visitor,
  staff,
  invoice,
  other,
}

extension UploadPurposeWire on UploadPurpose {
  String get wire => switch (this) {
    UploadPurpose.profile => 'PROFILE',
    UploadPurpose.verification => 'VERIFICATION',
    UploadPurpose.listing => 'LISTING',
    UploadPurpose.complaint => 'COMPLAINT',
    UploadPurpose.document => 'DOCUMENT',
    UploadPurpose.visitor => 'VISITOR',
    UploadPurpose.staff => 'STAFF',
    UploadPurpose.invoice => 'INVOICE',
    UploadPurpose.other => 'OTHER',
  };
}

/// A file the user picked, held in memory.
class PickedFile {
  const PickedFile({
    required this.name,
    required this.bytes,
    required this.mimeType,
    required this.sizeBytes,
  });

  final String name;
  final Uint8List bytes;
  final String mimeType;
  final int sizeBytes;

  static const int maxBytes = 5 * 1024 * 1024; // backend MAX_UPLOAD_MB = 5

  bool get tooLarge => sizeBytes > maxBytes;
}

/// Raised when picking or validating fails. The message is meant to be shown
/// to the user as-is.
class MediaException implements Exception {
  MediaException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// One place for camera, gallery and document picking: validation, size caps,
/// mime inference and the upload call itself.
///
/// Deliberately not a singleton of state — every call is independent, so a
/// screen never holds a half-picked file across a rebuild.
class MediaService {
  MediaService(this._files);
  final FilesApi _files;

  final ImagePicker _picker = ImagePicker();

  /// Picks an image from the camera.
  ///
  /// Returns null when the user cancels the camera. Throws [MediaException]
  /// when permission is denied or the file exceeds the cap.
  Future<PickedFile?> fromCamera({int maxSide = 1920, int quality = 85}) async {
    XFile? shot;
    try {
      shot = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxSide.toDouble(),
        maxHeight: maxSide.toDouble(),
        imageQuality: quality,
      );
    } on PlatformException catch (e) {
      throw _permissionOrCancel(e);
    }
    if (shot == null) return null;
    return _readImage(shot);
  }

  /// Picks an image from the gallery (a single image).
  Future<PickedFile?> fromGallery({
    int maxSide = 1920,
    int quality = 85,
  }) async {
    XFile? image;
    try {
      image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxSide.toDouble(),
        maxHeight: maxSide.toDouble(),
        imageQuality: quality,
      );
    } on PlatformException catch (e) {
      throw _permissionOrCancel(e);
    }
    if (image == null) return null;
    return _readImage(image);
  }

  /// Picks any number of images from the gallery.
  Future<List<PickedFile>> imagesFromGallery({
    int maxSide = 1920,
    int quality = 85,
    int maxCount = 8,
  }) async {
    List<XFile> images;
    try {
      images = await _picker.pickMultiImage(
        maxWidth: maxSide.toDouble(),
        maxHeight: maxSide.toDouble(),
        imageQuality: quality,
        limit: maxCount,
      );
    } on PlatformException catch (e) {
      throw _permissionOrCancel(e);
    }
    final out = <PickedFile>[];
    for (final image in images) {
      out.add(await _readImage(image));
    }
    return out;
  }

  /// Picks a document (PDF or an image) from the file system.
  Future<PickedFile?> document({
    List<String> allowedExtensions = const [
      'pdf',
      'jpg',
      'jpeg',
      'png',
      'webp',
    ],
  }) async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        withData: true,
      );
    } on PlatformException catch (e) {
      throw MediaException(_readPermissionMessage(e.message ?? e.code));
    }
    final file = result?.files.singleOrNull;
    if (file == null) return null;

    final bytes =
        file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) {
      throw MediaException('Could not read the picked file.');
    }
    if (bytes.length > PickedFile.maxBytes) {
      throw MediaException(
        'File is too large (${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB). '
        'The limit is 5 MB.',
      );
    }
    final name = file.name.isEmpty ? 'document' : file.name;
    return PickedFile(
      name: name,
      bytes: bytes,
      mimeType: _mimeForExtension(name),
      sizeBytes: bytes.length,
    );
  }

  /// Uploads [file] and returns the backend file id.
  Future<String> upload(
    PickedFile file, {
    required UploadPurpose purpose,
  }) async {
    if (file.tooLarge) {
      throw MediaException(
        'File is too large (${(file.sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB). '
        'The limit is 5 MB.',
      );
    }
    return _files.upload(
      bytes: file.bytes,
      fileName: file.name,
      purpose: purpose.wire,
      mimeType: file.mimeType,
    );
  }

  Future<PickedFile> _readImage(XFile shot) async {
    final bytes = await shot.readAsBytes();
    if (bytes.length > PickedFile.maxBytes) {
      throw MediaException(
        'Image is too large (${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB). '
        'The limit is 5 MB.',
      );
    }
    final name = shot.name.isEmpty ? 'photo.jpg' : shot.name;
    return PickedFile(
      name: name,
      bytes: bytes,
      mimeType: _mimeForExtension(name),
      sizeBytes: bytes.length,
    );
  }

  MediaException _permissionOrCancel(PlatformException e) {
    final message = (e.message ?? e.code).toLowerCase();
    if (message.contains('denied') ||
        message.contains('permission') ||
        message.contains('not granted')) {
      return MediaException(
        'Permission is off. Enable camera or photos for Habito Living in '
        'system settings, then try again.',
      );
    }
    return MediaException('Could not open the picker. Try again.');
  }

  static String _readPermissionMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('denied') || lower.contains('permission')) {
      return 'Permission is off. Allow file access for Habito Living in system '
          'settings, then try again.';
    }
    return 'Could not open the file picker. Try again.';
  }

  static String _mimeForExtension(String name) {
    final dot = name.lastIndexOf('.');
    final ext = dot == -1 ? '' : name.substring(dot + 1).toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' => 'image/heic',
      'pdf' => 'application/pdf',
      _ => 'application/octet-stream',
    };
  }
}
