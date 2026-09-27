// 학교 홈페이지 식단표(식당별 한 페이지)를 받아 날짜별 메뉴를 뽑는다.
// 휴대폰 앱은 학교에 바로 묻고, 웹은 중간 서버(bus_relay의 /menu)를 거친다.
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'bus_service.dart' show relayUrl;
import 'notice_service.dart' show unescapeHtml;
import 'school_http_native.dart' if (dart.library.js_interop) 'school_http_web.dart';

const String _school = 'https://www.jejunu.ac.kr/camp/stud/foodmenu/';

/// 식당 이름 → 학교 홈페이지 페이지 이름.
const Map<String, String> cafeterias = <String, String>{
  '백두관': 'firstfixmenu',
  '사라캠퍼스': 'secondfixmenu',
  '생활관 6호관': 'fixfirst',
  '생활관 1호관': 'fixmenu',
  '교수회관': 'fifthmenu',
};

String menuPageUrl(String place) => '$_school$place.htm';

/// 식단표 한 줄. label은 '09/21 (월)'(고정 메뉴 식당은 '월 화 수 목 금'), meals는 (식사 이름, 메뉴들).
class MenuDay {
  const MenuDay(this.label, this.meals);

  final String label;
  final List<(String, List<String>)> meals;
}

final RegExp _br = RegExp(r'<\s*/?\s*br\s*/?\s*>', caseSensitive: false);
final RegExp _tag = RegExp(r'<[^>]*>');
final RegExp _space = RegExp(r'\s+');
final RegExp _row = RegExp(r'<tr[\s\S]*?</tr>');
final RegExp _th = RegExp(r'<th[^>]*>([\s\S]*?)</th>');
final RegExp _td = RegExp(r'<td[^>]*>([\s\S]*?)</td>');

// 칸 속 글자: 태그를 지우고 공백을 하나로. 학교 페이지의 '\7,500원'은 원화 기호가 깨진 것이라 되돌린다.
String _text(String s) =>
    unescapeHtml(s.replaceAll(_tag, ' ')).replaceAll(_space, ' ').replaceAll(r'\', '₩').trim();

/// 식단표 페이지 HTML → 날짜별 메뉴. 식단표가 없으면(오류 페이지·모양 바뀜) FormatException.
List<MenuDay> parseMenu(String html) {
  final int start = html.indexOf('id="plannerWrap"');
  if (start < 0) throw const FormatException('식단표를 찾지 못함');
  // 식당에 따라 표 앞에 같은 내용을 주석으로 남겨 두어서 지운다.
  final String table = html.substring(start, html.indexOf('</table>', start)).replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
  final int body = table.indexOf('<tbody');
  final List<String> names = _th.allMatches(table.substring(0, body)).skip(1).map((Match m) => _text(m[1]!)).toList();
  final List<MenuDay> out = <MenuDay>[];
  for (final Match r in _row.allMatches(table.substring(body))) {
    final String tr = r[0]!;
    final List<String> cells = _td.allMatches(tr).map((Match m) => m[1]!).toList();
    if (cells.isEmpty) continue;
    out.add(MenuDay(_text(_th.firstMatch(tr)?[1] ?? ''), <(String, List<String>)>[
      for (int i = 0; i < cells.length; i++)
        (i < names.length ? names[i] : '', cells[i].split(_br).map(_text).where((String s) => s.isNotEmpty).toList()),
    ]));
  }
  return out;
}

/// '09/21 (월)'이 오늘인지. 식단표에 연도가 없어 월/일만 비교한다.
bool isMenuToday(String label, DateTime today) {
  final Match? m = RegExp(r'^(\d{1,2})/(\d{1,2})').firstMatch(label);
  return m != null && int.parse(m[1]!) == today.month && int.parse(m[2]!) == today.day;
}

final Dio _dio = schoolDio(BaseOptions(connectTimeout: const Duration(seconds: 8), responseType: ResponseType.plain));

Future<List<MenuDay>> fetchMenu(String place) async {
  final Response<String> resp = await _dio.get<String>(kIsWeb ? '$relayUrl/menu?place=$place' : menuPageUrl(place));
  return parseMenu(resp.data ?? '');
}
