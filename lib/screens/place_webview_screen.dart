import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// WebView 가 세로 드래그(스크롤) 제스처를 부모 시트에 뺏기지 않도록.
final Set<Factory<OneSequenceGestureRecognizer>> _webviewGestures = {
  Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
};

/// 네이버 장소 검색 모바일 URL (별점/메뉴/리뷰가 나오는 페이지).
String naverPlaceUrl(String query) =>
    'https://m.map.naver.com/search2/search.naver?query=${Uri.encodeComponent(query)}';

/// 웹뷰가 처리 못하는 커스텀 스킴(앱 열기·길찾기 등)을 외부 앱으로 넘긴다.
/// http/https 는 웹뷰가 그대로 로드하고, 그 외(nmap://, intent://, market:// 등)는
/// 외부 앱으로 실행 후 웹뷰 이동을 막아 에러 페이지가 뜨지 않게 한다.
NavigationDecision _handleNavigation(NavigationRequest request) {
  final uri = Uri.tryParse(request.url);
  final scheme = uri?.scheme.toLowerCase();
  if (scheme == 'http' || scheme == 'https') {
    return NavigationDecision.navigate;
  }
  if (uri != null) {
    // 외부 앱으로 열기 (실패해도 웹뷰 에러 페이지는 피한다).
    launchUrl(uri, mode: LaunchMode.externalApplication)
        .catchError((_) => false);
  }
  return NavigationDecision.prevent;
}

/// 하단 바텀시트 안에서 쓰는 인라인 WebView (화면 이동 없이 상세 표시).
class PlaceDetailSheet extends StatefulWidget {
  const PlaceDetailSheet({super.key, required this.query});

  final String query;

  @override
  State<PlaceDetailSheet> createState() => _PlaceDetailSheetState();
}

class _PlaceDetailSheetState extends State<PlaceDetailSheet> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: _handleNavigation,
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ))
      ..loadRequest(Uri.parse(naverPlaceUrl(widget.query)));
  }

  Future<void> _openExternal() async {
    await launchUrl(
      Uri.parse(
          'https://map.naver.com/v5/search/${Uri.encodeComponent(widget.query)}'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 고정 높이 시트(화면의 90%). DraggableScrollableSheet 를 쓰지 않아
    // WebView 가 세로 스크롤 제스처를 온전히 가져간다.
    final height = MediaQuery.of(context).size.height * 0.9;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          // 드래그 핸들
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(widget.query,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new, size: 20),
                  tooltip: '네이버 지도 앱에서 열기',
                  onPressed: _openExternal,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: WebViewWidget(
              controller: _controller,
              gestureRecognizers: _webviewGestures,
            ),
          ),
        ],
      ),
    );
  }
}

/// 앱을 나가지 않고 네이버 장소 상세(별점/메뉴/리뷰/사진)를 보여주는 WebView 화면.
///
/// 네이버 지도 모바일 검색 페이지(m.map.naver.com)를 임베드한다.
class PlaceWebViewScreen extends StatefulWidget {
  const PlaceWebViewScreen({super.key, required this.query});

  /// 검색어 (식당 이름 등).
  final String query;

  @override
  State<PlaceWebViewScreen> createState() => _PlaceWebViewScreenState();
}

class _PlaceWebViewScreenState extends State<PlaceWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  /// 네이버 지도 모바일 검색 URL (별점/메뉴/리뷰가 나오는 페이지).
  String get _url =>
      'https://m.map.naver.com/search2/search.naver?query=${Uri.encodeComponent(widget.query)}';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _handleNavigation,
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(_url));
  }

  /// 외부 네이버 지도 앱으로 열기 (길찾기 등 필요할 때).
  Future<void> _openExternal() async {
    final uri = Uri.parse(
        'https://map.naver.com/v5/search/${Uri.encodeComponent(widget.query)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.query, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: '네이버 지도 앱에서 열기',
            onPressed: _openExternal,
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
