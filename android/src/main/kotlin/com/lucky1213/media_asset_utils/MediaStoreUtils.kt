package com.lucky1213.media_asset_utils

import android.content.ContentValues
import android.content.Context
import android.media.ExifInterface
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.FileUtils
import android.provider.MediaStore
import android.util.Log
import android.webkit.MimeTypeMap
import java.io.File
import java.io.FileInputStream
import java.io.IOException


class MediaStoreUtils {
    companion object{

        fun generateTempPath(context: Context, directory: String, extension: String, subDirectory: String? = null, filename: String? = null): String {
            val sub = if (subDirectory != null) {
                File.separator + subDirectory
            } else {
                ""
            }
            val outputDir = File(context.getExternalFilesDir(directory), sub)
            Log.i("TempPathExists", outputDir.exists().toString())
            if (!outputDir.exists()) {
                outputDir.mkdirs()
            }
            return outputDir.absolutePath + File.separator + (filename ?: System.currentTimeMillis().toString()) + extension
        }

        private fun getMediaDirectory(context: Context, directory: String, subDirectory: String? = null): String {
            val sub = if (subDirectory != null) {
                File.separator + subDirectory
            } else {
                ""
            }
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                directory + File.separator + sub
            } else {
                val outputDir = File(Environment.getExternalStoragePublicDirectory(directory), sub)
                if (!outputDir.exists()) {
                    outputDir.mkdirs()
                }
                outputDir.absolutePath
            }
        }

        //针对非系统影音资源文件夹
        fun insert(context: Context, file: File, directory: String = Environment.DIRECTORY_PICTURES, subDirectory: String? = null) : Uri? {
            val createTime = System.currentTimeMillis() / 1000
            val contentResolver = context.contentResolver
            val mimeType = getMimeType(file)
            val isVideo = mimeType == "video/mp4"

            val values = ContentValues()
            values.put(MediaStore.MediaColumns.TITLE, createTime)
            values.put(MediaStore.MediaColumns.DISPLAY_NAME, createTime)
            values.put(MediaStore.MediaColumns.DATE_ADDED, createTime)
            values.put(MediaStore.MediaColumns.DATE_MODIFIED, createTime)
            values.put(MediaStore.MediaColumns.DATE_ADDED, createTime)

            values.put(MediaStore.MediaColumns.SIZE, file.length())
            values.put(MediaStore.MediaColumns.MIME_TYPE, mimeType)

            val path = getMediaDirectory(context, directory, subDirectory)
            //兼容Android Q和以下版本
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                values.put(MediaStore.MediaColumns.DATE_TAKEN, createTime)
                //android Q中不再使用DATA字段，而用RELATIVE_PATH代替 相对路径不是绝对路径
                values.put(MediaStore.Images.Media.RELATIVE_PATH, path)
            } else {
                //Android Q以下版本
                values.put(MediaStore.Images.Media.DATA, path + File.separator + createTime + ".${file.extension}")
            }
            //值一样，但是还是用常量区分对待
//            values.put(
//                    if (isVideo) MediaStore.Video.VideoColumns.DATE_TAKEN else MediaStore.Images.ImageColumns.DATE_TAKEN,
//                    createTime
//            )
            if (!isVideo) {
                try {
                    val exifInterface = ExifInterface(file.absolutePath)
                    val orientation = exifInterface.getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
                    values.put(MediaStore.Images.ImageColumns.ORIENTATION, when (orientation) {
                        ExifInterface.ORIENTATION_ROTATE_90 -> {
                            90
                        }
                        ExifInterface.ORIENTATION_ROTATE_180 -> {
                            180
                        }
                        ExifInterface.ORIENTATION_ROTATE_270 -> {
                            270
                        }
                        else -> 0
                    })
                } catch (e: IOException) {
                    values.put(MediaStore.Images.ImageColumns.ORIENTATION, 0)
                }
            } else {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    values.put(
                        MediaStore.MediaColumns.DURATION,
                        getVideoDuration(file.absolutePath)
                    )
                }
            }
            val uri = contentResolver.insert(
                    if (isVideo) MediaStore.Video.Media.EXTERNAL_CONTENT_URI else MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    values
            )
            //插入
            copyFile(context, uri, file)
            return uri
        }

        private fun copyFile(context: Context, uri: Uri?, file: File) {
            uri?.also {
                val outputStream = context.contentResolver.openOutputStream(it)
                outputStream?.also { os ->
                    val input = FileInputStream(file)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        FileUtils.copy(input, os)
                    } else {
                        input.copyTo(os)
                    }
                    os.close()
                    input.close()
                    Log.i("MediaUtils", it.path.toString())
                }
            }
        }

        private fun getApplicationName(context: Context): String {
            val applicationInfo = context.applicationInfo
            val stringId = applicationInfo.labelRes
            return if (stringId == 0) {
                applicationInfo.nonLocalizedLabel.toString()
            } else {
                context.getString(stringId)
            }
        }

        fun getFileExtension(file: File): String {
            return getFileExtension(file.path)
        }

        fun getFileExtension(url: String): String {
            return MimeTypeMap.getFileExtensionFromUrl(url)
        }

        private fun getMimeType(file: File): String? {
            val type: String?
            val extension = getFileExtension(file)
            type = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension.toLowerCase())

            if (type == null) {
                if (extension == "jpg" || extension == "jpeg") {
                    return "image/jpeg"
                } else if (extension == "png") {
                    return "image/png"
                } else if (extension == "tif" || extension == "tiff") {
                    return "image/tiff"
                } else if (extension == "gif") {
                    return "image/gif"
                } else if (extension == "mp4") {
                    return "video/mp4"
                }
                return type
            }
            return type
        }

        private fun getVideoDuration(path: String): Long {
            val media = MediaMetadataRetriever()
            media.setDataSource(path)

            val duration = media.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)

            return duration!!.toLong()
        }
    }

}