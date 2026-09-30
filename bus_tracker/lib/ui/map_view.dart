// KAKAO 지도를 WebView(웹에선 iframe)로 띄우고 A/B 버스 위치를 JS에 전달하는 화면.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../services/bus_service.dart';
import '../models/bus.dart';
import 'theme.dart';
import 'surface_native.dart' if (dart.library.js_interop) 'surface_web.dart';

/// 코스별 정문 출발 시각(시:분, 24시간제).
const Map<String, List<String>> departures = <String, List<String>>{
  'A': <String>[
    '08:05',
    '08:25',
    '08:45',
    '09:30',
    '10:05',
    '10:25',
    '10:45',
    '11:20',
    '12:40',
    '13:05',
    '13:25',
    '13:45',
    '14:30',
    '15:05',
    '15:25',
    '15:45',
    '16:10',
    '16:40',
    '17:20',
    '17:40',
    '18:00',
    '18:20',
    '18:40',
  ],
  'B': <String>[
    '08:10',
    '08:30',
    '08:50',
    '09:40',
    '10:10',
    '10:30',
    '10:50',
    '11:30',
    '12:50',
    '13:10',
    '13:30',
    '13:50',
    '14:40',
    '15:10',
    '15:30',
    '15:50',
    '16:20',
    '16:50',
    '17:30',
    '17:50',
    '18:10',
    '18:30',
    '18:50',
  ],
};

/// 출발 시각이 지나도 버스가 정문에 서 있으면 이만큼(분)까지는 그 편을 계속 보여준다.
/// 위치가 끊기거나 늦게 들어와도 이 시간이 지나면 시간표대로 넘어간다.
const int lateGrace = 5;

/// 실시간 위치로 볼 때 정문에서 출발을 기다리는 중인지.
bool atGate(Bus? bus) => bus?.isRecent == true && bus!.station == '정문' && bus.status == 'waiting';

/// 평일에 걸린 공휴일(대체공휴일 포함). 주말과 공휴일엔 버스가 다니지 않는다.
/// 2026년 관공서 공휴일에서 옮김(노동절·제헌절 포함). 해가 바뀌면 새해 공휴일을 더 넣어야 한다.
const Set<String> holidays = <String>{
  '2026-01-01', '2026-02-16', '2026-02-17', '2026-02-18', '2026-03-02', '2026-05-01', '2026-05-05', '2026-05-25',
  '2026-06-03', '2026-07-17', '2026-08-17', '2026-09-24', '2026-09-25', '2026-10-05', '2026-10-09', '2026-12-25',
};

/// 오늘 버스가 쉬는 까닭('주말' · '공휴일'). 다니는 날이면 null.
String? dayOff(DateTime now) {
  if (now.weekday >= DateTime.saturday) return '주말';
  final String ymd = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  return holidays.contains(ymd) ? '공휴일' : null;
}

/// 오늘 더 출발할 버스가 없을 때 짧은 문구.
String noServiceText(DateTime now) => dayOff(now) == null ? '운행 종료' : '${dayOff(now)} 운행 없음';

/// 출발 시각까지 남은 분('08:45'). 이미 지났으면 음수.
int minutesUntil(String t, DateTime now) =>
    int.parse(t.substring(0, 2)) * 60 + int.parse(t.substring(3)) - (now.hour * 60 + now.minute);

/// 다음 정문 출발 시각('08:45'). 오늘 막차가 지났거나 주말·공휴일이면 null.
/// 시각이 지났어도 버스가 아직 정문에 서 있으면(최대 [lateGrace]분) 그 편을 그대로 둔다.
/// 출발 시각 그 1분 안에 버스가 이미 정문을 떠났으면 그 편은 건너뛴다('0분 후'가 남지 않게).
String? nextDeparture(String busId, DateTime now, [Bus? bus]) {
  if (dayOff(now) != null) return null;
  final bool waiting = atGate(bus);
  final bool left = bus?.isRecent == true && !waiting;
  for (final String t in departures[busId] ?? const <String>[]) {
    final int d = minutesUntil(t, now);
    if (d > 0 || (d == 0 && !left) || (waiting && d >= -lateGrace)) return t;
  }
  return null;
}

/// 방금 출발 시각이 된(또는 지난 지 [lateGrace]분 안인) 편이 있는지. 이때만 실제 위치를 확인하면 된다.
bool departingNow(DateTime now) =>
    dayOff(now) == null &&
    departures.values.any(
      (List<String> ts) => ts.any((String t) => minutesUntil(t, now) <= 0 && minutesUntil(t, now) >= -lateGrace),
    );

/// 운행 중이 아닐 때 보여줄 다음 정문 출발 시각. 막차가 지났으면 운행 종료, 주말·공휴일이면 운행 없음.
String nextDepartureText(String busId, DateTime now) {
  final String? t = nextDeparture(busId, now);
  if (t == null) return dayOff(now) == null ? '오늘 운행 종료' : noServiceText(now);
  return '다음 출발 $t';
}

/// 상태 패널에 보여줄 위치 문구. 다음 정류장이 없을 때(종점 대기) 'null'이 찍히지 않게 한다.
String locationText(Bus? bus, [DateTime? now]) {
  if (bus == null) return '로딩 중...';
  if (bus.isRecent != true) return nextDepartureText(bus.busId, now ?? DateTime.now());
  if (bus.nextStation != null && bus.nextStation != bus.station) {
    return '${bus.station} → ${bus.nextStation}';
  }
  final String here = bus.station ?? '운행중';
  return bus.status == 'waiting' ? '$here (대기 중)' : here;
}

class MapView extends StatefulWidget {
  const MapView({super.key});
  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  late final MapSurface _surface;
  bool _ready = false;
  String? _lastSig;
  StreamSubscription<Position>? _locSub;
  Position? _lastPos;

  @override
  void initState() {
    super.initState();
    _surface = MapSurface(
      onReady: () {
        if (mounted && !_ready) {
          _ready = true;
          _push(context.read<BusService>());
          if (_lastPos != null) _pushLocation(_lastPos!);
          // 정류장을 누르면 뜨는 도착 예정 말풍선이 쓸 시간표와 오늘 쉬는 까닭.
          final DateTime now = DateTime.now();
          final String off = jsonEncode(dayOff(now) == null ? null : noServiceText(now));
          _surface.run('window.setSchedule && window.setSchedule(${jsonEncode(departures)}, $off);').onError((_, _) {});
        }
      },
    );
    _load();
    _startMyLocation();
  }

  // 내 위치: 권한을 받은 뒤 5m 이상 움직일 때마다 지도(JS)에 넘긴다.
  Future<void> _startMyLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      _locSub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
          ).listen((Position p) {
            _lastPos = p;
            _pushLocation(p);
          }, onError: (Object e) => debugPrint('location error: $e'));
    } catch (e) {
      debugPrint('location unavailable: $e');
    }
  }

  void _pushLocation(Position p) {
    _surface
        .run('window.showMyLocation && window.showMyLocation(${p.latitude}, ${p.longitude}, ${p.accuracy});')
        .onError((_, _) {});
  }

  Future<void> _load() async {
    _ready = false;
    _lastSig = null;
    await _surface.load(await rootBundle.loadString('assets/web/map.html'));
  }

  static Map<String, dynamic> serializeOne(Bus b) => <String, dynamic>{
    'busId': b.busId,
    'latitude': b.latitude,
    'longitude': b.longitude,
    'station': b.station,
    'nextStation': b.nextStation,
    'status': b.status,
    'progress': b.progress,
    'isRecent': b.isRecent,
  };

  void _push(BusService svc) {
    if (!_ready) return;
    final Bus a = svc.busA ?? Bus(busId: 'A', latitude: 0, longitude: 0);
    final Bus b = svc.busB ?? Bus(busId: 'B', latitude: 0, longitude: 0);
    // 옛날 위치는 운행 중으로 보이지 않게(화살표 없음) 넘긴다.
    final bool fresh = svc.isFresh(DateTime.now());
    Map<String, dynamic> one(Bus x) => serializeOne(x)..['isRecent'] = fresh && x.isRecent == true;
    // 좌표뿐 아니라 상태(대기·운행)가 바뀌어도 다시 보낸다.
    final String json = jsonEncode([one(a), one(b)]);
    if (json == _lastSig) return;
    _lastSig = json;
    _surface.run('window.receiveBusUpdate && window.receiveBusUpdate($json);').onError((_, _) {});
  }

  @override
  Widget build(BuildContext context) {
    final BusService svc = context.watch<BusService>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _push(svc);
    });

    // 상단이 초록 패널이라 시계·배터리 아이콘을 밝게.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          children: <Widget>[
            _surface.view,
            Positioned(top: 0, left: 0, right: 0, child: statusPanel(svc)),
            Positioned(
              bottom: 24,
              left: 16,
              child: circleButton(Icons.arrow_back, () => Navigator.of(context).maybePop(), '뒤로'),
            ),
            Positioned(bottom: 24, right: 16, child: circleButton(Icons.refresh, _load, '지도 새로고침')),
          ],
        ),
      ),
    );
  }

  // 홈 정문 출발 카드가 그대로 옮겨 온 초록 패널. 배경은 시계·노치 뒤까지 깔고, 글자는 안전 영역부터 놓는다.
  Widget statusPanel(BusService svc) {
    final bool fresh = svc.isFresh(DateTime.now());
    return HeroCard(
      tone: HeroTone.live,
      padding: EdgeInsets.zero,
      radius: const BorderRadius.vertical(bottom: Radius.circular(22)),
      child: SafeArea(
        bottom: false,
        minimum: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Row(
          children: <Widget>[
            Expanded(
              child: busCard(id: 'A', bus: svc.busA, fresh: fresh),
            ),
            Container(
              width: 1,
              height: 32,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: Colors.white.withValues(alpha: 0.3),
            ),
            Expanded(
              child: busCard(id: 'B', bus: svc.busB, fresh: fresh),
            ),
          ],
        ),
      ),
    );
  }

  Widget busCard({required String id, Bus? bus, required bool fresh}) {
    final bool online = fresh && bus?.isRecent == true;
    // 번호판 옆에 현재 위치(또는 다음 출발), 끝에 켜진/꺼진 점.
    return Row(
      children: <Widget>[
        CourseBadge(id, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            online || bus == null ? locationText(bus) : nextDepartureText(id, DateTime.now()),
            style: TextStyle(
              fontSize: 14,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: online || bus == null ? Colors.white : Colors.white70,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        // 켜진 점 = 최근 위치를 받는 중, 꺼진 점 = 운행 안 함.
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: online ? Colors.white : Colors.white.withValues(alpha: 0.3),
            boxShadow: online ? const <BoxShadow>[BoxShadow(color: Colors.white70, blurRadius: 6)] : null,
          ),
        ),
      ],
    );
  }

  Widget circleButton(IconData icon, VoidCallback onTap, String tooltip) {
    return overMap(
      Tooltip(
        message: tooltip,
        child: Pressable(
          scale: 0.9,
          child: Material(
            color: AppColors.card,
            shape: const CircleBorder(),
            elevation: 3,
            shadowColor: Colors.black26,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Icon(icon, size: 24, color: AppColors.text),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _locSub?.cancel();
    _surface.dispose();
    _lastSig = null;
    super.dispose();
  }
}
