// 앱 첫 화면. 위는 내 시간표(메인), 그 아래 작은 그라데이션 히어로 카드(지도에서 별표한 정류장 도착을 크게, 정문 출발은 작게, 누르면 실시간 지도).
// 화면 끝에서 더 아래로 내리면(휠·손가락) 누른 것처럼 실시간 지도 화면으로 넘어간다.
// 포털·학사일정·공지사항·학식 바로가기는 오른쪽 위 ≡ 버튼으로 펼치는 서랍 안에 있다.
// 포털은 학교 포털을(웹에선 새 탭으로), 나머지는 각 화면을 띄운다.
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/academic_schedule.dart';
import '../models/bus.dart';
import '../services/bus_service.dart';
import 'theme.dart';
import 'map_view.dart';
import 'menu_page.dart';
import 'notice_page.dart';
import 'schedule_page.dart';
import 'timetable.dart';
import 'surface_native.dart' if (dart.library.js_interop) 'surface_web.dart';

/// 다음 정문 출발까지 남은 분. 오늘 막차가 지났으면 null.
/// 버스가 정문에서 늦게 떠나는 중이면 음수.
int? minutesLeft(String busId, DateTime now, [Bus? bus]) {
  final String? t = nextDeparture(busId, now, bus);
  return t == null ? null : minutesUntil(t, now);
}

/// 코스 줄 오른쪽 문구. 한 시간이 넘게 남은 그날 첫차는 '첫차'. (5분 안이면 앞에 '곧 출발' 칩이 붙는다.)
String waitText(String busId, DateTime now, [Bus? bus]) =>
    _waitText(minutesLeft(busId, now, bus), nextDeparture(busId, now) == departures[busId]!.first, now);

/// 별표한 정류장 줄 오른쪽 문구. 정문 출발과 같은 말투('3분 후', '첫차', '운행 종료').
String stopWaitText(String busId, String stop, DateTime now) {
  final String? at = nextArrival(busId, stop, now);
  final bool first = at == nextArrival(busId, stop, DateTime(now.year, now.month, now.day));
  return _waitText(at == null ? null : minutesUntil(at, now), first, now);
}

String _waitText(int? mins, bool first, DateTime now) {
  if (mins == null) return noServiceText(now);
  if (mins < 0) return '${-mins}분 지연';
  if (mins < 60) return '$mins분 후';
  if (first) return '첫차';
  return mins % 60 == 0 ? '${mins ~/ 60}시간 후' : '${mins ~/ 60}시간 ${mins % 60}분 후';
}

/// 가장 가까운 남은 학사일정 한 줄('D-3 · 2학기 중간고사'). 올해 일정이 다 지났거나 해가 다르면 null.
String? nextScheduleText(DateTime today) {
  if (today.year != scheduleYear) return null;
  for (final (String start, String? end, String title) in academicSchedule) {
    final String? badge = scheduleBadge(start, end, today);
    if (badge != null) return '$badge · $title';
  }
  return null;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime _now = DateTime.now();
  late final Timer _tick;
  final ScrollController _scroll = ScrollController();
  double _pull = 0; // 화면 끝에서 손가락을 더 올린 거리.
  bool _inMap = false; // 지도 화면을 두 번 겹쳐 열지 않게.

  @override
  void initState() {
    super.initState();
    loadStarred();
    // 카드 시계와 '몇 분 후'를 갱신한다. 분이 바뀔 때만 다시 그린다.
    // 출발 시각 전후 몇 분 동안만 실제 위치를 받아, 버스가 정문을 떠났는지 확인한다.
    _tick = Timer.periodic(const Duration(seconds: 5), (_) {
      final DateTime n = DateTime.now();
      if (departingNow(n)) context.read<BusService>().fetchNow();
      if (n.minute != _now.minute) setState(() => _now = n);
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    _scroll.dispose();
    super.dispose();
  }

  // 손가락: 화면 끝에 닿은 뒤 손가락을 80 넘게 더 올리면 지도로. (아이폰은 끝에서 화면이 덜 늘어나서, 늘어난 양 대신 손가락 이동 거리를 잰다.)
  bool _onScroll(ScrollNotification n) {
    final DragUpdateDetails? drag = switch (n) {
      ScrollUpdateNotification(:final DragUpdateDetails? dragDetails) => dragDetails,
      OverscrollNotification(:final DragUpdateDetails? dragDetails) => dragDetails,
      _ => null,
    };
    if (n is ScrollStartNotification) _pull = 0;
    if (drag != null && n.metrics.extentAfter == 0) _pull -= drag.delta.dy;
    if (_pull > 80) _openMap();
    return false;
  }

  // 휠·트랙패드: 이미 맨 아래인데 또 내리면 지도로. (끝에선 화면이 안 움직여 스크롤 알림이 없어 휠을 직접 본다.)
  void _onWheel(PointerSignalEvent e) {
    if (e is PointerScrollEvent && e.scrollDelta.dy > 0 && _scroll.hasClients && _scroll.position.extentAfter == 0) {
      _openMap();
    }
  }

  // 폴링은 지도를 보는 동안에만 돈다. push가 끝나는 시점(뒤로가기)에 멈춘다.
  Future<void> _openMap() async {
    if (_inMap) return;
    _inMap = true;
    _pull = 0;
    final BusService svc = context.read<BusService>()..start();
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MapView()));
    svc.stop();
    _inMap = false;
  }

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  // 서랍을 닫고 나서 이동한다(돌아왔을 때 서랍이 열려 있지 않게).
  void _fromDrawer(VoidCallback go) {
    Navigator.of(context).pop();
    go();
  }

  @override
  Widget build(BuildContext context) {
    const String week = '월화수목금토일';
    return Scaffold(
      // 오른쪽 위 ≡ 버튼을 누르면 오른쪽에서 펼쳐지는 바로가기 서랍.
      endDrawer: Drawer(
        backgroundColor: AppColors.bg,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    _MenuRow(
                      icon: Icons.school_outlined,
                      title: '포털 접속하기',
                      subtitle: 'jnuclass.jejunu.ac.kr',
                      external: true,
                      onTap: () => _fromDrawer(() => openPortal(context, 'https://jnuclass.jejunu.ac.kr/')),
                    ),
                    const Divider(indent: 72, endIndent: 16),
                    _MenuRow(
                      icon: Icons.event_note_outlined,
                      title: '학사일정',
                      subtitle: nextScheduleText(_now) ?? '$scheduleYear학년도 학사일정',
                      onTap: () => _fromDrawer(() => _push(const SchedulePage())),
                    ),
                    const Divider(indent: 72, endIndent: 16),
                    _MenuRow(
                      icon: Icons.campaign_outlined,
                      title: '공지사항',
                      subtitle: '학사 · 장학 · 행사 공지',
                      onTap: () => _fromDrawer(() => _push(const NoticePage())),
                    ),
                    const Divider(indent: 72, endIndent: 16),
                    _MenuRow(
                      icon: Icons.restaurant_outlined,
                      title: '학식 메뉴',
                      subtitle: '식당 5곳 · 이번 주 식단',
                      onTap: () => _fromDrawer(() => _push(const MenuPage())),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        // 빈 곳까지 화면 전체가 스크롤을 받는다(지도에서 ← 누른 뒤 커서가 구석에 있어도 내리면 지도로).
        child: Listener(
          onPointerSignal: _onWheel,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) => SingleChildScrollView(
                controller: _scroll,
                // 내용이 화면보다 짧아도 끌어내릴 수 있게(그래야 지도로 넘어간다).
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: math.max(0, box.maxHeight - 40)), // 40 = 위아래 여백
                  // 휴대폰에선 카드를 맨 위에, 넓은 화면(웹)에선 가운데에.
                  child: Align(
                    alignment: box.maxWidth < 600 ? Alignment.topCenter : Alignment.center,
                    // 컴퓨터(웹)처럼 넓은 화면에서 카드가 끝까지 늘어나지 않게 폭을 제한한다.
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        '${_now.month}월 ${_now.day}일 ${week[_now.weekday - 1]}요일',
                                        style: const TextStyle(fontSize: 15, color: AppColors.textSub),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        '제주대 캠퍼스',
                                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                                Builder(
                                  builder: (BuildContext ctx) => Pressable(
                                    scale: 0.9,
                                    child: IconButton(
                                      icon: const Icon(Icons.menu, size: 28),
                                      tooltip: '메뉴',
                                      onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          TimetableCard(now: _now),
                          const SizedBox(height: 16),
                          _DepartureHero(now: _now, onTap: _openMap),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 버스 카드. 지도에서 별표한 정류장이 주인공이다: 정류장마다 코스별 다음 도착을 큰 글씨로,
/// 정문 출발은 그 아래 작은 한 줄로. 별표한 정류장이 없으면 예전처럼 정문 출발을 크게 보여 주고 별표하는 법을 알려 준다.
/// 색이 상태를 말한다 — 둘 다 운행 종료(또는 주말·공휴일)면 회색, 그 밖엔 초록.
class _DepartureHero extends StatelessWidget {
  const _DepartureHero({required this.now, required this.onTap});

  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String clock = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final BusService svc = context.watch<BusService>();
    // 받은 지 오래된 위치는 믿지 않고 시간표대로 보여준다.
    final bool fresh = svc.isFresh(DateTime.now());
    final Map<String, Bus?> buses = <String, Bus?>{'A': fresh ? svc.busA : null, 'B': fresh ? svc.busB : null};
    final List<String> waits = <String>[for (final String id in buses.keys) waitText(id, now, buses[id])];
    final HeroTone tone = waits.every((String w) => w == noServiceText(now)) ? HeroTone.off : HeroTone.live;
    const TextStyle head = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white70);
    return ValueListenableBuilder<List<String>>(
      valueListenable: starredStops,
      builder: (BuildContext context, List<String> stops, _) => HeroCard(
        tone: tone,
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.directions_bus_rounded, size: 18, color: Colors.white70),
                const SizedBox(width: 6),
                Text(stops.isEmpty ? '정문 출발' : '내 정류장 도착', style: head),
                const Spacer(),
                Text(clock, style: head.copyWith(fontFeatures: const <FontFeature>[FontFeature.tabularFigures()])),
              ],
            ),
            if (stops.isEmpty) ...<Widget>[
              for (final String id in buses.keys) ...<Widget>[
                const SizedBox(height: 6),
                _CourseRow(
                  id: id,
                  time: nextDeparture(id, now, buses[id]),
                  mins: minutesLeft(id, now, buses[id]),
                  wait: waitText(id, now, buses[id]),
                  soon: '곧 출발',
                ),
              ],
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 10, 4, 0),
                child: Text(
                  '지도에서 정류장을 누르고 ☆를 누르면 여기에 도착 시간이 나와요',
                  style: TextStyle(fontSize: 12.5, color: Colors.white70),
                ),
              ),
            ] else ...<Widget>[
              for (final String stop in stops) ...<Widget>[
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    const Icon(Icons.star_rounded, size: 18, color: Color(0xFFFFD54F)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(stop, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                for (final String id in buses.keys) ...<Widget>[
                  const SizedBox(height: 6),
                  _CourseRow(
                    id: id,
                    time: nextArrival(id, stop, now),
                    mins: nextArrival(id, stop, now) == null ? null : minutesUntil(nextArrival(id, stop, now)!, now),
                    wait: stopWaitText(id, stop, now),
                    soon: '곧 도착',
                  ),
                ],
              ],
              const SizedBox(height: 10),
              _GateRow(times: <String, String?>{for (final String id in buses.keys) id: nextDeparture(id, now, buses[id])}),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: <Widget>[
                  Text('실시간 버스 보기', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  Spacer(),
                  Icon(Icons.map_outlined, size: 20),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 큰 코스 줄: 번호판, 큰 시각, 오른쪽에 남은 시간(5분 안이면 앞에 흰 바탕 빨간 글씨 칩).
class _CourseRow extends StatelessWidget {
  const _CourseRow({required this.id, required this.time, required this.mins, required this.wait, required this.soon});

  final String id;
  final String? time;
  final int? mins;
  final String wait;
  final String soon; // '곧 출발' · '곧 도착'

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: <Widget>[
          CourseBadge(id, size: 26),
          const SizedBox(width: 12),
          Text(
            time ?? '--:--',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: time == null ? Colors.white60 : Colors.white,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 12),
          // 좁은 휴대폰에서는 오른쪽 문구만 줄여 한 줄을 지킨다.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (mins != null && mins! <= 5) ...<Widget>[
                    Pill(soon, bg: Colors.white, fg: AppColors.danger),
                    const SizedBox(width: 8),
                  ],
                  Text(wait, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 작은 정문 출발 한 줄: '정문 출발', 오른쪽에 코스별 다음 출발 시각.
class _GateRow extends StatelessWidget {
  const _GateRow({required this.times});

  final Map<String, String?> times;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: <Widget>[
          const Expanded(
            child: Text('정문 출발', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70)),
          ),
          for (final MapEntry<String, String?> e in times.entries) ...<Widget>[
            const SizedBox(width: 10),
            CourseBadge(e.key, size: 20),
            const SizedBox(width: 6),
            Text(
              e.value ?? '--:--',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: e.value == null ? Colors.white60 : Colors.white,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.external = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool external;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.97,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, color: AppColors.textSub),
                    ),
                  ],
                ),
              ),
              Icon(
                external ? Icons.open_in_new : Icons.chevron_right,
                color: AppColors.textMuted,
                size: external ? 18 : 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
