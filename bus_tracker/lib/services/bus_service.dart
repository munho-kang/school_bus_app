// A/B 버스 실시간 위치를 3초 간격으로 폴링해 상태를 관리하는 서비스.
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/bus.dart';

// 휴대폰 앱은 학교 서버에 바로 묻는다. 웹은 브라우저 보안 규칙 때문에 중간 서버(bus_relay)를 거친다.
// 다른 중간 서버를 쓰려면: flutter build web --dart-define=BUS_API=https://<중간 서버 주소>
const String relayUrl =
    String.fromEnvironment('BUS_API', defaultValue: 'https://jejunu-bus-relay.bus-relay.workers.dev');
const String _baseUrl = kIsWeb ? relayUrl : 'https://bus.jejunu.ac.kr';

class BusService extends ChangeNotifier {
  final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 8)));

  Bus? busA;
  Bus? busB;
  bool loading = true;
  bool hasError = false;
  String? errorMessage;
  DateTime? lastFetchedAt;

  Timer? _timer;
  bool _stopped = false;

  void start() {
    _stopped = false;
    _timer?.cancel(); // 두 번 불려도 타이머가 겹치지 않게
    fetchNow();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_stopped) fetchNow();
    });
  }

  void stop() {
    _stopped = true;
    _timer?.cancel();
  }

  Future<void> fetchNow() async {
    hasError = false;
    errorMessage = null;
    try {
      final resp = await _dio.get('$_baseUrl/api/location/get');
      final data = resp.data as Map<String, dynamic>;
      final list = (data['buses'] as List?) ?? const [];
      final buses = <Bus>[];
      for (final e in list) {
        if (e is Map) buses.add(Bus.fromJson(Map<String, dynamic>.from(e)));
      }
      busA = buses.firstWhere((b) => b.busId == 'A', orElse: () => busA ?? Bus(busId: 'A', latitude: 0, longitude: 0));
      busB = buses.firstWhere((b) => b.busId == 'B', orElse: () => busB ?? Bus(busId: 'B', latitude: 0, longitude: 0));
      lastFetchedAt = DateTime.now();
      loading = false;
      notifyListeners();
    } catch (e, st) {
      hasError = true;
      errorMessage = e.toString();
      // 한 번도 못 받았어도 '로딩 중...'에 멈추지 않고 시간표(다음 출발)를 보여주게 한다.
      busA ??= Bus(busId: 'A', latitude: 0, longitude: 0);
      busB ??= Bus(busId: 'B', latitude: 0, longitude: 0);
      loading = false;
      notifyListeners();
      debugPrint('BusService fetch error: $e\n$st');
    }
  }

  @override
  void dispose() {
    stop();
    notifyListeners();
    super.dispose();
  }
}
