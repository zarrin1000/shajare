import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';

class UpdateChecker {
  // لینک فایل JSON که در مرحله ۲ ساختید (لینک Raw گیت‌هاب را بگذارید)
  static const String updateJsonUrl = "https://rahoraz.ir/shajare-v2/downloads/update_info.json";

  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http.get(Uri.parse(updateJsonUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final latestVersion = data['latest_version'];
        final downloadUrl = data['download_url'];
        final message = data['update_message'];

        if (latestVersion != currentVersion) {
          _showUpdateDialog(context, latestVersion, message, downloadUrl);
        }
      }
    } catch (e) {
      print("خطا در بررسی بروزرسانی: $e");
    }
  }

  static void _showUpdateDialog(BuildContext context, String version, String message, String url) {
    showDialog(
      context: context,
      barrierDismissible: false, // کاربر نمی‌تواند پنجره را ببندد
      builder: (context) => AlertDialog(
        title: const Text('بروزرسانی جدید موجود است!', textAlign: TextAlign.right),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('نسخه $version', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
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
    // نمایش یک دیالوگ ساده در حال دانلود (می‌توانید با CircularProgressIndicator زیباترش کنید)
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      // ۱. درخواست مجوز ذخیره‌سازی (برای اندرویدهای قدیمی‌تر)
      if (await Permission.storage.request().isDenied) {
        Navigator.pop(context);
        return;
      }

      // ۲. دانلود فایل
      final response = await http.get(Uri.parse(url));
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/app-update.apk');
      await file.writeAsBytes(response.bodyBytes);

      Navigator.pop(context); // بستن دیالوگ دانلود

      // ۳. باز کردن فایل برای نصب
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