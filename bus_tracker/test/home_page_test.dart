// 앱을 켜면 지도가 아니라 '포털 접속하기'·'실시간 버스 보기' 버튼이 있는 첫 화면이 뜨는지 검사한다.
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
    expect(find.text('포털 접속하기'), findsOneWidget);
    expect(find.text('실시간 버스 보기'), findsOneWidget);
    expect(find.text('학사일정'), findsOneWidget);
    expect(find.text('공지사항'), findsOneWidget);
    expect(find.text('학식 메뉴'), findsOneWidget);
    expect(find.text('내 시간표'), findsOneWidget);
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
  test('안내판: 막차 뒤 운행 종료', () => expect(waitText('B', DateTime(2026, 9, 28, 19, 0)), '운행 종료'));
  test('홈 학사일정 줄: 가장 가까운 남은 일정', () => expect(nextScheduleText(DateTime(2026, 9, 27)), startsWith('진행 중 · ')));
  test('홈 학사일정 줄: 다른 해면 표시 안 함', () => expect(nextScheduleText(DateTime(2027, 3, 1)), isNull));
}
