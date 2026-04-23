// storage.dart — 图片选择 + 裁剪 + 压缩 + 上传到 Supabase Storage
//
// 使用示例：
//   final url = await StorageService().pickCropCompressAndUpload(
//     bucket: 'avatars',
//     pathPrefix: currentUserId!,
//     square: true,
//   );
//
// bucket 必须是在 Supabase Dashboard → Storage 预先创建好的 public bucket。
// 返回 publicUrl（上传失败返回 null）。

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase.dart';

class StorageService {
  final ImagePicker _picker = ImagePicker();

  /// End-to-end: pick → optionally crop (mobile) → compress → upload → publicUrl.
  ///
  /// Returns `null` if the user cancels or upload fails.
  Future<String?> pickCropCompressAndUpload({
    required String bucket,
    required String pathPrefix,
    bool square = true,
    ImageSource source = ImageSource.gallery,
  }) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );
    if (picked == null) return null;

    Uint8List bytes;
    String extension = _extOf(picked.name);
    String contentType = _mimeOf(extension);

    try {
      if (!kIsWeb && square) {
        final cropped = await _cropSquare(picked.path);
        if (cropped == null) return null;
        bytes = await cropped.readAsBytes();
        extension = _extOf(cropped.path);
        contentType = _mimeOf(extension);
      } else {
        bytes = await picked.readAsBytes();
      }
    } catch (_) {
      return null;
    }

    // Compress on mobile (web plugin lacks Uint8List compression for all formats).
    if (!kIsWeb) {
      try {
        final compressed = await FlutterImageCompress.compressWithList(
          bytes,
          quality: 75,
          minWidth: 1024,
          minHeight: 1024,
        );
        if (compressed.isNotEmpty) bytes = compressed;
      } catch (_) {
        // fall through with uncompressed bytes
      }
    }

    final storagePath =
        '$pathPrefix/${DateTime.now().millisecondsSinceEpoch}.$extension';
    try {
      await supabase.storage
          .from(bucket)
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: contentType),
          );
      return supabase.storage.from(bucket).getPublicUrl(storagePath);
    } catch (_) {
      return null;
    }
  }

  Future<CroppedFile?> _cropSquare(String sourcePath) async {
    return ImageCropper().cropImage(
      sourcePath: sourcePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(hideBottomControls: true, lockAspectRatio: true),
        IOSUiSettings(aspectRatioLockEnabled: true),
      ],
    );
  }

  /// Best-effort delete of an object by full storage path (e.g. "uid/123.jpg").
  Future<void> delete(String bucket, String path) async {
    try {
      await supabase.storage.from(bucket).remove([path]);
    } catch (_) {
      // ignore
    }
  }

  String _extOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return 'jpg';
    final raw = name.substring(dot + 1).toLowerCase();
    if (raw.isEmpty || raw.length > 5) return 'jpg';
    return raw;
  }

  String _mimeOf(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
