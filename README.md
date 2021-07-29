# media_asset_utils

Compress and save image/video native plugin (Swift/Kotlin)

This library can works on Android and iOS.

## 写在前面
家境贫寒，工作繁忙。只能不定期更新，还望网友们见谅！

各平台最低要求

Android 21+

iOS 9.0+

由于库依赖于 Kotlin 版本`1.5.21`，请更改项目级别的 build.gradle 文件来确保项目中的最低 kotlin 版本。

## 项目描述
1. 图片压缩使用 Luban （鲁班） —— 图片压缩工具
    - 仿微信朋友圈压缩策略，不支持控制quality
    
2. 视频压缩 使用硬件编码，并未使用`ffmpeg`
    - 根据quality对width、height进行自动缩放以及bitrate计算
    - bitrate计算公式 width * height * fps * 0.07

3. Native获取视频、图片信息 未完

4. 保存图片、视频到系统相册 支持Android Q

## 有点忙，没空写，未完

