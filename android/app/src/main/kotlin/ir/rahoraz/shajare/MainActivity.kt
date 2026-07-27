package ir.rahoraz.shajare

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Base64
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "ir.rahoraz.shajare/storage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
                call, result ->
            if (call.method == "saveFile") {
                val base64Data = call.argument<String>("data")
                val filename = call.argument<String>("filename")
                if (base64Data != null && filename != null) {
                    try {
                        val filePath = saveFileToDownloads(base64Data, filename)
                        result.success(filePath)
                    } catch (e: Exception) {
                        result.error("STORAGE_ERROR", "Failed to save file: ${e.message}", null)
                    }
                } else {
                    result.error("INVALID_ARGS", "Missing data or filename", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun saveFileToDownloads(base64Data: String, filename: String): String {
        val decodedBytes = Base64.decode(base64Data, Base64.DEFAULT)
        val resolver = applicationContext.contentResolver

        // ایجاد یک ورودی در MediaStore برای فایل
        val contentValues = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
            put(MediaStore.MediaColumns.MIME_TYPE, getMimeType(filename))
            // برای اندروید 10 (Q) و بالاتر، فایل در پوشه Downloads/Shajare ذخیره می‌شود
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + File.separator + "Shajare")
            }
        }

        // گرفتن URI برای فایل جدید
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
            ?: throw Exception("Failed to create new MediaStore entry.")

        // نوشتن داده‌ها در فایل
        resolver.openOutputStream(uri).use { outputStream ->
            if (outputStream != null) {
                outputStream.write(decodedBytes)
            } else {
                throw Exception("Failed to get output stream.")
            }
        }

        return "Downloads/Shajare/$filename"
    }

    private fun getMimeType(filename: String): String {
        return when (filename.substringAfterLast('.', "").lowercase()) {
            "png" -> "image/png"
            "svg", "html" -> "text/html" // فایل SVG تعاملی ما در واقع HTML است
            "pdf" -> "application/pdf"
            else -> "application/octet-stream"
        }
    }
}