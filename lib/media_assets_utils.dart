import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

enum MetadataKey {
  duration,
  mimetype,
  bitrate,
  location,
  video_rotation,
  video_height,
  video_width,
}

enum VideoQuality {
  // 360p
  very_low,
  // 480p
  low,
  // 540p
  medium,
  // 720p
  high,
  // 1080p
  very_high,
}

class MediaAssetsUtils {
  static const MethodChannel _channel =
      const MethodChannel('media_assets_utils');

  static Future<File?> compressVideo(
    File file, {
    File? outputFile,
    bool ignoreMedia = true,
    VideoQuality quality = VideoQuality.medium,
  }) async {
    final str = quality.toString();
    final qstr = str.substring(str.indexOf('.') + 1);

    final String? result = await _channel.invokeMethod('compressVideo', {
      'path': file.path,
      'outputPath': outputFile?.path,
      'ignoreMedia': ignoreMedia,
      'quality': qstr.toUpperCase(),
    });
    return result == null ? null : File(result);
  }

  static Future<File?> compressImage(
    File file, {
    File? outputFile,
    bool ignoreMedia = true,
  }) async {
    final String? result = await _channel.invokeMethod('compressImage', {
      'path': file.path,
      'outputPath': outputFile?.path,
      'ignoreMedia': ignoreMedia,
    });
    return result == null ? null : File(result);
  }

  static Future<File?> getVideoThumbnail(
    File file, {
    File? thumbnailFile,
    int quality = 100,
  }) async {
    final String? result = await _channel.invokeMethod('getVideoThumbnail', {
      'path': file.path,
      'thumbnailPath': thumbnailFile?.path,
      'quality': quality,
    });
    return result == null ? null : File(result);
  }

  static Future<bool?> saveToGallery(String path) async {
    final bool? result = await _channel.invokeMethod('saveToGallery', {
      'path': path,
    });
    return result;
  }

  static Future<String?> extractMetadata(
    String path,
    MetadataKey keyCode,
  ) async {
    final String? result = await _channel.invokeMethod('extractMetadata', {
      'path': path,
      'keyCode': keyCode,
    });
    return result;
  }
}
