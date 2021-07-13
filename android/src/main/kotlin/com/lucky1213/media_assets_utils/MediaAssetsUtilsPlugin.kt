package com.lucky1213.media_assets_utils

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.os.Environment
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
import java.io.OutputStream
import kotlin.math.ceil


enum class DIRECTORYTYPE {
    MOVIES, PICTURES
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
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "media_assets_utils")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    Log.i("AndroidCameraView", "onMethodCall: ${call.method} ${call.arguments}")
      when (call.method) {
          "compressVideo" -> {
              val outputPath = call.argument<String>("outputPath") ?: generatePath(DIRECTORYTYPE.MOVIES)
              val path = call.argument<String>("path")!!
              val quality = VideoOutputQuality.valueOf(call.argument<String>("quality") ?: "MEDIUM")

              val ignoreMedia = call.argument<Boolean>("ignoreMedia")!!
              // 文件小于1M
              if (File(path).length() < 1048576) {
                  result.success(path)
                  return
              }
              mediaMetadataRetriever = mediaMetadataRetriever ?: MediaMetadataRetriever()
              mediaMetadataRetriever!!.setDataSource(path)
              val bitrate = mediaMetadataRetriever!!.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)?.toInt()
              var width = mediaMetadataRetriever!!.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toInt()
              var height = mediaMetadataRetriever!!.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toInt()
              if (bitrate == null || width == null || height == null) {
                  result.error("TranscodeCanceled", "The video has no matedata data.", null)
                  return
              } else {
                  // 码率小于164kb/s
                  if (bitrate < 1351680) {
                      result.success(path)
                      return
                  }
                  Log.i("BITRATE", bitrate.toString())
              }

              val outputSize = when {
                  width >= quality.value || height >= quality.value -> {
                      when {
                          width > height -> {
                              Log.i("Height", ceil(height * quality.value / width.toDouble()).toString())
                              Size(quality.value, ceil(height * quality.value / width.toDouble()).toInt())
                          }
                          height > width -> {
                              Size(ceil(width * quality.value / height.toDouble()).toInt(), quality.value)
                          }
                          else -> {
                              Size(quality.value, quality.value)
                          }
                      }
                  }
                  else -> Size(width, height)
              }

              if (width >= height) {
                  width = outputSize.major
                  height = outputSize.minor
              } else {
                  width = outputSize.minor
                  height = outputSize.major
              }
              Log.i("OutputSize", "width=$width, height=$height")

              VideoCompressor.start(
                      srcPath = path,
                      destPath = outputPath,
                      listener = object : CompressionListener {
                          override fun onProgress(percent: Float) {
                              Log.i("TranscodeProgress", percent.toString())
                          }

                          override fun onStart() {
                              // Compression start
                          }

                          override fun onSuccess() {
                              result.success(outputPath)
                              if (ignoreMedia) {
                                  MediaStoreUtils.ignoreMedia(File(outputPath).parentFile!!)
                              }
                          }

                          override fun onFailure(failureMessage: String) {
                              result.error("CompressImageFailed", failureMessage, null)
                          }

                          @SuppressLint("WrongThread")
                          override fun onCancelled() {
                              result.error("TranscodeCanceled", "The transcoding operation was canceled.", null)
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
              val outputPath = call.argument<String>("outputPath") ?: generatePath(DIRECTORYTYPE.PICTURES)
              val path = call.argument<String>("path")!!
              val file = File(outputPath)
              val extension = MediaStoreUtils.getFileExtension(file)
              val ignoreMedia = call.argument<Boolean>("ignoreMedia")!!
              Luban.with(applicationContext)
                      .load(File(path))
                      .ignoreBy(100)
                      .setTargetDir(file.parent)
                      .setFocusAlpha(extension == "jpg" || extension == "jpeg")
                      .filter { path -> !(TextUtils.isEmpty(path) || path.toLowerCase().endsWith(".gif")) }
                      .setCompressListener(object : OnCompressListener {
                          override fun onStart() {
                              Log.i("CompressImageStart", "onStart")
                          }

                          override fun onSuccess(file: File) {
                              result.success(file.absolutePath)
                              if (ignoreMedia) {
                                  MediaStoreUtils.ignoreMedia(file.parentFile!!)
                              }
                          }

                          override fun onError(e: Throwable) {
                              result.error("CompressImageFailed", e.message, e.stackTrace)
                          }
                      })
                      .setRenameListener {
                          file.nameWithoutExtension + ".$extension"
                      }
                      .launch()
          }
          "extractMetadata" -> {
              val path = call.argument<String>("path")!!
              val keyCode = call.argument<Int>("keyCode")!!
              mediaMetadataRetriever = mediaMetadataRetriever ?: MediaMetadataRetriever()
              mediaMetadataRetriever!!.setDataSource(path)
              result.success(mediaMetadataRetriever!!.extractMetadata(keyCode))
          }
          "getVideoThumbnail" -> {
              val path = call.argument<String>("path")!!
              val thumbnailPath = call.argument<String>("thumbnailPath")
              val quality = call.argument<Int>("quality") ?: 100
              result.success(storeThumbnailToFile(path, thumbnailPath, quality))
          }
          "saveToGallery" -> {
              val path = call.argument<String>("file") ?: return
              MediaStoreUtils.insertIntoMediaStore(applicationContext, File(path))
              result.success(true)
          }
      }
  }

    private fun generatePath(type: DIRECTORYTYPE): String {
        val extension = if (type == DIRECTORYTYPE.MOVIES) {
            ".mp4"
        } else {
            ".jpg"
        }
        val output = if (Environment.getExternalStorageState() == Environment.MEDIA_MOUNTED) {
            File(applicationContext.getExternalFilesDir(if (type == DIRECTORYTYPE.MOVIES) {
                Environment.DIRECTORY_MOVIES
            } else {
                Environment.DIRECTORY_PICTURES
            }), "generate")
        } else {
            File(applicationContext.cacheDir.absolutePath + separator + if (type == DIRECTORYTYPE.MOVIES) {
                Environment.DIRECTORY_MOVIES
            } else {
                Environment.DIRECTORY_PICTURES
            }, "generate")
        }
        output.mkdirs()
        return output.absolutePath + separator + System.currentTimeMillis().toString() + extension
    }

    private fun storeThumbnailToFile(path: String, thumbnailPath: String? = null, quality: Int = 100) : String? {
        mediaMetadataRetriever = mediaMetadataRetriever ?: MediaMetadataRetriever()
        mediaMetadataRetriever!!.setDataSource(path)
        val bitmap: Bitmap? = mediaMetadataRetriever!!.frameAtTime

        val outputDir = if (thumbnailPath != null) {
            File(thumbnailPath).parentFile
        } else {
            File(path).parentFile!!
        }
        if (!outputDir.exists()) {
            outputDir.mkdir()
        }
        MediaStoreUtils.ignoreMedia(outputDir)

        var format = Bitmap.CompressFormat.JPEG
        val file = if (thumbnailPath != null) {
            File(thumbnailPath)
        } else {
            File(outputDir, File(path).nameWithoutExtension + "_thumbnail.jpg")
        }
        if (file.exists()) {
            file.delete()
        }
        if (thumbnailPath != null) {
            val extension = MediaStoreUtils.getFileExtensionFromUrl(thumbnailPath)
            format = if (extension == "jpg" || extension == "jpeg") {
                Bitmap.CompressFormat.JPEG
            } else if (extension == "png") {
                Bitmap.CompressFormat.PNG
            } else {
                Bitmap.CompressFormat.JPEG
            }
        }

        try {
            //outputStream获取文件的输出流对象
            val fos: OutputStream = file.outputStream()
            //压缩格式为JPEG图像，压缩质量为100%
            bitmap!!.compress(format, quality, fos)
            fos.flush()
            fos.close()
        } catch (e: Exception) {
            throw RuntimeException(e)
        }
        return file.absolutePath
    }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
