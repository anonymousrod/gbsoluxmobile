
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:async';

void main() {
  // Configure status bar to be transparent
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GBSolux Mobile',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  bool _isFirstLaunch = true;
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _rotationAnimation = Tween<double>(begin: 0.0, end: 2 * 3.14159).animate(_animationController);
    _checkFirstLaunch();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkFirstLaunch() async {
    const storage = FlutterSecureStorage();
    final firstLaunch = await storage.read(key: 'first_launch');
    setState(() {
      _isFirstLaunch = firstLaunch == null;
    });

    // Simulate loading time or preload WebView
    await Future.delayed(Duration(seconds: _isFirstLaunch ? 3 : 1));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WebViewScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: _isFirstLaunch
            ? Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blue, width: 4),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/ic_launcher.png',
                    fit: BoxFit.cover,
                  ),
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? _webViewController;
  final String _url = 'https://app.gbsolux.com/login';
  bool _isLoading = true;
  bool _isInitialLoad = true;
  static const platform = MethodChannel('com.example.gbsoluxmobile/file');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(_url)),
              initialOptions: InAppWebViewGroupOptions(
                crossPlatform: InAppWebViewOptions(
                  javaScriptEnabled: true,
                  useShouldOverrideUrlLoading: true,
                  useOnDownloadStart: true,
                  useOnLoadResource: true,
                  cacheEnabled: true,
                  clearCache: false,
                ),
                android: AndroidInAppWebViewOptions(
                  useHybridComposition: true,
                  allowFileAccess: true,
                  allowContentAccess: true,
                ),
              ),
              onWebViewCreated: (controller) {
                _webViewController = controller;
                // Sync cookies if needed
                _syncCookies();
                // Inject JavaScript for file uploads
                _injectFileUploadScript();
              },
              onLoadStart: (controller, url) {
                if (_isInitialLoad) {
                  setState(() {
                    _isLoading = true;
                  });
                }
              },
              onLoadStop: (controller, url) {
                setState(() {
                  _isLoading = false;
                  _isInitialLoad = false;
                });
              },
              onDownloadStartRequest: (controller, downloadStartRequest) async {
                // Handle downloads
                await _handleDownload(downloadStartRequest);
              },
              onConsoleMessage: (controller, consoleMessage) {
                print("WebView Console: ${consoleMessage.message}");
              },
              onReceivedServerTrustAuthRequest: (controller, challenge) async {
                return ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.PROCEED);
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                var uri = navigationAction.request.url!;

                // Intercept file downloads and previews to handle them within the app
                if (_shouldInterceptUrl(uri.toString())) {
                  try {
                    await platform.invokeMethod('downloadFile', {
                      'url': uri.toString(),
                      'filename': _extractFilename(uri.toString()),
                      'mimeType': _guessMimeType(uri.toString()),
                    });
                    return NavigationActionPolicy.CANCEL;
                  } on PlatformException catch (e) {
                    print("Failed to handle file: '${e.message}'.");
                    return NavigationActionPolicy.ALLOW;
                  }
                }

                // Handle external links or OAuth if needed
                return NavigationActionPolicy.ALLOW;
              },
            ),
            if (_isLoading)
              Container(
                color: Colors.white,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncCookies() async {
    // Sync cookies for authentication
    final cookieManager = CookieManager.instance();
    // Example: Set session cookie if stored
    const storage = FlutterSecureStorage();
    final sessionCookie = await storage.read(key: 'session_cookie');
    if (sessionCookie != null) {
      await cookieManager.setCookie(
        url: WebUri(_url),
        name: 'session',
        value: sessionCookie,
      );
    }
  }

  Future<List<String>> _showFileChooser() async {
    final picker = ImagePicker();
    final pickedFile = await showModalBottomSheet<XFile?>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Galerie'),
            onTap: () async {
              final file = await picker.pickImage(source: ImageSource.gallery);
              Navigator.of(context).pop(file);
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Caméra'),
            onTap: () async {
              final file = await picker.pickImage(source: ImageSource.camera);
              Navigator.of(context).pop(file);
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_present),
            title: const Text('Fichier'),
            onTap: () async {
              final result = await FilePicker.platform.pickFiles();
              Navigator.of(context).pop(result?.files.single.xFile);
            },
          ),
        ],
      ),
    );

    if (pickedFile != null) {
      return [pickedFile.path];
    }
    return [];
  }

  Future<void> _handleDownload(DownloadStartRequest downloadStartRequest) async {
    try {
      await platform.invokeMethod('downloadFile', {
        'url': downloadStartRequest.url.toString(),
        'filename': downloadStartRequest.suggestedFilename ?? 'download',
        'mimeType': downloadStartRequest.mimeType,
      });
    } on PlatformException catch (e) {
      print("Failed to download file: '${e.message}'.");
    }
  }

  Future<void> _injectFileUploadScript() async {
    const script = '''
      (function() {
        function overrideFileInput() {
          var inputs = document.querySelectorAll('input[type="file"]');
          for (var i = 0; i < inputs.length; i++) {
            inputs[i].addEventListener('click', function(e) {
              e.preventDefault();
              console.log('File input clicked, opening native chooser');
              // Send message to Flutter
              window.flutter_inappwebview.postMessage('fileChooser');
            });
          }
        }

        // Override on page load
        overrideFileInput();

        // Override on dynamic content changes
        var observer = new MutationObserver(function(mutations) {
          mutations.forEach(function(mutation) {
            if (mutation.type === 'childList') {
              overrideFileInput();
            }
          });
        });

        observer.observe(document.body, {
          childList: true,
          subtree: true
        });
      })();
    ''';

    try {
      await _webViewController?.evaluateJavascript(source: script);
    } catch (e) {
      print("Failed to inject file upload script: $e");
    }
  }

  // Helper method to determine if URL should be intercepted for file handling
  bool _shouldInterceptUrl(String url) {
    // Intercept URLs that are likely file downloads or previews
    // Note: PDF-generating pages are not intercepted to allow WebView to load them and trigger proper downloads
    return url.contains('.jpg') ||
           url.contains('.jpeg') ||
           url.contains('.png') ||
           url.contains('.doc') ||
           url.contains('.docx') ||
           url.contains('.xls') ||
           url.contains('.xlsx');
  }

  // Extract filename from URL
  String _extractFilename(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        return pathSegments.last;
      }
    } catch (e) {
      print("Error extracting filename: $e");
    }
    return 'download';
  }

  // Guess MIME type based on file extension
  String _guessMimeType(String url) {
    final extension = url.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
    }
  }
}
