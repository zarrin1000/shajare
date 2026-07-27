import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class _MainScreenState extends State<MainScreen> {

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _handleFileDownload(String base64Content, String filename, String fileType) async {
    try {
      // Request storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        await _showPermissionDialog('storage');
        return;
      }

      // Get Downloads directory
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');

        // Fallback if primary path doesn't exist
        if (!await downloadsDir.exists()) {
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            downloadsDir = Directory('${externalDir.parent.parent.parent.parent}/Download');
          }
        }
      } else if (Platform.isIOS) {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      if (downloadsDir == null) {
        throw Exception('Cannot access Downloads folder');
      }

      // Create Shajare subdirectory
      final shajareDir = Directory('${downloadsDir.path}/Shajare');
      if (!await shajareDir.exists()) {
        await shajareDir.create(recursive: true);
      }

      // Decode base64 and save file
      final bytes = base64Decode(base64Content);
      final file = File('${shajareDir.path}/$filename');
      await file.writeAsBytes(bytes);

      // Show success notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فایل با موفقیت ذخیره شد:\n${shajareDir.path}/$filename'),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.green,
          ),
        );
      }

      if (kDebugMode) {
        print('[v0] File saved to: ${shajareDir.path}/$filename');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در ذخیره فایل: ${e.toString()}'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
      if (kDebugMode) {
        print('[v0] File download error: $e');
      }
    }
  }

  @override
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
          // ... existing navigation code ...
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _showLoginButton = false;
                _showChatButton = false;
                if (!_isRetrying) {
                  _hasError = false;
                  _errorMessage = '';
                  _retryCount = 0;
                }
                _lastAttemptedUrl = url;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            // ... existing error handling ...
          },
          onHttpError: (HttpResponseError error) {
            // ... existing http error handling ...
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _retryCount = 0;
                _isRetrying = false;
                _hasError = false;
              });
            }
          },
        ),
      )
      ..addJavaScriptChannel(
        'AppControl',
        onMessageReceived: (JavaScriptMessage message) {
          _handleMessageFromWeb(message.message);
        },
      )
      ..addJavaScriptChannel(
        'FileDownloader',
        onMessageReceived: (JavaScriptMessage message) async {
          try {
            final parts = message.message.split('|');
            if (parts.length >= 3) {
              final base64Content = parts[0];
              final filename = parts[1];
              final fileType = parts[2];
              await _handleFileDownload(base64Content, filename, fileType);
            }
          } catch (e) {
            if (kDebugMode) {
              print('[v0] Error processing file download message: $e');
            }
          }
        },
      )
      ..setUserAgent('ShajareV2-MobileApp/1.0');

    if (controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;

      if (kDebugMode) {
        AndroidWebViewController.enableDebugging(true);
      }

      await androidController.setMediaPlaybackRequiresUserGesture(false);

      androidController.setOnPlatformPermissionRequest((request) async {
        // ... existing permission handling code ...
      });

      await androidController.setGeolocationPermissionsPromptCallbacks(
        onShowPrompt: (request) async {
          // ... existing geolocation handling ...
        },
      );

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

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleMessageFromWeb(String message) async {
  }

  // ... rest of existing code ...
}
