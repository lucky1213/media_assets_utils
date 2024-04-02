# media_asset_utils

Compress and save image/video native plugin (Swift/Kotlin)

This library can works on Android and iOS.

## 写在前面

工作繁忙。只能不定期更新，还望网友们见谅！

各平台最低要求

Android 24+

iOS 12.0+

## 项目描述

1. 图片压缩使用 Luban （鲁班） —— 图片压缩工具
   - 仿微信朋友圈压缩策略，不支持控制 quality
2. 视频压缩 使用硬件编码，并未使用`ffmpeg`

   - 根据 quality 对 width、height 进行自动缩放以及 bitrate 计算
   - bitrate 计算公式 width _ height _ fps \* 0.07

3. Native 获取视频、图片信息

4. 保存图片、视频到系统相册

## 配置

### Android

由于库依赖于 Kotlin 版本`1.8.22`，请更改项目级别的 build.gradle 文件来确保项目中的最低 kotlin 版本。

在 AndroidManifest.xml 中添加如下权限：

**API < 29**

```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission
    android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="28"
    tools:ignore="ScopedStorage" />
```

**API >= 29**

```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
android:maxSdkVersion="32"/>
```

**API >= 33**

```xml
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
```

### iOS

将以下内容添加到您的 Info.plist 文件中，该文件位于<project root>/ios/Runner/Info.plist：

```
<key>NSPhotoLibraryUsageDescription</key>
<string>${PRODUCT_NAME} library Usage</string>
```
