// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

export 'package:permission_handler/permission_handler.dart';

abstract class PermissionDeniedDelegate {
  /// 无法获得此权限，操作系统拒绝，在ios由于存在家长控制等主动限制，在android由于版本问题等
  Future<void> restrictedDialog(Permission permission);

  /// 受限制的，比如访问部分图片
  Future<void> limitedDialog(Permission permission);

  /// 被拒绝的
  Future<void> openAppSettingsConfirmDialog(Permission permission);
}

class GlobalPermissionDeniedDelegate extends PermissionDeniedDelegate {
  @override
  Future<void> limitedDialog(Permission permission) async {
    return;
  }

  @override
  Future<void> openAppSettingsConfirmDialog(Permission permission) async {}

  @override
  Future<void> restrictedDialog(Permission permission) async {}
}

class GGPermissionUtil {
  static Future<bool> photos() async {
    return PermissionUtil.request(Permission.photos);
  }

  static Future<bool> videos() async {
    return PermissionUtil.request(Permission.videos);
  }

  static Future<bool> audio() async {
    return PermissionUtil.request(Permission.audio);
  }

  static Future<bool> storage() async {
    return PermissionUtil.request(Permission.storage);
  }

  static Future<bool> album() async {
    return PermissionUtil.requestMulti(permissions: [
      Permission.photos,
      Permission.videos,
      Permission.audio,
      Permission.storage,
    ]);
  }

  static Future<bool> camera() async {
    return PermissionUtil.requestMulti(permissions: [
      Permission.camera,
      Permission.microphone,
    ]);
  }

  static Future<bool> location() async {
    return PermissionUtil.request(Permission.location);
  }
}

class PermissionUtil {
  static GlobalPermissionDeniedDelegate globalDelegate =
      GlobalPermissionDeniedDelegate();

  static Future<bool> request(
    Permission permission, {
    PermissionDeniedDelegate? delegate,
  }) async {
    final effectiveDelegate = delegate ?? globalDelegate;
    if (Platform.isAndroid) {
      if (permission == Permission.photos ||
          permission == Permission.videos ||
          permission == Permission.audio ||
          permission == Permission.storage) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt <= 32) {
          if (permission != Permission.storage) {
            permission = Permission.storage;
          }
        } else {
          if (permission == Permission.storage) {
            return true;
          }
        }
      }
    }
    final PermissionStatus status = await permission.request();
    bool allowed = false;
    switch (status) {
      case PermissionStatus.granted:
        allowed = true;
        break;
      case PermissionStatus.denied:
        break;
      case PermissionStatus.restricted:
        if (Platform.isAndroid) {
          // 安卓中因版本问题，拒绝使用该权限
          if (permission == Permission.storage ||
              permission == Permission.manageExternalStorage ||
              permission == Permission.photos) {
            allowed = true;
            break;
          }
        }
        effectiveDelegate.restrictedDialog(permission);
        break;
      case PermissionStatus.limited:
        // 受限制的，比如访问部分图片
        effectiveDelegate.limitedDialog(permission);
        allowed = true;
        break;
      case PermissionStatus.permanentlyDenied:
        // 安卓中永久性拒绝申请，系统设置权限页面
        effectiveDelegate.openAppSettingsConfirmDialog(permission);
        break;
    }
    return allowed;
  }

  static Future<bool> requestMulti({
    required List<Permission> permissions,
    PermissionDeniedDelegate? delegate,
  }) async {
    bool allowed = false;
    for (var element in permissions) {
      allowed = await request(element);
      if (!allowed) {
        break;
      }
    }
    return allowed;
  }

  static Future<Map<Permission, bool>> requestMultiReturnMap({
    required List<Permission> permissions,
    PermissionDeniedDelegate? delegate,
  }) async {
    Map<Permission, PermissionStatus> statuses = await permissions.request();
    return statuses.map((key, value) {
      bool allowed = value == PermissionStatus.granted ||
          value == PermissionStatus.limited;
      return MapEntry(key, allowed);
    });
  }
}
