// 앱을 켜면 지도가 아니라 작은 버스 버튼('실시간 버스 보기')·≡ 메뉴(포털 등 바로가기)가 있는 첫 화면이 뜨는지 검사한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bus_tracker/main.dart';
import 'package:bus_tracker/services/bus_service.dart';
import 'package:bus_tracker/ui/home_page.dart';
import 'package:bus_tracker/ui/map_view.dart';
import 'package:bus_tracker/ui/theme.dart';

void main() {
  testWidgets('첫 화면에 버튼이 있고 지도는 없음', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(ChangeNotifierProvider<BusService>(create: (_) => BusService(), child: const MyApp()));
    expect(find.text('내 시간표'), findsOneWidget);
    // 버스 버튼은 '제주대 캠퍼스'와 ≡ 사이, 시간표보다 위에 있다.
    final Rect bus = tester.getRect(find.byTooltip('실시간 버스 보기'));
    expect(bus.left, greaterThan(tester.getRect(find.text('제주대 캠퍼스')).right));
    expect(bus.right, lessThanOrEqualTo(tester.getRect(find.byTooltip('메뉴')).left));
    expect(bus.bottom, lessThan(tester.getRect(find.text('내 시간표')).top));
    // 바로가기는 처음엔 숨어 있다가 오른쪽 위 ≡ 버튼을 누르면 펼쳐진다.
    expect(find.text('포털 접속하기'), findsNothing);
    await tester.tap(find.byTooltip('메뉴'));
    await tester.pumpAndSettle();
    expect(find.text('포털 접속하기'), findsOneWidget);
    expect(find.text('학사일정'), findsOneWidget);
    expect(find.text('공지사항'), findsOneWidget);
    expect(find.text('학식 메뉴'), findsOneWidget);
    expect(find.text('제주대 순환버스'), findsNothing);
    expect(find.byType(MapView), findsNothing);
  });

  testWidgets('버튼 눌림 애니메이션: 톡 쳐도 줄었다가 제자리로 돌아오고, 누른 동작은 그대로', (WidgetTester tester) async {
    int taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Center(child: Pressable(child: OutlinedButton(onPressed: () => taps++, child: const Text('더 보기')))),
    ));
    double scale() => tester.widget<ScaleTransition>(find.byType(ScaleTransition)).scale.value;
    await tester.tap(find.text('더 보기')); // 누르고 바로 뗀다
    await tester.pump(); // 애니메이션 시계는 다음 화면 갱신부터 돈다
    await tester.pump(const Duration(milliseconds: 60));
    expect(scale(), lessThan(1));
    await tester.pumpAndSettle();
    expect(scale(), 1);
    expect(taps, 1);
  });

  test('정류장 도착: 정문 출발 + 정류장 수(분), 지나간 편은 건너뜀', () {
    expect(nextArrival('A', '학생회관', DateTime(2026, 9, 28, 8, 0)), '08:09'); // 08:05 + 4
    expect(nextArrival('A', '학생회관', DateTime(2026, 9, 28, 8, 9)), '08:09'); // 지금 도착하는 편
    expect(nextArrival('A', '학생회관', DateTime(2026, 9, 28, 8, 10)), '08:29');
    expect(nextArrival('B', '교양동', DateTime(2026, 9, 28, 8, 0)), '08:13'); // 08:10 + 3
    expect(nextArrival('A', '정문', DateTime(2026, 9, 28, 8, 0)), '08:05');
    expect(nextArrival('B', '학생회관', DateTime(2026, 9, 28, 18, 55)), '19:01'); // 막차 18:50 + 11
    expect(nextArrival('B', '학생회관', DateTime(2026, 9, 28, 19, 2)), null);
    expect(nextArrival('A', '학생회관', DateTime(2026, 9, 27, 9, 0)), null); // 일요일
    expect(nextArrival('A', '없는정류장', DateTime(2026, 9, 28, 8, 0)), null);
  });

  testWidgets('버스 버튼: 별표가 없으면 정문, 별표하면 그 정류장(여럿이면 마지막에 별표한 곳)만 나오며 저장된다', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(ChangeNotifierProvider<BusService>(create: (_) => BusService(), child: const MyApp()));
    await tester.pump();
    expect(find.text('정문'), findsOneWidget);
    await toggleStar('중앙도서관'); // 지도 말풍선의 별표가 부르는 것과 같다
    await toggleStar('가짜정류장'); // 없는 정류장은 무시
    await tester.pump();
    expect(find.text('중앙도서관'), findsOneWidget);
    expect(find.text('정문'), findsNothing);
    expect((await SharedPreferences.getInstance()).getStringList('starred_stops'), <String>['중앙도서관']);
    await toggleStar('학생회관');
    await tester.pump();
    expect(find.text('학생회관'), findsOneWidget);
    expect(find.text('중앙도서관'), findsNothing);
    await toggleStar('학생회관');
    await toggleStar('중앙도서관');
    await tester.pump();
    expect(find.text('정문'), findsOneWidget); // 별표를 다 풀면 다시 정문
    expect((await SharedPreferences.getInstance()).getStringList('starred_stops'), <String>[]);
  });

  test('버스 위치는 받은 지 30초 안일 때만 믿는다', () {
    final BusService svc = BusService();
    final DateTime t = DateTime(2026, 9, 28, 9, 30);
    expect(svc.isFresh(t), isFalse); // 한 번도 못 받음
    svc.lastFetchedAt = t.subtract(const Duration(seconds: 10));
    expect(svc.isFresh(t), isTrue);
    svc.lastFetchedAt = t.subtract(const Duration(minutes: 40));
    expect(svc.isFresh(t), isFalse); // 지난 출발 때 받은 것
  });
  test('홈 학사일정 줄: 가장 가까운 남은 일정', () => expect(nextScheduleText(DateTime(2026, 9, 27)), startsWith('진행 중 · ')));
  test('홈 학사일정 줄: 다른 해면 표시 안 함', () => expect(nextScheduleText(DateTime(2027, 3, 1)), isNull));
}
