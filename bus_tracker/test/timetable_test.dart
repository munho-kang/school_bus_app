// 시간표: 저장 형식이 그대로 되살아나는지, 표 시간 범위가 맞는지, 수업을 넣으면(시각은 바퀴로 굴려) 표에 나타나고 다시 켜도 남아 있는지 검사한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bus_tracker/ui/timetable.dart';

void main() {
  const Lesson a = Lesson(title: '자료구조', days: <int>[1, 3], start: 630, end: 705);
  const Lesson b = Lesson(title: '운영체제', days: <int>[2], start: 13 * 60, end: 14 * 60 + 15);

  test('저장했다 불러오면 그대로', () {
    expect(decodeLessons(encodeLessons(<Lesson>[a])).single.toJson(), a.toJson());
  });

  test('표 범위: 10:30~11:45, 13:00~14:15 → 10시~15시', () => expect(hourRange(<Lesson>[a, b]), (10, 15)));
  test('과목마다 다른 색, 같은 과목은 같은 색', () {
    final List<Lesson> ls = <Lesson>[a, b, a];
    expect(colorIndex(ls, '자료구조'), 0);
    expect(colorIndex(ls, '운영체제'), 1);
  });
  test('정시에 끝나면 그 시까지만', () => expect(hourRange(<Lesson>[b.copyEnd(14 * 60)]), (13, 14)));

  testWidgets('수업을 넣으면 표에 나오고 저장된다', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: TimetableCard(now: DateTime(2026, 9, 28))))));
    await tester.pumpAndSettle();
    expect(find.textContaining('아직 수업이 없어요'), findsOneWidget);

    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '과목'), '자료구조');
    await tester.tap(find.text('월'));
    await tester.tap(find.text('수'));
    await tester.drag(find.text('9').first, const Offset(0, -32)); // 시작 바퀴를 한 칸 위로 → 10:00
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('자료구조'), findsNWidgets(2)); // 월·수 두 칸
    final String saved = (await SharedPreferences.getInstance()).getString('timetable')!;
    expect(decodeLessons(saved).single.days, <int>[1, 3]);
    expect((decodeLessons(saved).single.start, decodeLessons(saved).single.end), (600, 720)); // 시작을 10:00으로 → 끝은 저절로 12:00

    // 칸을 눌러 삭제하면 비고, 저장도 비워진다.
    await tester.tap(find.text('자료구조').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(find.textContaining('아직 수업이 없어요'), findsOneWidget);
    expect(decodeLessons((await SharedPreferences.getInstance()).getString('timetable')!), isEmpty);
  });

  testWidgets('지금 시각 선: 평일 표 시간 안에만 보인다', (WidgetTester tester) async {
    Future<Finder> at(DateTime now) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'timetable': encodeLessons(<Lesson>[a, b])});
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: TimetableCard(key: UniqueKey(), now: now)))));
      await tester.pumpAndSettle();
      return find.byKey(const ValueKey<String>('now-line'));
    }

    expect(await at(DateTime(2026, 9, 28, 11)), findsOneWidget); // 월 11시
    expect(await at(DateTime(2026, 9, 28, 8)), findsNothing); // 표(10~15시) 밖
    expect(await at(DateTime(2026, 9, 27, 11)), findsNothing); // 일요일
  });
}

extension on Lesson {
  Lesson copyEnd(int e) => Lesson(title: title, days: days, start: start, end: e);
}
