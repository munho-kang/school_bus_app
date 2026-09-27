// 학사일정 화면의 상태 표시(D-day·진행 중) 규칙과 화면 구성을 검사한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bus_tracker/data/academic_schedule.dart';
import 'package:bus_tracker/ui/schedule_page.dart';

void main() {
  final DateTime today = DateTime(2026, 9, 27);

  test('지난 일정 → 표시 없음', () => expect(scheduleBadge('2026-09-21', null, today), isNull));
  test('오늘 하루 일정 → D-day', () => expect(scheduleBadge('2026-09-27', null, today), 'D-day'));
  test('다가오는 일정 → D-n', () => expect(scheduleBadge('2026-09-29', null, today), 'D-2'));
  test('기간 안 → 진행 중', () => expect(scheduleBadge('2026-09-01', '2026-09-30', today), '진행 중'));
  test('기간 마지막 날도 진행 중', () => expect(scheduleBadge('2026-09-01', '2026-09-27', today), '진행 중'));
  test('기간 끝남 → 표시 없음', () => expect(scheduleBadge('2026-09-01', '2026-09-26', today), isNull));
  test('날짜 표시(하루)', () => expect(scheduleDateText('2026-09-29', null), '09.29(화)'));
  test('날짜 표시(기간, 해 넘김)', () => expect(scheduleDateText('2026-12-28', '2027-01-18'), '12.28(월) ~ 01.18(월)'));
  test('데이터 59개, 날짜 형식 올바름', () {
    expect(academicSchedule.length, 59);
    for (final (String s, String? e, String _) in academicSchedule) {
      expect(DateTime.parse(s).year, scheduleYear);
      if (e != null) expect(DateTime.parse(e).isBefore(DateTime.parse(s)), isFalse);
    }
  });

  testWidgets('월별 제목과 일정이 보임', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: SchedulePage(today: today)));
    await tester.pumpAndSettle();
    expect(find.text('9월'), findsOneWidget);
    expect(find.text('2학기 수업일수 1/4선'), findsOneWidget);
    expect(find.text('D-2'), findsWidgets);
  });
}
