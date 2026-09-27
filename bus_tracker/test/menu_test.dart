// 학교 식단표에서 날짜별 메뉴를 뽑는 규칙과 학식 화면 동작을 검사한다.
// 견본은 2026-09-27에 받은 실제 페이지: 백두관(09/21 주, 추석 연휴 포함), 생활관 1호관(요일 없는 고정 메뉴).
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bus_tracker/services/menu_service.dart';
import 'package:bus_tracker/ui/menu_page.dart';

void main() {
  final String baekdu = File('test/fixtures/menu_baekdu.html').readAsStringSync();
  final String dorm1 = File('test/fixtures/menu_dorm1.html').readAsStringSync();

  test('백두관: 5일, 날짜·식사 이름·메뉴', () {
    final List<MenuDay> week = parseMenu(baekdu);
    expect(week.map((MenuDay d) => d.label), <String>['09/21 (월)', '09/22 (화)', '09/23 (수)', '09/24 (목)', '09/25 (금)']);
    expect(week.first.meals.map(((String, List<String>) m) => m.$1), <String>['중식1', '중식2', '석식']);
    expect(week.first.meals.first.$2.first, '돼지고기간장불고기');
    expect(week.first.meals.first.$2.last, '양배추샐러드&소스');
    expect(week[3].meals.map(((String, List<String>) m) => m.$2), <List<String>>[<String>['추석연휴'], <String>['추석연휴'], <String>['추석연휴']]);
  });

  test('생활관 1호관: 요일 대신 고정 메뉴 한 줄', () {
    final List<MenuDay> week = parseMenu(dorm1);
    expect(week, hasLength(1));
    expect(week.first.label, '월 화 수 목 금 토 일');
    expect(week.first.meals.first.$1, '메뉴');
    expect(week.first.meals.first.$2.first, "1. 오늘의 정식[Today's Meal]");
  });

  test('오늘 판별: 월/일만 비교', () {
    expect(isMenuToday('09/21 (월)', DateTime(2026, 9, 21)), isTrue);
    expect(isMenuToday('09/21 (월)', DateTime(2026, 9, 22)), isFalse);
    expect(isMenuToday('월 화 수 목 금', DateTime(2026, 9, 21)), isFalse);
  });

  test('식단표가 없는 페이지 → 오류', () {
    expect(() => parseMenu('<html><title>불편을 드려 죄송합니다.</title></html>'), throwsFormatException);
  });

  testWidgets('오늘 표시, 식당을 바꾸면 그 식당을 불러옴', (WidgetTester tester) async {
    final List<String> asked = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: MenuPage(
        today: DateTime(2026, 9, 22),
        load: (String place) async {
          asked.add(place);
          return parseMenu(baekdu);
        },
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('오늘'), findsOneWidget);
    expect(find.textContaining('돈코츠라멘'), findsOneWidget);

    await tester.tap(find.text('사라캠퍼스'));
    await tester.pumpAndSettle();
    expect(asked, <String>['firstfixmenu', 'secondfixmenu']);
  });

  testWidgets('불러오기 실패 → 안내와 다시 시도 버튼', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: MenuPage(load: (String place) async => throw Exception('offline'))));
    await tester.pumpAndSettle();
    expect(find.text('다시 시도'), findsOneWidget);
  });
}
