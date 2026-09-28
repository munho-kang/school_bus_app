// 학교 공지 페이지에서 제목·분류·부서·날짜를 뽑는 규칙과 공지 화면 동작을 검사한다.
// 견본(fixtures/notice_page1.html)은 2026-09-27에 받은 실제 공지 목록 1페이지.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bus_tracker/services/notice_service.dart';
import 'package:bus_tracker/ui/notice_page.dart';

void main() {
  final String page1 = File('test/fixtures/notice_page1.html').readAsStringSync();

  test('고정 공지 42개 + 새 글 20개', () {
    final List<Notice> all = parseNotices(page1);
    expect(all.where((Notice n) => n.pinned).length, 42);
    expect(all.where((Notice n) => !n.pinned).length, 20);
  });

  test('고정 공지 첫 글', () {
    final Notice n = parseNotices(page1).first;
    expect(n.title, 'JNU Co-PBL [아이디어를 웹으로: 바이브코딩 워크숍]');
    expect(n.category, '행사');
    expect(n.writer, '교수학습지원센터');
    expect(n.date, '2026-09-23');
    expect(n.url, 'https://www.jejunu.ac.kr/ara/noticesurvey/outEvent.htm?act=view&seq=281381');
  });

  test('새 글은 잘리지 않은 전체 제목', () {
    final Notice n = parseNotices(page1).firstWhere((Notice n) => !n.pinned);
    expect(n.title, '[SWEAT OUT] 2026 SWEAT OUT FESTIVAL 참가자 모집');
    expect(n.writer, '글로컬대학사업단');
  });

  test('특수문자(&amp;) 풀기', () {
    expect(parseNotices(page1).any((Notice n) => n.title == '💬 현장실습 Q&A 1:1 카카오톡 채팅방 운영'), isTrue);
  });

  test('목록이 없는 페이지(학교 오류 페이지) → 오류', () {
    expect(() => parseNotices('<html><title>불편을 드려 죄송합니다.</title></html>'), throwsFormatException);
  });

  testWidgets('고정 공지는 접혀 있고 새 글이 보이며, 분류를 누르면 그 분류로 다시 불러옴', (WidgetTester tester) async {
    final List<String?> asked = <String?>[];
    await tester.pumpWidget(MaterialApp(
      home: NoticePage(load: (int page, String? category) async {
        asked.add(category);
        return parseNotices(page1);
      }),
    ));
    await tester.pumpAndSettle();
    expect(find.text('고정 공지 42개'), findsOneWidget);
    expect(find.text('JNU Co-PBL [아이디어를 웹으로: 바이브코딩 워크숍]'), findsNothing);
    expect(find.text('[SWEAT OUT] 2026 SWEAT OUT FESTIVAL 참가자 모집'), findsWidgets); // 학교에 같은 제목 글이 2개 있음

    await tester.tap(find.widgetWithText(ChoiceChip, '학사')); // 공지 딱지에도 '학사'가 있어 분류 버튼만 집는다
    await tester.pumpAndSettle();
    expect(asked, <String?>[null, '320']);
  });

  test('새 글: 오늘부터 2일 전까지', () {
    final DateTime today = DateTime(2026, 9, 23, 15);
    expect(isNewNotice('2026-09-23', today), isTrue);
    expect(isNewNotice('2026-09-21', today), isTrue);
    expect(isNewNotice('2026-09-20', today), isFalse);
    expect(isNewNotice('날짜 없음', today), isFalse);
  });

  testWidgets('머리 카드: 최근 3일 새 공지 개수(고정 공지는 빼고 셈)', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: NoticePage(today: DateTime(2026, 9, 23), load: (int page, String? category) async => parseNotices(page1)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('최근 3일 새 공지'), findsOneWidget);
    expect(find.text('16개'), findsOneWidget);
  });

  testWidgets('불러오기 실패 → 안내와 다시 시도 버튼', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: NoticePage(load: (int page, String? category) async => throw Exception('offline')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('다시 시도'), findsOneWidget);
  });
}
