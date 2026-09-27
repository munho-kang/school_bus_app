// 학교 홈페이지 공지 목록을 받아 제목·분류·부서·날짜를 뽑는다.
// 휴대폰 앱은 학교에 바로 묻고, 웹은 중간 서버(bus_relay의 /notice)를 거친다.
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'bus_service.dart' show relayUrl;
import 'school_http_native.dart' if (dart.library.js_interop) 'school_http_web.dart';

const String _school = 'https://www.jejunu.ac.kr/ara/noticesurvey/outEvent.htm';

/// 분류 이름 → 학교 홈페이지 분류 번호. null은 전체.
const Map<String, String?> noticeCategories = <String, String?>{
  '전체': null,
  '학사': '320',
  '수업': '321',
  '장학': '323',
  '등록': '322',
  '일반': '203',
  '행사': '200',
  '봉사': '197',
  '자료실': '239',
};

class Notice {
  const Notice({required this.title, required this.category, required this.writer, required this.date, required this.url, required this.pinned});

  final String title;
  final String category;
  final String writer;
  final String date;
  final String url;

  /// 목록 맨 위에 늘 붙어 있는 고정 공지인지.
  final bool pinned;
}

/// HTML 특수문자 표기(&amp; 등)를 원래 글자로 되돌린다.
String unescapeHtml(String s) => s
    .replaceAllMapped(RegExp(r'&#(\d+);'), (Match m) => String.fromCharCode(int.parse(m[1]!)))
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&');

final RegExp _row = RegExp(r'<tr[\s\S]*?</tr>');
final RegExp _category = RegExp(r'article-category[^>]*>([^<]*)');
final RegExp _link = RegExp(r'act=view&amp;seq=(\d+)"[^>]*?title="([^"]*)"');
final RegExp _writerDate = RegExp(r'hidden-md-down"\s*>\s*([^<]*?)\s*</td>\s*<td class="nowrap">([^<]+)</td>');

/// 학교 공지 페이지 HTML → 공지 목록. 목록 표가 없으면(오류 페이지·모양 바뀜) FormatException.
List<Notice> parseNotices(String html) {
  final int start = html.indexOf('<tbody');
  if (start < 0) throw const FormatException('공지 목록을 찾지 못함');
  final String body = html.substring(start, html.indexOf('</tbody>', start));
  final List<Notice> out = <Notice>[];
  for (final Match r in _row.allMatches(body)) {
    final String tr = r[0]!;
    final Match? link = _link.firstMatch(tr);
    if (link == null) continue;
    final Match? wd = _writerDate.firstMatch(tr);
    out.add(Notice(
      title: unescapeHtml(link[2]!).trim(),
      category: _category.firstMatch(tr)?[1]?.trim() ?? '',
      writer: wd?[1] ?? '',
      date: wd?[2]?.trim() ?? '',
      url: '$_school?act=view&seq=${link[1]}',
      pinned: tr.contains('[공지]'),
    ));
  }
  return out;
}

final Dio _dio = schoolDio(BaseOptions(connectTimeout: const Duration(seconds: 8), responseType: ResponseType.plain));

Future<List<Notice>> fetchNotices(int page, String? category) async {
  final Response<String> resp = await _dio.get<String>(
    kIsWeb ? '$relayUrl/notice' : _school,
    queryParameters: <String, Object>{'page': page, 'category': ?category},
  );
  return parseNotices(resp.data ?? '');
}
