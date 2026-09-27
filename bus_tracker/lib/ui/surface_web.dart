// 웹 브라우저용: 지도는 iframe에 띄우고, 포털은 새 탭으로 연다. 휴대폰용은 surface_native.dart.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

class MapSurface {
  MapSurface({required VoidCallback onReady}) {
    // map.html은 준비되면 부모 창에 'bus-map-ready'를 보낸다.
    _listener = ((web.MessageEvent e) {
      if (e.data.dartify() == 'bus-map-ready') onReady();
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

  Future<void> run(String js) async =>
      _frame.contentWindow?.callMethod('eval'.toJS, js.toJS);

  void dispose() => web.window.removeEventListener('message', _listener);
}

void openPortal(BuildContext context, String url, {String title = ''}) =>
    web.window.open(url, '_blank');
