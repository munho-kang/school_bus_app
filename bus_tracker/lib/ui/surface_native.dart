// 휴대폰(iOS/Android)용: 지도와 포털을 앱 안의 WebView로 띄운다. 웹용은 surface_web.dart.
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'theme.dart';

class MapSurface {
  MapSurface({required VoidCallback onReady})
    : _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(AppColors.bg)
        ..addJavaScriptChannel('Ready', onMessageReceived: (_) => onReady());

  final WebViewController _controller;

  late final Widget view = WebViewWidget(controller: _controller);

  // Kakao 지도 SDK는 페이지 주소가 https일 때만 스크립트·타일을 https로 받는다.
  // file://로 열면 http로 받으려다 iOS(ATS)에 차단돼 지도가 비어 보이므로,
  // 학교 도메인(이 앱키가 등록된 도메인)을 기준 주소로 삼아 https 페이지처럼 띄운다.
  Future<void> load(String html) => _controller.loadHtmlString(html, baseUrl: 'https://bus.jejunu.ac.kr/');

  Future<void> run(String js) => _controller.runJavaScript(js);

  void dispose() {}
}

void openPortal(BuildContext context, String url, {String title = '제주대학교 포털'}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: pageBar(title),
        body: WebViewWidget(
          controller: WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..loadRequest(Uri.parse(url)),
        ),
      ),
    ),
  );
}

/// 휴대폰 WebView는 위에 놓인 Flutter 버튼의 클릭을 가로채지 않아 그대로 둔다(웹용은 surface_web.dart).
Widget overMap(Widget child) => child;
