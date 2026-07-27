import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class FileDownloadHandler {
  // کانال باید با نام تعریف شده در MainActivity.kt یکی باشد
  static const _channel = MethodChannel('ir.rahoraz.shajare/storage');

  static Future<String?> downloadFile({
    required String base64Content,
    required String filename,
  }) async {
    // فقط برای پلتفرم اندروید این منطق را اجرا می‌کنیم
    if (!Platform.isAndroid) {
      throw Exception('File download is only supported on Android.');
    }

    try {
      // فراخوانی متد 'saveFile' در کد نیتیو Kotlin
      final String? resultPath = await _channel.invokeMethod('saveFile', {
        'data': base64Content,
        'filename': filename,
      });

      if (kDebugMode) {
        print('[v0] Native code returned path: $resultPath');
      }
      return resultPath;

    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('[v0] Failed to save file via native code: ${e.message}');
      }
      // پرتاب مجدد خطا برای نمایش در UI
      throw Exception('خطا در ذخیره‌سازی فایل: ${e.message}');
    }
  }
}