// storage.dart — 图片选择 + 压缩 + 上传到 Supabase Storage

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase.dart';

class StorageService {
  final ImagePicker _picker = ImagePicker();

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

    Uint8List bytes = await picked.readAsBytes();
    String extension = _extOf(picked.name);
    String contentType = _mimeOf(extension);

    if (!kIsWeb) {
      try {
        final compressed = await FlutterImageCompress.compressWithList(
          bytes,
          quality: 75,
          minWidth: 1024,
          minHeight: 1024,
        );
        if (compressed.isNotEmpty) bytes = compressed;
      } catch (_) {}
    }

    final storagePath =
        '$pathPrefix/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await supabase.storage
        .from(bucket)
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );
    return supabase.storage.from(bucket).getPublicUrl(storagePath);
  }

  Future<void> delete(String bucket, String path) async {
    try {
      await supabase.storage.from(bucket).remove([path]);
    } catch (_) {}
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
