// 앱을 켜면 지도가 아니라 '실시간 버스 보기'·≡ 메뉴(포털 등 바로가기) 버튼이 있는 첫 화면이 뜨는지 검사한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bus_tracker/main.dart';
import 'package:bus_tracker/models/bus.dart';
import 'package:bus_tracker/services/bus_service.dart';
import 'package:bus_tracker/ui/home_page.dart';
import 'package:bus_tracker/ui/map_view.dart';
import 'package:bus_tracker/ui/theme.dart';

void main() {
  testWidgets('첫 화면에 버튼이 있고 지도는 없음', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(ChangeNotifierProvider<BusService>(create: (_) => BusService(), child: const MyApp()));
    expect(find.text('실시간 버스 보기'), findsOneWidget);
    expect(find.text('내 시간표'), findsOneWidget);
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

  testWidgets('지도에서 별표한 정류장이 지도 버튼 위에 나오고, 다시 누르면 빠지며 저장된다', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(ChangeNotifierProvider<BusService>(create: (_) => BusService(), child: const MyApp()));
    await tester.pump();
    expect(find.textContaining('☆를 누르면'), findsOneWidget);
    await toggleStar('중앙도서관'); // 지도 말풍선의 별표가 부르는 것과 같다
    await toggleStar('가짜정류장'); // 없는 정류장은 무시
    await tester.pump();
    expect(find.text('중앙도서관'), findsOneWidget);
    expect(find.textContaining('☆를 누르면'), findsNothing);
    // 별표 정류장이 크게(제목 '내 정류장 도착'), 정문 출발은 작은 한 줄로 아래에
    expect(find.text('내 정류장 도착'), findsOneWidget);
    expect(tester.getTopLeft(find.text('중앙도서관')).dy, lessThan(tester.getTopLeft(find.text('정문 출발')).dy));
    expect((await SharedPreferences.getInstance()).getStringList('starred_stops'), <String>['중앙도서관']);
    // 별표 줄이 '실시간 버스 보기' 버튼보다 위에 있다
    expect(tester.getTopLeft(find.text('중앙도서관')).dy, lessThan(tester.getTopLeft(find.text('실시간 버스 보기')).dy));
    await toggleStar('중앙도서관');
    await tester.pump();
    expect(find.text('중앙도서관'), findsNothing);
    expect(find.text('정문 출발'), findsOneWidget); // 별표가 없으면 다시 정문 출발이 제목
    expect((await SharedPreferences.getInstance()).getStringList('starred_stops'), <String>[]);
  });

  test('정류장 남은 시간: 정문 출발과 같은 말투', () {
    expect(stopWaitText('A', '학생회관', DateTime(2026, 9, 28, 8, 0)), '9분 후'); // 08:09 도착
    expect(stopWaitText('A', '학생회관', DateTime(2026, 9, 28, 6, 0)), '첫차');
    expect(stopWaitText('B', '학생회관', DateTime(2026, 9, 28, 11, 45)), '1시간 16분 후'); // 12:50 + 11 = 13:01
    expect(stopWaitText('B', '학생회관', DateTime(2026, 9, 28, 19, 2)), '운행 종료');
    expect(stopWaitText('A', '학생회관', DateTime(2026, 9, 27, 9, 0)), '주말 운행 없음');
  });

  test('안내판: 새벽엔 첫차', () => expect(waitText('A', DateTime(2026, 9, 28, 0, 53)), '첫차'));
  test('안내판: 2분 안도 몇 분 후', () => expect(waitText('A', DateTime(2026, 9, 28, 8, 3)), '2분 후'));
  test('곧 출발: 5분 안인지', () {
    expect(minutesLeft('A', DateTime(2026, 9, 28, 8, 0)), 5);
    expect(minutesLeft('A', DateTime(2026, 9, 28, 7, 59)), 6);
    expect(minutesLeft('B', DateTime(2026, 9, 28, 19, 0)), null);
  });
  test('안내판: 몇 분 후', () => expect(waitText('B', DateTime(2026, 9, 28, 8, 0)), '10분 후'));
  test('안내판: 낮 공백은 시간·분', () => expect(waitText('A', DateTime(2026, 9, 28, 11, 21)), '1시간 19분 후'));
  test('안내판: 정문에서 늦게 떠나면 몇 분 지연', () {
    final Bus gate = Bus(busId: 'A', latitude: 0, longitude: 0, station: '정문', status: 'waiting', isRecent: true);
    expect(waitText('A', DateTime(2026, 9, 28, 8, 47), gate), '2분 지연');
  });
  test('안내판: 주말은 운행 없음', () => expect(waitText('A', DateTime(2026, 9, 27, 9, 0)), '주말 운행 없음'));
  test('버스 위치는 받은 지 30초 안일 때만 믿는다', () {
    final BusService svc = BusService();
    final DateTime t = DateTime(2026, 9, 28, 9, 30);
    expect(svc.isFresh(t), isFalse); // 한 번도 못 받음
    svc.lastFetchedAt = t.subtract(const Duration(seconds: 10));
    expect(svc.isFresh(t), isTrue);
    svc.lastFetchedAt = t.subtract(const Duration(minutes: 40));
    expect(svc.isFresh(t), isFalse); // 지난 출발 때 받은 것
  });
  test('안내판: 막차 뒤 운행 종료', () => expect(waitText('B', DateTime(2026, 9, 28, 19, 0)), '운행 종료'));
  test('홈 학사일정 줄: 가장 가까운 남은 일정', () => expect(nextScheduleText(DateTime(2026, 9, 27)), startsWith('진행 중 · ')));
  test('홈 학사일정 줄: 다른 해면 표시 안 함', () => expect(nextScheduleText(DateTime(2027, 3, 1)), isNull));
}
