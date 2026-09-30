// 웹 브라우저용: 지도는 iframe에 띄우고, 포털은 새 탭으로 연다. 휴대폰용은 surface_native.dart.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

class MapSurface {
  MapSurface({required VoidCallback onReady, required void Function(String stop) onStar}) {
    // map.html은 준비되면 부모 창에 'bus-map-ready'를, 말풍선 별표를 누르면 'bus-star:정류장'을 보낸다.
    _listener = ((web.MessageEvent e) {
      final Object? d = e.data.dartify();
      if (d == 'bus-map-ready') onReady();
      if (d is String && d.startsWith('bus-star:')) onStar(d.substring(9));
    }).toJS;
    web.window.addEventListener('message', _listener);
  }

  late final JSFunction _listener;

  // srcdoc iframe은 이 페이지와 같은 출처라서 안쪽 함수를 바로 부를 수 있다.
  final web.HTMLIFrameElement _frame = web.HTMLIFrameElement()
    ..style.border = '0'
    ..style.width = '100%'
    ..style.height = '100%';

  late final Widget view = HtmlElementView.fromTagName(
    tagName: 'div',
    onElementCreated: (Object div) => (div as web.HTMLElement).append(_frame),
  );

  Future<void> load(String html) async => _frame.srcdoc = html.toJS;

  Future<void> run(String js) async => _frame.contentWindow?.callMethod('eval'.toJS, js.toJS);

  void dispose() => web.window.removeEventListener('message', _listener);
}

void openPortal(BuildContext context, String url, {String title = ''}) => web.window.open(url, '_blank');

/// 지도 iframe 위에 떠 있는 Flutter 버튼이 클릭을 받게 한다. 브라우저는 iframe 자리의 클릭을 iframe에 먼저 주므로,
/// 버튼 밑에 보이지 않는 HTML 칸을 한 겹 깔아 그 자리의 클릭을 Flutter로 돌린다(pointer_interceptor 패키지와 같은 방법).
Widget overMap(Widget child) => Stack(
  alignment: Alignment.center,
  children: <Widget>[
    Positioned.fill(child: HtmlElementView.fromTagName(tagName: 'div', isVisible: false)),
    child,
  ],
);
