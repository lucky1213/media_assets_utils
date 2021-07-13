package com.lucky1213.media_assets_utils

import android.content.ContentValues
import android.content.Context
import android.media.MediaMetadataRetriever
import android.os.Build
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import java.io.File
import java.util.*

class MediaStoreUtils {
    companion object{
        //针对非系统影音资源文件夹
        fun insertIntoMediaStore(context: Context, saveFile: File) {
            val createTime = System.currentTimeMillis()
            val contentResolver = context.contentResolver
            val type = getMimeType(saveFile)
            val isVideo = type == "video/mp4"

            val values = ContentValues()
            values.put(MediaStore.MediaColumns.TITLE, saveFile.name)
            values.put(MediaStore.MediaColumns.DISPLAY_NAME, saveFile.name)
            values.put(MediaStore.MediaColumns.DATE_MODIFIED, createTime)
            values.put(MediaStore.MediaColumns.DATE_ADDED, createTime)
            if (Build.VERSION.SDK_INT >= 29) {
                //值一样，但是还是用常量区分对待
                values.put(
                        if (isVideo) MediaStore.Video.VideoColumns.DATE_TAKEN else MediaStore.Images.ImageColumns.DATE_TAKEN,
                        createTime
                )
                if (!isVideo) values.put(MediaStore.Images.ImageColumns.ORIENTATION, 0)
                if (isVideo) values.put(MediaStore.MediaColumns.DURATION, getVideoDuration(saveFile.absolutePath))
            }
            values.put(MediaStore.MediaColumns.SIZE, saveFile.length())
            values.put(MediaStore.MediaColumns.MIME_TYPE, type)
            //插入
            contentResolver.insert(
                    if (isVideo) MediaStore.Video.Media.EXTERNAL_CONTENT_URI else MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    values
            )
        }

        fun getFileExtension(file: File): String {
            return getFileExtensionFromUrl(file.path)
        }

        fun getFileExtensionFromUrl(url: String): String {
            var extension = MimeTypeMap.getFileExtensionFromUrl(url)

            if (extension == null) {
                val position: Int = url.lastIndexOf(".")
                if (position > 0)
                    extension = url.substring(position + 1).toLowerCase(Locale.ROOT)
            }
            return extension
        }

        private fun getMimeType(file: File): String? {
            val type: String?
            val extension = getFileExtension(file)
            type = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension.toLowerCase(Locale.ROOT))

            if (type == null) {
                if (extension == "jpg" || extension == "jpeg") {
                    return "image/jpeg"
                } else if (extension == "png") {
                    return "image/png"
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

        // 插入.nomedia禁止MediaStore收录
        fun ignoreMedia(dir: File) {
            val nomedia = File(dir, ".nomedia")
            if (!nomedia.exists()) {
                nomedia.createNewFile()
            }
        }
    }

}