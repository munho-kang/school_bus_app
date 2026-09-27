// 상태 패널에 표시되는 위치 문구 규칙을 검사한다.
import 'package:flutter_test/flutter_test.dart';
import 'package:bus_tracker/models/bus.dart';
import 'package:bus_tracker/ui/map_view.dart';

void main() {
  Bus bus({String? station, String? next, String? status, bool recent = true}) =>
      Bus(busId: 'A', latitude: 0, longitude: 0, station: station, nextStation: next, status: status, isRecent: recent);

  test('데이터 없음 → 로딩 중', () => expect(locationText(null), '로딩 중...'));
  test('운행 중 → 현재 → 다음', () => expect(locationText(bus(station: '본관', next: '학생회관', status: 'running')), '본관 → 학생회관'));
  test('종점 대기(다음 정류장 없음) → null 대신 대기 중', () => expect(locationText(bus(station: '정문', status: 'waiting')), '정문 (대기 중)'));
  test('다음 정류장이 현재와 같으면 화살표 없음', () => expect(locationText(bus(station: '정문', next: '정문', status: 'running')), '정문'));
  test('운행 안 함 → 다음 정문 출발 시각', () => expect(locationText(bus(station: '정문', recent: false), DateTime(2026, 9, 25, 7, 0)), '다음 출발 08:05'));
  test('출발 시각 정각이면 그 시각', () => expect(locationText(bus(recent: false), DateTime(2026, 9, 25, 13, 5)), '다음 출발 13:05'));
  test('B 코스는 B 시간표', () => expect(nextDepartureText('B', DateTime(2026, 9, 25, 11, 31)), '다음 출발 12:50'));
  test('막차 이후 → 운행 종료', () => expect(nextDepartureText('A', DateTime(2026, 9, 25, 18, 41)), '오늘 운행 종료'));
  test('시간표 23회', () => expect(departures.values.map((List<String> l) => l.length), <int>[23, 23]));
}
