// 앱을 켜면 지도가 아니라 '포털 접속하기'·'실시간 버스 보기' 버튼이 있는 첫 화면이 뜨는지 검사한다.
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:bus_tracker/main.dart';
import 'package:bus_tracker/services/bus_service.dart';
import 'package:bus_tracker/ui/home_page.dart';
import 'package:bus_tracker/ui/map_view.dart';

void main() {
  testWidgets('첫 화면에 버튼이 있고 지도는 없음', (WidgetTester tester) async {
    await tester.pumpWidget(ChangeNotifierProvider<BusService>(create: (_) => BusService(), child: const MyApp()));
    expect(find.text('포털 접속하기'), findsOneWidget);
    expect(find.text('실시간 버스 보기'), findsOneWidget);
    expect(find.text('학사일정'), findsOneWidget);
    expect(find.text('공지사항'), findsOneWidget);
    expect(find.text('학식 메뉴'), findsOneWidget);
    expect(find.text('제주대 순환버스'), findsNothing);
    expect(find.byType(MapView), findsNothing);
  });

  test('안내판: 새벽엔 첫차', () => expect(waitText('A', DateTime(2026, 9, 28, 0, 53)), '첫차'));
  test('안내판: 2분 안이면 곧 출발', () => expect(waitText('A', DateTime(2026, 9, 28, 8, 3)), '곧 출발'));
  test('안내판: 몇 분 후', () => expect(waitText('B', DateTime(2026, 9, 28, 8, 0)), '10분 후'));
  test('안내판: 낮 공백은 시간·분', () => expect(waitText('A', DateTime(2026, 9, 28, 11, 21)), '1시간 19분 후'));
  test('안내판: 막차 뒤 운행 종료', () => expect(waitText('B', DateTime(2026, 9, 28, 19, 0)), '운행 종료'));
  test('홈 학사일정 줄: 가장 가까운 남은 일정', () => expect(nextScheduleText(DateTime(2026, 9, 27)), startsWith('진행 중 · ')));
  test('홈 학사일정 줄: 다른 해면 표시 안 함', () => expect(nextScheduleText(DateTime(2027, 3, 1)), isNull));
}
