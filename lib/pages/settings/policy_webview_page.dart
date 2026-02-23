import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 이용약관 및 개인정보처리방침을 앱 내부 WebView로 표시하는 페이지
class PolicyWebViewPage extends StatefulWidget {
  final String url;
  final String title;

  const PolicyWebViewPage({super.key, required this.url, required this.title});

  @override
  State<PolicyWebViewPage> createState() => _PolicyWebViewPageState();
}

class _PolicyWebViewPageState extends State<PolicyWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    
    // 20초 타임아웃 설정
    _timeoutTimer = Timer(const Duration(seconds: 20), () {
      if (_isLoading && mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '페이지 로딩 시간이 초과되었습니다.\n네트워크 연결을 확인해주세요.';
        });
      }
    });
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      // User-Agent 설정 (일반 브라우저처럼)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            debugPrint('🌐 WebView 페이지 시작: $url');
            if (mounted) {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
            }
          },
          onPageFinished: (String url) {
            debugPrint('✅ WebView 페이지 완료: $url');
            _timeoutTimer?.cancel();
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('❌ WebView 에러: ${error.description} (코드: ${error.errorCode})');
            _timeoutTimer?.cancel();
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage =
                    '페이지를 불러올 수 없습니다.\n${error.description}\n\n에러 코드: ${error.errorCode}';
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            debugPrint('🔗 네비게이션 요청: ${request.url}');
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        elevation: 0,
        actions: [
          // 디버그 정보 표시
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _controller.loadRequest(Uri.parse(widget.url));
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'URL: ${widget.url}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        _timeoutTimer?.cancel();
                        _timeoutTimer = Timer(const Duration(seconds: 20), () {
                          if (_isLoading && mounted) {
                            setState(() {
                              _isLoading = false;
                              _errorMessage = '페이지 로딩 시간이 초과되었습니다.';
                            });
                          }
                        });
                        setState(() {
                          _errorMessage = null;
                          _isLoading = true;
                        });
                        _controller.loadRequest(Uri.parse(widget.url));
                      },
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            )
          else
            WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    '페이지를 불러오는 중...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
