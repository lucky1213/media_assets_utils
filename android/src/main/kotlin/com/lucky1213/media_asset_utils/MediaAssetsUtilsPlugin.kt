package com.lucky1213.media_asset_utils

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.os.*
import android.text.TextUtils
import android.util.Log
import androidx.annotation.NonNull
import com.abedelazizshe.lightcompressorlibrary.CompressionListener
import com.abedelazizshe.lightcompressorlibrary.VideoCompressor
import com.abedelazizshe.lightcompressorlibrary.VideoQuality
import com.abedelazizshe.lightcompressorlibrary.config.Configuration
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import top.zibin.luban.Luban
import top.zibin.luban.OnCompressListener
import java.io.File
import java.io.File.separator
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.OutputStream
import kotlin.concurrent.thread
import kotlin.math.ceil


enum class DirectoryType(val value: String) {
    MOVIES(Environment.DIRECTORY_MOVIES),
    PICTURES(Environment.DIRECTORY_PICTURES),
    MUSIC(Environment.DIRECTORY_MUSIC),
    DCIM(Environment.DIRECTORY_DCIM),
    DOCUMENTS(Environment.DIRECTORY_DOCUMENTS),
    DOWNLOADS(Environment.DIRECTORY_DOWNLOADS)
}

enum class VideoOutputQuality(val value:Int, val level: VideoQuality){
    VERY_LOW(640, VideoQuality.VERY_LOW),
    LOW(640, VideoQuality.LOW),
    MEDIUM(960, VideoQuality.MEDIUM),
    HIGH(1280, VideoQuality.HIGH),
    VERY_HIGH(1920, VideoQuality.VERY_HIGH)
}


/** MediaAssetsUtilsPlugin */
class MediaAssetsUtilsPlugin: FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private lateinit var applicationContext : Context
  private var mediaMetadataRetriever: MediaMetadataRetriever? = null

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    applicationContext = flutterPluginBinding.applicationContext
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "media_asset_utils")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    Log.i("AndroidCameraView", "onMethodCall: ${call.method} ${call.arguments}")
      when (call.method) {
          "compressVideo" -> {
              val path = call.argument<String>("path")!!
              val quality = VideoOutputQuality.valueOf(call.argument<String>("quality")?.toUpperCase() ?: "MEDIUM")
              val tempPath = call.argument<String>("outputPath")
              val outputPath = tempPath ?: MediaStoreUtils.generateTempPath(applicationContext, DirectoryType.PICTURES.value, ".mp4")
              val file = File(outputPath)

              val saveToLibrary = call.argument<Boolean>("saveToLibrary") ?: false
              val storeThumbnail = call.argument<Boolean>("storeThumbnail") ?: true
              val thumbnailPath = call.argument<String>("thumbnailPath")
              val thumbnailQuality = call.argument<Int>("thumbnailQuality") ?: 100
              // 文件小于1M
              if (File(path).length() < 1048576) {
                  result.success(path)
                  return
              }
              mediaMetadataRetriever = mediaMetadataRetriever ?: MediaMetadataRetriever()
              try {
                  mediaMetadataRetriever!!.setDataSource(path)
              } catch (e: IllegalArgumentException) {
                  result.error("VideoCompress", e.message, null)
                  return
              }

              val bitrate = mediaMetadataRetriever!!.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)?.toInt()
              var width = mediaMetadataRetriever!!.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toInt()
              var height = mediaMetadataRetriever!!.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toInt()
              if (bitrate == null || width == null || height == null) {
                  result.error("VideoCompress", "Cannot find video track.", null)
                  return
              } else {
                  // 码率小于164kb/s
                  if (bitrate < 1351680) {
                      result.success(path)
                      return
                  }
                  Log.i("BITRATE", bitrate.toString())
              }
              when {
                  width >= quality.value || height >= quality.value -> {
                      when {
                          width > height -> {
                              height = ceil(height * quality.value / width.toDouble()).toInt()
                              width = quality.value
                          }
                          height > width -> {
                              width = ceil(width * quality.value / height.toDouble()).toInt()
                              height = quality.value
                          }
                          else -> {
                              width = quality.value
                              height = quality.value
                          }
                      }
                  }
              }

              if (!file.parentFile!!.exists()) {
                  file.parentFile!!.mkdir()
              }

              Log.i("OutputSize", "width=$width, height=$height")
              VideoCompressor.start(
                      srcPath = path,
                      destPath = outputPath,
                      listener = object : CompressionListener {
                          override fun onProgress(percent: Float) {
                              Handler(Looper.getMainLooper()).post {
                                  Log.i("onVideoCompressProgress", percent.toString())
                                  channel.invokeMethod("onVideoCompressProgress", if (percent > 100) { 100 } else { percent})
                              }
                          }

                          override fun onStart() {
                              // Compression start
                          }

                          override fun onSuccess() {
                              thread {
                                  try {
                                      val file = File(outputPath)
                                      if (storeThumbnail) {
                                          storeThumbnailToFile(outputPath, thumbnailPath, thumbnailQuality, false)
                                      }
                                      Handler(Looper.getMainLooper()).post {
                                          result.success(outputPath)
                                      }
                                      if (saveToLibrary) {
                                          MediaStoreUtils.insert(applicationContext, file)
                                      }
                                  } catch (e: Exception) {
                                      Handler(Looper.getMainLooper()).post {
                                          result.error("VideoCompress", e.message, null)
                                      }
                                  }
                              }
                          }

                          override fun onFailure(failureMessage: String) {
                              result.error("VideoCompress", failureMessage, null)
                          }

                          override fun onCancelled() {
                              Handler(Looper.getMainLooper()).post {
                                  result.error("VideoCompress", "The transcoding operation was canceled.", null)
                              }
                          }

                      },
                      configureWith = Configuration(
                              quality = quality.level,
                              isMinBitRateEnabled = false,
                              keepOriginalResolution = false,
                              videoWidth = width.toDouble(),
                              videoHeight = height.toDouble(),
                              videoBitrate = (width * height * 25 * 0.07).toInt()
                      )
              )
          }
          "compressImage" -> {
              val path = call.argument<String>("path")!!
              val srcFile = File(path)
              val tempPath = call.argument<String>("outputPath")
              val outputPath = tempPath ?: MediaStoreUtils.generateTempPath(applicationContext, DirectoryType.PICTURES.value, ".${srcFile.extension}")
              val outputFile = File(outputPath)
              val saveToLibrary = call.argument<Boolean>("saveToLibrary") ?: false
              if (!outputFile.parentFile!!.exists()) {
                  outputFile.parentFile!!.mkdir()
              }
              Luban.with(applicationContext)
                      .load(srcFile)
                      .ignoreBy(100)
                      .setTargetDir(outputFile.parent)
                      .setFocusAlpha(outputFile.extension == "png")
                      .filter { path -> !(TextUtils.isEmpty(path) || path.toLowerCase().endsWith(".gif")) }
                      .setCompressListener(object : OnCompressListener {
                          override fun onStart() {
                              Log.i("ImageCompress", "onStart")
                          }

                          override fun onSuccess(file: File) {
                              result.success(file.absolutePath)
                              if (saveToLibrary && file.absolutePath == outputFile.absolutePath) {
                                  MediaStoreUtils.insert(applicationContext, file)
                              }
                          }

                          override fun onError(e: Throwable) {
                              result.error("ImageCompress", e.message, e.stackTrace)
                          }
                      })
                      .setRenameListener {
                          outputFile.name
                      }
                      .launch()
          }
          "extractMetadata" -> {
              val path = call.argument<String>("path")!!
              val keyCode = call.argument<String>("keyCode")!!
              mediaMetadataRetriever = mediaMetadataRetriever ?: MediaMetadataRetriever()
              mediaMetadataRetriever!!.setDataSource(path)
              val value = when (keyCode) {
                  "duration" -> {
                      MediaMetadataRetriever.METADATA_KEY_DURATION
                  }
                  "bitrate" -> {
                      MediaMetadataRetriever.METADATA_KEY_BITRATE
                  }
                  "video_width" -> {
                      MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH
                  }
                  "video_height" -> {
                      MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT
                  }
                  else -> null
              }
              if (value != null) {
                  result.success(mediaMetadataRetriever!!.extractMetadata(value)?.toInt())
              } else {
                  result.error("ExtractMetadata", "Unsupported the metadata.", null)
              }
          }
          "getVideoThumbnail" -> {
              val path = call.argument<String>("path")!!
              val thumbnailPath = call.argument<String>("thumbnailPath")
              val quality = call.argument<Int>("quality") ?: 100
              val saveToLibrary = call.argument<Boolean>("saveToLibrary") ?: false
              try {
                  result.success(storeThumbnailToFile(path, thumbnailPath, quality, saveToLibrary))
              } catch (e: Exception) {
                  result.error("VideoThumbnail", e.message, null)
              }
          }
          "saveToGallery" -> {
              val path = call.argument<String>("path") ?: return
              thread {
                  try {
                      val srcFile = File(path)
                      MediaStoreUtils.insert(applicationContext, srcFile)
                      Handler(Looper.getMainLooper()).post {
                          result.success(true)
                      }
                  } catch (e: Exception) {
                      Handler(Looper.getMainLooper()).post {
                          result.error("SaveToGallery", e.message, null)
                      }
                  }
              }

          }
          else -> {
              result.error("NoImplemented", "Handles a call to an unimplemented method.", null)
          }
      }
  }

    private fun storeThumbnailToFile(path: String, thumbnailPath: String? = null, quality: Int = 100, saveToLibrary: Boolean = true) : String? {
        mediaMetadataRetriever = mediaMetadataRetriever ?: MediaMetadataRetriever()
        try {
            mediaMetadataRetriever!!.setDataSource(path)
        } catch (e: IllegalArgumentException){
            return null
        }
        val bitmap: Bitmap? = mediaMetadataRetriever!!.frameAtTime
        var format = Bitmap.CompressFormat.JPEG
        if (thumbnailPath != null) {
            val outputDir = File(thumbnailPath).parentFile!!
            if (!outputDir.exists()) {
                outputDir.mkdir()
            }
            val extension = MediaStoreUtils.getFileExtension(thumbnailPath)
            format = if (extension == "jpg" || extension == "jpeg") {
                Bitmap.CompressFormat.JPEG
            } else if (extension == "png") {
                Bitmap.CompressFormat.PNG
            } else {
                Bitmap.CompressFormat.JPEG
            }
        }

        val file = if (thumbnailPath != null) {
            File(thumbnailPath)
        } else {
            File(MediaStoreUtils.generateTempPath(applicationContext, DirectoryType.PICTURES.value, extension = ".jpg", filename = File(path).nameWithoutExtension+"_thumbnail"))
        }
        if (file.exists()) {
            file.delete()
        }
        try {
            //outputStream获取文件的输出流对象
            val fos: OutputStream = file.outputStream()
            //压缩格式为JPEG图像，压缩质量为100%
            bitmap!!.compress(format, quality, fos)
            fos.flush()
            fos.close()
            if (saveToLibrary) {
                MediaStoreUtils.insert(applicationContext, file)
            }
            return file.absolutePath
        } catch (e: Exception) {
            throw RuntimeException(e)
        }
    }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
