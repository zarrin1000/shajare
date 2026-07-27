import 'package:flutter/material.dart';
import 'package:shajare/main_screen.dart';
import 'update_checker.dart'; // اضافه کردن فایل چک‌کننده بروزرسانی

void main() {
  // اطمینان از اینکه ویجت‌های فلاتر قبل از اجرای پلاگین‌ها مقداردهی شده‌اند
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    
    // بررسی بروزرسانی با ۲ ثانیه تاخیر برای اطمینان از لود شدن کامل رابط کاربری
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        UpdateChecker.checkForUpdate(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'شجره نامه',
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      home: const MainScreen(),
    );
  }
}