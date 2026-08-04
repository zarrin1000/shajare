import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';

class UpdateChecker {
  // آدرس API جدید
  static const String updateApiUrl = "https://rahoraz.ir/shajare-v2/api/api_app_update.php";

  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      // دریافت نسخه فعلی اپلیکیشن
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      debugPrint("🔍 Checking for updates...");
      debugPrint("Current Version: $currentVersion");
      
      // اضافه کردن پارامترهای لازم برای API
      final uri = Uri.parse(updateApiUrl).replace(
        queryParameters: {
          'version': currentVersion,
          't': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );

      final response = await http.get(uri);
      
      debugPrint("API Response Status: ${response.statusCode}");
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        debugPrint("API Response: $data");
        
        // بررسی آیا آپدیت موجود است
        if (data['has_update'] == true) {
          final message = data['message'] ?? 'نسخه جدید موجود است';
          final description = data['description'] ?? 'لطفاً اپلیکیشن را بروزرسانی کنید.';
          final downloadUrl = data['download_url'] ?? 'https://rahoraz.ir/shajare-v2/downloads/app-release.apk';
          
          _showUpdateDialog(context, message, description, downloadUrl);
        } else {
          debugPrint("✅ No update needed");
        }
      } else {
        debugPrint("❌ Failed to fetch update info. Status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Error in update check: $e");
      // نمایش خطا به کاربر برای عیب‌یابی
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در بررسی آپدیت: $e')),
      );
    }
  }

  static void _showUpdateDialog(BuildContext context, String title, String message, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title, textAlign: TextAlign.right),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.right),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('بعداً', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _downloadAndInstall(url, context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('دانلود و نصب', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  static Future<void> _downloadAndInstall(String url, BuildContext context) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      if (await Permission.storage.request().isDenied) {
        Navigator.pop(context);
        return;
      }

      final response = await http.get(Uri.parse(url));
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/app-update.apk');
      await file.writeAsBytes(response.bodyBytes);

      Navigator.pop(context);

      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خطا در باز کردن فایل نصب. لطفاً مجوز نصب از منابع ناشناس را بررسی کنید.')),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در دانلود: $e')),
      );
    }
  }
}