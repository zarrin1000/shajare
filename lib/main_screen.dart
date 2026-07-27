import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'file_download_handler.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _showLoginButton = false;
  bool _showChatButton = false;
  bool _hasError = false;
  String _errorMessage = '';
  String _lastAttemptedUrl = '';
  int _retryCount = 0;
  final int _maxRetries = 3;
  bool _isRetrying = false;

  final String _chatUrl = 'https://rahoraz.ir/shajare-v2/mobile_chat.php';
  final String _homeUrl = 'https://rahoraz.ir/shajare-v2/home.php';
  final String _loginUrl = 'https://rahoraz.ir/shajare-v2/login.php';
  final String _indexUrl = 'https://rahoraz.ir/shajare-v2/index.php';

  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _requestInitialPermissions() async {
    await [
      Permission.location,
      Permission.microphone,
      Permission.camera,
    ].request();
  }

  Future<void> _autoRetry(String url) async {
    if (_retryCount >= _maxRetries || !mounted) return;
    _retryCount++;
    _isRetrying = true;
    if (kDebugMode) print('[v0] Auto-retry attempt $_retryCount of $_maxRetries for URL: $url');
    await Future.delayed(Duration(seconds: _retryCount));
    if (mounted) {
      try {
        await _controller.loadRequest(Uri.parse(url));
      } catch (e) {
        if (kDebugMode) print('[v0] Retry failed: $e');
      }
    }
    _isRetrying = false;
  }

  bool _isRetryableError(int errorCode) {
    const retryableErrors = [-7, -8, -109];
    const nonRetryableErrors = [-2, -6];
    if (nonRetryableErrors.contains(errorCode)) return false;
    return retryableErrors.contains(errorCode);
  }

  Future<void> _handleFileDownload(String base64Content, String filename) async {
    try {
      final filePath = await FileDownloadHandler.downloadFile(
        base64Content: base64Content,
        filename: filename,
      );
      if (mounted && filePath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فایل با موفقیت در پوشه زیر ذخیره شد:\n$filePath'),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _initializeApp() async {
    await _requestInitialPermissions();
    final prefs = await SharedPreferences.getInstance();
    final bool wasPreviouslyLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    String initialUrl = wasPreviouslyLoggedIn ? _indexUrl : _homeUrl;
    _lastAttemptedUrl = initialUrl;

    final WebViewController controller = WebViewController();

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() {
              _showLoginButton = false;
              _showChatButton = false;
              if (!_isRetrying) { _hasError = false; _errorMessage = ''; _retryCount = 0; }
              _lastAttemptedUrl = url;
            });
          },
          onWebResourceError: (WebResourceError error) {
            if (error.isForMainFrame != true) return;
            if (kDebugMode) print('[v0] Main frame error: ${error.errorCode} - ${error.description}');
            if (_isRetryableError(error.errorCode) && _retryCount < _maxRetries) {
              _autoRetry(_lastAttemptedUrl);
              return;
            }
            if (mounted) {
              String errorMsg;
              switch (error.errorCode) {
                case -2: errorMsg = 'عدم دسترسی به سرور\n\nلطفاً اتصال اینترنت خود را بررسی کنید.'; break;
                case -6: errorMsg = 'سرور در دسترس نیست\n\nلطفاً بعداً تلاش کنید.'; break;
                case -7: errorMsg = 'زمان اتصال به پایان رسید\n\nلطفاً اتصال اینترنت خود را بررسی کنید.'; break;
                default: errorMsg = 'خطا در بارگذاری صفحه\n\nکد خطا: ${error.errorCode}';
              }
              setState(() { _hasError = true; _errorMessage = errorMsg; _isLoading = false; _isRetrying = false; });
            }
          },
          onPageFinished: (String url) {
            if (mounted) setState(() { _isLoading = false; _retryCount = 0; _isRetrying = false; _hasError = false; });
          },
        ),
      )
      ..addJavaScriptChannel('AppControl', onMessageReceived: (JavaScriptMessage message) => _handleMessageFromWeb(message.message))
      ..addJavaScriptChannel(
        'FileDownloader',
        onMessageReceived: (JavaScriptMessage message) async {
          try {
            final parts = message.message.split('|');
            if (parts.length >= 2) await _handleFileDownload(parts[0], parts[1]);
          } catch (e) {
            if (kDebugMode) print('[v0] Error processing file download message: $e');
          }
        },
      )
      ..setUserAgent('ShajareV2-MobileApp/1.0');

    if (controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;
      if (kDebugMode) AndroidWebViewController.enableDebugging(true);
      await androidController.setMediaPlaybackRequiresUserGesture(false);

      androidController.setOnPlatformPermissionRequest((request) async {
        final Map<String, Permission> permissionMap = {};
        for (final type in request.types) {
          switch (type.name) {
            case 'geolocation':
              permissionMap['location'] = Permission.location;
              break;
            case 'audioCapture':
              permissionMap['microphone'] = Permission.microphone;
              break;
            case 'videoCapture':
              permissionMap['camera'] = Permission.camera;
              break;
          }
        }
        if (permissionMap.isNotEmpty) {
          final statuses = await permissionMap.values.toList().request();
          bool allGranted = true;
          bool anyPermanentlyDenied = false;
          String? deniedPermissionName;
          for (var entry in statuses.entries) {
            if (!entry.value.isGranted) {
              allGranted = false;
              if (entry.value.isPermanentlyDenied) {
                anyPermanentlyDenied = true;
                for (var permEntry in permissionMap.entries) {
                  if (permEntry.value == entry.key) {
                    deniedPermissionName = permEntry.key;
                    break;
                  }
                }
                break;
              }
            }
          }
          if (anyPermanentlyDenied && deniedPermissionName != null) {
            if (mounted) _showPermissionDialog(deniedPermissionName);
            request.deny();
          } else if (allGranted) {
            request.grant();
          } else {
            request.deny();
          }
        } else {
          request.grant();
        }
      });

      // ★★★ شروع بخش کلیدی و بازگردانده شده برای موقعیت مکانی ★★★
      await androidController.setGeolocationPermissionsPromptCallbacks(
        onShowPrompt: (request) async {
          final status = await Permission.location.request();

          if (status.isGranted) {
            return const GeolocationPermissionsResponse(
              allow: true,
              retain: true,
            );
          } else if (status.isPermanentlyDenied) {
            if (mounted) {
              _showPermissionDialog('location');
            }
          }

          return const GeolocationPermissionsResponse(
            allow: false,
            retain: false,
          );
        },
      );
      // ★★★ پایان بخش کلیدی برای موقعیت مکانی ★★★

      await androidController.setOnShowFileSelector((params) async {
        final result = await FilePicker.platform.pickFiles();
        if (result != null && result.files.single.path != null) {
          return [File(result.files.single.path!).uri.toString()];
        }
        return [];
      });
    }

    _controller = controller;
    await _controller.loadRequest(Uri.parse(initialUrl));
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _showPermissionDialog(String permissionType) async {
    String permissionName = '';
    switch (permissionType) {
      case 'location': permissionName = 'موقعیت مکانی'; break;
      case 'microphone': permissionName = 'میکروفون'; break;
      case 'camera': permissionName = 'دوربین'; break;
      default: permissionName = 'این ویژگی';
    }
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('نیاز به دسترسی'),
          content: Text('برای استفاده از $permissionName، لطفاً از تنظیمات برنامه، دسترسی لازم را فعال کنید.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('بستن')),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('باز کردن تنظیمات'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _retryLoading() async {
    if (mounted) setState(() { _isLoading = true; _hasError = false; });
    try {
      await _controller.loadRequest(Uri.parse(_lastAttemptedUrl));
    } catch (e) {
      if (mounted) setState(() { _hasError = true; _errorMessage = 'خطا در بارگذاری صفحه'; _isLoading = false; });
    }
  }

  Future<void> _handleMessageFromWeb(String message) async {
    final prefs = await SharedPreferences.getInstance();
    if (message.startsWith('store_biometric_token:')) {
      await prefs.setString('biometric_token', message.substring('store_biometric_token:'.length));
      return;
    }
    if (message == 'trigger_biometric_auth') {
      await _handleBiometricAuthRequest();
      return;
    }
    bool shouldShowLogin = false, shouldShowChat = false;
    switch (message) {
      case 'show_login': shouldShowLogin = true; await prefs.setBool('isLoggedIn', false); break;
      case 'show_chat': shouldShowChat = true; await prefs.setBool('isLoggedIn', true); break;
      case 'hide_all': await prefs.setBool('isLoggedIn', true); break;
    }
    if (mounted) setState(() { _showLoginButton = shouldShowLogin; _showChatButton = shouldShowChat; });
  }

  Future<void> _handleBiometricAuthRequest() async {
    final prefs = await SharedPreferences.getInstance();
    final String? biometricToken = prefs.getString('biometric_token');
    if (biometricToken == null) {
      await _controller.runJavaScript("onBiometricAuthFailure('اثر انگشت فعال نشده است. لطفاً یک بار با رمز عبور وارد شوید تا این قابلیت فعال شود.');");
      return;
    }
    bool authenticated = false;
    try {
      if (await _auth.canCheckBiometrics && await _auth.isDeviceSupported()) {
        authenticated = await _auth.authenticate(
          localizedReason: 'برای ورود به حساب کاربری، هویت خود را تایید کنید',
          options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
        );
      } else {
        await _controller.runJavaScript("onBiometricAuthFailure('دستگاه شما از احراز هویت بیومتریک پشتیبانی نمی‌کند.');");
        return;
      }
    } on PlatformException catch (e) {
      await _controller.runJavaScript("onBiometricAuthFailure('خطایی در احراز هویت رخ داد: ${e.code}');");
      return;
    }
    if (authenticated) {
      await _controller.runJavaScript("onBiometricAuthSuccess('$biometricToken');");
    } else {
      await _controller.runJavaScript("onBiometricAuthFailure('احراز هویت لغو شد.');");
    }
  }

  Future<bool> _onWillPop() async {
    if (await _controller.canGoBack()) {
      _controller.goBack();
      return false;
    }
    return true;
  }

  Widget _buildShimmerButton({required String label, required IconData icon, required VoidCallback onPressed}) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF764BA2), Color(0xFF667eea)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: const Color(0xFF764BA2).withAlpha(153), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.white.withAlpha(204),
        highlightColor: Colors.white,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white, size: 24),
          label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            elevation: 0,
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0d1117),
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              if (!_isLoading && !_hasError)
                WebViewWidget(
                  controller: _controller,
                  gestureRecognizers: {
                    Factory<VerticalDragGestureRecognizer>(() => VerticalDragGestureRecognizer()),
                    Factory<HorizontalDragGestureRecognizer>(() => HorizontalDragGestureRecognizer()),
                  },
                ),
              if (_isLoading)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      if (_isRetrying && _retryCount > 0) ...[
                        const SizedBox(height: 16),
                        Text('تلاش مجدد... ($_retryCount از $_maxRetries)', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ],
                  ),
                ),
              if (_hasError)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 80),
                        const SizedBox(height: 24),
                        Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5)),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: _retryLoading,
                          icon: const Icon(Icons.refresh),
                          label: const Text('تلاش مجدد'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF667eea),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Builder(builder: (context) {
          if (_showLoginButton) {
            return _buildShimmerButton(
              label: 'ورود / ثبت نام',
              icon: Icons.login,
              onPressed: () => _controller.loadRequest(Uri.parse(_loginUrl)),
            );
          }
          if (_showChatButton) {
            return Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: _buildShimmerButton(
                  label: 'چت آنلاین',
                  icon: Icons.chat,
                  onPressed: () => _controller.loadRequest(Uri.parse(_chatUrl)),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }),
      ),
    );
  }
}